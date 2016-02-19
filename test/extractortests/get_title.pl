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
Converter::verbosity(5) if $verbosity > 5;
convert2xml($file);
system("cat \"$file.xml\"") if $verbosity > 5;

my $start = time;

my $extractor = Extractor->new();
$extractor->verbosity($verbosity);
$extractor->init("$file.xml");
$extractor->extract('authors', 'title');
system("rm \"$file.xml\"");

sub escape {
    my $str = shift;
    return '' unless $str;
    $str =~ s/"/\\"/g;
    $str =~ s/\n/\\n/g;
    return $str;
}

print "\n '$file' => {\n",
    "   authors => [\"",
    join('", "', map { escape($_) } @{$extractor->{authors}}),"\"],\n",
    "   title => \"", escape($extractor->{title}), "\",\n",
    " },\n";

my $end = time;
print "\ntime: ",$end - $start,"\n";
