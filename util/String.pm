package util::String;
use strict;
use warnings;
use utf8;
use HTML::Strip;
use Text::Capitalize;
use Text::Aspell;
use Memoize;
use lib '..';
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&strip_tags &tidy_text &plaintext &is_word &tokenize/;

sub strip_tags_new {
    my $str = shift;
    my $hs = HTML::Strip->new();
    my $text = $hs->parse($str);
    $hs->eof;
    return $text;
}

sub strip_tags {
    # this is from http://www.perlmonks.org/?node_id=161281
    my $str = shift;
    # ALGORITHM:
    #   find < ,
    #       comment <!-- ... -->,
    #       or comment <? ... ?> ,
    #       or one of the start tags which require correspond
    #           end tag plus all to end tag
    #       or if \s or ="
    #           then skip to next "
    #           else [^>]
    #   >
    $str =~ s{
    <               # open tag
    (?:             # open group (A)
      (!--) |       #   comment (1) or
      (\?) |        #   another comment (2) or
      (?i:          #   open group (B) for /i
        ( TITLE  |  #     one of start tags
          SCRIPT |  #     for which
          APPLET |  #     must be skipped
          OBJECT |  #     all content
          STYLE     #     to correspond
        )           #     end tag (3)
      ) |           #   close group (B), or
      ([!/A-Za-z])  #   one of these chars, remember in (4)
    )               # close group (A)
    (?(4)           # if previous case is (4)
      (?:           #   open group (C)
        (?!         #     and next is not : (D)
          [\s=]     #       \s or "="
          [\"\`\']  #       with open quotes
        )           #     close (D)
        [^>] |      #     and not close tag or
        [\s=]       #     \s or "=" with
        \`[^\`]*\` |#     something in quotes ` or
        [\s=]       #     \s or "=" with
        \'[^\']*\' |#     something in quotes ' or
        [\s=]       #     \s or "=" with
        \"[^\"]*\"  #     something in quotes "
      )*            #   repeat (C) 0 or more times
    |               # else (if previous case is not (4))
      .*?           #   minimum of any chars
    )               # end if previous char is (4)
    (?(1)           # if comment (1)
      (?<=--)       #   wait for "--"
    )               # end if comment (1)
    (?(2)           # if another comment (2)
      (?<=\?)       #   wait for "?"
    )               # end if another comment (2)
    (?(3)           # if one of tags-containers (3)
      </            #   wait for end
      (?i:\3)       #   of this tag
      (?:\s[^>]*)?  #   skip junk to ">"
    )               # end if (3)
    >               # tag closed
     }{}gsx;        # STRIP THIS TAG
    # chop whitespace:
    $str =~ s/^\s*(.+?)\s*$/$1/s;
    return $str;
}

sub plaintext {
    my $txt = shift;
    # remove excessive whitespace:
    $txt =~ s|\s\s+| |g;
    # remove footnote marks, but keep whitespace:
    $txt =~ s|<sup>(?:<.>)*\W?.?\W?(?:</.>)*</sup>| |g;
    # and trailing footnote star *:
    $txt =~ s/(\*|\x{2217})\s*$//;
    # and non-<sup>'ed footnote symbols in brackets:
    $txt =~ s|\[.\]$||;
    # and non-<sup>'ed number right after last word:
    $txt =~ s|([\pL\?!])\d$|$1|;
    $txt = strip_tags($txt);
    return $txt;
}

sub tidy_text {
    my $txt = shift;
    # merge HTML elements split at linebreak:
    $txt =~ s|</([^>]+)>\n\s*<\1>|\n|g;
    # combine word-parts that are split at linebreak:
    while ($txt =~ /(\pL\pL+)-\n\s*(\p{Lower}\pL+)/g) {
        my ($combined, $w1, $w2) = ($&, $1, $2);
        if (one_word($w1, $w2)) {
            $txt =~ s/$combined/$w1$w2/;
        }
        else {
            $txt =~ s/$combined/$w1-$w2/;
        }
    }
    # remove linebreaks:
    $txt =~ s|\s*\n\s*| |g;
    # remove excessive whitespace:
    $txt =~ s|\s\s+| |g;
    my $otxt;
    do {
        $otxt = $txt;
        # merge consecutive HTML elements:
        $txt =~ s|</([^>]+)>(\s*)<\1>|$2|g;
        # chop whitespace at beginning and end:
        $txt =~ s|^\s*(.+?)\s*$|$1|;
        # chop surrounding tags:
        $txt =~ s|^<([^>]+)>(.+)</\1>$|$2|;
        # chop surrounding quotes:
        $txt =~ s|^$re_lquote(.+)$re_rquote.?\s*$|$1|;
        # remove footnote marks:
        $txt =~ s|<sup>(?:<.>)*\W?.?\W?(?:</.>)*</sup>||g;
        # and trailing footnote star or cross:
        $txt =~ s/(\*|\x{2217}|†)\s*$//;
        # and non-<sup>'ed footnote symbols in brackets:
        $txt =~ s|\[.\]$||;
        # and non-<sup>'ed number right after last word:
        $txt =~ s|([\pL\?!])\d$|$1|;
        # fix HTML:
        $txt = fix_html($txt);
    } while ($txt ne $otxt);
    # put closing tags before space ("<i>foo </i>" => "<i>foo</i> "):
    $txt =~ s| </([^>]+)>|</$1> |g;
    # replace allcaps (note: string may contain e.g. '&amp;'):
    if ($txt !~ /[[:lower:]]/ or $txt =~ /\b[[:upper:]]{3,}\s[[:upper:]]{3,}/) {
        $txt = capitalize_title($txt);
    }
    return $txt;
}

sub one_word {
    my ($w1, $w2) = @_;
    return 1 if is_word($w1.$w2);
    return 0 if is_word($w2); # e.g. "decision-theoretic"
    return 1;
}

my $speller;
sub speller {
    unless ($speller) {
        $speller = Text::Aspell->new;
        $speller->set_option('lang', 'en_US');
        $speller->set_option('sug-mode', 'fast');
    }
    return $speller;
}

sub is_word {
    my $sp = speller();
    return $sp && $sp->check($_[0]);
}

sub tokenize {
    # Split 'stringofwords' into 'string of words'. If second argument
    # is set (for internal use), return value is prefixed by a number
    # counting how many non-dictionary words ar in the returned
    # string.
    my ($str, $recurse) = @_;
    if (is_word($str)) {
        return $recurse ? "0 $str" : $str;
    }
    if (length($str) < 3) {
        return $recurse ? "1 $str" : $str;
    }
    my @wordlist;
    my $numbad;
    my $max_cut = length($str) < 17 ? length($str)-2 : 15;
    for my $cut (1 .. $max_cut) {
        my $w = substr($str, 0, $cut);
        # our dictionary counts every single letter as a word, ignore all but 'a':
        if ($w eq 'a' or ($cut > 1 and is_word($w))) {
            #print "$w|",substr($str, $cut),"?\n";
            my ($rembad, @remlist) = split(' ', tokenize(substr($str, $cut), 1));
            # prefer short word lists with few non-dict words:
            if (!@wordlist or $rembad < $numbad or 
                ($numbad == $rembad and $#remlist+1 < $#wordlist)) {
                @wordlist = ($w, @remlist);
                $numbad = $rembad;
                #print "(1) best tokenization of $str so far: $numbad ", join(' ', @wordlist), "\n";
            }
        }
    }
    unless (@wordlist) {
        # string does not begin with a dictionary word
        for my $cut (1 .. $max_cut) {
            my $w = substr($str, 0, $cut);
            #print "$w|",substr($str, $cut),"?\n";
            my ($rembad, @remlist) = split(' ', tokenize(substr($str, $cut), 1));
            #print "tokenized: ",($rembad + 1)," $w ", join(' ', @remlist)," [$#remlist, $#wordlist]\n";
            if (!@wordlist or $rembad+1 < $numbad or
                ($numbad == $rembad+1 and $#remlist+1 < $#wordlist)) {
                @wordlist = ($w, @remlist);
                $numbad = $rembad + 1;
                #print "(2) best tokenization of $str so far: $numbad ", join(' ', @wordlist), "\n";
            }
        }
    }
    #print "best tokenization of $str: $numbad ", join(' ', @wordlist), "\n";
    if ($recurse) {
        return "$numbad ".join(' ', @wordlist);
    }
    return join ' ', @wordlist;
}
memoize('tokenize');

sub fix_html {
    my $str = shift;
    my %open = ('i', 0, 'b', 0, 'sub', 0, 'sup', 0);
    my $res = $str;
    while ($str =~ /<(\/?)(i|b|su.)>/g) {
        if ($1) {
            if ($open{$2}) {
                $open{$2}--;
            }
            else {
                $res = "<$2>$res";
            }
        }
        else {
            $open{$2}++;
        }
    }
    foreach ('i', 'b', 'sub', 'sup') {
        while ($open{$_}) {
            $res .= "</$_>";
            $open{$_}--;
        }
    }
    return $res;
}



1;
