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

 '/home/wo/programming/opp-tools/test/doctests/12-Avigad-Understanding.pdf' => {
   authors => ["Jeremy Avigad"],
   title => "Understanding, formal verification, and the philosophy of mathematics",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Rayo-Generality.pdf' => {
   authors => ["Agustín Rayo"],
   title => "Absolute Generality Reconsidered",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Skyrms-Game.pdf' => {
   authors => ["Brian Skyrms"],
   title => "Game Theory, Rationality and Evolution of the Social Contract",
 },

 '/home/wo/programming/opp-tools/test/doctests/11-Incurvati-Smith-Rejection.pdf' => {
   authors => ["Luca Incurvati", "Peter Smith"],
   title => "Rejection and valuations",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Kolodny-Myth.pdf' => {
   authors => ["Niko Kolodny"],
   title => "The Myth of Practical Consistency",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Newman-Wholes.pdf' => {
   authors => ["Andrew Newman"],
   title => "In Defence of Real Composite Wholes",
 },

 '/home/wo/programming/opp-tools/test/doctests/21-Polger-Shapiro-Understanding.pdf' => {
   authors => ["Thomas W. Polger", "Lawrence A. Shapiro"],
   title => "Understanding the Dimensions of Realization",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Roxborough-Cumby-Folk.pdf' => {
   authors => ["Craig Roxborough", "Jill Cumby"],
   title => "Folk Psychological Concepts: Causation",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Anon-Ramsey.pdf' => {
   authors => [""],
   title => "Two Interpretations of the Ramsey Test",
 },

 '/home/wo/programming/opp-tools/test/doctests/32-Potts-et-al-Expressives.pdf' => {
   authors => ["Christopher Potts", "Ash Asudeh", "Seth Cable", "Yurie Hara", "Eric McCready", "Martin Walkow", "Luis Alonso-Ovalle", "Rajesh Bhatt", "Christopher Davis", "Angelika Kratzer", "Tom Roeper"],
   title => "Expressives and identity conditions",
 },

 '/home/wo/programming/opp-tools/test/doctests/31-Seidenfeld-et-al-Preference.pdf' => {
   authors => ["Joseph B. Kadane", "Mark J. Schervish", "Teddy Seidenfeld"],
   title => "Preference for equivalent random variables: A price for unbounded utilities",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Fricker-Understanding.pdf' => {
   authors => ["Elizabeth Fricker"],
   title => "Understanding and Knowledge of What is Said",
 },

 '/home/wo/programming/opp-tools/test/doctests/B22-Fox-Lappin-Foundations.pdf' => {
   authors => ["Chris Fox", "Shalom Lappin"],
   title => "Foundations of Intensional Semantics",
 },

 '/home/wo/programming/opp-tools/test/doctests/31-Davies-Stoljar-Introduction.pdf' => {
   authors => ["Daniel Stoljar", "Martin Davies"],
   title => "Introduction",
 },

 '/home/wo/programming/opp-tools/test/doctests/32-Block-Functional.pdf' => {
   authors => ["Ned Block"],
   title => "Functional Reduction",
 },

 '/home/wo/programming/opp-tools/test/doctests/22-Anon-Aposteriori.pdf' => {
   authors => [""],
   title => "A Posteriori Identities and the Requirements of Rationality",
 },

 '/home/wo/programming/opp-tools/test/doctests/23-Byrne-et-al-See.pdf' => {
   authors => ["Alex Byrne", "David R. Hilbert", "Susanna Siegel"],
   title => "Do we see more than we can access?",
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
