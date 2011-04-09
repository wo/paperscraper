package Doctidy;
use strict;
use warnings;
use Encode;
use utf8;
use Getopt::Std;
use List::Util qw/max min/;
use Data::Dumper;
use util::Io;
use util::String 'strip_tags';
use util::Functools qw/reduce/;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&doctidy/;

binmode STDOUT, ":utf8";

sub usage() {
    print <<EOF;

Tidies up XML produced by pdftohtml: merges continuous text blocks,
inserts <sup> and <sub> tags, puts text blocks in right order, fixes
a few characters and words.

Can be called from the command-line, or included as a module.
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
sub verbose {
    $verbose = shift if @_;
    return $verbose;
}

sub doctidy {
    my $file = shift;
    print "\n\nDOCTIDY: $file\n" if $verbose;
    
    open IN, $file or die $!;
    open OUT, ">$file.tidy" or die $!;
    binmode(OUT, ":utf8");

    my $page = '';
    while (<IN>) {
        $_ = Encode::decode_utf8($_);
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
       if ($str =~ /^<.+?>(.*)<.+?>$/) {
           return tidy_text($1);
       }
    };
}

sub xml2chunk {
    my $str = shift;
    my $el = elem($str);
    my $chunk = {
        'top'       => $el->('top'),
        'left'      => $el->('left'),
        'width'     => $el->('width'),
        'height'    => $el->('height'),
        'font'      => $el->('font'),
        'text'      => $el->(),
    };
    $chunk->{right} = $chunk->{left} + $chunk->{width};
    $chunk->{bottom} = $chunk->{top} + $chunk->{height};
    $chunk->{col} = 0;
    $chunk->{length} = length(strip_tags($chunk->{text}));
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
    if (!$chunk->{text} 
        || $chunk->{text} =~ /^(?:<[^>]+>)?\s*(?:<[^>]+>)?$/) {
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
    if ($chunk->{length} < 7 || $line->{length} < 7) {
        # line or chunk might be sub/sup:
        $min_y -= $line->{height}/3;
        $max_y += $line->{height}/3;
    }
    if ($chunk_y > $max_y || $chunk_y < $min_y) {
        print "  $chunk_y out of Y range $min_y-$max_y\n" if $verbose;
        push @$lines, $chunk;
        return $lines;
    }

    # Does the chunk begin too far right or left?
    my $chunk_x = $chunk->{left};
    my $ex = $line->{width} / $line->{length};
    my $max_x = $line->{right} + 7*$ex;
    if ($chunk_x > $max_x) {
        print "  $chunk_x > $max_x: too far right\n" if $verbose;
        push @$lines, $chunk;
        return $lines;
    }
    my $overlap = $line->{right} - $chunk_x;
    if ($overlap > 3*$ex) {
        print "  chunks overlap by $overlap!\n" if $verbose;
        push @$lines, $chunk;
        return $lines;
    }
    elsif ($overlap > $ex/2) {
        print "  chunks overlap ($overlap)!\n" if $verbose;
        # do the overlapping chunks compose a single letter?
        my $last = substr($line->{text}, -1);
        my $first = substr($chunk->{text}, 0, 1);
        my $combined = combine_letters($last, $first);
        if ($combined) {
            print "  merging $last and $first into $combined\n" if $verbose;
            substr($line->{text}, -1) = $combined;
            $chunk->{text} = substr($chunk->{text}, 1);
        }
    }

    # OK, now merge $chunk into $line:
    print "  continues line\n" if $verbose;
    append($line, $chunk);

    return $lines;
}

sub append {
    my ($line, $chunk) = @_;

    my $ex = $line->{width} / $line->{length};
    $line->{top} = min($line->{top}, $chunk->{top});
    my $bottom = max($line->{bottom}, $chunk->{top} + $chunk->{height});
    $line->{height} = $bottom - $line->{top};
    if ($chunk->{length} > $line->{length}) {
        $line->{font} = $chunk->{font};
    }
    if ($chunk->{left} - $line->{right} > $ex/4) {
        print "  inserting whitespace\n" if $verbose;
        $line->{text} .= ' ';
        $line->{length}++;
    }
    if ($chunk->{bottom} < $line->{bottom}
        && $chunk->{top} < $line->{top}) {
        print "chunk is sup (or line sub)\n" if $verbose;
        if ($chunk->{width} <= $line->{width}) {
            $line->{text} .= "<sup>".$chunk->{text}."</sup>";
        }
        else {
            $line->{text} = "<sub>".$line->{text}."</sub>".$chunk->{text};
        }
    }
    elsif ($chunk->{bottom} > $line->{bottom}
           && $chunk->{top} > $line->{top}) {
        print "chunk is sub (or line sup)\n" if $verbose;
        if ($chunk->{width} <= $line->{width}) {
            $line->{text} .= "<sub>".$chunk->{text}."</sub>";
        }
        else {
            $line->{text} = "<sup>".$line->{text}."</sup>".$chunk->{text};
        }
    }
    else {
        $line->{text} .= $chunk->{text};
    }
    $line->{width} = $chunk->{right} - $line->{left};
    $line->{right} = $chunk->{right};
    $line->{length} += $chunk->{length}
}

sub combine_letters {
    my ($x, $y) = @_;
    # stub!
    return $y if ($x =~ /[\s´\`¨]/);
    return $x if ($y =~ /[\s´\`¨]/);
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

    my @newlines;
    my $numcols = 1;
    for (my $i=0; $i<@lines; $i++) {

        push @newlines, $lines[$i];
        $lines[$i]->{col} = $numcols unless $lines[$i]->{col};

        next unless ($lines[$i+1]
                     && $lines[$i]->{length} > 5
                     && $lines[$i+1]->{length} > 5
                     && $lines[$i+1]->{left} > $lines[$i]->{right}
                     && $lines[$i+1]->{col} <= $lines[$i]->{col});

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
            # Merge chunks that are on the same line and not in
            # different columns, unless they are really far apart:
            my $ex = $lines[$i]->{width} / $lines[$i]->{length};
            if ($lines[$i]->{right} + 10*$ex < $lines[$i+1]->{left}) {
                print "appending\n" if $verbose;
                append($lines[$i], $lines[$i+1]);
                $i++;
            }
        }
    }
    if ($numcols > 1) {
        @newlines = sort { $a->{col}*1000 + $a->{top} <=>
                        $b->{col}*1000 + $b->{top} } @newlines;
    }
    return @newlines;
}

sub tidy_text {
    my $str = shift;
    # strip empty tags:
    while ($str =~ /<([^>\s]+)[^>]*>\s*<\/\1>/) {
        $str =~ s/$&//;
    }
    return fixchars($str);
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
                  "\x10|\x11" => '"',
                  "\x1b" => 'ff',
                  "\x1d" => 'fl',
                  "\x10" => '"',
                  "\x10" => '"',
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

    #while ($str =~ /([^a-zA-Z\d\s\.\[\]\(\),-\?:"'])/g) {
        #print "odd char $1 :", ord($1)," in $str\n";
    #}
    return $str;
}

1;
