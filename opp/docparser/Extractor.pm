package Extractor;
use strict;
use warnings;
use Memoize;
use List::Util qw/min max reduce first/;
use Statistics::Lite 'stddev';
use Text::Names qw/samePerson parseNames reverseName/;
use Cwd 'abs_path';
use File::Basename;
use Getopt::Std;
use Encode;
use JSON;
use FindBin;
use lib "$FindBin::Bin/.";
use util::Functools 'allof';
use util::Io;
use util::String;
use util::Estimator 'makeLabeler';
use rules::Keywords;

my $path = dirname(abs_path(__FILE__));

sub new {
    my ($class, $xmlfile) = @_;
    my $self = {
        xmlfile => $xmlfile,
        # read from xmlfile:
        converters => [],
        fromOCR => 0,
        fromHTML => 0,
        sourceauthors => [],
        anchortext => '',
        linkcontext => '',
        sourcecontent => '',
        url => '',
        # will be set by Extractor:
        #doctype => {}, # 'REVIEW' => 0.7, ...
        chunks => [],
        pages => [],
        numpages => 0,
        numwords => 0,
        fontsize => 1,
        linespacing => 1,
        geometry => {},
        marginals => [],
        footnotes => [],
        authors => [],
        title => '',
        abstract => '',
        bibliography => [],
        text => '',
        confidence => 1,
    };
    bless $self, $class;
    $self->init($xmlfile) if $xmlfile;
    return $self;
}

sub say { 1; }

