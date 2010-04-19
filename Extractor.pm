package Extractor;
use strict;
use warnings;
use Data::Dumper;
#use HTML::StripScripts::Parser;
use Text::Capitalize;
use String::Approx 'amatch';
use Encode;
use util::Io;
use util::String;

# known author names, firstnames, and strings that are not names:
use constant DATA             => 'data/';
use constant AUTHORS_FILE     => DATA.'names.txt';
use constant FIRSTNAMES_FILE  => DATA.'firstnames.txt';
use constant NOTNAMES_FILE    => DATA.'notnames.txt';

# these are defined at the end:
my ($re_name, $re_pre_name, $re_post_name, $re_authors_separator,
    $re_bad_author, $re_bad_title, $re_bad_abstract);

sub new {
    my ($class, $filename) = @_;
    die "Extractor::new() requires filename parameter" unless defined($filename);
    my $self  = {
	filename  => $filename,
	verbosity => 0,
	converters => '', # OCR, pdftohtml, etc.
	document  => {
	    pages        => 0,
	    lines        => 0,
	    left         => 0,
	    right        => 0,
	    linespacing  => 0,
	    fontsize     => 0,
	    authors      => undef,
	    title        => '',
	    abstract     => '',
	    confidence   => 0.9, # this will go down whenever we encounter a problem
	},
	priors => {
	    author   => {},
	    title    => {},
	    abstract => {},
	},
    };
    bless $self, $class;
    return $self;
}

sub filename {
    my $self = shift;
    $self->{filename} = shift if @_;
    return $self->{filename};
}

sub verbosity {
    my $self = shift;
    $self->{verbosity} = shift if (@_);
    return $self->{verbosity};
}

sub prior {
    my ($self, $field, $value, $prob) = @_;
    $self->{_priors}->{$field}{$value} = $prob;
}

sub parse {
    my $self = shift;
    die "local file ".$self->{filename}." not found" unless -e $self->{filename};
    my $xml = readfile($self->{filename});
    print $xml if $self->verbosity > 4;
    my @converters = $xml =~ /<converter>(.+?)<\/converter>/og;
    $self->{converters} .= join ', ', @converters;
    $self->confidence(-0.08, 'OCR') if $self->{converters} =~ /OCR/;
    $self->confidence(-0.05, 'HTML') if $self->{converters} =~ /mozilla/;
    $self->confidence(-0.05, 'Word') if $self->{converters} =~ /rtf|word/;
    $xml = fix_chars($xml) if $self->{converters} =~ /pdftohtml/;
    my $blocks = $self->parse_xml(\$xml);
    # my $startblocks = $self->get_startblocks($blocks);
    # $self->get_metadata($startblocks);
    $self->get_metadata($blocks);
    $self->{document}->{text} = strip_tags($xml);
    return $self->{document};
}

sub parse_xml {
    my $self = shift;
    my $xmlref = shift or die 'parse_xml requires string ref parameter';
    my $chunks = $self->xml2chunks($xmlref) or die 'no text found in converted document';
    my $lines  = $self->chunks2lines($chunks);
    die 'no text found in converted document (2)' unless defined($lines->[1]);
    my $blocks = $self->lines2blocks($lines);
    # later, we presuppose that there are at least 2 blocks, that's why we check that here.
    die 'no text found in converted document (3)' unless defined($blocks->[1]);
    return $blocks;
}

sub xml2chunks {
    my $self = shift;
    my $xmlref = shift or die 'xml2chunks requires string ref parameter';
    print "\n\n=== EXTRACTING TEXT CHUNKS ===\n" if $self->verbosity >= 3;
    # parse fontsize declarations:
    my %fontsizes = $$xmlref =~ /<fontspec id=\"(\d+)\" size=\"(\d+)\"/og; # id => size
    # parse all xml body chunks into @chunks array:
    my @pages = split /<page number=/, $$xmlref;
    $self->{document}->{pages} = $#pages;
    my %fontsize_freq; # for determining document fontsize
    my @chunks;
    my $strlen = 0;
    foreach my $p (1 .. $#pages) {
	while ($pages[$p] =~ /<text top=\"(\d+)\" left=\"(\d+)\" width=\"(\d+)\" height=\"(\d+)\" font=\"(\d+)\">(.*?)<\/text>/gso) {
	    my $chunk = {
		'top'     => $1,
		'left'    => $2,
		'width'   => $3,
		'height'  => $4,
		'bottom'  => $1 + $4,
		'right'   => $2 + $3,
		'fsize'   => $fontsizes{$5} || 1, # yes, sometimes blocks have unspec'd font: 49803
		'text'    => $6,
		'page'    => $p,
		'textpos' => $strlen
		};
	    # fix S I L L Y S P A C E S left by pdftohtml:
	    if ($chunk->{text} !~ /\p{isAlpha}{2}/ && $chunk->{text} =~ /\p{isAlpha}\s\p{isAlpha}/) {
		$chunk->{text} =~ s/\s//g;
	    }
	    push @chunks, $chunk;
	    $fontsize_freq{$chunk->{fsize}}++;
            $strlen += length $chunk->{text};
	}
   }
    my $fontsize = 0;
    foreach my $fs (keys %fontsize_freq) {
	if (!$fontsize || $fontsize_freq{$fs} > $fontsize_freq{$fontsize}) {
	    $fontsize = $fs;
	}
    }
    $self->{document}->{fontsize} = $fontsize;
    return \@chunks;
}

