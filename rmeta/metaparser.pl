#! /usr/bin/perl -w
use strict;
use warnings;
use utf8;
use DBI;
use Data::Dumper;
use Digest::MD5;
#use lib '/home/wo/exec/opp-trunk/metaparser';
use JSON;
use CGI;
use Util;
use Converter;
use Extractor;
binmode STDOUT, ":utf8";
my $cgi = new CGI;
$cgi->charset("utf-8");
open (STDERR, ">&STDOUT");
$| = 1; # flush STDOUT at newline
chdir('/home/wo/exec/opp-trunk/metaparser');

#############################################################################
#
# Takes URL of a paper (in HTML, PDF, DOC or RTF format) and tries to guess
# author, title, abstract, etc. Output is in JSON format. Usage:
#
# $ perl metaparser.pl <url> [verbosity] [local address]
#
# Local address is to avoid needless transfers if the paper is available
# locally. Arguments can also be passed by CGI as 'url', 'verbosity', 'file'. 
#
#############################################################################


my $url = shift || $cgi->param('url')
    or die 'no url specified';
my $verbosity = shift || $cgi->param('verbosity') || 0;
my $file = shift || $cgi->param('file') || '';

my $meta = {
    url        => $url,
    status     => 100,
    error      => '',
    filetype   => undef,
    filesize   => undef,
    author     => undef,
    title      => undef,
    abstract   => undef,
    problems   => 0
};

sub result {
    if (($_ = shift)) {
	$meta->{error} = $_;
	print "Error: $_\n" if $verbosity;
    }
    print Dumper $meta if $verbosity;
    print to_json($meta);
    die ($_? 1 : 0);
}

print "checking $url\n" if $verbosity;

if (!$file) {
    # retrieve document:
    Util::verbosity($verbosity);
    my $res = Util::fetch_url($meta->{url});
    if (!$res || !$res->is_success) { 
	# url could not be fetched
	$meta->{status} = $res ? $res->code : 50;
	result("Could not fetch URL: status ".$res->code.".");
    }
    $meta->{filesize} = $res->{filesize};
    $meta->{filetype} = $res->{filetype};
    # save local copy:
    $file = '../temp/'.Digest::MD5::md5_hex($url).'.'.$meta->{filetype};
    Util::save($file, $res->content) or result("Could not save local file.");
}
else {
    # open local file:
    if (!-r $file) {
	result("can't open local file $file.");
    }
    $meta->{filesize} = -s $file;
    if ($file =~ /\/.+\.([a-z]{3,4})$/) {
	$meta->{filetype} = lc($1);
    }
}

my ($basename, $filetype) = ($file =~ /^(.*?)\.?([^\.]+)$/);

# check if filetype is supported:
my @supported_filetypes = qw/pdf doc rtf html/;
if (!(grep /$filetype/, @supported_filetypes)) {
    result("unsupported filetype '".$meta->{filetype}."'");
}

# convert RTF and Word to PDF:
if ($filetype !~ /pdf|html/) {
    Converter::verbosity($verbosity);
    Converter::convert2pdf($file, $basename.'.pdf')
      or result("PDF conversion failed: ".Converter::errmsg());
    $file = "$basename.pdf";
}

my $result;
eval {
    my $extractor = Extractor->new(filename => $file, verbosity => $verbosity);
    $result = $extractor->parse() or result("Parser error.");
};
result($@) if ($@);

$meta->{author}   = join ', ', @{$result->{authors}};
$meta->{title}    = $result->{title};
$meta->{abstract} = $result->{abstract};
$meta->{problems} = $result->{problems};
$meta->{status}   = 1;

result();


