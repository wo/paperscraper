package util::String;
use strict;
use warnings;
use utf8;
use HTML::Strip;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(&strip_tags);

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
