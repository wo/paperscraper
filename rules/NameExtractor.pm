package rules::NameExtractor;
use strict;
use warnings;
use Exporter;
use List::Util qw/max min/;
use Cwd 'abs_path';
use File::Basename;
use lib '..';
use util::String;
use util::Estimator;
use rules::Keywords;
use rules::Name_Features;
use rules::Helper;
our @ISA = ('Exporter');
our @EXPORT = qw/&parse/;

my $estim = util::Estimator->new();
my $name_features = \@rules::Name_Features::name_features;
foreach (@$name_features) {
    $estim->add_feature(@$_);
}

my $verbose = 0;
sub verbosity {
   $verbose = shift if @_;
   $estim->verbose($verbose);
}

sub parse {
    my $str = shift;
    my %res; # name => probability
    print "--parsing name $str\n" if $verbose;
    my @parts = split($re_name_separator, $str);
    while (my ($i, $part) = each @parts) {
        if ($part !~
            /^(?:$re_name_before)?($re_name)(?:$re_name_after)?$/
            || $1 =~ /$re_noname/) {
            print "---skipping $part\n" if $verbose;
            next;
        }
        my %name = ('text' => $1, 'first' => $2, 'last' => $3);
        my $p = $estim->test(\%name);
        if ($p > 0.6) {
            $res{$name{text}} = $p;
        }
    }
    return \%res;
}

1;
