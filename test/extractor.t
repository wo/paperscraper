#! /usr/bin/perl -w
use strict;
use warnings;
use Test::More 'no_plan';
binmode STDOUT, ":utf8";
use lib '..';
use Cwd 'abs_path';
use Converter;
use Doctidy 'doctidy';
use Extractor;
my %cfg = do 'config.pl';

use Time::HiRes 'time';
sub profile {
    my ($func) = @_;
    return sub {
        my $start = time;
        my $return = $func->(@_);
        my $end = time;
        print $end - $start;
        return $return;
    };
}

sub get_meta {
    my $file = shift;
    my $bib = shift;
    $file = abs_path($file);
    Converter::verbosity(0);
    convert2xml($file);
    doctidy("$file.xml");
    my $extractor = Extractor->new();
    $extractor->verbosity(0);
    $extractor->init("$file.xml");
    my @fields = $bib ? ('bibliography') : ('authors', 'title', 'abstract');
    $extractor->extract(@fields);
    system("rm $file.xml");
    return $extractor;
}

my $result = get_meta('doctests/testdoc.pdf');
ok(defined($result), "extractor can process testdoc.pdf");
is(join('', @{$result->{authors}}), 'David J. Chalmers',
     "extractor recognises author of testdoc.pdf");
is($result->{title}, 'Ontological Anti-Realism',
     "extractor recognises title of testdoc.pdf");
like($result->{abstract}, qr/^The basic question.*and others.$/s,
     "extractor recognises abstract of testdoc.pdf");
like($result->{text}, qr/Is this ontological pluralism/,
     "extractor returns plain text of testdoc.pdf");

$result = get_meta('doctests/testdoc3.doc');
ok(defined($result), "extractor can process testdoc3.doc");
is(join(',', @{$result->{authors}}), 'Wolfgang Schwarz',
     "extractor recognises author of testdoc3.doc");
is($result->{title}, 'Preferring the less reliable method',
     "extractor recognises title of testdoc3.doc");
like($result->{abstract}, qr/^Compare the following.*irrational.$/s,
     "extractor recognises abstract of testdoc3.doc");
like($result->{text}, qr/suppose you apply the Bad method/,
     "extractor returns plain text of testdoc3.doc");

$result = get_meta('doctests/testdoc3.ps');
ok(defined($result), "extractor can process testdoc3.ps");
is(join(',', @{$result->{authors}}), 'Wolfgang Schwarz',
     "extractor recognises author of testdoc3.ps");
is($result->{title}, 'Preferring the less reliable method',
     "extractor recognises title of testdoc3.ps");
like($result->{abstract}, qr/^Compare the following.*irrational.$/s,
     "extractor recognises abstract of testdoc3.ps");
like($result->{text}, qr/suppose you apply the Bad method/,
     "extractor returns plain text of testdoc3.ps");

$result = get_meta('doctests/testdoc4.pdf');
ok(defined($result), "extractor can process scanned file testdoc4.pdf");
is(join(',', @{$result->{authors}}), 'Wolfgang Schwarz',
     "extractor recognises author of testdoc4.pdf");
is($result->{title}, 'Intensions, extensions, and quantifiers',
     "extractor recognises title of testdoc4.pdf");
like($result->{abstract}, qr/^Suppose we want.*to trouble.$/s,
     "extractor recognises abstract of testdoc4.pdf");
like($result->{text}, qr/But we could also accept this/,
     "extractor returns plain text of testdoc4.pdf");

$result = get_meta('doctests/testdoc.pdf', 1);
ok(scalar @{$result->{bibliography}},
     "extractor can parse bibliography from testdoc.pdf");

my $file = 'doctests/testdoc.pdf';
$file = abs_path($file);
convert2xml($file);
doctidy("$file.xml");
my $extractor = Extractor->new();
my $called = 0;
$extractor->{known_work} = sub {
    $called++;
    return 1;
};
$extractor->verbosity(0);
$extractor->init("$file.xml");
$extractor->extract('bibliography');
system("rm $file.xml");
ok($called, "Extractor uses passed known_work");
