package rules::Keywords;
use strict;
use warnings;
use utf8;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/
$re_ignore_url
$re_session_id
$re_name
$re_name_inverted
$re_noname
$re_name_before
$re_name_after
$re_name_separator
$re_address_word
$re_bad_ending
$re_bad_beginning
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
$re_legalese
$re_thanks
$re_year_words
$re_lquote
$re_rquote
$re_dash
/;

# ignore the following links on source pages:
our $re_ignore_url = qr{
    \#|
    ^mailto|
    ^data|
    ^javascript|
    ^.+//[^/]+/?$|          # TLD
    twitter\.com|
    fonts\.googleapis\.com|
    philpapers\.org/asearch|
    \.(?:css|mp3|avi|mov|jpg|gif|ppt|png|ico|mso|xml)(?:\?.+)?$   # .css?version=12
}xi;

# ignore this part of a URL when checking for new links:
our $re_session_id = qr{
    \bs\w*id=[\w_-]+|
    halsid=[\w_-]+|
    wpnonce=\w+|
    locale=[\w_-]+|
    session=[\w_-]+
}xi;

# stuff that indicates publication info:
our $re_publication_word = qr/\b(?:
    forthcoming|editors?|ed\.|eds\.|edited|publish\w*|press|volume|
    to\sappear\sin|draft|editor\w*|reprints?|excerpt|
    circulation|cite
    )\b/ix;

our $re_journal = qr/\b(?:
    journal|philosophical|studies|proceedings
    )\b/ix;

our $re_publisher = qr/\b(?:
    university|press|oxford|cambridge|clarendon|reidel|springer|
    routledge|macmillan|publish.+
    )\b/ix;

our $re_editor = qr/^\(?ed(?:itor)?s?[\.\)].?$/ix;

our $re_legalese = qr/\b(?:
    copyright|\(c\)|©|\x{A9}|trademarks?|registered|distributed\sunder|
    terms\sand\sconditions|http|permission
    )\b/ix;

our $re_thanks = qr/\b(?:
    thank|comments|suggestions|helpful|grateful
    )\b/ix;

# stuff that disqualifies something from being a name:
our $re_address_word = qr/\b(?:
    universit\w+|center|centre|institut.?|college|
    avenue|street|professor|department|program|
    philosoph.*|linguistics|filosofi.*|
    umass|uc
    )\b/ix;

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

# unicode character classes like \p{IsAlpha} seem buggy, so I use POSIX:
my $upper = '[[:upper:]]';
my $alpha = '[[:alpha:]]';
my $fname = qr/$upper\.?$alpha*(?:[\-\']$alpha+)*/; # John, J, J., Hans-Peter, T'or
my $re_name_first =  qr/$fname(?:\s$fname){0,2}\.?/; # Ann Mary, J.R.G., J.Robbie G.
my $re_name_middle = qr/$alpha+(?:\s$alpha+){0,3}/; # von, de la
my $re_name_last = qr/$alpha*$upper[\S\-\']*$alpha{2}/;
    # using \S here because foreign chars sometimes not IsAlpha

our $re_name = qr/($re_name_first) ((?:$re_name_middle )?$re_name_last)/;

our $re_name_inverted = qr/
    ($re_name_middle $re_name_last),\s*($re_name_first) 
    /x;

# stuff that may come before a name in an author line:
our $re_name_before = qr/
    \s*(?:copyright|\(c\)|©)[\s\d]*|   # "(c) 2009 H. Kamp" ..
    \s*\w*\s*by\s+|                    # "Commentary by Hans Kamp"
    \s*\d[\d\-\s]+                     # "2009 Hans Kamp"
    /ix;

# stuff that may come after a name in an author line:
our $re_name_after = qr/
    \s+\d.+|                           # "Hans Kamp 12.12.2009"
    \s+\S+@\S+|                        # "Hans Kamp hans@kamp.de"
    \.|                                # "Hans, Peter, and Fred."
    \d|\*                              # "Hans Kamp1"
    /ix;

# stuff that separates authors from one another or rest of line:
our $re_name_separator = qr/
    \s*(?:
        ,?\s?\band\b|&amp;|,|
        :|                            # author: title
        \s[^\p{isAlpha}\d\s\@<>\/]|   # weird symbol
        \s\s        # hack: leftover space from supscript removal in plaintext() 
       )
    \s*
    /ix;

# words that suggest title continues on next line:
our $re_bad_ending = qr/
    \b(?:
       of|and|or|the|a|an|by
    )\b
    /ix;

# words that suggest title is continued from previous line:
our $re_bad_beginning = qr/
    \b(?:
       of|and|or
    )\b
    /ix;

# may be ordinary text content:
our $re_content = qr/
    \b(?:
       the|to|a|in|is|it|you|that|he|was|for|on|are|with|
       as|I|his|they|be|at|one|have|this|from|or|had|by|
       but|what|some|we|can|out|other|were|all|there|when|
       up|use|your|how|said|an|each|she
    )\b
    /x;

# begins with section number, e.g. '1' or '1.2':
our $re_sec_number = qr/^\s*
   [\divx\.]+
   \b/ix;

our $re_bib_heading = qr/\s*.{0,4}\s*\b
    (?:references|bibliography|
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

our $re_year_words = qr/\b(?:
    forthcoming|manuscript|unpublished|typescript|draft
    )/ix;


