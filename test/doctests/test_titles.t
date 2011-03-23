#! /usr/bin/perl -w
use strict;
use warnings;
use Test::More 'no_plan';
binmode STDOUT, ":utf8";
use utf8;
use lib '../..';
use Cwd 'abs_path';
use Converter;
use Doctidy 'doctidy';
use Extractor;
my %cfg = do 'config.pl';

my %tests = (

 '/home/wo/programming/opp-tools/test/doctests/11-Chalmers-probability.pdf' => {
   authors => ["David J. Chalmers"],
   title => "Probability and Propositions",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Byrne-Hayek-Hume.pdf' => {
   authors => ["Alex Byrne", "Alan Hájek"],
   title => "David Hume, David Lewis, and Decision Theory",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Avigad-Understanding.pdf' => {
   authors => ["Jeremy Avigad"],
   title => "Understanding, formal verification, and\nthe philosophy of mathematics",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Rayo-Generality.pdf' => {
   authors => ["Agustín Rayo"],
   title => "Absolute Generality Reconsidered",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Skyrms-Game.pdf' => {
   authors => ["Brian Skyrms"],
   title => "Game Theory, Rationality and\nEvolution of the Social Contract",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Incurvati-Smith-Rejection.pdf' => {
   authors => ["Luca Incurvati", "Peter Smith"],
   title => "Rejection and valuations",
 },

);

sub proc {
    my $file = shift;
    convert2xml($file);
    doctidy("$file.xml");
    my $extractor = Extractor->new("$file.xml");
    $extractor->extract(qw/authors title/);
    system("rm $file.xml");
    return ($extractor->{authors}, $extractor->{title});
}

while (my ($file, $res) = each(%tests)) {
    my ($au, $ti) = proc($file);
    is(join(", ", @$au), join(", ", @{$res->{authors}}));
    is($ti, $res->{title});
}