my $verbosity = 0;
sub verbosity {
    my $self = shift;
    if (@_) {
        $verbosity = shift;
        no warnings 'redefine';
        if ($verbosity) {
            *say = sub {
                return if $_[0] > $verbosity;
                my ($v, $txt, @txt) = @_;
                print "\n" while ($txt =~ s/^\n//);  
                print "[] ", $txt, @txt, "\n";
            };
        }
        else {
            *say = sub { 1; };
        }
    }
    return $verbosity;
}

sub pushlink(\@@) {
    my ($arr, $first, @rest) = @_;
    return unless $first;
    if (@$arr) {
        $arr->[-1]->{next} = $first;
        $first->{prev} = $arr->[-1];
    }
    push @$arr, $first, @rest;
}

sub removelink {
    my $el = shift;
    if ($el->{prev}) {
        $el->{prev}->{next} = $el->{next};
    }
    if ($el->{next}) {
        $el->{next}->{prev} = $el->{prev};
    }
    $el->{_REMOVED} = 1;
}

sub init {
    my ($self, $xmlfile) = @_;
    say(3, "\ninitialising Extractor: $xmlfile");

    $self->{xmlfile} = $xmlfile;
    my $xml = readfile($xmlfile);
    say(6, $xml);

    my @converters = $xml =~ /<converter>(.+?)<\/converter>/g;
    $self->{converters} = \@converters;
    $self->{fromOCR} = 1 if grep(/OCR/, @converters);
    $self->{fromHTML} = 1 if grep(/wkhtmltopdf/, @converters);
    my @sourceauthors = $xml =~ /<sourceauthor>(.+?)<\/sourceauthor>/g;
    $self->{sourceauthors} = \@sourceauthors;
    if ($xml =~ /<url>(.+?)<\/url>/s) {
        $self->{url} = $1;
    }
    if ($xml =~ /<anchortext>(.+?)<\/anchortext>/s) {
        $self->{anchortext} = $1;
    }
    if ($xml =~ /<linkcontext>(.+?)<\/linkcontext>/s) {
        $self->{linkcontext} = $1;
    }
    if ($xml =~ /<sourcecontent>(.+?)<\/sourcecontent>/s) {
        $self->{sourcecontent} = $1;
    }
    if ($xml =~ /<url>(.+?)<\/url>/s) {
        $self->{url} = $1;
    }

    say(3, "collecting text chunks");

    my %fontsizes;
    my @pages = split /<page number=/, $xml;
    my @chunks;
    my $pageno = 0; # first element of @pages isn't a page
    my $charno = 1;
    my $lineno = 0;
    for my $page (@pages) {
        while ($page =~/(<fontspec.+?>)/g) {
            my $el = elem($1);
            $fontsizes{$el->('id')} = $el->('size');
        }
        my @pagechunks;
        while ($page =~ /(<text.*?>.*?<\/text>)/isgo) {
            my $chunk = xml2chunk($1);
            next unless $chunk->{height};
            $chunk->{fsize} = $fontsizes{$chunk->{font}} || 1;
            # yes, sometimes blocks have unspec'd font: 49803
            $chunk->{id} = $lineno++;
            $chunk->{textpos} = $charno;
            $charno += length($chunk->{plaintext});
            $chunk->{doc} = $self;
            pushlink @pagechunks, $chunk;
        }
        next unless @pagechunks;
        pushlink @{$self->{pages}}, pageinfo(\@pagechunks, $pageno);
        pushlink @chunks, @pagechunks;
        $pageno++;
    }
        
    die "pdf conversion failed" unless @chunks;

    $self->{numpages} = $#pages;
    $self->{chunks} = \@chunks;

    $self->fontinfo();
    $self->get_geometry();
    $self->strip_coverpages();
    $self->strip_marginals();
    $self->strip_footnotes();
    $self->get_text();
    $self->{numwords} = () = ($self->{text} =~ /\s\w\w/g);
    #$self->get_doctype();

}

sub elem {
    my $str = shift;
    return sub {
       my $attr = shift;
       if ($attr) {
           return $str =~ /$attr="(.*?)"/ && $1;
       }
       if ($str =~ /<.+?>(.*)<.+>/) {
           return $1;
       }
    };
}

sub xml2chunk {
    my $str = shift;
    my $el = elem($str);
    my $chunk = {
        'top'     => $el->('top'),
        'left'    => $el->('left'),
        'width'   => $el->('width'),
        'height'  => $el->('height'),
        'font'    => $el->('font'),
        'col'     => $el->('col') || 1,
        'text'    => $el->(),
    };
    $chunk->{right} = $chunk->{left} + $chunk->{width};
    $chunk->{bottom} = $chunk->{top} + $chunk->{height};
    $chunk->{plaintext} = plaintext($chunk->{text});
    return $chunk;
}

sub pageinfo {
    my ($chunks, $pageno) = @_;

    my %page;
    $page{number} = $pageno;
    $page{left} = min(map { $_->{left} } @$chunks);
    $page{right} = max(map { $_->{right} } @$chunks);
    $page{width} = $page{right} - $page{left};
    $page{top} = min(map { $_->{top} } @$chunks);
    $page{bottom} = max(map { $_->{bottom} } @$chunks);
    $page{height} = $page{bottom} - $page{top};
    $page{chunks} = $chunks;
    $page{doc} = $chunks->[0]->{doc};
    if ($verbosity > 1) { # for debugging
        $page{text} = $chunks->[0]->{text}.'...';
    }

    foreach (@$chunks) {
        $_->{page} = \%page;
    }

    return \%page;
}

sub fontinfo {
    my $self = shift;

    # find default font-size and line-spacing:
    my %fs_freq;
    my %sp_freq;
    foreach my $ch (@{$self->{chunks}}) {
        next if length($ch->{plaintext}) < 10;
        # ignore footnotes:
        next if $ch->{bottom} / $ch->{page}->{bottom} > 0.7;
        # ignore endnotes and references:
        last if $self->{numpages} > 2 &&
            $ch->{page}->{number} / $self->{numpages} > 0.7;
        $fs_freq{$ch->{fsize}} = 0 unless defined $fs_freq{$ch->{fsize}};
        $fs_freq{$ch->{fsize}}++;
        next unless $ch->{prev};
        my $spacing = ($ch->{top} - $ch->{prev}->{top}) / $ch->{height};
        $spacing = sprintf "%.1f", $spacing;
        $sp_freq{$spacing}++;
    }

    my @sizes = sort { $fs_freq{$a} <=> $fs_freq{$b} } keys(%fs_freq);
    $self->{fontsize} = (@sizes) ? $sizes[-1] : 10;
    say(3, "default font size $self->{fontsize}");

    my @spacings = sort { $sp_freq{$a} <=> $sp_freq{$b} } keys(%sp_freq);
    $self->{linespacing} = (@spacings && $spacings[-1] > 1) ? $spacings[-1] : 1;
    say(3, "default line spacing $self->{linespacing}");

    # relativise font-sizes so that 0 = default, +2 = [120-130)%, etc.
    # For OCR'ed documents, font-sizes are unreliable, so we generally
    # round +3 to +2, -1 to 0 etc. Also, store largest relativized
    # size.
    $self->{largest_font} = 0;
    foreach my $ch (@{$self->{chunks}}) {
        $ch->{fsize} = ($ch->{fsize} - $self->{fontsize}) * 10/$self->{fontsize};
        if ($ch->{fsize} > $self->{largest_font} && length($ch->{plaintext}) > 5) {
            $self->{largest_font} = $ch->{fsize};
        }
    }
    say(3, "largest font (relative): $self->{largest_font}");
    
}


sub get_geometry {
    my $self = shift;

    # find common page dimensions:
    my @pars = ('top', 'right', 'bottom', 'left');
    my %freq;
    foreach my $par (@pars) {
        $freq{$par} = {};
    }
    foreach my $page (@{$self->{pages}}) {
        foreach my $par (@pars) {
            $freq{$par}->{$page->{$par}} = 0 
                unless defined $freq{$par}->{$page->{$par}};
            $freq{$par}->{$page->{$par}}++;
        }
    }
    $self->{geometry} = {};
    foreach my $par (@pars) {
        my @vals = sort { $freq{$par}->{$a} <=> $freq{$par}->{$b} }
                        keys(%{$freq{$par}});
        $self->{geometry}->{$par} = (@vals) ? $vals[-1] : 0;
        say(3, "default page $par: ", $self->{geometry}->{$par});
    }
}

sub strip_coverpages {
    my $self = shift;

    use rules::Page_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);

    my @startpages = @{$self->{pages}}[0..min(2,$#{$self->{pages}})];
    my $res = label_chunks(
        chunks => \@startpages,
        features => \%rules::Page_Features::features,
        labels => ['COVERPAGE'],
        iterations => 1,
        );

    foreach my $page (@{$res->{COVERPAGE}}) {
        say(3, "stripping cover page $page->{number}");
        remove_page($page);
    }
}

sub strip_marginals {
    my $self = shift;

    # strip header and footer lines -- they tend to confuse the line
    # classification.
    use rules::Line_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);

    my $max_y = $self->{geometry}->{top} + 25;
    my $headers = label_chunks(
        chunks => [ 
            grep { $_->{top} <= $max_y } @{$self->{chunks}}
        ],
        features => \%rules::Line_Features::features,
        labels => ['HEADER'],
        );

    my $min_y = $self->{geometry}->{bottom} - 20;
    my $footers = label_chunks(
        chunks => [
            grep { $_->{bottom} >= $min_y } @{$self->{chunks}}
        ],
        features => \%rules::Line_Features::features,
        labels => ['FOOTER'],
        min_p => 0.3,
        );

    foreach my $ch (@{$headers->{HEADER}}) {
        say(5, "header: $ch->{text}");
        push @{$self->{marginals}}, $ch;
        remove_chunk($ch);
    }

    foreach my $ch (@{$footers->{FOOTER}}) {
        next if $ch->{p}->('FOOTER') < 0.5;
        say(5, "footer: $ch->{text}");
        push @{$self->{marginals}}, $ch;
        remove_chunk($ch);
    }
}

sub strip_footnotes {
    my $self = shift;

    use rules::Line_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);

    my $notes = label_chunks(
        chunks => $self->{chunks},
        features => \%rules::Line_Features::features,
        labels => ['FOOTNOTESTART'],
        );

    my %note_lines;
    foreach my $ch (@{$notes->{FOOTNOTESTART}}) {
        next if $note_lines{$ch};
        say(4, "footnote: $ch->{text}...");
        while (1) {
            push @{$self->{footnotes}}, $ch;
            remove_chunk($ch);
            $note_lines{$ch} = 1;
            last unless $ch->{next} && $ch->{page} == $ch->{next}->{page};
            $ch = $ch->{next};
        }
    }
}

