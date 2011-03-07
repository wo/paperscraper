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
