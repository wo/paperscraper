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
    ['document has many pages', [0, -0.5]],
    ['very first page', [0.1, -0.4]],
    ['unusual dimensions', [0.4, -0.4]],
    ['no normal font', [0.3, -0.3]],
    ['contains typical coverpage words', [0.4, -0.4]],
    ['more than 1 page before page with no 2', [0.4, -0.5]],
    ['next page begins with capital letter', [0.1, -0.4]],
    ];

my %f;

$f{'document has many pages'} = sub {
    return $_[0]->{doc}->{numpages} > 3;
};

$f{'very first page'} = sub { 
    return $_[0]->{number} == 0;
};

$f{'unusual dimensions'} = sub {
    my $page = $_[0];
    my $count = 0;
    while (($page = $page->{next})) {
        $count++ if $page->{width} == $_[0]->{width};
        return 0 if $count > 2;
    }
    return $count ? 0.5 : 1;
};

$f{'no normal font'} = sub {
    my $default_font = $_[0]->{doc}->{font};
    my @normal = grep { length($_->{text}) > 8 
                        and $_->{font} == $default_font } 
                      @{$_[0]->{chunks}};
    return @normal ? 0 : 1;
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
