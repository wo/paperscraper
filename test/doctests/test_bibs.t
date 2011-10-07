#! /usr/bin/perl -w
use strict;
use warnings;
use Test::More 'no_plan';
binmode STDOUT, ":utf8";
use utf8;
use lib '../..';
use Cwd 'abs_path';
use Converter;
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
    year => "1984",
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
    year => "1997",
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
    title => "Enquiries Concerning Human Understanding and Concerning the Principles of Morals",
    year => "1975",
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
    year => "1990",
   },
   {
    authors => ["H. Moulin"],
    title => "Game Theory for the Social Sciences",
    year => "1986",
   },
   {
    authors => ["R. Nagel"],
    title => "Unravelling in guessing games:An experimental study",
    year => "1995",
   },
   {
    authors => ["D. G. Pearce"],
    title => "Rationalizable strategic behaviour and the problem of perfection",
    year => "1984",
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
    title => "Ethics:The Collected Works of Spinoza, Volume I",
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
    year => "1997",
   },
 ],


 '/home/wo/programming/opp-tools/test/doctests/11-Byrne-Hayek-Hume.pdf' => [
   {
    authors => ["Horacio Arló Costa", "John Collins", "Isaac Levi"],
    title => "Desire-as-Belief Implies Opinionation or Indifference",
    year => "1995",
   },
   {
    authors => ["John Collins"],
    title => "Belief, Desire, and Revision",
    year => "1988",
   },
   {
    authors => ["John Collins"],
    title => "Belief Revision",
    year => "1991",
   },
   {
    authors => ["Peter Gärdenfors"],
    title => "Imaging and Conditionalization",
    year => "1982",
   },
   {
    authors => ["Allan Gibbard", "William Harper"],
    title => "Counterfactuals and Two Kinds of Expected Utility",
    year => "1978",
   },
   {
    authors => ["Alan Hájek"],
    title => "Triviality on the Cheap?",
    year => "1994",
   },
   {
    authors => ["Alan Hájek"],
    title => "The Fearless and Moderate Revision: Extending Lewis’s Triviality Results",
    year => "1996",
   },
   {
    authors => ["Alan Hájek", "Philip Pettit"],
    title => "In the Spirit of Desire-as-Belief",
    year => "1996",
   },
   {
    authors => ["David Hume"],
    title => "A Treatise of Human Nature",
    year => "1739–40",
   },
   {
    authors => ["Richard Jeffrey"],
    title => "The Logic of Decision",
    year => "1965",
   },
   {
    authors => ["David Lewis"],
    title => "Probabilities of Conditionals and Conditional Probabilities",
    year => "1976",
   },
   {
    authors => ["David Lewis"],
    title => "Counterfactual Dependence and Time’s Arrow",
    year => "1979",
   },
   {
    authors => ["David Lewis"],
    title => "Causal Decision Theory",
    year => "1981",
   },
   {
    authors => ["David Lewis"],
    title => "<i>Philosophical Papers,</i> vol. II",
    year => "1986",
   },
   {
    authors => ["David Lewis"],
    title => "Desire as Belief",
    year => "1988",
   },
   {
    authors => ["David Lewis"],
    title => "Dispositional Theories of Value",
    year => "1989",
   },
   {
    authors => ["David Lewis"],
    title => "Desire as Belief II",
    year => "1996",
   },
   {
    authors => ["Huw Price"],
    title => "Defending Desire-as-Belief",
    year => "1989",
   },
   {
    authors => ["Robert Stalnaker"],
    title => "A Theory of Conditionals",
    year => "1968",
   },
   {
    authors => ["Paul Teller"],
    title => "Conditionalization and Observation",
    year => "1973",
   },
 ],


 '/home/wo/programming/opp-tools/test/doctests/11-Chalmers-probability.pdf' => [
   {
    authors => ["D. F. Austin"],
    title => "What’s the Meaning of “This”?",
    year => "1990",
   },
   {
    authors => ["D. Braun"],
    title => "Russellianism and psychological generalization",
    year => "2000",
   },
   {
    authors => ["D. J. Chalmers"],
    title => "Does conceivability entail possibility?",
    year => "2002",
   },
   {
    authors => ["D. J. Chalmers"],
    title => "Epistemic two-dimensional semantics",
    year => "2004",
   },
   {
    authors => ["D. J. Chalmers", "F. Jackson"],
    title => "Conceptual analysis and reductive explanation",
    year => "2001",
   },
   {
    authors => ["A. Elga"],
    title => "Self-locating belief and the Sleeping Beauty problem",
    year => "2000",
   },
   {
    authors => ["D. Lewis"],
    title => "A subjectivist’s guide to objective chance",
    year => "1980",
   },
   {
    authors => ["D. Lewis"],
    title => "Attitudes de dicto and de se",
    year => "1983",
   },
   {
    authors => ["F. Jackson"],
    title => "From Metaphysics to Ethics",
    year => "1998",
   },
   {
    authors => ["R. Stalnaker"],
    title => "Inquiry",
    year => "1984",
   },
 ],


 '/home/wo/programming/opp-tools/test/doctests/11-Rayo-Generality.pdf' => [
   {
    authors => ["W. Alston"],
    title => "Ontological Commitments",
    year => "1957",
   },
   {
    authors => ["J. Azzouni"],
    title => "On ‘On What There Is’",
    year => "1998",
   },
   {
    authors => ["J. Beall"],
    title => "Liars and Heaps",
    year => "2003",
   },
   {
    authors => ["G. Boolos"],
    title => "Meaning and Method: Essays in Honor of Hilary Putnam",
    year => "1990",
   },
   {
    authors => ["O. Bueno", "Ø. Linnebo"],
    title => "New Waves in Philosophy of Mathematics",
    year => "(forthcoming)",
   },
   {
    authors => ["J. Burgess"],
    title => "Being Explained Away",
    year => "2005",
   },
   {
    authors => ["R. Cartwright"],
    title => "Ontology and the theory of meaning",
    year => "1954",
   },
   {
    authors => ["R. Cartwright"],
    title => "Philosophical Essays",
    year => "1987",
   },
   {
    authors => ["K. Fine"],
    title => "The Question of Realism",
    year => "2001",
   },
   {
    authors => ["W. Goldfarb"],
    title => "Metaphysics and Nonsense: On Cora Diamond’s The Realistic Spirit",
    year => "1997",
   },
   {
    authors => ["P. Hacker"],
    title => "Insight and Illusion: Themes in the Philosophy of Wittgenstein",
    year => "1986",
   },
   {
    authors => ["J. Heil"],
    title => "From an Ontological Point of View",
    year => "2003",
   },
   {
    authors => ["H. T. Hodes"],
    title => "Ontological Commitments: Thick and Thin",
    year => "1990",
   },
   {
    authors => ["F. Jackson"],
    title => "Ontological Commitment and Paraphrase",
    year => "1980",
   },
   {
    authors => ["S. Kanger", " S. Öhman"],
    title => "Philosophy and Grammar",
    year => "1980",
   },
   {
    authors => ["D. Lewis"],
    title => "Index, context, and content",
    year => "1980",
   },
   {
    authors => ["D. Lewis"],
    title => "New Work for a Theory of Universals",
    year => "1983",
   },
   {
    authors => ["D. Lewis"],
    title => "Noneism or Allism",
    year => "1990",
   },
   {
    authors => ["D. Lewis"],
    title => "Papers in Philosophical Logic",
    year => "1998",
   },
   {
    authors => ["D. Lewis"],
    title => "Papers in Metaphysics and Epistemology",
    year => "1999",
   },
   {
    authors => ["J. Melia"],
    title => "On What There Isn’t",
    year => "1995",
   },
   {
    authors => ["C. Parsons"],
    title => "Sets and Classes",
    year => "1974",
   },
   {
    authors => ["T. Parsons"],
    title => "Are There Non-existent Objects?",
    year => "1982",
   },
   {
    authors => ["D. Pears"],
    title => "The False Prison: A Study of the Development of Wittgenstein’s Philosophy",
    year => "1987",
   },
   {
    authors => ["G. Priest"],
    title => "Towards Non-Being: the Logic and Metaphysics of Intentionality",
    year => "2005",
   },
   {
    authors => ["H. Putnam"],
    title => "The Many Faces of Realism",
    year => "1987",
   },
   {
    authors => ["W. V. Quine"],
    title => "On what there is",
    year => "1948",
   },
   {
    authors => ["W. V. Quine"],
    title => "On Carnap’s Views on Ontology",
    year => "1951",
   },
   {
    authors => ["W. V. Quine"],
    title => "Ontology and Ideology",
    year => "1951",
   },
   {
    authors => ["W. V. Quine"],
    title => "From a Logical Point of View",
    year => "1953",
   },
   {
    authors => ["W. V. Quine"],
    title => "Logic and the Reification of Universals",
    year => "1953",
   },
   {
    authors => ["A. Rayo"],
    title => "Word and Objects",
    year => "2002",
   },
   {
    authors => ["A. Rayo"],
    title => "When does ‘everything’ mean everything?",
    year => "2003",
   },
   {
    authors => ["A. Rayo"],
    title => "Towards a Trivialist Account of Mathematics",
    year => "2009",
   },
   {
    authors => ["A. Rayo"],
    title => "Neo-Fregeanism Reconsidered",
    year => "(forthcoming)",
   },
   {
    authors => ["A. Rayo"],
    title => "Possibility and Content: Metaphysics without Deep Metaphysics",
    year => "(typescript)",
   },
   {
    authors => ["A. Rayo", "G. Uzquiano"],
    title => "Toward a Theory of Second-Order Consequence",
    year => "1999",
   },
   {
    authors => ["A. Rayo", " G. Uzquiano"],
    title => "Absolute Generality",
    year => "2006",
   },
   {
    authors => ["A. Rayo", "G. Uzquiano"],
    title => "Introduction to Absolute Generality",
    year => "2006",
   },
   {
    authors => ["A. Rayo", "T. Williamson"],
    title => "A Completeness Theorem for Unrestricted First-Order Languages",
    year => "2003",
   },
   {
    authors => ["R. Routley"],
    title => "On What There Is Not",
    year => "1982",
   },
   {
    authors => ["T. Sider"],
    title => "Writing the Book of theWorld",
    year => "(typescript)",
   },
   {
    authors => ["L. Wittgenstein"],
    title => "Tractatus Logico-Philosophicus",
    year => "1922",
   },
   {
    authors => ["S. Yablo"],
    title => "Does Ontology Rest on a Mistake",
    year => "1998",
   },
 ],

 '/home/wo/programming/opp-tools/test/doctests/12-Avigad-Understanding.pdf' => [
   {
    authors => ["Jeremy Avigad"],
    title => "Number theory and elementary arithmetic",
    year => "2003",
   },
   {
    authors => ["Jeremy Avigad"],
    title => "Mathematical method and proof",
    year => "2006",
   },
   {
    authors => ["Jeremy Avigad"],
    title => "Understanding proofs",
    year => "",
   },
   {
    authors => ["Jeremy Avigad", "Edward Dean", "John Mumma"],
    title => "A formal system for Euclid’s Elements",
    year => "2009",
   },
   {
    authors => ["Jeremy Avigad", "Kevin Donnelly", "David Gray", "Paul Raff"],
    title => "A formally verified proof of the prime number theorem",
    year => "2007",
   },
   {
    authors => ["H. Furstenberg"],
    title => "Ergodic behavior of diagonal measures and a theorem of Szemeredi on arithmetic progressions",
    year => "1977",
   },
   {
    authors => ["Marcus Giaquinto"],
    title => "Visual Thinking in Mathematics: An Epistemological Study",
    year => "2007",
   },
   {
    authors => ["Georges Gonthier"],
    title => "Formal proof—the four-color theorem",
    year => "2008",
   },
   {
    authors => ["Georges Gonthier", "Assia Mahboubi"],
    title => "A small scale reflection extension for the coq system",
    year => "2008",
   },
   {
    authors => ["Georges Gonthier", "Assia Mahboubi", "Laurence Rideau", "Enrico Tassi", "Laurent Thery"],
    title => "A modular formalisation of finite group theory",
    year => "2007",
   },
   {
    authors => ["Thomas C. Hales"],
    title => "The Jordan curve theorem, formally and informally",
    year => "2007",
   },
   {
    authors => ["Thomas C. Hales"],
    title => "Formal proof",
    year => "2008",
   },
   {
    authors => ["John Harrison"],
    title => "A formalized proof of dirichlet’s theorem on primes in arithmetic progression",
    year => "2009",
   },
   {
    authors => ["John Harrison"],
    title => "Formalizing an analytic proof of the prime number theorem",
    year => "2009",
   },
   {
    authors => ["John Harrison"],
    title => "Handbook of Practical Logic and Automated Reasoning",
    year => "2009",
   },
   {
    authors => ["Steven Kieffer", "Jeremy Avigad", "Harvey Friedman"],
    title => "A language for mathematical language management",
    year => "2009",
   },
   {
    authors => ["Penelope Maddy"],
    title => "Second Philosophy: A Naturalistic Method",
    year => "2007",
   },
   {
    authors => ["Paolo Mancosu"],
    title => "The Philosophy of Mathematical Practice",
    year => "2008",
   },
   {
    authors => ["Kenneth Manders"],
    title => "The Euclidean diagram",
    year => "",
   },
   {
    authors => ["Henri Poincare"],
    title => "Science et Methode",
    year => "1908",
   },
   {
    authors => ["Pavel Pudlak"],
    title => "The lengths of proofs",
    year => "1998",
   },
   {
    authors => ["John Alan Robinson", "Andrei Voronkov"],
    title => "Handbook of Automated Reasoning (in 2 volumes)",
    year => "2001",
   },
   {
    authors => ["P. Rudnicki"],
    title => "An overview of the mizar project",
    year => "1992",
   },
   {
    authors => ["Bertrand Russell"],
    title => "The Problems of Philosophy",
    year => "1912",
   },
   {
    authors => ["C. Smorynski"],
    title => "“Big” news from Archimedes to Friedman",
    year => "1983",
   },
   {
    authors => ["E. Szemeredi"],
    title => "On sets of integers containing no k elements in arithmetic progression",
    year => "1975",
   },
   {
    authors => ["Terence Tao"],
    title => "A quantitative ergodic theory proof of Szemeredi’s theorem",
    year => "2006",
   },
   {
    authors => ["Jamie Tappenden"],
    title => "Proof style and understanding in mathematics I: visualization, unification, and axiom choice",
    year => "2005",
   },
   {
    authors => ["Alasdair Urquhart"],
    title => "Mathematics and physics: strategies of assimilation",
    year => "",
   },
   {
    authors => ["V. S. Varadarajan"],
    title => "Euler Through Time: A New Look at Old Themes",
    year => "2006",
   },
   {
    authors => ["Makarius Wenzel"],
    title => "Isabelle/Isar—a generic framework for human-readable proof documents",
    year => "2007",
   },
   {
    authors => ["Freek Wiedijk"],
    title => "The Seventeen Provers of the World",
    year => "2006",
   },
   {
    authors => ["Mark Wilson"],
    title => "Wandering Significance: An Essay on Conceptual Behavior",
    year => "",
   },
   {
    authors => ["Ludwig Wittgenstein"],
    title => "Remarks on the Foundations of Mathematics",
    year => "1956",
   },
 ],


 '/home/wo/programming/opp-tools/test/doctests/22-Silby-Zombies.pdf' => [
   {
    authors => ["D. Armstrong"],
    title => "What is Consciousness",
    year => "1981",
   },
   {
    authors => ["N. Block"],
    title => "On a Confusion about a Function of Consciousness",
    year => "1995",
   },
   {
    authors => ["D. Chalmers"],
    title => "The Conscious Mind",
    year => "1996",
   },
   {
    authors => ["A. Cottrell"],
    title => "On the conceivability of zombies: Chalmers v. Dennett",
    year => "1996",
   },
   {
    authors => ["D. Dennett"],
    title => "Quining Qualia",
    year => "1988",
   },
   {
    authors => ["D. Dennett"],
    title => "Consciousness Explained",
    year => "1993",
   },
   {
    authors => ["D. Dennett"],
    title => "The Unimagined Preposterousness of Zombies",
    year => "1995",
   },
   {
    authors => ["D. Dennett"],
    title => "The Path Not Taken",
    year => "1995",
   },
   {
    authors => ["F. Dretske"],
    title => "Conscious Experience",
    year => "1993",
   },
   {
    authors => ["G. Guzeldere"],
    title => "Introduction: The Many Faces of Consciousness: A Field Guide",
    year => "1997",
   },
   {
    authors => ["T. Horgan"],
    title => "Supervenient Qualia",
    year => "1987",
   },
   {
    authors => ["J. Levine"],
    title => "On Leaving Out What It's Like",
    year => "1993",
   },
   {
    authors => ["G. Rey"],
    title => "Contemporary Philosophy of Mind",
    year => "1997",
   },
   {
    authors => ["S. Shoemaker"],
    title => "Functionalism and Qualia",
    year => "1975",
   },
   {
    authors => ["G. Vision"],
    title => "Blindsight and Philosophy",
    year => "1998",
   },
 ],

);


sub proc {
    my $file = shift;
    convert2xml($file);
    my $extractor = Extractor->new("$file.xml");
    $extractor->extract(qw/bibliography/);
    system("rm $file.xml");
    return ($extractor->{bibliography});
}

while (my ($file, $res) = each(%tests)) {
    print substr($file, length('/home/wo/programming/opp-tools/test/doctests/')), "\n";
    my $bib;
    eval {
        $bib = proc($file);
    };
    next if ($@);
    print "\n",("=" x 70),"\n== $file\n", ("=" x 70), "\n\n";
    if (scalar @$bib != scalar @$res) {
        print "\n\n\n!! Document has ",scalar @$res," references, ",
              "but ",scalar @$bib, " retrieved! Skipping.\n\n\n";
        next;
    }
    my $min = @{$bib} > @{$res} ? @{$res} : @{$bib};
    for my $i (0 .. $min-1) {
        my $act = $bib->[$i];
        my $ref = $res->[$i];
        print "== testing ",join(", ", @{$ref->{authors}}),": ",
              $ref->{title},"\n";
        is(join(", ", @{$act->{authors}}), join(", ", @{$ref->{authors}}));
        is($act->{title}, $ref->{title});
        is($act->{year}, $ref->{year});
    }
}
