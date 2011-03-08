package Extractor;
use strict;
use warnings;
use Data::Dumper;
use Memoize;
use List::Util qw/min max reduce/;
use Statistics::Lite 'stddev';
use Text::Capitalize;
use Text::Names 'samePerson';
use Cwd 'abs_path';
use File::Basename;
use Encode;
use util::Functools 'allof';
use util::Io;
use util::String;
use util::Estimator 'makeLabeler';
use rules::Authors 'extract_names';
use rules::Keywords;

my $path = dirname(abs_path(__FILE__));

sub new {
    my ($class, $xmlfile) = @_;
    my $self = {
        xmlfile => $xmlfile,
        converters => [],
        fromOCR => 0,
        chunks => [],
        pages => 0,
        fontsize => 0,
        linespacing => 0,
        authors => [],
        title => '',
        bibliography => [],
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

sub init {
    my ($self, $xmlfile) = @_;
    say(3, "\ninitialising Extractor: $xmlfile");

    $self->{xmlfile} = $xmlfile;
    my $xml = readfile($xmlfile);
    say(6, $xml);

    my @converters = $xml =~ /<converter>(.+?)<\/converter>/og;
    $self->{converters} = \@converters;
    $self->{fromOCR} = 1 if grep 'OCR', @converters;

    say(3, "collecting text chunks");

    my %fontsizes = $xml =~/<fontspec id="(\d+)" size="(\d+)"/og;
    my @pages = split /<page number=/, $xml;
    my @chunks;
    my $pageno = 0; # first element of @pages isn't a page
    my $charno = 1;
    my $lineno = 1;
    for my $page (@pages) {
        my @pagechunks;
        while ($page =~ /(<text.*?>.*?<\/text>)/isgo) {
            my $chunk = xml2chunk($1);
            $chunk->{fsize} = $fontsizes{$chunk->{font}} || 1;
            # yes, sometimes blocks have unspec'd font: 49803
            $chunk->{id} = $lineno++;
            $chunk->{textpos} = $charno;
            $charno += length $chunk->{plaintext};
            $chunk->{doc} = $self;
            pushlink @pagechunks, $chunk;
        }
        add_pageinfo(\@pagechunks, $pageno);
        $pageno++;
        pushlink @chunks, @pagechunks; 
    }

    $self->{pages} = $#pages;
    $self->{chunks} = \@chunks;
    $self->fontinfo();
    $self->relativize_fsize();
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
    $chunk->{plaintext} = strip_tags($chunk->{text});
    return $chunk;
}

sub add_pageinfo {
    my ($chunks, $pageno) = @_;
    return unless @$chunks;

    my %page;
    $page{number} = $pageno;
    $page{left} = min(map { $_->{left} } @$chunks);
    $page{right} = max(map { $_->{right} } @$chunks);
    $page{width} = $page{right} - $page{left};
    $page{top} = min(map { $_->{top} } @$chunks);
    $page{bottom} = max(map { $_->{bottom} } @$chunks);
    $page{height} = $page{bottom} - $page{top};
    $page{lines} = $#$chunks;

    foreach (@$chunks) {
        $_->{page} = \%page;
    }
}

sub fontinfo {
    my ($self) = @_;

    # find most common ('default') font-size and line-spacing (as fraction):
    my %fs_freq;
    my %sp_freq;
    foreach my $ch (@{$self->{chunks}}) {
        next if length($ch->{plaintext}) < 10;
        next if $ch->{bottom} / $ch->{page}->{bottom} > 0.7;
        last if $self->{pages} > 2 &&
            $ch->{page}->{number} / $self->{pages} > 0.7;
        $fs_freq{$ch->{fsize}} = 0 unless defined $fs_freq{$ch->{fsize}};
        $fs_freq{$ch->{fsize}}++;
        next unless $ch->{prev};
        my $spacing = ($ch->{top} - $ch->{prev}->{top}) / $ch->{height};
        $spacing = int($spacing*10)/10;
        $sp_freq{$spacing}++;
    }

    my ($default_fs,) = each(%fs_freq);
    while (my ($fs, $freq) = each(%fs_freq)) {
        $default_fs = $fs if $freq > $fs_freq{$default_fs};
    }
    $self->{fontsize} = $default_fs;
    say(3, "default font size $default_fs");

    my ($default_sp,) = each(%sp_freq);
    while (my ($sp, $freq) = each(%sp_freq)) {
        $default_sp = $sp if $freq > $sp_freq{$default_sp};
    }
    $self->{linespacing} = $default_sp;
    say(3, "default line spacing $default_sp");
}

sub relativize_fsize {
    my $self = shift;

    # relativise font-sizes; e.g.  +2 = [120-130)%.  For OCR'ed
    # documents, font-sizes are unreliable, so we round +3 to +2, -1
    # to 0 etc.
    my $def = $self->{fontsize};
    foreach my $ch (@{$self->{chunks}}) {
        $ch->{fsize} = int(($ch->{fsize} - $def) * 10/$def);
        if ($self->{fromOCR}) {
            $ch->{fsize} = int($ch->{fsize}/2) * 2;
        }
    }
}

##### metadata extraction #####

sub extract {
    my ($self, @fields) = @_;
    # default = extract everything:
    @fields = qw/authors title abstract bibliography/ unless @fields;

    say(3, "\nextract: ", join(', ', @fields));

    use rules::Line_Features;
    util::Estimator->verbose($verbosity > 4 ? 1 : 0);
    
    # These are the line labels we need to extract the required info:
    my %labels = (
        'authors'      => ['AUTHOR', 'TITLE', 'HEADING'],
        'title'        => ['AUTHOR', 'TITLE', 'HEADING'],
        'abstract'     => ['ABSTRACTSTART', 'ABSTRACTCONTENT'],
        'bibliography' => ['BIB', 'BIBSTART', 'HEADING'],
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

    foreach my $i (1 .. $iterations) {
        say(4, "\nlabeling chunks, stage $i");

        my $labeler = makeLabeler($features, $i);

        # cache probability values, and don't use advanced stage
        # computations if initial P < min_p or the relevant label is
        # uninteresting:
        my $make_p = sub {
            my $ch = shift;
            my %cache;
            my $oldp = $ch->{p};
            my $newp = $labeler->($ch);
            my $threshold = $arg{relabel_all} ? 0.2 : $min_p;
            return sub {
                my $label = shift;
                return $cache{$label} if exists($cache{$label});
                #print "computing $ch p $label\n";
                if ($oldp) {
                    my $val = $oldp->($label);
                    if ($val < $threshold || !grep /$label/, @labels) {
                        #print "using oldp $val\n";
                        return $cache{$label} = $val;
                    }
                    #print "not using oldp\n";
                }
                return $cache{$label} = $newp->($label);
            };
        };
        # Features at iteration > 1 may refer to the probability from
        # earlier iterations, so we leave ->{p} in place until the new
        # probability has been computed:
        my $p = $i > 1 ? 'p2' : 'p';
        foreach my $ch (@$chunks) {
            $ch->{$p} = $make_p->($ch);
        }
        # At this point, $chunk->{$p} is a function that calculates
        # the probability for the label given as argument; but the
        # calculation has not yet been made.
        foreach my $label (@labels) {
            my $candidates = $arg{relabel_all} ? $chunks : $best{$label};
            my @best;
            foreach my $c (@$candidates) {
                if ($c->{$p}->($label) >= $min_p) {
                    push @best, $c;
                }
            }
            @best = sort { $b->{$p}->($label) <=> $a->{$p}->($label) } @best;
            if ($verbosity > 3) {
                say(4, "\n$label chunks (stage $i):\n  ", 
                    join("\n  ", map {
                    $_->{text}.' => '.$_->{$p}->($label) } @best));
                say(5, "\n");
            }
            $best{$label} = \@best;
        }

        foreach my $ch (@$chunks) {
            # inform chunks about best chunks:
            $ch->{best} = \%best;
            if ($i > 1) {
                $ch->{p} = $ch->{$p};
            }
        }
    }
    if ($verbosity > 3) {
        say(4, "\ncomputing result");
        my @res;
        foreach my $ch (@$chunks) {
            my @labs = grep { $ch->{p}->($_) > .5 }
                       sort { $ch->{p}->($b) <=> $ch->{p}->($a) } 
                       keys %$features;
            push @res, join(' ', @labs)." >> ".$ch->{text};
        }
        say(4, "\nresult:\n", join("\n", @res), "\n");
    }
    # Note that if the features for label A depend on some other
    # chunk's probability for label B, and B isn't in @labels, then
    # the other chunks probability for B retrieved at every stage is
    # typically the stage 1 probability for B. If the B probability is
    # crucial, B should be added to @labels.
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
        
        use Data::Dumper;
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

sub bits {
    # returns the set of bit positions set in a number, e.g. 5 =>
    # {0,2} because 5 = 101
    my $num = shift;
    my @res;
    for (my $pos=0; $num; $pos++) {
        push(@res, $pos) if ($num & 1);
        $num >>= 1;
    }
    return @res;
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
    foreach (@{$self->{best_chunks}->{AUTHOR}}, 
             @{$self->{best_chunks}->{TITLE}}) {
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
      if (($counter > 1000 && @parsings) || $counter > 10000) {
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

    @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;

    my $parsing = shift @parsings;
    say(3, "best parsing", $parsing->{text});

    $self->{confidence} = $parsing->{quality};
    foreach my $block (@{$parsing->{blocks}}) {
        my $text = tidy_text($block->{text}, 1);
        if ($block->{label}->{TITLE}) {
            $self->{title} = $text;
            # TODO: remove authors from title if block is also title
            # TODO $title = capitalize_title($title) if ($title !~ /\p{isLower}/);
        }
        if ($block->{label}->{AUTHOR}) {
            foreach my $chunk (@{$block->{chunks}}) {
                foreach my $name (keys %{$chunk->{names}}) {
                    # remove duplicates:
                    my $ok = 1;
                    foreach my $old (@{$self->{authors}}) {
                        $ok = 0 if Text::Names::samePerson($name, $old);
                    }
                    push @{$self->{authors}}, $name if $ok;
                }
            }
        }
    }

    say(1, "authors: '", (join "', '", @{$self->{authors}}));
    say(1, "title: '", $self->{title}, "'");
}

sub extract_abstract {
    my $self = shift;
    say(2, "\nextracting abstract");

    my $chunk = shift @{$self->{best_chunks}->{ABSTRACTSTART}};
    my $maxlen = 1400;
    unless ($chunk) {
        say(3, "no designated abstract");
        # use first ABSTRACTCONTENT chunk:
        foreach my $ch (@{$self->{chunks}}) {
            next if $ch->{p}->('ABSTRACTCONTENT') < 0.7;
            do {
                $chunk = $ch;
            } while (($ch = $ch->{prev})
                     && $ch->{p}->('ABSTRACTCONTENT') > 0.5);
            last;
        }
        $maxlen = 800;
    }

    while ($chunk) {
        say(5, $chunk->{text});
        if ($chunk->{p}->('ABSTRACTCONTENT') > 0.5) {
            $self->{abstract} .= $chunk->{text}."\n";
            if (length($self->{abstract}) > $maxlen) {
                say(5, 'abstract is getting too long');
                $self->{abstract} =~ s/^(.+\w\w.?[\.\?!]).*$/$1/s;
                last;
            }
        }
        elsif ($self->{abstract} && $chunk->{p}->('HEADING') > 0.5) {
            last;
        }
        $chunk = $chunk->{next};
    };

    say(1, "abstract: '", $self->{abstract}, "'");
}

sub extract_bibliography {
    my $self = shift;
    say(2, "\nextracting bibliography");

    use rules::Bibblock_Features;
    my $evaluator = parsing_evaluator(
                    \%rules::Bibblock_Features::block_features,
                    \@rules::Bibblock_Features::parsing_features);

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
    say(5, "end of parsings");

    @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;

    my $parsing = shift @parsings;
    say(3, "best parsing", $parsing->{text});

    foreach my $block (@{$parsing->{blocks}}) {
        my $entry = parsebib($block);
        if ($entry) {
            push @{$self->{bibliography}}, $entry;
        }
    }
}

sub parsebib {
    my $entry = shift;
    say(3, "\nparsing bib entry: ", $entry->{text});
    
    $entry->{text} = tidy_text($entry->{text});

    my @words;
    my $textpos = 0;
    foreach my $str (split /\s+/, $entry->{text}) {
        my $w = {
            text => $str,
            id => scalar @words,
            textpos => $textpos,
            entry => $entry,
        };
        $textpos += length($str)+1; # +1 from split \s
        pushlink @words, $w;
    }

    use rules::Bib_Features;
    my @labels = keys %rules::Bib_Features::word_features;
    my $best = label_chunks(
        chunks => \@words,
        features => \%rules::Bib_Features::word_features,
        relabel_all => 1,
        min_p => 0.4,
        );

    my $evaluator = parsing_evaluator(
                    \%rules::Bib_Features::block_features,
                    \@rules::Bib_Features::parsing_features);

    my $parsings = generate_parsings(
        chunks => \@words,
        labels => \@labels,
        min_p => 0.4,
        );

    my @parsings;
    my $satisfaction = 0;
    my $counter = 0;
  PARSING: while (my $chunks = $parsings->()) {
      $counter++;
      if ($counter > 2000 - $satisfaction) {
          last;
      }
      say(5, "evaluating parsing $counter (sat $satisfaction)");
      my @blocks;
      my $mkblock = make_block(' ');
      my ($author, $title);
      for (my $i=0; $i < @$chunks; $i++) {
          my $chunk = $chunks->[$i];
          my $is = $chunk->{label};
          say(5, "  $i: ",($is->{TITLE} ? 'TITLE ' : ''),
              ($is->{AUTHOR} ? 'AUTHOR ' : ''),
              ($is->{YEAR} ? 'YEAR ' : ''),
              '| ', $chunk->{text});
          if ($is->{TITLE} && $title || $is->{AUTHOR} && $author) {
              say(5, "double title or author");
              next PARSING;
          }
          my $label = '';
          foreach (@labels) {
              $label = $_ if $is->{$_};
          }
          my @block_chunks = ($chunk);
          while ($chunks->[$i+1]
                 && $chunks->[$i+1]->{label}->{$label}) {
              pushlink @block_chunks, $chunks->[++$i];
          }
          my $block = $mkblock->(@block_chunks);
          $block->{id} = scalar @blocks;
          pushlink @blocks, $block;
          $title = $block if $is->{TITLE};
          $author = $block if $is->{AUTHOR};
      }
      my $parsing = parsing(\@blocks);
      my $quality = $evaluator->($parsing);
      say(5, "Quality: $quality");
      if ($quality > 0.5) {
          $parsing->{quality} = $quality;
          push @parsings, $parsing;
          $satisfaction += 50 + max(0, ($quality-0.9)*5000);
      }
  }

    my $res;

    if (@parsings) {
        @parsings = sort { $b->{quality} <=> $a->{quality} } @parsings;

        my $parsing = shift @parsings;
        say(3, "best parsing", $parsing->{text});
        foreach my $block (@{$parsing->{blocks}}) {
            if ($block->{label}->{TITLE}) {
                $res->{title} = tidy_text($block->{text}, 1)
            }
            elsif ($block->{label}->{AUTHOR}) {
                my @authors = Text::Names::parseNames($block->{text});
                @authors = map { Text::Names::reverseName($_) } @authors;
                $res->{authors} = \@authors;
            }
            elsif ($block->{label}->{YEAR}) {
                $res->{year} = $block->{text};
                $res->{year} =~ s/.*(\d{4}(?:$re_dash\d{2,4})?).*/$1/;
            }
        }
    }

    return $res;
}

sub tidy_text {
    my $txt = shift;
    my $thorough = shift;
    # put closing tags before space:
    $txt =~ s| </([^>]+)>|</$1> |g;
    # combine word-parts that are split at linebreak:
    $txt =~ s|\b-\n\s*||g;
    $txt =~ s|\b-</([^>]+)>\n\s*<\1>||g;
    # merge HTML elements split at linebreak:
    $txt =~ s|</([^>]+)>\n\s*<\1>|\n|g;
    if ($thorough) {
        # chop whitespace at beginning and end of lines:
        $txt =~ s|^\s*(.+?)\s*$|$1|gm;
        # and footnote marks:
        $txt =~ s|<sup>\W?.\W?<.sup>$||;
        # and surrounding tags:
        $txt =~ s|^<([^>])>(.+)</\1>$|$2|mg;
        # and surrounding quotes:
        $txt =~ s|^$re_lquote(.+)$re_rquote.?$|$1|s;
        # chop footnote star *:
        $txt =~ s/(\*|\x{2217})$//;
        # chop non-<sup>'ed footnote symbols in brackets:
        $txt =~ s|[\(\[] . [\)\]]$||x;
        # chop non-<sup>'ed number right after last word:
        $txt =~ s|([\pL\?!])\d$|$1|;
        # and odd trailing punctuations:
        $txt =~ s|[\.,:;]$||;
    }
    return $txt;
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

1. Split the entry by whitespace and assign to each part a probability
   for belonging to an authors string, a title, a year, or junk.

2. Turn the result into various "parsing hypotheses". A parsing
   hypothesis is a segmentation of the bib entry into authors, title,
   year, junk parts. Except for junk, the parts have to be contiguous.

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