sub remove_chunk {
    my $chunk = shift;
    removelink($chunk);

    my $doc = $chunk->{doc};
    if ($chunk->{id} >= scalar @{$doc->{chunks}}) {
        warn "splice problem at $doc->{url}\n";
    }
    my $rem = splice @{$doc->{chunks}}, $chunk->{id}, 1;
    for my $i ($chunk->{id} .. $#{$doc->{chunks}}) {
        $doc->{chunks}->[$i]->{id} = $i;
    }

    my $page = $chunk->{page};
    $page->{chunks} = [ grep { ! $_->{_REMOVED} } @{$page->{chunks}} ];
    if (@{$page->{chunks}}) {
        $page->{left} = min(map { $_->{left} } @{$page->{chunks}});
        $page->{right} = max(map { $_->{right} } @{$page->{chunks}});
        $page->{width} = $page->{right} - $page->{left};
        $page->{top} = min(map { $_->{top} } @{$page->{chunks}});
        $page->{bottom} = max(map { $_->{bottom} } @{$page->{chunks}});
        $page->{height} = $page->{bottom} - $page->{top};
    }
}

sub remove_page {
    my $page = shift;
    removelink($page);

    my $doc = $page->{doc};
    my $rem = splice @{$doc->{pages}}, $page->{number}-1, 1;
    for my $i ($page->{number}-1 .. $#{$doc->{pages}}) {
        $doc->{chunks}->[$i]->{number} = $i+1;
    }

    for my $chunk (@{$page->{chunks}}) {
        removelink($chunk);
        splice @{$doc->{chunks}}, $chunk->{id}, 1;
        for my $i ($chunk->{id} .. $#{$doc->{chunks}}) {
            $doc->{chunks}->[$i]->{id} = $i;
        }
    }
}

sub get_text {
    my $self = shift;
    foreach my $ch (@{$self->{chunks}} ) {
        $self->{text} .= $ch->{plaintext}."\n";
    }
    # prevent perl crashes:
    $self->{text} =~ s/\n\s*\n/\n/g;
}

sub adjust_confidence {
    my $self = shift;
    if ($self->{fromOCR}) {
        $self->decr_confidence(0.8, 'from OCR');
    }
    elsif ($self->{fromHTML}) {
        $self->decr_confidence(0.9, 'from HTML');
    }
    if ($self->{numpages} < 5) {
        $self->decr_confidence(0.98, 'less than 5 pages');
    }
    if ($self->{numpages} > 80) {
        $self->decr_confidence(0.9, 'more than 80 pages');
    }
    #if ($self->{doctype}->{REVIEW} > 0.3) {
    #    my $review_p = $self->{doctype}->{REVIEW};
    #    $self->decr_confidence(1-$review_p/2, "possibly review: $review_p");
    #}
    if (exists $self->{author_title_parsings}) {
        my @parsings = @{$self->{author_title_parsings}};
        my $parsing = $parsings[0];
        $self->decr_confidence(0.5 + ($parsing->{quality} - 0.3) * 0.7, 
                               'parsing quality');
        if ($parsings[1]) {
            my $lead = $parsing->{quality} - $parsings[1]->{quality};
            $self->decr_confidence(1 + min(0.1, $lead-0.2), 'alternative parsings');
        }
        for my $block (@{$parsing->{blocks}}) {
            for my $label ('TITLE', 'AUTHOR') {
                if ($block->{label}->{$label}) {
                    my $min_p = min(map { $_->{p}->($label) } @{$block->{chunks}});
                    $self->decr_confidence(min(1, $min_p+0.2),
                                           "$label chunk probability $min_p");
                }
            }
        }
        if ($self->{sourcecontent}
            && !is_rough_substring($self->{title}, $self->{sourcecontent})) {
            $self->decr_confidence(0.7, "title not on source page");
        }
        if (@{$self->{sourceauthors}}) {
            my $source_author = 0;
            for my $au (@{$self->{authors}}) {
                for my $src_au (@{$self->{sourceauthors}}) {
                    $source_author = 1 if Text::Names::samePerson($src_au, $au);
                    say(5, "checking if $au matches $src_au")
                    #$source_author = 1 if (amatch($src_au, ['i 30%'], $au));
                }
            }
            unless ($source_author) {
                $self->decr_confidence(0.9, "source author not among authors");
            }
        }
    }    
}

sub get_doctype {
    my $self = shift;
    use rules::Doctype_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);
    my @doctypes = ('REVIEW');
    my $res = label_chunks(
        chunks => [$self],
        features => \%rules::Doctype_Features::features,
        labels => \@doctypes,
        iterations => 1,
        );
    for my $dt (@doctypes) {
        $self->{doctype}->{$dt} = $self->{p}->($dt);
    }
        
}

sub decr_confidence {
    my ($self, $percent, $reason) = @_;
    say(3, "reducing confidence by $percent because $reason");
    $self->{confidence} *= $percent;
}


##### metadata extraction #####

