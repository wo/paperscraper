package rules::Keywords;
use strict;
use warnings;
use utf8;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/
$re_name
$re_name_inverted
$re_noname
$re_name_before
$re_name_after
$re_name_separator
$re_title
$re_content
$re_bib_heading
$re_sec_number
$re_editor
$re_abstract
$re_footnote_label
$re_cit_label
$re_journal
$re_publisher
$re_publication_word
$re_year_words
$re_lquote
$re_rquote
$re_dash
/;

# stuff that commonly occurs in addresses or affiliations:
my $re_address_word = qr/\b(?:
    university|center|centre|institute|sciences?|college|research|
    avenue|street|philosophy|professor|address|department
    )\b/ix;

# stuff that commonly occurs in publication info:
our $re_publication_word = qr/\b(?:
    forthcoming|editors?|edited|publish\w*|press|volume
    to appear in|draft|editor\w*|\d{4}|reprints?|excerpt|
    circulation|cite
    )\b/ix;

our $re_journal = qr/\b(?:
    journal|studies|philosophical|proceedings
    )\b/ix;

our $re_publisher = qr/\b(?:
    university|press|oxford|cambridge|clarendon|reidel|springer|
    routledge|macmillan|publish.+
    )\b/ix;

our $re_editor = qr/^\(?ed(?:itor)?s?[\.\)].?$/ix;

# stuff that disqualifies something from being a name:
our $re_noname = qr/
    \d |
    $re_address_word |
    $re_publication_word |
    \b(?:thanks?|
       @|
       abstract|introduction|overview|
       the|for|of|with|to|about|this|what|new|account|
       search|home|
       free|
       see
       )\b
    /ix;

# stuff that disqualifies something from being a title:
my $re_notitle = qr/(?:
    $re_address_word |
    $re_publication_word |
    \bthanks?\b|@|
    abstract
    )/ix;

my $re_nocontent = qr/(?:
    $re_address_word |
    $re_publication_word
    )/ix;

# unicode character classes like \p{IsAlpha} seem buggy, so I use POSIX:
my $upper = '[[:upper:]]';
my $alpha = '[[:alpha:]]';
my $re_name_first =  qr/(?:$upper$alpha*[\.\s\-\']+){1,3}/;
my $re_name_middle = qr/(?:$alpha+\s+){0,3}/; # von, de la, etc.
my $re_name_last = qr/$alpha*$upper [\S\-\']*$alpha {2}/x;
    # using \S here because foreign chars sometimes not IsAlpha

our $re_name = qr/
    ($re_name_first) ($re_name_middle $re_name_last)
    /x;

our $re_name_inverted = qr/
    ($re_name_middle $re_name_last),\s* ($re_name_first) 
    /x;

# stuff that may come before a name in an author line:
our $re_name_before = qr/
    \s*(?:copyright|\(c\))[\s\d]*|     # "(c) 2009 H. Kamp" ..
    \s*\w*\s*by\s+|                    # "reviewed by Hans Kamp"
    \s*\d[\d\-\s]+                     # "2009 Hans Kamp"
    /ix;

# stuff that may come after a name in an author line:
our $re_name_after = qr/
    \s*\d[\d\-\.\s]+|                  # "Hans Kamp 12.12.2009"
    \s*\S+@\S+|                        # "Hans Kamp hans@kamp.de"
    \.                                 # "Hans, Peter, and Fred."
    /ix;

# stuff that separates authors from one another or rest of line:
our $re_name_separator = qr/
    \s*(?:
        \band\b|&amp;|,|
        :|                         # author: title
        \s[^\p{isAlpha}\d\.\s\@-]  # weird symbol
       )
    \s*
    /ix;

# may be a title:
our $re_title = qr/
    (?!.*$re_notitle.*)
    \p{IsAlpha}                        # At least one word character
    /x;

# may be ordinary text content:
our $re_content = qr/
    (?!.*$re_nocontent.*)
    \b(?:
       the|to|a|in|is|it|you|that|he|was|for|on|are|with|
       as|I|his|they|be|at|one|have|this|from|or|had|by|
       but|what|some|we|can|out|other|were|all|there|when|
       up|use|your|how|said|an|each|she
    )
    /x;

# begins with section number, e.g. '1' or '1.2':
our $re_sec_number = qr/^\s*
   [\divx\.]+
   \b/x;

our $re_bib_heading = qr/\s*.{0,4}\s*\b
    (?:references?|bibliography|
     references\s+cited|\w+\s+cited)
    \b\s*.{0,4}\s*
    /ix;

our $re_abstract = qr/
   abstract
   /ix;

our $re_footnote_label = qr/
   (?:<sup>)\s*(?:\*|\x{2217}|\d+)\s*(?:<\/sup>)
   /x;

our $re_cit_label = qr/
   \[.+\]
   /x;

our $re_dash = '[–—−—]';

our $re_lquote = '["“`‘¨‘‛‟„‵‶‷❛❝]';

our $re_rquote = '["¨´’’‛”′″‴⁗❜❞]';

our $re_year_words = 
    '\b(?:forthcoming|manuscript|unpublished|typescript|draft)\b';



my $re_bad_abstract = qr/(?:
    ^\s*<sup>|
    table of contents|\bdraft\b|forthcoming|\beditor|\bpress\b|\bpublish|Vol\.|
    terms and conditions|copyright|journal\b|jstor|permission|
    @|url|http|
    \bthank
    )/ix;


