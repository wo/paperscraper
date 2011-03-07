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

 '/home/wo/programming/opp-tools/test/doctests/1-Avigad-Understanding.pdf' => "The philosophy of mathematics has long been concerned with determining the means\nthat are appropriate for justifying claims of mathematical knowledge, and the metaphysical\nconsiderations that render them so. But, as of late, many philosophers have called attention\nto the fact that a much broader range of normative judgments arise in ordinary mathematical\npractice; for example, questions can be interesting, theorems important, proofs explanatory,\nconcepts powerful, and so on. The associated values are often loosely classified as aspects\nMeanwhile, in a branch of computer science known as “formal verification,” the practice\nof interactive theorem proving has given rise to software tools and systems designed to\nsupport the development of complex formal axiomatic proofs. Such efforts require one to\ndevelop models of mathematical language and inference that are more robust than the the\nsimple foundational models of the last century. This essay explores some of the insights\nthat emerge from this work, and some of the ways that these insights can inform, and be\ninformed by, philosophical theories of mathematical understanding.\n",

);

sub proc {
    my $file = shift;
    convert2xml($file);
    doctidy("$file.xml");
    my $extractor = Extractor->new("$file.xml");
    $extractor->extract('abstract');
    system("rm $file.xml");
    return $extractor->{abstract};
}

while (my ($file, $res) = each(%tests)) {
      is($res, proc($file));
}
