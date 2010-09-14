#! /usr/bin/perl -w
use strict;
use warnings;
use DBI;
my %cfg = do '../config.pl';

my $dbh = DBI->connect('DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
    $cfg{'MYSQL_PASS'}, { RaiseError => 1 })
    or die DBI->errstr;

$dbh->do("DROP TABLE IF EXISTS documents") or die DBI->errstr;
$dbh->do("DROP TABLE IF EXISTS links") or die DBI->errstr;
$dbh->do("DROP TABLE IF EXISTS sources") or die DBI->errstr;
$dbh->do("DROP TABLE IF EXISTS locations") or die DBI->errstr;

system("/usr/bin/mysql -u$cfg{'MYSQL_USER'} -p$cfg{'MYSQL_PASS'} "
       ."$cfg{'MYSQL_DB'} < ../setup.sql");
