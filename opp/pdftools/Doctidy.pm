#! /usr/bin/perl -w
package Doctidy;
use strict;
use warnings;
use Encode;
use utf8;
use Getopt::Std;
use List::Util qw/max min/;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../docparser";
use util::Io;
use util::String qw/strip_tags tokenize force_utf8/;
use util::Functools qw/reduce/;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&doctidy/;

binmode STDOUT, ":utf8";

sub usage() {
    print <<EOF;

Tidies up XML produced by pdftohtml or pdfocr: merges contiguous text
blocks, inserts <sup> and <sub> tags, puts text blocks in right order,
fixes a few characters and words.

Can be called from the command-line, or included as a module.
Command-line usage: $0 [-hv] <xmlfile>

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
    verbose($opts{v} || 0);
    doctidy($file);
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

    my $inpage = 0;
    my $page = '';
    while (<IN>) {
        $_ = Encode::decode_utf8($_);
        if ($inpage) {
            if (/<\/page>/) {
                print OUT pagetidy($page);
                $inpage = 0;
            }
            else {
                $page .= $_;
                next;
            }
        }
        if (/<page /) {
            $inpage = 1;
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
    print "== tidying page:\n$page\n\n" if $verbose;
    my @texts = ($page =~ /(<text.+?<\/text>)/sg);
    my @chunks = sortlines(map { xml2chunk($_) } @texts);
    @chunks = strip_linenumbers(@chunks);
    my $lines = reduce(\&mergechunks, [], @chunks);
    my @sorted = columnize(@$lines);
    my $xml = reduce(\&chunk2xml, '', @sorted);
    $page =~ s/<text.+<\/text>/$xml/s;
    print "== tidied page:\n$page\n\n" if $verbose;
    return $page;
}

sub elem {
    my $str = shift;
    return sub {
       my $attr = shift;
       if ($attr) {
           return $str =~ /$attr="(.*?)"/ && $1;
       }
       if ($str =~ /^<.+?>(.*)<.+?>$/s) {
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
    $chunk->{plaintext} = strip_tags($chunk->{text});
    $chunk->{length} = length($chunk->{plaintext});
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
    my ($lines, $chunk) = (@_); # lines up to now and next chunk

    # skip empty chunks:
    if (!$chunk->{text} || $chunk->{text} =~ /^(?:<[^>]+>)?\s*(?:<[^>]+>)?$/) {
        print "skipping empty chunk: $chunk->{text}\n" if $verbose;
        return $lines;
    }
    # skip extremely small chunks sometimes inserted by publishers:
    if ($chunk->{height} < 5) {
        print "skipping tiny chunk: $chunk->{text}\n" if $verbose;
        return $lines;
    }
    print "chunk: $chunk->{text}\n" if $verbose;

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

    # Does the chunk begin too far right? Here we have to be careful
    # because two-column papers often have rather little space between
    # the columns. So we err on the side of keeping too many chunks
    # and fix this later when columnizing.
    my $chunk_x = $chunk->{left};
    my $ex = $line->{width} / $line->{length};
    my $max_x = $line->{right} + 2*$ex;
    if ($chunk_x > $max_x) {
        print "  $chunk_x > $max_x: too far right\n" if $verbose;
        push @$lines, $chunk;
        return $lines;
    }
    
    # Does the chunk begin too far left?
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

    my $ex = $chunk->{width} / $chunk->{length};
    if ($chunk->{length} > $line->{length}
        # don't count smallcaps as very small font:  
        && $chunk->{text} =~ /[j-z]/) {
        $line->{font} = $chunk->{font};
    }
    if ($chunk->{left} - $line->{right} > $ex/4) {
        print "  inserting whitespace\n" if $verbose;
        $line->{text} .= ' ';
        $line->{length}++;
    }
    my $subsup_threshold = $line->{height}*0.1;
    if ($line->{bottom} - $chunk->{bottom} > $subsup_threshold
        and ($line->{top} - $chunk->{top} > $subsup_threshold
             or $chunk->{height} < $line->{height}*0.7)
        and $chunk->{length} < 4) {
        # Assumption: lines never start with subscripted text.
        print "chunk is sup\n" if $verbose;
        $line->{text} .= "<sup>".$chunk->{text}."</sup>";
    }
    elsif ($chunk->{bottom} - $line->{bottom} > $subsup_threshold
           and $chunk->{top} - $line->{top} > $subsup_threshold) {
        if ($chunk->{width} <= $line->{width}
            and $chunk->{length} < 4) {
            print "chunk is sub\n" if $verbose;
            $line->{text} .= "<sub>".$chunk->{text}."</sub>";
        }
        elsif (length($line->{plaintext}) < 4) {
            # e.g. footnotes: often start with supscripted text
            print "chunk follows sup\n" if $verbose;
            $line->{text} = "<sup>".$line->{text}."</sup>".$chunk->{text};
        }
    }
    else {
        $line->{text} .= $chunk->{text};
        # vertical line dimensions do not include subs and sups,
        # otherwise we wouldn't detect further subs and sups on the
        # same line.
        $line->{top} = min($line->{top}, $chunk->{top});
        $line->{bottom} = max($line->{bottom}, $chunk->{bottom});
        $line->{height} = $line->{bottom} - $line->{top};
    }

    # <sup>S</sup>MALLCAPS S<sup>OMETIMES</sup> cause problems:
    $line->{text} =~ s/<su.>([[:upper:]])<\/su.>([[:upper:]]+)/$1$2/;
    $line->{text} =~ s/([[:upper:]])<su.>([[:upper:]]+)<\/su.>/$1$2/g;
 
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
    # first sort lines top->bottom and left->right:
    my @lines = @_;
    sub comp {
        my $tolerance = ($b->{bottom} - $b->{top})/3;
        return 1 if $a->{top} > $b->{bottom}-$tolerance;
        return -1 if $b->{top} > $a->{bottom}-$tolerance;
        return $a->{left} <=> $b->{left};
    }
    return sort comp @lines;
}

sub columnize {
    my @lines = @_;

    print "== columnizing lines ==\n" if $verbose;

    # The order of text elements produced by pdftohtml is not reliable:
    # sometimes a first line in a PDF is a footnote. (OTOH, the order
    # of chunks within a single line tends to be reliable.) Also,
    # sorting lines by vertical position would get multi-column
    # layouts wrong. 
    #
    # To sort the lines, I assign column numbers, like so:
    #
    #  | col1 col1 col1 col1   |
    #  | col2 | col3 col3 col3 |
    #  | col2 | col3 col3 col3 |
    #  | col2 |  col4  | col5  |
    #  | col2 | col6 col6 col6 |
    #  | col7 col7 col7 col7   |

    my @newlines;
    my $numcols = 1;
    for (my $i=0; $i<=$#lines; $i++) {

        # Go through lines until we hit a case where the next line is
        # to the right and not yet recognized as such:
        
        print "line $i: ",$lines[$i]->{text},"\n" if $verbose;
        push @newlines, $lines[$i];

        $lines[$i]->{col} = $numcols unless $lines[$i]->{col};

        next unless (exists $lines[$i+1]
                     && $lines[$i]->{length} > 5
                     && $lines[$i+1]->{length} > 5
                     && $lines[$i+1]->{top} <= $lines[$i]->{bottom}-5
                     && $lines[$i+1]->{left} > $lines[$i]->{right}
                     && $lines[$i+1]->{col} <= $lines[$i]->{col}); # initial {col} is 0

        print "line $i+1 to the right of $i: $lines[$i+1]->{text}\n" if $verbose;

        # Look up and down for more lines belonging to the columns of
        # line i and i+1 until we encounter lines that break the
        # border:
        my @leftcol = ($lines[$i]);
        my @rightcol = ($lines[$i+1]);
        my $j = $i;
        my $unbroken = 1;
        while ($unbroken) {
            $j = ($j <= $i ? $j-1 : $j+1);
            $unbroken = 0 unless $j >= 0 && exists $lines[$j];
            
            # only consider lines from the same column as i and i+1:
            if ($unbroken && (!$lines[$j]->{col} 
                              || $lines[$j]->{col} == $lines[$i]->{col})) {
                if ($lines[$j]->{right} < $lines[$i+1]->{left}) {
                    print "line $j same col as $i: $lines[$j]->{text}\n" if $verbose;
                    push @leftcol, $lines[$j];
                }
                elsif ($lines[$j]->{left} > $lines[$i]->{right}) {
                    print "line $j same col as $i+1: $lines[$j]->{text}\n" if $verbose;
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

        # Ignore single-line columns unless the chunks are really far
        # apart:
        if (scalar @leftcol == 1 && scalar @rightcol == 1) {
            my $ex = $lines[$i]->{width} / $lines[$i]->{length};
            if ($lines[$i]->{right} + 10*$ex > $lines[$i+1]->{left}) {
                print "ignoring narrow, one-line columnisation\n" if $verbose;
                append($lines[$i], $lines[$i+1]);
                $i++;
                next;
            }
        }
        
        # If there are embedded columns, e.g.
        #
        #  | foo foo foo | bar |
        #  | foo1 | foo2 | bar |
        #  | foo1 | foo2 | bar |
        #  | foo foo foo | bar |
        #
        # then the subcolumns are currently all recognized as part of
        # the supercolumn; we still need to columnize them:

        print "sorting lines in left column\n" if $verbose;
        @leftcol = columnize(@leftcol);
        # Now the subcolumn {col} values start with 1; fix:
        foreach my $line (@leftcol) {
            $line->{col} += $numcols;
        }
        $numcols = $leftcol[-1]->{col};

        print "sorting lines in right column\n" if $verbose;
        @rightcol = columnize(@rightcol);
        foreach my $line (@rightcol) {
            $line->{col} += $numcols;
        }
        $numcols = $rightcol[-1]->{col};
    }

    # sort by column, top->bottom:
    if ($numcols > 1) {
        @newlines = sort { $a->{col}*1000 + $a->{top} <=>
                        $b->{col}*1000 + $b->{top} } @newlines;
    }
    print "done columnizing\n" if $verbose;
    return @newlines;
}

sub strip_linenumbers {
    # strip line numbers that are common in proofs from publishers:
    my @chunks = @_;
    my @numbers = grep { $_->{text} =~ /^\s*\d+\s*$/ } @chunks;
    return @chunks unless scalar(@numbers) > 5;
    # figure out most frequent horizontal position to tell apart line
    # numbers from footnote labels, page number, etc.:
    my %x_freq;
    for my $ch (@numbers) {
        $x_freq{$ch->{left}} = 0 unless defined $x_freq{$ch->{left}};
        $x_freq{$ch->{left}}++;
    }
    my @x_freqs = sort { $x_freq{$a} <=> $x_freq{$b} } keys(%x_freq);
    my $lineno_x = $x_freqs[-1];
    # don't be too strict, as '9' may begin a little further to the
    # right than '10':
    @numbers = grep { abs($_->{left}-$lineno_x) < 8 } @numbers;
    print "stripping line numbers ", (map { $_->{text} } @numbers), "\n"
        if $verbose;
    my @res;
    my %lookup;
    @lookup{@numbers} = ();
    for my $ch (@chunks) {
        push(@res, $ch) unless exists $lookup{$ch};
    }
    return @res;
}

sub tidy_text {
    my $str = shift;
    # strip empty tags:
    $str =~ s/<([^>\s]+)[^>]*>(\s*)<\/\1>/$2/g;
    $str =~ s/<. \/>//g; # '<b />' in www.cs.cornell.edu/home/halpern/papers/cheathus.pdf
    $str = force_utf8($str);
    $str = fix_whitespace($str);
    $str = fix_chars($str);
    $str = fix_kerning($str);
    return $str;
}

sub fix_whitespace {
    my $str = shift;
    $str =~ s/<br \/>/ /g;
    $str =~ s/\s|\h|\v|\R/ /g; # replace all kinds of horizontal and vertical whitespace and linebreaks by ' '
    $str =~ s/   */  /g; # strip excessive whitespace 
    #$str =~ s/\r//g; # remove ^M carriage returns
    #$str=~ s/ ?\t ?/ /g; # and tabs
    #$str =~ s/\xOB|\x0C|\x85|\x{2028}|\x{2029}/ /g; # and line/paragraph separators
    #$str =~ s/\n/ /g; # no newline chars in line chunks
    return $str;
}

sub fix_chars {
    my $str = shift;
    my %trans;

    # Some characters and character combinations are often extracted
    # incorrectly, depending on the program that generated the PDF
    # file. For example, to draw a lowercase "u" with an umlaut
    # accent, LaTeX sometimes draws a "u" and then an umlaut accent
    # over it. This means that pdftohtml will extract two separate
    # characters '¨' and 'u'.

    $trans{"\x{a8}a"} = "\x{e4}"; # ä
    $trans{"\x{a8}o"} = "\x{f6}"; # ö
    $trans{"\x{a8}u"} = "\x{fc}"; # ü
    $trans{"\x{a8}A"} = "\x{c4}"; # Ä
    $trans{"\x{a8}O"} = "\x{d6}"; # Ö
    $trans{"\x{a8}U"} = "\x{dc}"; # Ü
    $trans{"\x{a8}\x{131}"} = "\x{ef}"; # ¨ı
    $trans{"\x{a8}I"} = "\x{ff}"; # ¨I

    # We also break apart ligatures:
    
    $trans{"\x{fb00}"} = "ff";
    $trans{"\x{fb01}"} = "fi";
    $trans{"\x{fb02}"} = "fl";
    $trans{"\x{fb03}"} = "ffi";
    $trans{"\x{fb04}"} = "ffl";
    $trans{"\x{fb05}"} = "st";
    $trans{"\x1b"} = "ff";
    $trans{"\x1d"} = "fl";

    # Some odd mistakes I have noticed:

    $trans{"\x10|\x11"} = "\"";
    $trans{"\x{a0}"} = " "; #  
    $trans{"\x{a4}"} = "ff"; # ¤

    # Replace HTML escape codes:
    
    $trans{"&quot;"} = "\"";

    while (my ($key,$esc) = each(%trans)) {
        $str =~ s/$key/$esc/g;
    }

    #while ($str =~ /([^a-zA-Z\d\s\.\[\]\(\),-\?:"'])/g) {
        #print "odd char $1 :", ord($1)," in $str\n";
    #}
    return $str;
}

sub fix_kerning {
    my $str = shift;

    # pdftohtml often leaves S I L L Y  S PA C E S in words, especially
    # in author names, where dictionary lookups are of little help:
    if ($str =~ / \p{isAlpha} \p{isAlpha} \p{isAlpha} /) {
        print "odd kerning in $str\n" if $verbose;
        #$str =~ s/(?<! ) //g;
        $str =~ s/ (\p{isAlpha}) /$1/g;
        print "turned to $str\n" if $verbose;
        # If we're lucky, we now have sensible word breaks because
        # pdftohtml put double spaces where there should be single
        # spaces. Otherwise we enter the next clause.
    }
    # Sometimes there are nospacesatallbetweenwords.
    while ($str =~ /(\p{isAlpha}{25,})/g) {
        print "odd kerning in $str: $1\n" if $verbose;  
        my $repl = tokenize($1);
        $str =~ s/$1/$repl/;
        print "turned to $str\n" if $verbose;
    }
    return $str;
}

1;