sub chunks2lines {
    my $self = shift;
    my $chunks = shift or die 'chunks2lines requires array ref parameter';
    print "\n\n=== MERGING CHUNKS INTO LINES ===\n" if $self->verbosity >= 3;
    my @lines;
    for (my $i=0; $i<= scalar(@{$chunks})-1; $i++) {
	print "\nchunk $i: ", $chunks->[$i]->{text} if $self->verbosity > 4;
	my %line = %{$chunks->[$i]};
	my @line_chunks = ($chunks->[$i]);
	my %longest_chunk = %{$chunks->[$i]};
	my $min_top = $chunks->[$i]->{top};
	my $max_bottom = $chunks->[$i]->{bottom};
	while ($chunks->[$i+1]) {
	    my %chunk = %{$chunks->[$i+1]};
	    print "\nchunk $i+1: ", $chunk{text} if $self->verbosity > 4;
	    my $tolerance = ($max_bottom - $min_top) / 2;
	    $tolerance = 10 if $tolerance < 10; # e.g. line beginning with small, superscripted footnote label
	    if ($min_top - $chunk{top} > $tolerance) {
		print "\nline ends: chunk is too high (",($min_top-$chunk{top})." from \$min_top, tolerance $tolerance)" if $self->verbosity > 4;
		last;
	    }
	    if ($chunk{bottom} - $max_bottom > $tolerance) {
		print "\nline ends: chunk is too low (",($chunk{bottom}-$max_bottom)," from \$max_bottom, tolerance $tolerance)" if $self->verbosity > 4;
		last;
	    }
	    my $em = $chunk{fsize};
	    if ($chunk{left} < $chunks->[$i]->{right} - $em/2) {
		print "\nline ends: chunk is too far left ($chunk{left} from $chunks->[$i]->{right})" if $self->verbosity > 4;
		last;
	    }
	    if ($chunk{left} > $chunks->[$i]->{right} + 5*$em) {
		print "\nline ends: chunk is too far right ($chunk{left}, from $chunks->[$i]->{right})" if $self->verbosity > 4;
		last;
	    }
	    my $distance = $chunk{left} - $chunks->[$i]->{right};
	    print "\npre-fixing space if $distance > $em/5: " if $self->verbosity > 4;
	    $chunk{text} = ' '.$chunk{text} if ($distance > $em/5);
	    push @line_chunks, {%chunk};
	    $min_top = min($min_top, $chunk{top});
	    $max_bottom = max($max_bottom, $chunk{bottom});
	    %longest_chunk = %chunk if ($chunk{width} > $longest_chunk{width});
            $i++;
	}
	$line{fsize} = $longest_chunk{fsize} || 1;
	$line{top} = $longest_chunk{top} || 1;
	$line{bottom} = $longest_chunk{bottom} || 1;
	$line{height} = $longest_chunk{height} || 1;
	$line{abstop} = $min_top; # including sub/supscripts
	$line{absbottom} = $max_bottom;
	$line{absheight} = $max_bottom - $min_top;
	$line{col} = 0;
	$line{text} = '';
	foreach my $chunk (@line_chunks) {
	    if ($chunk->{bottom} < $line{bottom} && $chunk->{top} < $line{top}) {
		$line{text} .= '<sup>'.$chunk->{text}.'</sup>';
	    }
	    elsif ($chunk->{bottom} > $line{bottom} && $chunk->{top} > $line{top}) {
		$line{text} .= '<sub>'.$chunk->{text}.'</sub>';
	    }
	    else {
		$line{text} .= $chunk->{text};
	    }
	    $line{right} = $chunk->{right};
	}
        $line{text} =~ s/\n//g; # PDF files can have silly \n
	$line{width} = $line{right} - $line{left};
	# ignore empty lines, they only cause trouble:
	if ($line{height} > 0 && strip_tags($line{text}) !~ /^\s*$/) {
	    print "\nline: $line{text}\n" if $self->verbosity > 3;
	    push @lines, {%line};
	}
    }

    # The order of the lines is not reliable: sometimes first line even
    # in a PDF is a footnote. So we gotta sort them. But sorting simply
    # by page number and vertical position gets multi-column layouts
    # wrong. So we assign column numbers to the lines:
    #
    #  | col1 col1 col1  |
    #  | col2 | col3     |
    #  | col2 | col3     |
    #  | col4 col4 col4  |

    @lines = sort { $a->{page}*10000 + $a->{top} <=> $b->{page}*10000 + $b->{top} } @lines;
    my $numcols = 1;
    foreach my $i (0 .. $#lines) {
	$lines[$i]->{col} = $numcols unless $lines[$i]->{col};
	print "--line $i ($lines[$i]->{text}): $lines[$i]->{col}.\n" if $self->verbosity > 4;
	if ($lines[$i+1]
	    && length($lines[$i]->{text}) > 5 && length($lines[$i+1]->{text}) > 5
	    && $lines[$i+1]->{page} == $lines[$i]->{page}
	    && $lines[$i+1]->{left} > $lines[$i]->{right}
	    && $lines[$i+1]->{col} <= $lines[$i]->{col}) {
	    print "$i+1 is to the right of $i.\n" if $self->verbosity > 4;
	    # i+1 is to the right of i and not yet recognized as
	    # different columns. Look up and down for more lines
	    # belonging to their blocks until we encounter lines that
	    # break the border:
	    my @leftcol = ($lines[$i]);
	    my @rightcol = ($lines[$i+1]);
	    my $j = $i;
	    my $unbroken = 1;
	    while ($unbroken) {
		$j = ($j <= $i ? $j-1 : $j+1);
		$unbroken = $lines[$j] && $lines[$j]->{page} == $lines[$i]->{page};
		# only consider lines from the same column as i and i+1:
		if ($unbroken && (!$lines[$j]->{col} || $lines[$j]->{col} == $lines[$i]->{col})) {
		    if ($lines[$j]->{right} < $lines[$i+1]->{left}) {
			print "line $j on same col as $i.\n" if $self->verbosity > 4;
			push @leftcol, $lines[$j];
		    }
		    elsif ($lines[$j]->{left} > $lines[$i]->{right}) {
			print "line $j on same col as $i+1.\n" if $self->verbosity > 4;
			push @rightcol, $lines[$j];
		    }
		    else {
			$unbroken = 0;
		    }
		}
		if (!$unbroken && $j < $i) {
		    $j = $i+1; # start looking downwards
		    $unbroken = 1;
		}
	    }
	    if ($#leftcol > 2 && $#rightcol > 2) {
		$numcols++;
		foreach my $line (@leftcol) {
		    $line->{col} = $numcols;
		}
		$numcols++;
		foreach my $line (@rightcol) {
		    $line->{col} = $numcols;
		}
	    }
	    else {
		print "ignoring columnisation: too small" if $self->verbosity > 4;
	    }
	}
    }
    if ($numcols > 1) {
	$self->confidence(-0.05, 'multi-column layout');
	@lines = sort { $a->{page}*100000 + $a->{col}*1000 + $a->{top} <=>
			  $b->{page}*100000 + $b->{col}*1000 + $b->{top} } @lines;
    }
    print Dumper @lines if $self->verbosity > 5;
    $self->{document}->{lines} = $#lines;
    return \@lines;
}

