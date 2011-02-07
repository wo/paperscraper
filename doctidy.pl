#! /usr/bin/perl -w
use strict;
use warnings;
use Getopt::Std;
use List::Util qw/max min/;
use Data::Dumper;
use util::Io;
use util::Functools qw/reduce/;
binmode STDOUT, ":utf8";

sub usage() {
    print <<EOF;

Tidies up XML produced by pdftohtml: merges continuous text blocks,
inserts <sup> and <sub> tags, puts text blocks in right order, fixes
a few characters and words.

Call either from the command-line, or include and call the 'doctidy'
function with the XML file as argument.

Command-line usage: $0 [-hv] <file>

-v        : verbose
-h        : this message

EOF
    exit;
}

unless (caller) { # called from command-line
    my %opts;
    getopts("vh", \%opts);
    my $file = $ARGV[0];
    usage() if (!$file || $opts{h});
    doctidy($file, $opts{v});
}

my $verbose = 0;

sub doctidy {
    my $file = shift;
    $verbose = shift;
    print "\n\nDOCTIDY: $file\n" if $verbose;
    
    open IN, $file or die $!;
    open OUT, ">$file.tidy" or die $!;
    binmode(OUT, ":utf8");

    my $page = '';
    while (<IN>) {
	if (/^<text /) { 
	    $page .= $_;
	    next;
	}
	if (/^<\/page>/) {
	    print OUT pagetidy($page);
	    $page = '';
	}
	print OUT $_;
    }

    close IN;
    close OUT;

    rename "$file.tidy", $file;
}

sub pagetidy {
    my $page = shift;
    print "== tidying page ==\n" if $verbose;
    my @texts = split /\n/, $page;
    my @chunks = map { xml2chunk($_) } @texts;
    my $lines = reduce(\&mergechunks, [], @chunks);
    my @sorted = sortlines($lines);
    my $xml = reduce(\&chunk2xml, '', @sorted);
    return $xml;
}

