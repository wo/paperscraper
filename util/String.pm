package util::String;
use strict;
use warnings;
use utf8;
use HTML::Strip;
use Text::Capitalize;
use Text::Aspell;
use lib '..';
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&strip_tags &tidy_text &is_word/;

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

sub tidy_text {
    my $txt = shift;
    # put closing tags before space ("<i>foo </i>" => "<i>foo</i> "):
    $txt =~ s| </([^>]+)>|</$1> |g;
    # merge consecutive HTML elements:
    $txt =~ s|</([^>]+)>(\s*)<\1>|$2|g;
    $txt =~ s|\b-</([^>]+)>\n\s*<\1>(?=\p{Lower})|\n|g;
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
    # merge HTML elements split at linebreak:
    $txt =~ s|</([^>]+)>\n\s*<\1>| |g;
    # remove linebreaks:
    $txt =~ s|\s*\n\s*| |g;
    for (1 .. 2) {
        # chop whitespace at beginning and end:
        $txt =~ s|^\s*(.+?)\s*$|$1|;
        # chop surrounding tags:
        $txt =~ s|^<([^>]+)>(.+)</\1>\s*$|$2|;
        # chop surrounding quotes:
        $txt =~ s|^$re_lquote(.+)$re_rquote.?\s*$|$1|;
        # chop odd trailing punctuations:
        $txt =~ s|[\.,:;]$||;
        # remove footnote marks:
        $txt =~ s|<sup>(?:<.>)*\W?.?\W?(?:</.>)*</sup>||g;
        # and trailing footnote star *:
        $txt =~ s/(\*|\x{2217})\s*$//;
        # and non-<sup>'ed footnote symbols in brackets:
        $txt =~ s|\[.\]$||;
        # and non-<sup>'ed number right after last word:
        $txt =~ s|([\pL\?!])\d$|$1|;
        # fix HTML:
        $txt = fix_html($txt);
    }
    # replace allcaps:
    $txt = capitalize_title($txt) if ($txt !~ /\p{isLower}{2}/);
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