sub extract {
    my ($self, @fields) = @_;
    # default = extract everything:
    @fields = qw/authors title abstract bibliography/ unless @fields;

    say(3, "\nextract: ", join(', ', @fields));

    use rules::Line_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);
    
    # These are the line labels needed to extract the required info:
    my %labels = (
        'authors'      => ['AUTHOR', 'TITLE'],
        'title'        => ['AUTHOR', 'TITLE'],
        'abstract'     => ['ABSTRACT', 'ABSTRACTSTART', 'ABSTRACTEND'],
        'bibliography' => ['BIB', 'BIBSTART'],
        );
    my @labels = merge(map { $labels{$_} } @fields);

    $self->{best_chunks} = label_chunks(
        chunks => $self->{chunks},
        iterations => 5,
        features => \%rules::Line_Features::features,
        labels => \@labels,
        );

    # Now that the line labels are assigned, hand control to more
    # specific functions:
    my %dispatch = (
        # Perl has trouble with method pointers, hence the strings:
        'authors'      => 'extract_authors_and_title',
        'title'        => 'extract_authors_and_title',
        'abstract'     => 'extract_abstract',
        'bibliography' => 'extract_bibliography',
        );

    my @tasks = map { $dispatch{$_} } @fields;
    my %done;
    foreach my $task (@tasks) {
        next if $done{$task};
        eval {
            my $method = \&$task;
            $self->$method();
        };
        warn $@ if $@;
        $done{$task} = 1;
    }
    $self->adjust_confidence();
    say(2, "adjusted confidence: ", $self->{confidence});
}

sub merge {
    my (@res, %in);
    foreach my $a (@_) {
        foreach (@$a) {
            next if $in{$_};
            $in{$_} = 1;
            push @res, $_;
        }
    }
    return @res;
}

sub label_chunks {
    my %arg = @_;
    my ($chunks, $iterations, $features) = 
        ($arg{chunks}, $arg{iterations} || 5, $arg{features});
    my @labels = $arg{labels} ? @{$arg{labels}} : keys %$features;
    my $min_p = exists($arg{min_p}) ? $arg{min_p} : 0.5;
    
    # Here we will store the chunks with P >= $min_p:
    my %best;
    foreach (@labels) {
        $best{$_} = $chunks;
    }
    
    foreach my $stage (1 .. $iterations) {
        say(4, "\nlabeling chunks ", @labels," stage $stage");

        my $labeler = makeLabeler($features, $stage);

        # cache probability values, and don't use advanced stage
        # computations if previous probability very low:
        my $recurse = 0;
        my $make_p = sub {
            my $chunk = shift;
            my %cache;
            my $oldp = $stage > 1 ? $chunk->{p} : undef;
            my $newp = $labeler->($chunk);
            my $threshold = 0.2;
            return sub {
                my $label = shift;
                my $arg = shift;
                return $cache{$label} if exists($cache{$label});
                # don't calculate oldp if there's no cached value of it:
                return 1 if $arg{cache_only};
                my $rec = exists ($arg{recurse}) ?
                    $arg{recurse} : $recurse;
                if ($oldp) {
                    my $val = $oldp->($label, {cache_only=>1});
                    if ($val < $threshold) {
                        #print "**using oldp $val\n";
                        return $cache{$label} = $val;
                    }
                    #print "**not using oldp $val\n";
                }
                say(5, "\n>>calculating p ($stage,$rec) $label");
                # use previous stage for recursive calls:
                my $usep = $rec && $oldp ? $oldp : $newp;
                $recurse++;
                my $ret = $usep->($label, $rec);
                $recurse--;
                $cache{$label} = $ret unless $rec;
                say(5, "<<calculated p ($stage,$rec) $label");
                return $ret;
            };
        };

        # Features at iteration > 1 may refer to the probability from
        # earlier iterations, so we leave ->{p} in place until the new
        # probability has been computed:
        my $p = $stage > 1 ? 'p2' : 'p';
        foreach my $ch (@$chunks) {
            $ch->{$p} = $make_p->($ch);
        }

        # At this point, $chunk->{$p} is a function that calculates
        # the probability for the label given as argument; but the
        # calculation has not yet been made.
        my %relevant;
        foreach my $label (@labels) {
            my @best;
            foreach my $chunk (@$chunks) {
                my $prob = $chunk->{$p}->($label);
                if ($prob >= $min_p/2) {
                    $relevant{$chunk} = 1;
                    if ($prob >= $min_p) {
                        push @best, $chunk;
                    }
                }
            }
            @best = sort { $b->{$p}->($label) <=> $a->{$p}->($label) } @best;
            if ($verbosity > 3) {
                say(4, "\n$label chunks (stage $stage):\n  ",
                    join("\n  ", map { $_->{text}.' => '.$_->{$p}->($label) } @best));
                say(5, "\n");
            }
            $best{$label} = \@best;
        }
        $chunks = [ grep { exists $relevant{$_} } @$chunks ];

        foreach my $chunk (@$chunks) {
            # inform chunks about best chunks:
            $chunk->{best} = \%best;
            if ($stage > 1) {
                $chunk->{p} = $chunk->{$p};
            }
        }
    }

    if ($verbosity > 3) {
        my @res;
        foreach my $chunk (@$chunks) {
            my @labs = grep { $chunk->{p}->($_) > $min_p }
                       sort { $chunk->{p}->($b) <=> $chunk->{p}->($a) } 
                       @labels;
            push @res, join(' ', @labs)." >> ".$chunk->{text};
        }
        say(4, "\nresult:\n", join("\n", @res), "\n");
    }
    return \%best;
}