sub lines2blocks {
    my $self = shift;
    my $lines = shift or die 'lines2blocks requires array ref parameter';
    print "\n\n=== MERGING LINES INTO BLOCKS ===\n" if $self->verbosity >= 3;
    my @blocks;
    # first we calculate the most common line spacing, and the left and right border of the document:
    my %spacings;
    my @edges;
    my $prevline;
    foreach my $line (@{$lines}) {
	if ($prevline && $line->{height}) {
	    my $spacing = ($line->{top} - $prevline->{top}) / $line->{height};
	    $spacings{$spacing}++ if ($spacing > 0.5); # sometimes lines are detected wrongly
	}
	push @edges, $line->{left};
	push @edges, $line->{right};
	$prevline = $line;
    }
    my $normal_spacing = 0;
    foreach my $sp (keys %spacings) {
	if (!$normal_spacing || $spacings{$sp} > $spacings{$normal_spacing}) {
	    $normal_spacing = $sp;
	}
    }
    print "most common line spacing: $normal_spacing\n" if $self->verbosity > 2;
    @edges = sort {$a <=> $b} @edges;
    my $doc_left = $edges[0];
    my $doc_right = $edges[-1];
    print "document left border: $doc_left; right border: $doc_right\n" if $self->verbosity > 2;
    $self->{document}->{linespacing} = $normal_spacing;
    $self->{document}->{left} = $doc_left;
    $self->{document}->{right} = $doc_right;

    # assign 'align' and 'boldness' property to lines:
    my $boldness_re = qr/^\s*<(b|i)>  # start tag
	(?:<(b|i)>)?                  # optional second tag: <i><b>title<.b><.i>
	.+                            # content
	<\/.>                         # end tag
	\s*\W?(<sup>.+<\/sup>)?\s*    # optional junk appended
	$/ix;
    foreach my $line (@{$lines}) {
	$line->{boldness} = 0;
	if ($line->{text} =~ /$boldness_re/) {
	    $line->{boldness} = ($1 =~ /b/i || $2 && $2 =~ /b/i) ? 3 : 1;
	}
	if (strip_tags($line->{text}) !~ /\p{IsLower}/) { # all caps
	    $line->{boldness} += 2;
	}
	$line->{align} = 'center';
	$line->{align} = 'left' if ($line->{left} < $doc_left+5);
	if ($line->{right} > $doc_right-5) {
	    $line->{align} = ($line->{align} eq 'left') ? 'justify' : 'right';
	}
    }

    # now merge the lines into blocks
    for (my $i=0; $i<=$#$lines; $i++) {
	#print "line $i: ",$lines->[$i]->{text},"\n" if $self->verbosity > 4;
	print Dumper $lines->[$i] if $self->verbosity > 4;
	#if (strip_tags($lines->[$i]->{text}) =~ /^\s*$/) {
	#    print "skipping empty line $i\n" if $self->verbosity > 4;
	#    next;
	#}
	# new text block:
	print "new block: ",$lines->[$i]->{text},"\n" if $self->verbosity > 4;
	my %block = %{$lines->[$i]};
	$block{spacing} = 0;
	while ($lines->[$i+1]) {
	    my %line = %{$lines->[$i+1]}; # candidate next line
	    print "line $i+1: ",$line{text},"\n" if $self->verbosity > 4;
	    if (strip_tags($line{text}) =~ /^(?:\s|\*|\x{2217})*$/) {
		# ignore empty lines or lines containing only a footnote symbol:
		print "ignoring empty line\n" if $self->verbosity > 4;
		$i++;
		next;
	    }
	    if ($line{fsize} != $block{fsize}) {
		print "block ends: next line has different font size\n" if $self->verbosity > 4;
		last;
	    }
	    if ($line{boldness} != $lines->[$i]->{boldness}) {
                # don't catch "blabla <i>bla</i> bla\n<i>bla</i>.":
                unless ($line{text} =~ /^\s*<(.?)>/ && $block{text} =~ /<$1>/) {
		    print "block ends: boldness face changing\n" if $self->verbosity > 4;
		    last;
		}
	    }
	    # check for large gaps:
	    my $acceptable_spacing = $block{spacing} ? 1.15 * $block{spacing} : 1.45 * $normal_spacing;
	    my $spacing = ($line{top} - $lines->[$i]->{top}) / $lines->[$i]->{height};
	    if (abs($spacing) > $acceptable_spacing) {
		print "block ends: large spacing $spacing (acceptable: $acceptable_spacing, block: $block{spacing}, normal: $normal_spacing)\n" if $self->verbosity > 4;
		last;
	    }
	    # check for alignment/indentation changes:
	    my $dist_left = $line{left} - $lines->[$i]->{left};
	    $dist_left = 10 if ($line{text} =~ /^   /); # sometimes indentation is by whitespace characters
	    my $dist_right = $lines->[$i]->{right} - $line{right};
	    if (abs($dist_left) < 10) {
		$block{align} = (abs($dist_right) < 10) ? 'justify'
		    : ($block{align} ne 'justify') ? 'left' # justified blocks may end left-aligned
		    : $block{align};
	    }
	    elsif ($dist_left > 5 && ($block{align} eq 'left' || $block{align} eq 'justify')) {
		if ($block{text} !~ /\.(?:<[^>]+>|\s)*/) { # first lines of centered text looked justified
		    $block{align} = 'center';
		}
		elsif (strip_tags($lines->[$i]->{text}) =~ /^\p{IsUpper}/)  {
		    print strip_tags($block{text})." block ends: next line is too far right (indented paragraph)\n" if $self->verbosity > 4;
		    last;
		}
	    }
	    #commented because it strips indented first line from ragged paragraphs.
	    #elsif ($dist_right < -10 && $line{align} ne 'center') {
	    #   print "block ends: next line extends too far on both sides\n" if $self->verbosity > 2;
	    #   last;
	    #}
	    else {
		$block{align} = $line{align};
	    }
	    print "block continues: ".$line{text}. " (align ".$block{align}.")\n" if $self->verbosity > 4;
	    $block{spacing} = $spacing;
	    $block{text} .= "\n".$line{text};
	    $block{left} = min($block{left}, $line{left});
	    $block{width} = max($block{width}, $line{width});
	    $i++;
	    # if ($this->verbosity > 4) print "block:\n".var_export($block, true)."\n\n" if $self->verbosity > 4;
	}
        # fix words split at line breaks:
        $block{text} =~ s/([a-z])-\n([a-z])/$1$2/g;
	$block{index} = scalar @blocks;
	push @blocks, {%block};
	print Dumper(\%block) if $self->verbosity >= 5;
    }
    # I once checked here for blocks of the form
    #    paragraph -> quote/example/formula -> paragraph,
    # (like this very comment) and tried to merge them. But this would
    # occasionally merge author -> title -> first paragraph. So we
    # leave such blocks un-merged for now and add some heuristics to
    # get_abstract
    return \@blocks;
}

