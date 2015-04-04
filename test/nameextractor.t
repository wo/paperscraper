#! /usr/bin/perl -w
use strict;
use warnings;
use utf8;
use Test::More 'no_plan';
binmode STDOUT, ":utf8";
use lib '..';
use Cwd 'abs_path';
use rules::NameExtractor; 

my %tests = (

 'David J. Chalmers' => ['David J. Chalmers'],
 'Alex Byrne and Alan Hájek' => ['Alex Byrne', 'Alan Hájek'],
 'Alex Byrne, Alan Hájek' => ['Alex Byrne', 'Alan Hájek'],
 'Lara Buchak, UC Berkeley' => ['Lara Buchak'],
 'Ash Asudeh, Carleton University' => ['Ash Asudeh'],
 'Teddy Seidenfeld, Mark J. Schervish, and Joseph B. Kadane' => ['Teddy Seidenfeld', 'Mark J. Schervish', 'Joseph B. Kadane'],
 'Formal Study, John L. Pollock' => ['John L. Pollock'],

);

rules::NameExtractor::verbosity(1);

foreach my $str (keys %tests) {
    print "$str\n";
    my @names = sort @{$tests{$str}};
    my %res = %{parse($str)};
    my @au;
    while (my ($name, $prob) = each %res) {
        print "$name: $prob\n";
        if ($prob > 0.5) {
            push @au, $name;
        }
    }
    @au = sort @au;
    is(join(",", @au), join(",", @names));
}