sub generate_parsings {
    my %arg = @_;
    my ($chunks, $labels) = ($arg{chunks}, $arg{labels});
    my $min_p = exists($arg{min_p}) ? $arg{min_p} : 0.5;

    say(3, "\n\ngenerate parsings");

    my @atoms;
    foreach my $chunk (@$chunks) {
        my $atom = {
            chunk => $chunk
        };
        my @alabels;
        foreach my $label (@$labels) {
            my $p = $chunk->{p}->($label);
            say(5, $chunk->{text}, " fits $label? $p: ");
            if ($p >= $min_p) {
                say(5, "yes");
                if ($arg{allow_multi} && @alabels) {
                    my @oldlabels = @alabels;
                    foreach (@oldlabels) {
                        my ($lab, $pr) = @$_;
                        push @alabels, [$lab.'+'.$label, min($pr, $p)];
                    }
                }
                push @alabels, [$label, $p];
            }
        }
        if ($arg{allow_empty}) {
            push @alabels, ['NONE', 1-max(map { $_->[1] } @alabels)];
        }
        unless (@alabels) {
            say(3, 'ignoring chunk: no label');
            next;
        }
        @alabels = sort { $b->[1] <=> $a->[1] } @alabels;

        $atom->{labels} = \@alabels;
        $atom->{variance} = stddev(map { $_->[1] } @alabels);
        push @atoms, $atom;
    }

    @atoms = sort { $a->{variance} <=> $b->{variance} } @atoms;

    my @state = map { 0 } @atoms;
    my $finished = scalar @atoms ? 0 : 1;
    return sub {
        # print join(" ", @state),"\n";
        return undef if $finished;
        foreach my $i (0 .. $#atoms) {
            my $chunk = $atoms[$i]->{chunk};
            my $alabels = $atoms[$i]->{labels}->[$state[$i]];
            my ($labels, $p) = @$alabels; 
            my %label = map { ($_, $p) } split(/\+/, $labels);
            $chunk->{label} = \%label;
        }
        
        my $cursor = 0;
        while ($cursor < @state) {
            if ($atoms[$cursor]->{labels}->[$state[$cursor]+1]) {
                $state[$cursor]++;              
                last;
            }
            $state[$cursor] = 0;
            $cursor++;
        }
        $finished = 1 if $cursor == scalar @state;
        
        return $chunks;
    };
}

{
    my %cache;
    sub make_block {
        my ($sep, $lab) = @_;
        return sub {
            my (@chunks) = @_;
            my $label = $lab ? { $lab => 1 } : $chunks[0]->{label};
            my $key = join(':', @chunks, keys %$label);
            unless ($cache{$key}) {
                my $block = {
                    chunks => \@chunks,
                    label => $label,
                    text => join($sep, map { $_->{text} } @chunks),
                };
                if ($verbosity) {
                    $block->{debug} = '{ '.substr(join('', keys %$label, 
                    map({ ' | '.$_->{text} } @chunks)), 0, 100)." }\n";
                }
                $cache{$key} = $block;
            }
            return $cache{$key};
        };
    }
}

sub parsing {
    my $sequence = shift;
    my $res = { blocks => $sequence };
    if ($verbosity) {
        $res->{text} = join ' ', '', map { $_->{debug} } @$sequence;
    };
    return $res;
}

sub parsing_evaluator {
    my ($block_featuremap, $parsing_features) = @_;
    say(4, "\n\n creating parsing evaluator");

    my $labeler = makeLabeler($block_featuremap);

    my $estim = util::Estimator->new();
    $estim->verbose(1) if $verbosity > 5;
    foreach (@$parsing_features) {
        $estim->add_feature(@$_);
    }

    return sub {
        my $parsing = shift;
        foreach my $block (@{$parsing->{blocks}}) {
            next if $block->{p};
            $block->{p} = memoize($labeler->($block));
        }
        return $estim->test($parsing);
    }
}

