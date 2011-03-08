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

 '/home/wo/programming/opp-tools/test/doctests/00-test.pdf' => [
   {
    authors => ["Andreas Albrecht", "Lorenzo Sorbo"],
    title => "Can the universe afford inflation?",
    year => "2004",
   },
 ],

 '/home/wo/programming/opp-tools/test/doctests/11-Skyrms-Game.pdf' => [
   {
    authors => ["J. Alexander"],
    title => "The (spatial) evolution of the equal split",
    year => "1999",
   },
   {
    authors => ["J. Alexander", "B. Skyrms"],
    title => "Bargaining with neighbors: is justice contagious?",
    year => "1999",
   },
   {
    authors => ["R. J. Aumann"],
    title => "Subjectivity and correlation in randomized strategies",
    year => "1974",
   },
   {
    authors => ["R. J. Aumann"],
    title => "Correlated equilibrium as an expression of Bayesian rationality",
    year => "1987",
   },
   {
    authors => ["K. Binmore"],
    title => "Game theory and the social contract Vol. 1",
    year => "1993",
   },
   {
    authors => ["K. Binmore"],
    title => "Game theory and the social contract Vol. 2",
    year => "1998",
   },
   {
    authors => ["K. Binmore", "J. Gale", "L. Samuelson"],
    title => "Learning to be imperfect:The ultimatum game",
    year => "1995",
   },
   {
    authors => ["B. D. Bernheim"],
    title => "Rationalizable strategic behaviour",
    year => "1007–28",
   },
   {
    authors => ["J. Bjornerstedt", "J. Weibull"],
    title => "Nash equilibrium and evolution by imitation",
    year => "1995",
   },
   {
    authors => ["I. Bomze"],
    title => "Non-cooperative two-person games in biology: A classification",
    year => "1986",
   },
   {
    authors => ["T. Borgers", "R. Sarin"],
    title => "Learning through reinforcement and the replicator dynamics",
    year => "1997",
   },
   {
    authors => ["V. Camerer"],
    title => "Progress in behavioural game theory",
    year => "1997",
   },
   {
    authors => ["J. Duffy", "R. Nagel"],
    title => "On the robustness of behaviour in experimental “Beauty Contest” games",
    year => "1684–700",
   },
   {
    authors => ["D. Fudenberg", "D. Levine"],
    title => "The Theory of Learning in Games",
    year => "1998",
   },
   {
    authors => ["D. Gauthier"],
    title => "The Logic of the Leviathan",
    year => "1969",
   },
   {
    authors => ["D. Gauthier"],
    title => "Morals by Agreement",
    year => "1986",
   },
   {
    authors => ["A. Gibbard"],
    title => "Wise Choices, Apt Feelings:A Theory of Normative Judgement",
    year => "1990",
   },
   {
    authors => ["W. Güth", "R. Schmittberger", "B. Schwarze"],
    title => "‘An experimental analysis of ultimatum bargainin’,g",
    year => "1982",
   },
   {
    authors => ["W. Güth", "R. Tietz"],
    title => "Ultimatum bargaining behaviour: A survey and comparison of experimental results",
    year => "1990",
   },
   {
    authors => ["W. D. Hamilton"],
    title => "The genetical evolution of social behaviour",
    year => "1964",
   },
   {
    authors => ["W. Harms"],
    title => "Discrete replicator dynamics for the ultimatum game with mutation and recombination",
    year => "1994",
   },
   {
    authors => ["W. Harms"],
    title => "Evolution and ultimatum bargaining",
    year => "1997",
   },
   {
    authors => ["J. Harsanyi", "R. Selten"],
    title => "A General Theory of Equilibrium Selection in Games",
    year => "1988",
   },
   {
    authors => ["T. H. Ho", "K. Weigelt", "C. Camerer"],
    title => "Iterated dominance and iterated best-response in experimental <i>p</i>-beauty contests",
    year => "1996",
   },
   {
    authors => ["J. Hofbauer", "K. Sigmund"],
    title => "The Theory of Evolution and Dynamical Systems",
    year => "1988",
   },
   {
    authors => ["D. Hume"],
    title => "<i>Enquiries Concerning Human Understanding and Concerning the Principles of Morals</i>",
    year => "1777",
   },
   {
    authors => ["J. M. Keynes"],
    title => "The General Theory of Employment, Interest and Money",
    year => "1936",
   },
   {
    authors => ["D. Lewis"],
    title => "Convention",
    year => "1969",
   },
   {
    authors => ["J. Maynard-Smith", "G. R. Price"],
    title => "The logic of animal conflict",
    year => "1973",
   },
   {
    authors => ["J. Maynard-Smith", "G. R. Parker"],
    title => "The logic of asymmetric contests",
    year => "1976",
   },
   {
    authors => ["P. Milgrom", "D. North", "B. Weingast"],
    title => "The role of institutions in the revival of trade: The law merchant, private judges, and the champagne fairs",
    year => "2005",
   },
   {
    authors => ["H. Moulin"],
    title => "Game Theory for the Social Sciences",
    year => "1986",
   },
   {
    authors => ["R. Nagel"],
    title => "Unravelling in guessing games:An experimental study",
    year => "1313–26",
   },
   {
    authors => ["D. G. Pearce"],
    title => "Rationalizable strategic behaviour and the problem of perfection",
    year => "1029–50",
   },
   {
    authors => ["P. L. Sacco"],
    title => "Comment",
    year => "1995",
   },
   {
    authors => ["L. Samuelson"],
    title => "Evolutionary Games and Equilibrium Selection",
    year => "1997",
   },
   {
    authors => ["L. Samuelson"],
    title => "Evolutionary foundations of solution concepts for finite two-player normal form games",
    year => "1988",
   },
   {
    authors => ["K. Schlag"],
    title => "Why imitate and if so how? Exploring a model of social evolution",
    year => "1994",
   },
   {
    authors => ["K. Schlag"],
    title => "Why imitate and if so, how? A bounded rational approach to many armed bandits",
    year => "1996",
   },
   {
    authors => ["R. Selten"],
    title => "Re-examination of the perfectness concept of equilibrium in extensive games",
    year => "1975",
   },
   {
    authors => ["R. Selten"],
    title => "Spieltheoretische Behandlung eines Oligopolmodells mit Nachfragetragheit",
    year => "1965",
   },
   {
    authors => ["B. Skyrms"],
    title => "The Dynamics of Rational Deliberation",
    year => "1990",
   },
   {
    authors => ["B. Skyrms"],
    title => "Darwin meets ‘The logic of decision’: Correlation in evolutionary game theory",
    year => "1994",
   },
   {
    authors => ["B. Skyrms"],
    title => "Sex and justice",
    year => "1994",
   },
   {
    authors => ["B. Skyrms"],
    title => "Introduction to the Nobel symposium on game theory",
    year => "1995",
   },
   {
    authors => ["B. Skyrms"],
    title => "Evolution of the Social Contract",
    year => "1996",
   },
   {
    authors => ["B. Skyrms"],
    title => "Mutual aid",
    year => "1998",
   },
   {
    authors => ["B. Skyrms"],
    title => "Evolution of an anomaly",
    year => "1998",
   },
   {
    authors => ["B. Skyrms"],
    title => "Evolution of inference",
    year => "1999",
   },
   {
    authors => ["E. Sober"],
    title => "The evolution of altruism: Correlation, cost and benefit",
    year => "1992",
   },
   {
    authors => ["E. Sober", "D. S. Wilson"],
    title => "Unto Others:The Evolution and Psychology of Unselfish behaviour",
    year => "1998",
   },
   {
    authors => ["B. Spinoza"],
    title => "<i>Ethics:The Collected Works of Spinoza, Volume I</i>",
    year => "1985",
   },
   {
    authors => ["D. O. Stahl"],
    title => "Boundedly rational rule learning in a guessing game",
    year => "1996",
   },
   {
    authors => ["R. Sugden"],
    title => "The Economics of Rights, Co-operation and Welfare",
    year => "1986",
   },
   {
    authors => ["P. Taylor", "L. Jonker"],
    title => "Evolutionarily stable strategies and game dynamics",
    year => "1978",
   },
   {
    authors => ["E. van Damme"],
    title => "Stability and Perfection of Nash Equilibria",
    year => "1987",
   },
   {
    authors => ["P. Vanderschraaf"],
    title => "Knowledge, equilibrium and convention",
    year => "1998",
   },
   {
    authors => ["P. Vanderschraaf"],
    title => "Convention as correlated equilibrium",
    year => "1995",
   },
   {
    authors => ["P. Vanderschraaf", "B. Skyrms"],
    title => "Deliberational correlated equilibrium",
    year => "1994",
   },
   {
    authors => ["J. von Neumann", "O. Morgenstern"],
    title => "Theory of Games and Economic Behaviour, 2nd. ed",
    year => "1947",
   },
   {
    authors => ["J. Weibull"],
    title => "Evolutionary Game Theory",
    year => "2005",
   },
 ],

);

sub proc {
    my $file = shift;
    convert2xml($file);
    doctidy("$file.xml");
    my $extractor = Extractor->new("$file.xml");
    $extractor->extract(qw/bibliography/);
    system("rm $file.xml");
    return ($extractor->{bibliography});
}

while (my ($file, $res) = each(%tests)) {
    my $bib = proc($file);
    my $max = @{$bib} > @{$res} ? @{$bib} : @{$res};
    for my $i (0 .. $max-1) {
        my $act = $bib->[$i];
        my $ref = $res->[$i];
        is(join(", ", @{$act->{authors}}), join(", ", @{$ref->{authors}}));
        is($act->{title}, $ref->{title});
        is($act->{year}, $ref->{year});
    }
}