sub get_startblocks { # xxxx this is not used any more, looking for author name at end
    my $self = shift;
    my $blocks = shift or die 'get_title_and_authors requires blocks parameter';
    print "\n\n=== getting start blocks ===\n" if $self->verbosity > 3;
    my @floats;
    my $limit = min($#$blocks, 30);
    foreach my $i (0 .. $limit) {
	if (length($blocks->[$i]->{text}) <= 1) {
	    print "\nblock $i is too short: ",$blocks->[$i]->{text} if $self->verbosity > 3;
	    next;
	}
	#if ($i > 1 && length($blocks->[$i]->{text}) > 300) {
	#   print "\nblock $i is too long: ",substr($blocks->[$i]->{text}, 0, 30) if $self->verbosity > 3;
	#   next;
	#}
	push @floats, $blocks->[$i];
    }
    return \@floats;
}

sub get_metadata {
    my $self = shift;
    my $blocks = shift or die 'get_metadata requires blocks parameter';
    print "\n\n=== scanning for author, title, abstract ===\n" if $self->verbosity > 2;

    my (@authors, $first_author_id, $last_author_id);
    my ($title, $title_id);
    my ($abstract, $abstract_id);

    # We go through all blocks and assign to each a title_score based
    # on facts like font size, text content, position on page,
    # etc. Then we do the same with author_score, and (later)
    # with abstract_score.
    my %title_score;     # id => score, a negative or positive number; 0 means neutral
    my %author_score;
    foreach my $id (0 .. $#$blocks) {
	$author_score{$id} = $self->author_score($blocks, $id);
    }
    foreach my $id (0 .. $#$blocks) {
	$title_score{$id} = $self->title_score($blocks, $id) if ($id < 30);
    }

    # Order ids by scores:
    my @title_order =  sort {$title_score{$b} <=> $title_score{$a} } keys %title_score;
    my @author_order =  sort {$author_score{$b} <=> $author_score{$a} } keys %author_score;

    # Sometimes title, author and publication info or address are in a
    # single block; if so, split the block by lines and re-classify:
    if ($title_score{$title_order[0]} < 2 && $blocks->[$author_order[0]]->{text} =~ /\n/) {
	$self->confidence(-0.05, "splitting author block: might contain title");
	my @new_blocks = ();
	my $j=0;
	for (my $i=0; $i<=$#$blocks; $i++) {
	    if ($i == $author_order[0]) {
		foreach my $textline (split /\n/, $blocks->[$i]->{text}) {
		    my %bl = %{$blocks->[$i]};
		    $bl{index} = $i + $j;
		    $bl{text} = $textline;
		    push @new_blocks, \%bl;
		    $j++;
		}
	    }
	    else {
		$blocks->[$i]->{index} = $i + $j;
		push @new_blocks, $blocks->[$i];
	    }
	}
	return $self->get_metadata(\@new_blocks);
    }

    # We take the highest ranked title block, except if that is the
    # only good author candidate:
    $title_id = $title_order[0];
    if ($title_id == $author_order[0]) {
	$self->confidence(-0.08, "best author candidate == best title candidate");
	# Use other title?
	if ($blocks->[$title_id]->{text} !~ /\w.*[:,\n].*\w/ # doesn't look like 'author:title'
	    && $title_score{$title_id} < 2 * $title_score{$title_order[1]} # second best isn't so bad
	    && $author_score{$title_id} > 3 * $author_score{$author_order[1]}) { # second best author much worse
	    $self->confidence(-0.02, "using second best title candidate"); # will be punished hard below by 'no clear title'
	    $title_id = $title_order[1];
	}
    }
    # If the title score is very bad, we may choose a prior value instead:
    if ($title_score{$title_id} < 1) {
	$self->confidence(-0.2, "no good title");
	my $curprob = 0;
	while (my($name, $prob) = each(%{$self->{_priors}->{title}})){
	    $title = $name if ($prob > $curprob);
	    $title_id = 0;
	}
    }
    if (!$title) { # i.e. if we didn't just set it to the prior
	$title = $blocks->[$title_id]->{text} || '';
	$title = tidy($title);
	# is our title clearly ahead?
	if ($title_score{$title_id} < 1.5 * $title_score{$title_order[1]}) {
	    $self->confidence($title_order[1] == $author_order[0] ? -0.05 : -0.1, "no clear title");
	}
	# do we have a multi-line title spread over several blocks?
        if (defined $blocks->[$title_id+1]) {
	    my $merge_titles = 1;
	    $merge_titles = 0 if $title =~ m/\n/ || $blocks->[$title_id+1] =~ m/\n/;
	    $merge_titles = 0 if $blocks->[$title_id+1]->{title_score} < -5;
	    $merge_titles = 0 unless $title =~ m/[:\;\-,]$/;
	    if ($merge_titles) {
		$title .= ' '.$blocks->[$title_id+1]->{text};
		$title = tidy($title);
		$self->confidence(-0.03, "merging title blocks");
	    }
	}
	$title =~ s/\n/ /g;
	# shorten title if too long:
	if (length($title) > 200) {
	    $title = substr($title, 0, index($title, ' ', 190)).'...';
	}
	print "\nprovisionary title: $title.\n" if $self->verbosity > 2;
	# this string might still contain the author name. See below.
    }
    $title = "[Untitled]" unless ($title && length($title));

    # Now on to the authors. Here we can't just take the best
    # candidate because there could be several author blocks.
    # We go through the author blocks in order of quality, though
    # eventually we want authors in the order of their appearance; so
    # we first store all authors in an 'authors' property of the
    # blocks, and then collect them from there:
    my $best_block;
    foreach my $i (@author_order) {
	last if ($author_score{$i} < 0);
	my @known = @{$blocks->[$i]->{known_authors}};
	my @unknown = @{$blocks->[$i]->{unknown_authors}};
	print "\nchecking authors @known/@unknown.\n" if $self->verbosity > 2;
	# compare this block to first and therefore best author block:
	my $diff_to_best = 0;
	if (defined $best_block) {
	    print "diffs to best: " if $self->verbosity > 3;
	    $diff_to_best++ if $blocks->[$i]->{align} ne $best_block->{align};
	    $diff_to_best++ if $blocks->[$i]->{fsize} != $best_block->{fsize};
	    $diff_to_best++ if $blocks->[$i]->{boldness} != $best_block->{boldness};
	    $diff_to_best += abs($blocks->[$i]->{page} - $best_block->{page});
	    print "$diff_to_best" if $self->verbosity > 3;
	    # other side of title:
	    $diff_to_best += 2 if ($i < $title_id) != ($first_author_id < $title_id);
	    print ",$diff_to_best" if $self->verbosity > 3;
	    # far away from title and other authors:
	    my $offset = min(min(
				 abs($blocks->[$i]->{textpos} - $blocks->[$first_author_id]->{textpos}),
				 abs($blocks->[$i]->{textpos} - $blocks->[$last_author_id]->{textpos})),
			         abs($blocks->[$i]->{textpos} - $blocks->[$title_id]->{textpos})
			    );
	    $diff_to_best += $offset/300;
	    print ",$diff_to_best" if $self->verbosity > 3;
	    # difference in author score (mainly for lowering confidence):
	    $diff_to_best += ($author_score{$best_block->{index}} - $author_score{$i})/20;
	    print ",$diff_to_best\n" if $self->verbosity > 3;
	}
	next if ($diff_to_best > 2);
	if (grep /^\Q$title\E$/, @known) {
	    $self->confidence(-0.18, "title '$title' recognized as author @known");
	    @known = grep { $_ ne $title } @known; # remove title from @known
	}
	@unknown = grep { $_ ne $title } @unknown; # remove title from @unknown
	foreach my $unknown (@unknown) {
	    if ($self->is_name($unknown)) {
		$self->confidence(-0.04, "unknown author $unknown");
		$self->confidence(-0.05, "unknown author without first name") if $unknown =~ /^. /;
		push @known, $unknown;
	    }
	}
	if (@known) {
	    $self->confidence(-$diff_to_best/20, "diff $diff_to_best to best author block") if $diff_to_best;
	    print "authors: @known.\n" if $self->verbosity > 1;
	    $blocks->[$i]->{authors} = \@known;
	    if (!defined $best_block) {
		$first_author_id = $last_author_id = $i;
		$best_block = $blocks->[$i];
	    }
	    else {
		$first_author_id = min($first_author_id, $i);
		$last_author_id = max($last_author_id, $i);
	    }
	}
    }
    # Collect authors in correct order:
    foreach my $i (0 .. $#$blocks) {
	next unless defined $blocks->[$i]->{authors};
 	my @au = @{$blocks->[$i]->{authors}};
	# remove duplicates and empty authors:
      DU: foreach my $a (@au) {
	    next unless defined $a;
	    foreach my $b (@authors) {
		if (same_author($a, $b)) {
		    print "$a == $b\n" if $self->verbosity > 2;
		    next DU;
		}
	    }
	    push @authors, $a
	}
    }
    if (!@authors) {
	$self->confidence(-0.25, "no author"); # only -0.2 because usually follows "no good author"
	# use best prior if available:
	my $curprob = 0;
	while(my($name, $prob) = each(%{$self->{_priors}->{author}})){
	    if ($prob > $curprob) {
		@authors = ($name);
		$self->confidence(+0.1, "using prior $name as author");
	    }
	}
	$last_author_id = 0;
    }
    else {
	if ($author_score{$best_block->{index}} < 2) {
	    $self->confidence(-0.13, "no good author");
	}
	# remove author strings from $title:
	my $authors_pattern = join '|', map(quotemeta, @authors);
	my $authors_re = qr/$authors_pattern/i;
	my $matches = 0;
	while ($title =~ /^(.{5,})\s*(?:by|and|&amp;|\W)?\s*$authors_re.*/i) { # end, also strip remainder (email etc)
	    $title = tidy($1) || '';
	    $matches++;
	    last if $matches > 5;
	}
	while ($title =~ /^\s*$authors_re(?:and|&amp;|\W)?\s*(.*)/i) { # beginning
	    $title = tidy($1) || '';
	    $matches++;
	    last if $matches > 5;
	}
	$self->confidence((@authors > 1 ? -0.14 : -0.07), "removing author /$authors_re/ from title") if $matches;
	if (length($title) < 2) {
	    $self->confidence(-0.2, "no title left after author removal: $title");
	}
    }

    # Now determine abstract scores. But first, we merge blocks of the form
    #    blah blah blah
    #      (1) foo
    #    blah blah blah.
    # (We didn't do that earlier because it often messes up title/author stuff.)
    my @new_blocks = ();
    my $mergings = 0;
    for (my $i=0; $i<=$#$blocks; $i++) {
	push @new_blocks, $blocks->[$i];
        next if ($i <= $title_id || ($i <= $last_author_id && $last_author_id < 10));
	$blocks->[$i]->{index} -= $mergings;
	my $j;
	for ($j=$i; defined $blocks->[$j+2]; $j+=2) {
	    last if ($blocks->[$j+1]->{left} <= $blocks->[$j]->{left});
	    # all kinds of factors are relevant here; we check them all and make a guess
	    my $should_merge = 0;
	    $blocks->[$j+1]->{left} >= $blocks->[$j]->{left} + 20        && ($should_merge += 5);
	    $blocks->[$j+1]->{text} =~ /^\s*\(?.{1,3}\)|\(.{1,3}\)\s*$/  && ($should_merge += 7); # labeled formula
	    $blocks->[$j]->{text} =~ /:\s*$/                             && ($should_merge += 5);
	    $blocks->[$j+1]->{fsize} > $blocks->[$j]->{fsize}            && ($should_merge -= 10);
	    $blocks->[$j+2]->{left} != $blocks->[$j]->{left}             && ($should_merge -= 8);
	    $blocks->[$j+1]->{right} > $self->{document}->{right} - 50   && ($should_merge -= 5);
	    $blocks->[$j]->{boldness} > 0                                && ($should_merge -= 7); # heading before indented par?
	    $blocks->[$j]->{text} =~ /\.\s*$/                            && ($should_merge -= 5); # par ends before indented par?
	    $blocks->[$j+1]->{text} =~ /[a-z\-]\s*$/                     && ($should_merge -= 5); # indented par?
	    print "\nmerging blocks? (\$should_merge $should_merge):"
	      ."\n  +".substr($blocks->[$j]->{text},0,20)
	      ."\n  +".substr($blocks->[$j+1]->{text},0,20)
	      ."\n  +".substr($blocks->[$j+2]->{text},0,20) if $self->verbosity > 4;
	    last if $should_merge <= 0;
	    $blocks->[$j+1]->{text} =~ s/\n/<br>\n/g;
	    $blocks->[$i]->{text} .= "\n<blockquote>\n".$blocks->[$j+1]->{text}."\n</blockquote>\n".$blocks->[$j+2]->{text};
	    $mergings += 2;
	}
	$i = $j;
    }
    $blocks = \@new_blocks;

    my %abstract_score;  # id => score
    foreach my $id (0 .. $#$blocks) {
	my $bl = $blocks->[$id];
	$abstract_score{$id} = $self->abstract_score($blocks, $id, $title_id) if $id < 30;
    }
    my @abstract_order =  sort {$abstract_score{$b} <=> $abstract_score{$a} } keys %abstract_score;

    $abstract = $blocks->[$abstract_order[0]]->{text} || '';
    $abstract_id = $abstract_order[0];

    if ($abstract_score{$abstract_id} < 0) {
	$self->confidence(-0.08, "no good abstract");
    }

    # we can easily mess up mergings of blocks:
    if ($abstract =~ m/<blockquote/) {
    	$self->confidence(-0.02, "merged blocks in abstract");
    }
    # todo: merge abstracts that are split by page break?? xxx

    # tidy up:
    $abstract = tidy($abstract);
    $abstract =~ s/^(?:abstract|\d?.?\s*introduction)\W?//si; # chop "abstract" prefix
    $abstract .= '...' if ($abstract =~ /\w$/); # happens when we missed part of abstract on next page
    # shorten abstract if too long:
    if (length($abstract) > 2000) {
	$abstract = substr($abstract, 0, index($abstract, '. ', 1990)).'...';
    }

    # If there are multiple authors and the abstract contains one of
    # them not followed by a number (in brackets perhaps), remove it
    # -- most like a discussion/review of this guy.  We also delete
    # authors that occur first in the abstract: we probably got them
    # from here.
  LO: while (scalar @authors > 1) {
      for my $i (0 .. $#authors) {
	  my $au = $authors[$i];
	  $au =~ s/$re_name/$1/;
	  next if ($abstract !~ /\b\Q$au\E\b/i);
	  my $ok = 0;
	  for (my $j=0; $j<$abstract_id; $j++) {
	      $ok = 1 if ($j != $title_id && $blocks->[$j]->{text} =~ /\b\Q$au\E\b/i);
	  }
	  if (!$ok) {
	      $self->confidence(-0.12, "removing $au from authors: first occurrence in abstract");
	      splice @authors, $i, 1;
	      next LO;
	  }
	  if ($abstract =~ /\b\Q$au\E\b\D{4}/) {
	      $self->confidence(-0.12, "removing $au from authors: part of abstract");
	      splice @authors, $i, 1;
	      next LO;
	  }
      }
      last LO;
  }

    # reduce confidence if (single) author is part of abstract:
    my $au = $authors[0];
    $au =~ s/$re_name/$1/;
    $self->confidence(-0.15, "author in abstract") if ($au && $abstract =~ /\b\Q$au\E\b\D{4}/i);

    # reduce confidence depending on how much stuff is above title, author, abstract:
    my $offset = $blocks->[$last_author_id]->{textpos} || 0;
    $self->confidence(max($offset * -0.00006, -0.1), "$offset chars above author");
    $offset = $blocks->[$title_id]->{textpos};
    $self->confidence(max($offset * -0.00009, -0.2), "$offset chars above title");
    $offset = abs($blocks->[$abstract_id]->{textpos} - $offset);
    $self->confidence(max($offset * -0.00003, -0.1), "$offset chars above abstract");

    # reduce confidence if title contains unusual words:
    if ($title =~ /course|abstract|chapter|introduction$/i) {
	$self->confidence(-1.6, "title contains unusual words");
    }
    # if we've used OCR, reduce confidence if title is not in google:
    if ($self->{converters} =~ /OCR/ && !$self->in_google($title)) {
	$self->confidence(-2, "title not in google");
    }

    # fix all caps:
    $title = capitalize_title($title) if ($title !~ /\p{isLower}/);
    for my $i (0 .. $#authors) {
	$authors[$i] = capitalize_title($authors[$i]) if ($authors[$i] !~ /\p{isLower}/);
    }

    $self->{document}->{title} = $title;
    $self->{document}->{authors} = \@authors;
    $self->{document}->{abstract} = $abstract;

    print Dumper $self->{document} if $self->verbosity > 2;

}

sub author_score {
    my $self = shift;
    my $blocks = shift;
    my $id = shift;
    my $bl = $blocks->[$id];
    my $score = 0;

    # calculating the author score goes hand in hand with extracting author names;
    # so we take the opportunity to do both.

    $bl->{known_authors} = [];
    $bl->{unknown_authors} = [];
    my $doc_width = $self->{document}->{right} - $self->{document}->{left};

    print "\nscore author '".substr($bl->{text},0,20)."': " if $self->verbosity > 2;
    # author blocks tend to be at the beginning,
    # ... except maybe at very end, where the further down the better:
    if ($id < $#$blocks/2) {
	$score -= $bl->{textpos}/500;
    }
    else {
	$score -= 1;
	my $toend = $#$blocks-$id;
	$score -= $toend/10;
    }
    print $score, '|' if $self->verbosity > 2;
    # author blocks are narrow:
    $score += 1 - ($bl->{width} / $doc_width)*2;
    print $score, '|' if $self->verbosity > 2;
    # author blocks are mostly centered:
    # $score += ($bl->{align} eq 'left' || $bl->{align} eq 'justify') ? -0.5 : 0.5;
    $score += ($bl->{align} eq 'center') ? 0.5 : -0.5;
    print $score, '|' if $self->verbosity > 2;
    # author blocks are not footnotes:
    $score -= 2 if $bl->{text} =~ /^<sup>\d<\/sup>/;
    $score -= 1 if $bl->{fsize} < $self->{document}->{fontsize};
    print $score, '|' if $self->verbosity > 2;

    # now line by line:
    my @lines = split /\n/, $bl->{text};
    my $nothingfound = 1;
    foreach my $i (0 .. $#lines) {
	print '+' if $self->verbosity > 2;
	if ($i > 2 && $nothingfound) {
	    # no author candidate found until third line of block -- abort this block:
	    last;
	}
	# the further down the block, the worse:
	$score -= 0.2 if ($i > 0);
	print $score, '|' if $self->verbosity > 2;
	# tidy up line:
	my $line = $lines[$i];
	$line = strip_tags($line);
	# make sure line is not part of bibliography at end:
	$score -= 3 if ($id > $#$blocks/2 && $line =~/\d{4}|forthcoming|manuscript/);
	# ignore lines that don't begin with name (e.g. 'to appear in Hans Kamp (ed.), ...')
	if ($line =~ /^$re_pre_name?($re_name)/) {
	    if ($1 =~ /$re_bad_author/) {
		print "begins with bad name." if $self->verbosity > 3;
		next;
	    }
	}
	else {
	    print "doesn't begin with name." if $self->verbosity > 3;
	    next;
	}

	# split line by author separators:
	foreach my $part (split $re_authors_separator, $line) {
	    # strip footnotes and brackets after author:
	    $part = tidy($part);
	    next if (!$part);
	    if ($part !~ /^($re_pre_name?)$re_name($re_post_name?)$/) {
		print "$part not name|" if $self->verbosity > 2;
		last;
	    }
	    my ($pre, $surname, $post) = ($1, $2, $3);
	    if ($pre) {
		$part =~ s/^$re_pre_name//;
		$score -= 0.6;
	    }
	    if ($post) {
		$part =~ s/$re_post_name$//;
		$score -= 0.6;
	    }
	    if ($part =~ /$re_bad_author/) {
		print "$part bad|" if $self->verbosity > 2;
		$score -= 0.1;
		next; # not last: we can have "introduction: Daniel C. Dennett" xxx
	    }
	    if ($line =~ /$surname [\[\(]?\d{4}/) { # Despite Lewis (1999), my...
		$score -= 1.5;
	    }
	    $nothingfound = 0;
	    my $lookupname = substr($part,0,1)." $surname";
	    if ($self->is_known_author($lookupname)) {
		print "$lookupname known author|" if $self->verbosity > 2;
		push @{$bl->{known_authors}}, $part;
	    }
	    else {
		print "$part unknown author candidate ($pre)($surname)($post)|" if $self->verbosity > 2;
		push @{$bl->{unknown_authors}}, $part;
	    }
	    # check if author resembles prior:
	    while (my ($name, $prob) = each(%{$self->{_priors}->{author}})){
		if (amatch($name, ['i 30%'], $part)) {
		    print "$part resembles prior $name|" if $self->verbosity > 2;
		    $score += $prob * 5;
		}
	    }
	}
    }

    if (@{$bl->{known_authors}}) {
	$score += 4;
    }
    elsif (@{$bl->{unknown_authors}}) {
	$score += 2.5;
    }
    else {
	$score -= 5;
    }
    print $score, '|' if $self->verbosity > 2;
    $bl->{author_score} = $score;
    return $score;
}

sub title_score {
    my $self = shift;
    my $blocks = shift;
    my $id = shift;
    my $bl = $blocks->[$id];
    my $score = 0;

    print "\nscore title '".substr($bl->{text},0,20)."': " if $self->verbosity > 2;
    # near beginning of document:
    $score += 1 - max($id-2,0)/5; # first three elements equally good
    $score += 1 - max($bl->{textpos}-100,0)/500;
    print $score, '|' if $self->verbosity > 2;
    # larger fonts better:
    $score += 0.5 * min($bl->{fsize} - $self->{document}->{fontsize}, 10);
    print $score, '|' if $self->verbosity > 2;
    # bold:
    $score += 0.4 * $bl->{boldness};
    print $score, '|' if $self->verbosity > 2;
    # centered:
    $score += ($bl->{align} eq 'left' || $bl->{align} eq 'justify') ? -1 : 0.5;
    print $score, '|' if $self->verbosity > 2;
    # near top of page:
    $score -= abs(100-$bl->{top})/800;
    print $score, '|' if $self->verbosity > 2;
    # doesn't match bad title words:
    $score -= 2 if ($bl->{text} =~ /$re_bad_title/);
    print $score, '|' if $self->verbosity > 2;
    # has word characters in it:
    $score -= 3 if (strip_tags($bl->{text}) =~ tr/[a-zA-Z]// < 2);
    print $score, '|' if $self->verbosity > 2;
    # not high author score:
    $score -= 1 if ($bl->{author_score} > 3);
    print $score, '|' if $self->verbosity > 2;
    # reasonable length:
    $score += 
	length($bl->{text}) < 5 ? -1 :
	length($bl->{text}) < 10 ? 0 :
	length($bl->{text}) > 200 ? -3 :
	length($bl->{text}) > 100 ? -1 :
	length($bl->{text}) > 50 ? 0 :
	1;
    print $score, '|' if $self->verbosity > 2;
    # resembles prior:
    my ($name, $prob);
    while(($name, $prob) = each(%{$self->{_priors}->{title}})) {
	if (amatch($name, ['i 30%'], $bl->{text})) {
	    print "$bl->{text} resembles prior $name|" if $self->verbosity > 2;
	    $score += $prob * 5;
	}
    }
    print $score, '|' if $self->verbosity > 2;	
    $bl->{title_score} = $score;
    return $score;
}

sub abstract_score {
    my $self = shift;
    my $blocks = shift;
    my $id = shift;
    my $title_id = shift;
    my $bl = $blocks->[$id];
    my $score = 0;

    return -100 unless $bl->{text};
    print "\nscore abstract '".substr($bl->{text},0,20)."': " if $self->verbosity > 2;
    # near title, but not <= title:
    my $title_pos = $blocks->[$title_id]->{textpos};
    my $dist = $bl->{textpos} - $title_pos;
    $score += $dist < 0 ? -4 : $dist == 0 ? -10 : -$dist/400;
    print $score, '|' if $self->verbosity > 2;
    # prefer normal font:
    $score -= abs($bl->{fsize} - $self->{document}->{fontsize})/3;
    print $score, '|' if $self->verbosity > 2;
    # not bold:
    $score -= 0.5 if ($bl->{boldness});
    print $score, '|' if $self->verbosity > 2;
    # low density of bad_abstract words:
    $score -= 400/length($bl->{text}) while ($bl->{text} =~ /$re_bad_abstract/g);
    print $score, '|' if $self->verbosity > 2;
    # not centered:
    $score += ($bl->{align} eq 'left' || $bl->{align} eq 'justify') ? 1 : -0.5;
    print $score, '|' if $self->verbosity > 2;
    # begins with 'abstract':
    $score += 5 if ($bl->{text} =~ /^\s*abstract/i);
    print $score, '|' if $self->verbosity > 2;
    # previous block is 'abstract' heading:
    $score += 3 if ($id && $blocks->[$id-1]->{text} =~ /^\s*(?:<.+>)?abstract/i);
    print $score, '|' if $self->verbosity > 2;
    # is not a footnote:
    $score -= 3 if ($bl->{text} =~ /^\s*[\*\d\[]/);
    print $score, '|' if $self->verbosity > 2;
    # is not a motto:
    $score -= 1 if ($bl->{text} =~ /^\"[^\"]+\".{0-20}$/s);
    print $score, '|' if $self->verbosity > 2;
    # contains at least one fullstop:
    $score -= 2 if ($bl->{text} !~ /\./);
    print $score, '|' if $self->verbosity > 2;
    # contains at least one 'is':
    $score -= 1 if ($bl->{text} !~ /\bis\b/);
    print $score, '|' if $self->verbosity > 2;
    # is sufficiently long:
    $score +=
	length($bl->{text}) < 20 ? -8 :
	length($bl->{text}) < 60 ? -4 :
	length($bl->{text}) < 100 ? -2 :
	length($bl->{text}) > 250 ? +3 :
	length($bl->{text}) > 150 ? +2 :
	0;
    print $score, '|' if $self->verbosity > 2;
    $bl->{abstract_score} = $score;
    return $score;
}

sub is_known_author {
    my $self = shift;
    my $name = lc(shift);
    if (!$self->{author_names}) {
   	$self->{author_names} = {};
	open NAMES, AUTHORS_FILE or die "Couldn't open authors name list: $!";
	binmode(NAMES, ':utf8');
   	while (<NAMES>) {
	    chomp $_;
	    $self->{author_names}->{$_} = 1;
   	}
	close NAMES;
    }
    return 1 if $self->{author_names}->{$name};
    return 0;
}

sub add_author {
    my $self = shift;
    my $name = lc(shift);
    $self->{author_names}->{$name} = 1;
    open NAMES, ">>".AUTHORS_FILE;
    binmode(NAMES, ':utf8');
    print NAMES "$name\n";
    close NAMES;
}

sub is_known_notname {
    my $self = shift;
    my $name = lc(shift);
    if (!$self->{not_names}) {
   	$self->{not_names} = {};
	open NOTNAMES, NOTNAMES_FILE;
	binmode(NOTNAMES, ':utf8');
   	while (<NOTNAMES>) {
	    chomp $_;
	    $self->{not_names}->{$_} = 1;
   	}
	close NOTNAMES;
    }
    return 1 if $self->{not_names}->{$name};
    return 0;
}

sub add_notname {
    my $self = shift;
    my $name = lc(shift);
    $self->{not_names}->{$name} = 1;
    open NOTNAMES, ">>".NOTNAMES_FILE;
    binmode(NOTNAMES, ':utf8');
    print NOTNAMES "$name\n";
    close NOTNAMES;
}

sub is_firstname {
    my $self = shift;
    my $name = lc(shift);
    return 0 if length($name) < 2;
    if (!$self->{firstnames}) {
   	$self->{firstnames} = {};
	open FNAMES, FIRSTNAMES_FILE;
	binmode(FNAMES, ':utf8');
   	while (<FNAMES>) {
	    chomp $_;
	    $self->{firstnames}->{$_} = 1;
   	}
	close FNAMES;
    }
    return 1 if $self->{firstnames}->{$name};
    return 0;
}

sub same_author {
    my ($a, $b) = @_;
    return 0 unless ($a && ($a =~ /$re_name/));
    my $sur1 = lc($1);
    return 0 unless ($b && ($b =~ /$re_name/));
    my $sur2 = lc($1);
    return 1 if (substr($a,0,1) eq substr($b,0,1)) && ($sur1 eq $sur2);
    return 0;
}

sub is_name {
    my $self = shift;
    my $name = shift;
    return 0 if (!$name || $name !~ /^$re_name$/);
    my $lastname = $1;
    my ($firstname) = ($name =~ /(\p{IsUpper}[\p{IsAlpha}\-\']*)/);
    # is in blacklist?
    if ($self->is_known_notname("$firstname $lastname")) {
	print "$firstname $lastname is in blacklist.\n" if $self->verbosity > 2;
	return 0;
    }
    # exists on people.yahoo.com?
    print "looking up $firstname $lastname on people.yahoo.com.\n" if $self->verbosity > 2;
    my $url = "http://search.yahoo.com/search?p=first%3A\"$firstname\"+last%3A\"$lastname\"+&meta=pplt%3De&fr=php-emai";
    util::Io::verbosity($self->verbosity > 3 ? 1 : 0);
    my $http_res = fetch_url($url);
    if (!$http_res->is_success) {
	$self->confidence(-0.5, "yahoo lookup error ".$http_res->status_line);
	return 0;
    }
    if ($http_res->{content} =~ /id=.pplres/) {
	print "person found.\n" if $self->verbosity > 2;
	# disabled saving because yahoo finds things like "A Account":
	#$self->add_author(substr($name,0,1).' '.$lastname);
	return 1;
    }
    # pdf file linked in yahoo results AND firstname in name list?
    if ($http_res->{content} =~ />PDF</ && $self->is_firstname($firstname)) {
	print "person not found, but firstname is okay and PDF in result.\n" if $self->verbosity > 2;
	#$self->add_author(substr($name,0,1).' '.$lastname);
	return 1;
    }
    print "person not found.\n" if $self->verbosity > 2;
    $self->add_notname("$firstname $lastname");
    return 0;
}

sub in_google {
    my $self = shift;
    my $str = shift;
    $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg; # urlencode
    print "looking up '$str' on google.\n" if $self->verbosity > 2;
    my $url = "http://www.google.com/search?q=\"$str\"";
    util::Io::verbosity($self->verbosity > 3 ? 1 : 0);
    my $http_res = fetch_url($url);
    if (!$http_res->is_success) {
	$self->confidence(-0.5, "google lookup error ".$http_res->status_line);
	return 1;
    }
    if ($http_res->{content} =~ /did not match any|No results found for/) {
	print "nothing found.\n" if $self->verbosity > 2;
	return 0;
    }
    print "found.\n" if $self->verbosity > 2;
    return 1;
}

sub confidence {
    # simple method to boost or lower confidence. If current confidence is 0.5,
    # resulting confidence is 0.5 + arg; otherwise the effect is scaled according
    # to the value of confidence.
    my ($self, $boost, $msg) = @_;
    my $h = $self->{document}->{confidence};
    my $h2 = $h + $boost * ($boost > 0 ? 1-$h : $h)*2;
    $h2 = 0.05 if $h2 < 0.05;
    $self->{document}->{confidence} = $h2;
    print "confidence $h => $h2: $msg.\n" if $self->verbosity;
}

sub max {
    my $max = shift;
    for (@_) { $max = $_ if $max < $_ }
    return $max;
}

sub min {
    my $min = shift;
    for (@_) { $min = $_ if $min > $_ }
    return $min;
}

sub strip_scripts {
    my $str = shift;
    my $hss = HTML::StripScripts::Parser->new({
	Context   => 'Document',
	AllowSrc  => 1,
	AllowHref => 1,
	AllowRelURL => 1,
	AllowMailto => 1,
    });
    return $hss->filter_html($str);
}

sub fix_chars {
    # Certain characters and character combinations may be extracted
    # incorrectly, depending on the program that generated the PDF
    # file. For example, ligatures such as "fi", "fl", "ff" and "ffl"
    # are often rendered using a special glyph rather than as
    # individual characters, and this information may be lost in the
    # textual representation. Also, some PDF generating programs may
    # not correctly encode accented characters. For example, to draw a
    # lowercase "u" with an umlaut accent, LaTeX draws a "u" and then
    # draws an umlaut accent over it. This means that pdftohtml will
    # extract two separate characters '..' and 'u'.
    my $str = shift;
    $str =~ s/\x{a8}([AOUaou])/&$1uml;/g; # e.g. in 56544
    my %transl = (
		  "\x{fb00}" => "ff",
		  "\x{fb01}" => "fi",
		  "\x{fb02}" => "fl",
		  "\x{fb03}" => "ffi",
		  "\x{fb04}" => "ffl",
		  "\x{fb05}" => "st",
		 );
    while (my ($key,$esc) = each(%transl)) {
	$str =~ s/$key/$esc/g;
    }
    return $str;
}

sub tidy {
    my $str = shift;
    $str =~ s/^\s*(.+?)\s*$/$1/gm;         # chop whitespace at beginning and end of lines
    $str =~ s/<sup>\W?.\W?<.sup>$//;       # chop footnote marks like <sup>(1)</sup>
    $str = strip_tags($str);
    $str =~ s/(\*|\x{2217})$//;            # chop footnote star *
    $str =~ s/[\(\[] . [\)\]]$//x;         # chop non-<sup>'ed footnote symbols in brackets
    $str =~ s/([a-zA-Z\?!])\d\s*$/$1/;     # chop non-<sup>'ed number right after last word
    return $str;
}

# footnote symbol (to be stripped from authors and titles):
#$re_fnmark = qr/
#    <sup>\W?.\W?<.sup>  |         # <sup>(1)</sup>
#    \*|\x{2217}  |                # star *
#    [\(\[\s] \d [\)\]]            # (1) or [1]
#   /x;

# looks like a name:
$re_name = qr/
      (?:\p{IsUpper}\p{IsAlpha}*[\.\s\-\']+){1,3}        # first name(s)
      (?:\p{IsAlpha}+\s+){0,3}                           # von, van, de la, etc.
      (\p{IsAlpha}*\p{IsUpper}[\S\-\']*\p{IsAlpha}{2})   # surname, incl. deMoulin, O'Leary-Hawthorne
                                                         # \S because weird foreign chars sometimes not IsAlpha
    /x;

# stuff a name can be prefixed with:
$re_pre_name = qr/
    \s*(?:copyright|\(c\))[\s\d]*|     # "copyright Hans Kamp", "(c) 2009 H. Kamp" etc
    \s*\w*\s*by\s+|                    # "by Hans Kamp", "reviewed by Hans Kamp"
    \s*\d[\d\-\s]+                     # "2009 Hans Kamp"
    /ix;

# stuff a name can be postfixed with:
$re_post_name = qr/
    \s*\d[\d\-\.\s]+|                  # "Hans Kamp 12.12.2009"
    \s*\S+@\S+|                        # "Hans Kamp hans@kamp.de"
    \.                                 # "Hans, Peter, and Fred."
    /ix;

# stuff that separates authors:
$re_authors_separator = qr/
    \s*(?:
        \band\b|&amp;|,|
        :|                         # author: title
        \s[^\p{isAlpha}\d\.\s\@-]  # weird symbol
       )
    \s*
    /ix;

# strings that tend to disqualify a chunk of text as name:
$re_bad_author = qr/
    \d|
    \b(?:thanks?|forthcoming|editors?|edited|publish\w*|press|volume|
       draft|reprints?|excerpt|address|lecture|
       permission|circulation|please|
       university|center|centre|institute|sciences?|college|research|
       @|
       avenue|street|
       ann arbor|san diego|
       abstract|introduction|overview|
       on|the|for|of|with|to|about|this|what|new|account|by|
       search|home|
       free|
       see
       )\b
    /ix;

$re_bad_title = qr/(?:
    ^\s*\w[\.\)] |                                      # probably section heading
    \bthanks?\b|
    forthcoming|\bto appear in\b|\bdraft\b|\beditor|\d{4}|
    university|department|professor|
    abstract
    )/ix;

$re_bad_abstract = qr/(?:
    ^\s*<sup>|
    table of contents|\bdraft\b|forthcoming|\beditor|\bpress\b|\bpublish|Vol\.|
    terms and conditions|copyright|journal\b|jstor|permission|
    @|url|http|
    \bthank
    )/ix;


1;
