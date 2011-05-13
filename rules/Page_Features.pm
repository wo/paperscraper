package rules::Page_Features;
use warnings;
use strict;
use List::Util qw/min max/;
use util::String;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%features/;


our %features;

$features{COVERPAGE} = [
    ['default', [-0.25, 0]],
    ['document has many pages', [0, -1]],
    ['within first few pages', [0, -1]],
    ['unusual dimensions', [0.2, -0.2]],
    ['little normal font', [0.2, -0.1]],
    ['matches coverpage pattern', [0.3, -0.2]],
    ];

my %f;

$f{'default'} = sub {
    return 1;
};

$f{'document has many pages'} = sub {
    return $_[0]->{doc}->{numpages} > 3;
};

$f{'within first few pages'} = sub { 
    2 / max($_[0]->{number}+1, 2);
};

$f{'unusual dimensions'} = sub {
    my $page = $_[0];
    my $count = 0;
    while ($page = $page->{next}) {
        $count++ if $page->{width} == $_[0]->{width};
        return 0 if $count > 2;
    }
    return $count ? 0.5 : 1;
};

$f{'little normal font'} = sub {
    my $count = 0;
    foreach my $ch (@{$_[0]->{chunks}}) {
        $count++ if $ch->{fsize} > 1.25 || $ch->{fsize} < 0.8;
        return 0 if $count > 10;
    }
    return 1-$count/10;
};

$f{'matches coverpage pattern'} = sub {
    my $count = 0;
    foreach my $ch (@{$_[0]->{chunks}}) {
        $count++ if ($ch->{plaintext} =~ $re_coverpage);
        return 1 if $count > 3;
    }
    return $count ? 0.5 + $count/6 : 0;
};

compile(\%features, \%f);

1;
