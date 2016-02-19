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
    # We want to strip coverpages inserted by JSTOR etc., but not
    # separate coverpages inserted by the authors listing title,
    # author, affiliation etc., which are sometimes the only place
    # where title and authors are listed.
    ['very first page', [0.1, -0.4]],
    ['unusual dimensions', [0.4, -0.4]],
    ['no normal font', [0.3, -0.3]],
    ['contains typical coverpage words', [0.4, -0.5]],
    ['more than 1 page before page with no 2', [0.3, -0.5]],
    ['next page begins with capital letter', [0.1, -0.4]],
    ];

my %f;

$f{'very first page'} = sub { 
    return $_[0]->{number} == 0;
};

$f{'unusual dimensions'} = sub {
    # documents that were once scanned often have some variability in
    # page dimensions, so we have to check for variability: (We only
    # check width because height is often very variable anyway.)
    my @widths;
    my $page = $_[0];
    while (($page = $page->{next})) {
        push @widths, $page->{width};
        last if $page->{number} > 8;
    }
    return undef unless scalar @widths > 2;
    # ignore next page if there are enough pages:
    if (scalar @widths > 4) {
        shift @widths;
    }
    @widths = sort { $a <=> $b } @widths;
    my $tolerance = $widths[-1] - $widths[0];
    #print "xxx width $_[0]->{width} in ",@widths," +- $tolerance\n";
    return 1 if $_[0]->{width} + $tolerance < $widths[0];
    return 1 if $_[0]->{width} - $tolerance > $widths[-1];
    return 0;
};

$f{'no normal font'} = sub {
    my $ret = 1;
    foreach my $ch (@{$_[0]->{chunks}}) {
        next unless length($ch->{text}) > 8;
        my $diff = abs($ch->{fsize});
        #print "$diff $ch->{fsize} $ch->{text}\n";
        return 0 if $diff == 0;
        $ret = 0.5 if $diff < 2;
    }
    return $ret;
};


our $re_coverpage = qr/\b(?:
    Manuscript\sInformation|
    Terms\sand\sConditions|
    copyright\sowners
    )\b/ix;

$f{'contains typical coverpage words'} = sub {
    my $count = 0;
    foreach my $ch (@{$_[0]->{chunks}}) {
        $count++ if ($ch->{plaintext} =~ $re_coverpage);
        return 1 if $count > 3;
    }
    return $count ? (0.5 + $count/6) : 0;
};

$f{'more than 1 page before page with no 2'} = sub {
    my $page = $_[0];
    my $dist = 0;
    my $re_numbertwo = qr/\W*2\W*/;
    while (($page = $page->{next})) {
        $dist++;
        next unless @{$page->{chunks}};
        if ($page->{chunks}->[0]->{plaintext} =~ /^$re_numbertwo$/
            or $page->{chunks}->[-1]->{plaintext} =~ /^$re_numbertwo$/) {
            return $dist > 1 ? 1 : 0;
        }
        last if $dist > 3;
    }
    return undef; # no page with number '2'
};

$f{'next page begins with capital letter'} = sub {
    my $page = $_[0]->{next};
    return undef unless $page;
    for my $ch (@{$page->{chunks}}) {
        if ($ch->{plaintext} =~ /([[:alpha:]])/) {
            return ($1 =~ /[[:upper:]]/) ? 1 : 0;
        }
    }
    return undef;
};

compile(\%features, \%f);

1;
