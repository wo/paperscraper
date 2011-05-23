#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use CGI;
use POSIX;
use Cwd 'abs_path';
use File::Basename;

my $path = dirname(abs_path(__FILE__));
my %cfg = do "$path/../config.pl";

my $cgi = new CGI;
$cgi->charset("utf-8");
print $cgi->header('text/html');

my $nospam = $cgi->param('nospam');

my $since = $cgi->param('since');
my $until = $cgi->param('until');
my $limit = 100;
if (!$since) {
    $limit = 100;
    $since = "1970-01-01";
    $until = strftime("%Y-%m-%d 23:59:59", localtime());
}
elsif (!$until) {
    $until = strftime("%Y-%m-%d 23:59:59", localtime());
}

my $dbh = DBI->connect('DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
                       $cfg{'MYSQL_PASS'}, { RaiseError => 1 }) 
    or die "Couldn't connect to database: " . DBI->errstr;

my $select = $dbh->prepare(<<SQL);
   SELECT documents.*, locations.url, locations.filetype
   FROM documents
   INNER JOIN locations ON documents.document_id = locations.document_id
   WHERE documents.found_date > ?
   AND documents.found_date < ?
   AND documents.meta_confidence > $cfg{'CONFIDENCE_THRESHOLD'}
   AND locations.spamminess < $cfg{'SPAM_THRESHOLD'}
   AND locations.status = 1
   GROUP BY documents.document_id
   LIMIT ?
SQL
$select->execute($since, $until, $limit) or die DBI->errstr;

print <<EOD;

<head>
<title>Online Papers in Philosophy</title>
<style type="text/css" src="opp.css"></style>
</head>
<h1>Online Papers in Philosophy</h1>
<ul>

EOD

while (my $row = $select->fetchrow_hashref) {
   print_item($row);
}

print <<EOD;

</ul>

EOD

sub print_item {
    my $doc = shift;
    my $authors = dec($doc->{authors});
    my $title = dec($doc->{title});
    my $url = $doc->{url};
    my $abstract = dec($doc->{abstract});
    my $filetype = $doc->{filetype};
    my $id = $doc->{document_id};
    print <<EOD;

<li>
   <div class="title">
      $id. $authors: <a href="$url">$title</a>
   </div>
   <div class="abstract">
       $abstract
   </div>
   <div class="meta">
       <span>length: $doc->{length}</span>
       <span>found: $doc->{found_date}</span>
       <span>confidence: $doc->{meta_confidence}</span>
   </div>
</li>

EOD

}

sub dec {
   use Encode 'decode';
   return decode('utf8',shift());
}