sub elem {
    my $str = shift;
    return sub {
       my $attr = shift;
       if ($attr) {
	   return $str =~ /$attr="(.*?)"/ && $1;
       }
       if ($str =~ /<.+?>(.*)<.+>/) {
	   return fixchars($1);
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
	'text'    => $el->(),
    };
    $chunk->{right} = $chunk->{left} + $chunk->{width};
    $chunk->{bottom} = $chunk->{top} + $chunk->{height};
    $chunk->{col} = 0;
    return $chunk;
}

sub chunk2xml {
    my ($xml, $chunk) = @_;
    $xml .= sprintf('<text top="%u" left="%u" width="%u" '
		   .'height="%u" font="%u">%s</text>',
		   $chunk->{top}, $chunk->{left}, $chunk->{width},
		   $chunk->{height}, $chunk->{font}, $chunk->{text});
    return "$xml\n";
}

sub mergechunks {
    my ($lines, $chunk) = (@_);

    # skip empty chunks:
    unless ($chunk->{text} && $chunk->{text} =~ /\S/) {
	return $lines;
    }

    print "chunk: ", $chunk->{text}, "\n" if $verbose;

    # turn very first chunk into first line:
    unless (@$lines) {
	return [$chunk];
    }
    
    my $line = $lines->[-1];

    # Now the task is to check if $chunk continues $line, which is
    # also just a chunk (or a merger of chunks). If yes, we merge
    # $chunk onto the $line, else we add $chunk to @lines, thereby
    # starting a new line.

    # Is the chunk too high or too low?
    my $chunk_y = $chunk->{top} + $chunk->{height} / 2;
    my $min_y = $line->{top};
    my $max_y = $line->{bottom};
    if (length($chunk->{text}) < 5 || length($line->{text}) < 5) {
	# line or chunk might be a footnote label or the like:
	$min_y -= $line->{height}/4;
	$max_y += $line->{height}/4;
    }
    if ($chunk_y > $max_y || $chunk_y < $min_y) {
	print "  $chunk_y out of Y range $min_y-$max_y\n" if $verbose;
	push @$lines, $chunk;
	return $lines;
    }

    # Does the chunk begin too far right or left?
    my $chunk_x = $chunk->{left};
    my $ex = $line->{width} / length($line->{text});
    my $min_x = $line->{right} - $ex; # chunks overlap!
    my $max_x = $line->{right} + 5*$ex;
    if ($chunk_x > $max_x || $chunk_x < $min_x) {
	print "  $chunk_x out of X range $min_x-$max_x\n" if $verbose;
	push @$lines, $chunk;
	return $lines;
    }

    # OK, now merge $chunk into $line:
    print "  continues line\n" if $verbose;
    $line->{top} = min($line->{top}, $chunk->{top});
    my $bottom = max($max_y, $chunk->{top} + $chunk->{height});
    $line->{height} = $bottom - $line->{top};
    $line->{width} = $chunk->{right} - $chunk->{left};
    if (length($chunk->{text}) > length($line->{text})) {
	$line->{font} = $chunk->{font};
    }
    if ($chunk_x - $line->{right} > $ex/5) {
	print "  inserting whitespace\n" if $verbose;
	$line->{text} .= ' ';
    }
    if ($chunk->{bottom} < $max_y && $chunk->{top} < $line->{top}) {
	print "  chunk is <sup>\n" if $verbose;
	$line->{text} .= '<sup>'.$chunk->{text}.'</sup>';
    }
    elsif ($chunk->{bottom} > $max_y && $chunk->{top} > $line->{top}) {
	print "  chunk is <sub>\n" if $verbose;
	$line->{text} .= '<sub>'.$chunk->{text}.'</sub>';
    }
    else {
	$line->{text} .= $chunk->{text};
    }

    return $lines;
}

sub sortlines {
    my $lines = shift;

    print "== sorting lines ==\n" if $verbose;

    # The order of textelements produced by pdftohtml is not reliable:
    # sometimes a first line in a PDF is a footnote. (OTOH, the order
    # of chunks within a single line tends to be reliable.) Also,
    # sorting lines by vertical position would get multi-column
    # layouts wrong. 
    #
    # To sort the lines, I assign column numbers, like so:
    #
    #  | col1 col1 col1  |
    #  | col2 | col3     |
    #  | col2 | col3     |
    #  | col4 col4 col4  |

    my @lines = sort { $a->{top} <=> $b->{top} } @$lines;

    my $numcols = 1;
    foreach my $i (0 .. $#lines) {

	$lines[$i]->{col} = $numcols unless $lines[$i]->{col};

	if ($lines[$i+1]
	    && length($lines[$i]->{text}) > 5
	    && length($lines[$i+1]->{text}) > 5
	    && $lines[$i+1]->{left} > $lines[$i]->{right}
	    && $lines[$i+1]->{col} <= $lines[$i]->{col}) {

	    if ($verbose) {
		print "line $i: ",$lines[$i]->{text},"\n";
		print "line $i+1: ",$lines[$i+1]->{text},"\n";
		print "line $i+1 is to the right of $i.\n" if $verbose;
	    }
	    # i+1 is to the right of i and not yet recognized as
	    # different column. Look up and down for more lines
	    # belonging to their blocks until we encounter lines that
	    # break the border:

	    my @leftcol = ($lines[$i]);
	    my @rightcol = ($lines[$i+1]);
	    my $j = $i;
	    my $unbroken = 1;
	    while ($unbroken) {
		$j = ($j <= $i ? $j-1 : $j+1);
		$unbroken = $lines[$j];

		# only consider lines from the same column as i and i+1:
		if ($unbroken && (!$lines[$j]->{col} 
		    || $lines[$j]->{col} == $lines[$i]->{col})) {
		    if ($lines[$j]->{right} < $lines[$i+1]->{left}) {
			print "line $j same col as $i.\n" if $verbose;
			push @leftcol, $lines[$j];
		    }
		    elsif ($lines[$j]->{left} > $lines[$i]->{right}) {
			print "line $j same col as $i+1.\n" if $verbose;
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
		print "ignoring columnisation: too small\n" if $verbose;
	    }
	}
    }
    if ($numcols > 1) {
	@lines = sort { $a->{col}*1000 + $a->{top} <=>
			$b->{col}*1000 + $b->{top} } @lines;
    }
    return @lines;
}

sub fixchars {
    my $str = shift;

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

    # strip newline characters within text chunks:
    $str =~ s/\n//g;

    # strip S I L L Y S P A C E S left by pdftohtml:
    # TODO -- should be much more careful here, checking with
    # dictionaries, etc.
    if ($str !~ /\p{isAlpha}{2}/ && $str =~ /\p{isAlpha}\s\p{isAlpha}/) {
	$str =~ s/\s//g;
    }

    return $str;
}
