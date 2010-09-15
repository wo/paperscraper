#! /usr/bin/perl -w
use strict;
use warnings;
use DBI;
use POSIX;
use XML::XPath;
use Test::More 'no_plan';
use lib '../';
use util::Io;

do 'reset_db.pl';
my %cfg = do '../config.pl';
chdir('../');

my $dbh = DBI->connect('DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
                       $cfg{'MYSQL_PASS'}, { RaiseError => 1 })
    or die DBI->errstr;

sub sql {
    my $sql = shift;
    system("echo \"$sql\" | /usr/bin/mysql -u$cfg{'MYSQL_USER'} "
           ."-p$cfg{'MYSQL_PASS'} $cfg{'MYSQL_DB'}");
}

# set the URL of rss:
my $RSS_URL = "http://localhost/opp-tools/rss";

sub read_url {
    my $url = shift;
    my $res = fetch_url($url);
    return $res->{content};
}

SKIP: {

    my $res = read_url("$RSS_URL");
    skip "CGI not properly configured (url: $RSS_URL)"
        unless $res && $res =~ /<?xml/;

    my $yesterday = time() - 24*60*60;
    my $yesterdate = strftime("%Y-%m-%d 12:00", localtime($yesterday));
    sql("INSERT INTO documents (authors,title,abstract,found_date,meta_confidence) "
        ."VALUES ('author1', 'title1', 'abstract1', '$yesterdate', 0.9)");
    sql("INSERT INTO documents (authors,title,abstract,found_date,meta_confidence) "
        ."VALUES ('author2', 'title2', 'abstract2', '2010-01-05 12:00', 0.8)");
    sql("INSERT INTO documents (authors,title,abstract,found_date,meta_confidence) "
        ."VALUES ('author3', 'title3', 'abstract3', '2010-02-05 12:00', 0.9)");
    sql("INSERT INTO locations (document_id,url,spamminess) "
        ."VALUES (1, 'u1', 0.1)");
    sql("INSERT INTO locations (document_id,url,spamminess) "
        ."VALUES (2, 'u2', 0.1)");
    sql("INSERT INTO locations (document_id,url,spamminess) "
        ."VALUES (3, 'u3', 0.1)");

    $res = read_url("$RSS_URL");
    my $xp = XML::XPath->new(xml => $res);
    my $nodes = $xp->find('//channel');
    ok(defined $nodes, "rss script outputs valid XML");
    $nodes = $xp->find('//item');
    foreach my $node ($nodes->get_nodelist()) {
        my $nodestr = XML::XPath::XMLParser::as_string($node);
        like($nodestr, qr/title1/, "RSS contains document from (only) yesterday");
    }

    $res = read_url("$RSS_URL?since=2008-01-01");
    $xp = XML::XPath->new(xml => $res);
    $nodes = $xp->find('//item');
    my $count = 0;
    foreach my $node ($nodes->get_nodelist()) {
        $count++;
    }
    is($count, 3, "since parameter sets date range correctly");

    $res = read_url("$RSS_URL?since=2008-01-01&until=2010-05-05");
    $xp = XML::XPath->new(xml => $res);
    $nodes = $xp->find('//item');
    $count = 0;
    foreach my $node ($nodes->get_nodelist()) {
        $count++;
    }
    is($count, 2, "since and until parameters set date range correctly");

}