sub extract_authors_and_title {
    my $self = shift;
    say(2, "\nextracting authors and title");

    use rules::Title_Features;
    my $evaluator = parsing_evaluator(
                    \%rules::Title_Features::block_features,
                    \@rules::Title_Features::parsing_features);

    my %chunks;
    my @author_candidates = @{$self->{best_chunks}->{AUTHOR}};
    my @title_candidates = @{$self->{best_chunks}->{TITLE}};
    if (scalar @author_candidates > 8) {
        @author_candidates = grep { $_->{p}->('AUTHOR') > 0.6 }
                             @author_candidates;
    }
    if (scalar @title_candidates > 7) {
        @title_candidates = grep { $_->{p}->('TITLE') > 0.6 }
                             @title_candidates;
    } 
    foreach (@author_candidates, @title_candidates) {
        $chunks{$_} = $_;
    }
    my @chunks = sort { $a->{id} <=> $b->{id} } values %chunks;
    my $parsings = generate_parsings(
        chunks => \@chunks,
        labels => ['AUTHOR', 'TITLE'],
        allow_multi => 1,
        allow_empty => 1
        );

    my @parsings;
    my $counter = 0;
  PARSING: while (my $chunks = $parsings->()) {
      $counter++;
      if (($counter > 50000 && @parsings) || $counter > 100000) {
          say(2, "too many author-title parsings");
          last;
      }
      say(5, "evaluating parsing $counter");
      my @blocks;
      my ($author, $title);
      my $mkblock = make_block("\n");
      for (my $i=0; $i < @$chunks; $i++) {
          my $chunk = $chunks->[$i];
          my $is = $chunk->{label};
          say(5, "  $i: ",($is->{TITLE} ? 'TITLE ' : ''),
              ($is->{AUTHOR} ? 'AUTHOR ' : ''), '| ', $chunk->{text});
          if ($is->{AUTHOR}) {
              if ($title && ($is->{TITLE} || $author 
                             && $author->{id} < $title->{id})) {
                  say(5, "double title or author on either side");
                  next PARSING;
              }
              $author = $mkblock->($chunk);
              $author->{id} = scalar @blocks;
              pushlink @blocks, $author;
              next;
          }
          if ($is->{TITLE} && $title) {
              say(5, "double title");
              next PARSING;
          }
          my $label = $is->{TITLE} ? 'TITLE' : 'NONE';
          my @block_chunks = ($chunk);
          while ($chunks->[$i+1]
                 && $chunks->[$i+1]->{label}->{$label} 
                 && !$chunks->[$i+1]->{label}->{AUTHOR}) {
              pushlink @block_chunks, $chunks->[++$i];
          }
          my $block = $mkblock->(@block_chunks);
          $block->{id} = scalar @blocks;
          pushlink @blocks, $block;
          $title = $block if $is->{TITLE};
      }
      my $parsing = parsing(\@blocks);
      $parsing->{quality} = $evaluator->($parsing);
      say(5, "Quality: ", $parsing->{quality}, ": ", $parsing->{text});
      push @parsings, $parsing;
  }

    unless (@parsings) {
        $self->decr_confidence(0, "no parsing for authors and title found!");
        return 0;
    }

    @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;
    $self->{author_title_parsings} = \@parsings;

    my $parsing = $parsings[0];
    say(3, "best parsing", $parsing->{text});

    foreach my $block (@{$parsing->{blocks}}) {
        if ($block->{label}->{TITLE}) {
            $self->{title} = tidy_text($block->{text});
            # bold in titles looks too bold:
            $self->{title} =~ s|<(/?)b>|<$1i>|gi;
            $self->{title} = tidy_text($self->{title});
            # chop odd trailing punctuations:
            $self->{title} =~ s|[\.,:;]$||;
            if ($block->{label}->{AUTHOR}) {
                foreach my $name (keys %{$block->{chunks}->[0]->{names}}) {
                    $self->{title} =~ s/$name//i;
                    $self->{title} =~ s/$re_name_separator//;
                }
            }
        }
        if ($block->{label}->{AUTHOR}) {
            foreach my $chunk (@{$block->{chunks}}) {
                my @chunk_authors;
              NAME: while (my ($name, $prob) = each %{$chunk->{names}}) {
                    say(5, "name $name probability $prob");
                    # normalise and remove duplicates:
                    $name = tidy_text($name);
                    foreach my $old (@{$self->{authors}}) {
                        next NAME if Text::Names::samePerson($name, $old);
                    }
                    $self->decr_confidence(min(1,$prob+0.2), "author $name probability $prob");
                    push @chunk_authors, $name;
                }
                # restore correct order:
                @chunk_authors = sort {
                    return -1 if $chunk->{text} =~ /$a.*$b/i;
                    return 1;
                } @chunk_authors;
                push @{$self->{authors}}, @chunk_authors;
            }
        }
    }

    unless (@{$self->{authors}}) {
        $self->decr_confidence(0.9, "no authors found");
        if ($self->{sourceauthors}) {
            say(2, "no author -- using source author(s)");
            $self->{authors} = $self->{sourceauthors};
            foreach my $au (@{$self->{authors}}) {
                $self->{title} =~ s/[,:\s]*$au[,:\s]*(and)?//;
            }
        }
    }

    say(1, "authors: '", (join "', '", @{$self->{authors}}), "'");
    say(1, "title: '", $self->{title}, "'");
    say(2, "confidence: ", $self->{confidence});
}


sub extract_abstract {
    my $self = shift;
    say(2, "\nextracting abstract");

    # generate candidate abstracts:
    my @chunks = @{$self->{best_chunks}->{ABSTRACT}};
    my %candidates;
    foreach my $threshold (0.8, 0.7, 0.6) {
        my %done;
        foreach my $chunk (@chunks) {
            next if $done{$chunk};
            say(5, "\nstarting with: $chunk->{text} ($threshold)");
            my @current = ($chunk);
            # go through earlier chunks until we hit a plausible
            # starting point:
            my $start = $chunk;
            while ($start = $start->{prev}) {
                my $min = $threshold;
                # the further away, the more reluctant we are:
                $min += (scalar @current)/400;
                # be more reluctant if we've just met a plausible
                # ABSTRACTSTART, less if we haven't:
                $min += ($current[0]->{p}->('ABSTRACTSTART')-0.5);
                my $p = max($start->{p}->('ABSTRACT'), $start->{p}->('ABSTRACTSTART'));
                if ($p < $min) {
                    say(5, "stopping before: $start->{text} ($p < $min)");
                    last;
                }
                say(5, "prepending: $start->{text} ($p > $min)");
                unshift @current, $start;
                $done{$start} = 1;
            }
            # go through later chunks until we hit a plausible end point:
            my $end = $chunk;
            while ($end = $end->{next}) {
                my $min = $threshold;
                $min += (scalar @current)/200;
                $min += ($current[-1]->{p}->('ABSTRACTEND')-0.5);
                my $p = max($end->{p}->('ABSTRACT'), $end->{p}->('ABSTRACTEND'));
                if ($p < $min) {
                    say(5, "stopping before: $end->{text} ($p < $min)");
                    last;
                }
                say(5, "appending: $end->{text} ($p > $min)");
                push @current, $end;
                $done{$end} = 1;
            }
            if (scalar @current > 1) {
                my $id = $current[0]->{id}.'-'.$current[-1]->{id};
                $candidates{$id} = \@current;
            }
        }
    }

    my $estim = util::Estimator->new();
    $estim->verbose(1) if $verbosity > 5;
    use rules::Abstract_Features;
    foreach (@rules::Abstract_Features::block_features) {
        $estim->add_feature(@$_);
    }

    my $best = [];
    my $best_score = 0;
    foreach my $candidate (values %candidates) {
        if ($verbosity > 4) {
            say(5, "\ntesting: ",
                reduce { $a .' '. $b->{text} } '', @$candidate);
        }
        my $score = $estim->test($candidate);
        if ($score > $best_score) {
            $best = $candidate;
            $best_score = $score;
        }
    }

    my $abstract = reduce { $a ."\n". $b->{text} } '', @$best;
    $self->decr_confidence($best_score/2 + 0.5, 'abstract score');
    if (length($abstract) > 2000) {
        $self->decr_confidence(0.95, 'abstract too long');
        $abstract =~ s/^(.+\w\w.?[\.\?!]).*$/$1/s;
    }
    # strip "Abstract:" beginning:
    $abstract =~ s/^(?:\s|<.>)*$re_abstract[\.:]?(?:<\/.>)*[\.:\n]?\s*//i;
    $self->{abstract} = tidy_text($abstract);

    say(1, "abstract: '", $self->{abstract}, "'");
    say(2, "confidence: ", $self->{confidence});
}

