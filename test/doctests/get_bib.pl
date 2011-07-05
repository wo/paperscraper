#! /usr/bin/perl -w
use strict;
use warnings;
use Getopt::Std;
use Time::HiRes 'time';
binmode STDOUT, ":utf8";
use lib '../..';
use Cwd 'abs_path';
use Converter;
use Extractor;

my %opts;
getopts("v:", \%opts);
my $verbosity = exists($opts{v}) ? $opts{v} : 2;

my $file = shift @ARGV;
$file = abs_path($file);
convert2xml($file);

my $start = time;

my $extractor = Extractor->new();
$extractor->verbosity($verbosity);
$extractor->init("$file.xml");
$extractor->extract('bibliography');
system("rm $file.xml");

sub escape {
    my $str = shift;
    return '' unless $str;
    $str =~ s/"/\\"/g;
    $str =~ s/\n/\\n/g;
    return $str;
}

print "\n '$file' => [\n";
foreach my $bib (@{$extractor->{bibliography}}) {
    print "   {\n",
        "    authors => [\"",
        join('", "', map { escape($_) } @{$bib->{authors}}),"\"],\n",
        "    title => \"", escape($bib->{title}), "\",\n",
        "    year => \"", escape($bib->{year}), "\",\n",
        "   },\n";
}
print " ],\n";

my $end = time;
print "\ntime: ",$end - $start,"\n";
 