sub extract_bibliography {
    my $self = shift;
    say(2, "\nextracting bibliography");

    # use exclusive labels for generate_parsings: 
    my $redefine_p = sub {
        my $p = $_[0]->{p};
        return sub {
            if ($_[0] eq 'BIB') {
                return $p->('BIBSTART') > 0.7 ? 0 : 0.51;
            }
            return $p->($_[0]);
        };
    };
    my %chunks;
    foreach my $ch (@{$self->{best_chunks}->{BIB}},
                    @{$self->{best_chunks}->{BIBSTART}}) {
        next if $chunks{$ch};
        $ch->{p} = $redefine_p->($ch);
        $chunks{$ch} = $ch;
    }
    my @chunks = sort { $a->{id} <=> $b->{id} } values %chunks;

    my $parsings = generate_parsings(
        chunks => \@chunks,
        labels => ['BIB', 'BIBSTART'],
        );

    use rules::Bibblock_Features;
    my $evaluator = parsing_evaluator(
                    \%rules::Bibblock_Features::block_features,
                    \@rules::Bibblock_Features::parsing_features);

    my @parsings;
    my $counter = 0;
  PARSING: while (my $chunks = $parsings->()) {
      $counter++;
      if (($counter > 1000 && @parsings) || $counter > 10000) {
          say(2, "too many parsings");
          last;
      }
      say(5, "evaluating parsing $counter");
      my @blocks;
      my $mkblock = make_block("\n", 'ENTRY');
      my ($author, $title);
      for (my $i=0; $i < @$chunks; $i++) {
          my $chunk = $chunks->[$i];
          my $is = $chunk->{label};
          say(5, "  $i: ",($is->{BIB} ? 'BIB ' : ''),
              ($is->{BIBSTART} ? 'BIBSTART ' : ''), '| ', $chunk->{text});
          my @block_chunks = ($chunk);
          while ($chunks->[$i+1] 
                 && !$chunks->[$i+1]->{label}->{BIBSTART}) {
              pushlink @block_chunks, $chunks->[++$i];
          }
          my $block = $mkblock->(@block_chunks);
          $block->{id} = scalar @blocks;
          pushlink @blocks, $block;
      }
      my $parsing = parsing(\@blocks);
      $parsing->{quality} = $evaluator->($parsing);
      say(5, "Quality: ", $parsing->{quality});
      push @parsings, $parsing;
  }

    @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;

    my $parsing = shift @parsings;
    say(3, "best parsing", $parsing->{text});

    foreach my $block (@{$parsing->{blocks}}) {
        # need to pass previous authors in case author field is '--':
        my @last_authors = @{$self->{bibliography}} ?
            @{$self->{bibliography}->[-1]->{authors}} : ();
        my $entry = $self->parsebib($block, @last_authors);
        push(@{$self->{bibliography}}, $entry) if $entry;
    }
}

sub parsebib {
    my $self = shift;
    my $entry = shift;
    my @last_authors = @_;
    say(3, "\nparsing bib entry: ", $entry->{text});
    
    $entry->{text} = tidy_text($entry->{text});

    # split the entry into consecutive strings without punctuation:
    my @fragments;
    my $separator = qr/(?:
         [^\pL\pN]\s |           # split 'Kamp. Formal', '71) 12'
         \s(?=[^\pL\pN]) |       # split 'Kamp (1971'
         [^\pN\pL]$re_dash |     # split '--1971', '--Kamp'
         \pL\s*(?=\d{4})         # split 'Kamp 1971', 'Kamp1971'
         )\K                     # keep the separator
         /ox;
    my $textpos = 0;
    foreach my $str (split /$separator/, $entry->{text}) {
        my $frag = {
            text => $str,
            id => scalar @fragments,
            textpos => $textpos,
            entry => $entry,
        };
        $frag->{text} =~ s/^\s*(.+?)\s*$/$1/;
        $textpos += length($str);
        pushlink @fragments, $frag;
    }

    use rules::Bib_Features;
    if ($self->{known_work}) {
        $rules::Bib_Features::known_work = $self->{known_work};
    }
    my @labels = keys %rules::Bib_Features::fragment_features;
    my $best = label_chunks(
        chunks => \@fragments,
        features => \%rules::Bib_Features::fragment_features,
        relabel_all => 1,
        min_p => 0.4,
        );

    my $evaluator = parsing_evaluator(
                    \%rules::Bib_Features::block_features,
                    \@rules::Bib_Features::parsing_features);

    my $parsings = generate_parsings(
        chunks => \@fragments,
        labels => \@labels,
        min_p => 0.4,
        );

    my @parsings;
    my $satisfaction = 0;
    my $counter = 0;
  PARSING: while (my $chunks = $parsings->()) {
      if (++$counter > 2000 - $satisfaction) {
          last;
      }
      say(5, "evaluating parsing $counter (sat $satisfaction)");
      my @blocks;
      my $mkblock = make_block(' ');
      my %fields;
      for (my $i=0; $i < @$chunks; $i++) {
          my $chunk = $chunks->[$i];
          my $is = $chunk->{label};
          my $label = first { $is->{$_} } @labels;
          say(5, "  $i: $label | ", $chunk->{text});
          if (grep($label, ('AUTHOR', 'TITLE')) && $fields{$label}) {
              say(5, "double title or author");
              next PARSING;
          }
          my @block_chunks = ($chunk);
          while ($chunks->[$i+1]
                 && $chunks->[$i+1]->{label}->{$label}) {
              pushlink @block_chunks, $chunks->[++$i];
          }
          my $block = $mkblock->(@block_chunks);
          $block->{id} = scalar @blocks;
          pushlink @blocks, $block;
          $fields{$label} = $block;
      }
      my $parsing = parsing(\@blocks);
      if ($fields{'AUTHORDASH'}) {
          $parsing->{dash_authors} = \@last_authors;
      }
      $parsing->{bib} = bib_from_parsing($parsing);
      my $quality = $evaluator->($parsing);
      say(5, "Quality: $quality");
      if ($quality > 0.5) {
          $parsing->{quality} = $quality;
          push @parsings, $parsing;
          $satisfaction += 50 + max(0, ($quality-0.9)*5000);
      }
  }

    return { authors => [] } unless @parsings;

    @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;

    my $parsing = shift @parsings;
    say(3, "best parsing", $parsing->{text});
    my $res = $parsing->{bib};
    say(3, "authors: ", @{$res->{authors}}, "; ",
           "title: $res->{title}; year: $res->{year}; ",
           "known id: $res->{known_id}");
    return $res;

}

sub bib_from_parsing {
    my $parsing = shift;
    my %fields;
    foreach my $bl (@{$parsing->{blocks}}) {
        foreach my $label (keys %{$bl->{label}}) {
            $fields{$label} ||= $bl->{text};
        }
    }
    my $res;
    $res->{title} = $fields{TITLE} || '';
    $res->{title} =~ s/[\.,]$//;
    $res->{title} = tidy_text($res->{title});
    $res->{year} = $fields{YEAR} || '';
    $res->{year} =~ s/.*(\d{4}(?:$re_dash\d{2,4})?).*/$1/;
    $res->{authors} = [];
    if ($fields{AUTHOR}) {
        my @authors = Text::Names::parseNames($fields{AUTHOR});
        @authors = map { Text::Names::reverseName($_) } @authors;
        $res->{authors} = \@authors;
    }
    if ($parsing->{dash_authors}) {
        $res->{authors} = [@{$parsing->{dash_authors}}, @{$res->{authors}}];
    }
    if ($verbosity > 4) {
        say(5, 'tidied-up bib:');
        use Data::Dumper;
        print Dumper $res;
    }
    return $res;
}

# for standalone use:
sub serialize {
    my $self = shift;
    my %doc = (
        # type => $self->{doctype},
        # chunks => [],
        #numpages => $self->{numpages},
        #numwords => $self->{numwords},
        fontsize => $self->{fontsize},
        linespacing => $self->{linespacing},
        authors => join(', ', @{$self->{authors}}),
        title => $self->{title},
        abstract => $self->{abstract},
        # bibliography => [],
        #content => $self->{text},
        meta_confidence => $self->{confidence},
        );
    return encode_json(\%doc);
}

# standalone use:
unless (caller) {
    my %opts;
    getopts("v:", \%opts);
    my $xmlfile = $ARGV[0];
    die 'need xmlfile argument' unless $xmlfile;
    my $ex = Extractor->new();
    $ex->verbosity(exists($opts{v}) ? $opts{v} : 0);
    $ex->init($xmlfile);
    $ex->extract(qw/authors title abstract/);
    print "=========== RESULT ===========\n";
    print $ex->serialize();
}

1;

=explanation

The information we want to extract usually corresponds to specific
parts of the document, e.g. the title or the author names appearing
below the title. Our task is therefore to identify the relevant
document parts.

One challenge here is that we have a combined segmentation and
labeling problem. For example, suppose we have somehow extracted an
entry from the bibliography, and now want to identify the parts
designating authors, title, and year of the cited work. We proceed in
three stages.

1. Split the entry by punctuation symbols and assign to each part a
   probability for belonging to an authors string, a title, a year, or
   something else.

2. Turn the result into various "parsing hypotheses". A parsing
   hypothesis is a segmentation of the bib entry into authors, title,
   year, and other parts. Except for "other", the parts have to be
   contiguous.

3. Evaluate each hypothesis for its probability, by considering the
   probability of its authors part being a complete authors string,
   etc.

The same issue arises when extracting authors and title of the
document itself. Many papers start with "Title\nAuthor", which can
look just like "Title\nSecond line of title". So we can't segment the
document into components independently of assigning labels for
"author", "title" etc. to the resulting components. Our strategy is
the same as for bibliography entries. This time, the building blocks
in step 1 are not words, but lines (more precisely, "chunks"). So we
first assign to each line a probability for being an authors string,
(part of) a title, or something else. Then we construct parsing
hypotheses from these values, and evaluate each hypothesis for its
probability.

Extraction of abstracts is a bit different. We check if there's a
heading "Abstract" or line beginning with "Abstract" towards the
beginning of the paper. If so, we take all the following text until
there's a gap or a heading. If there is no element, we take the first
line of normal text until either the end of the 5th sentence or a gap
or a heading. For that, we need line labels for "abstract_start" and
"normal text". 

For extracting bib items, we start with line labels "bibline" and
"biblinestart", and construct parsing hypotheses from these, parsing
the document into various bib items. 

=cut
