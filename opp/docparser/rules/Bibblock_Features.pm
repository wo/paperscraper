package rules::Bibblock_Features;
use strict;
use warnings;
use List::Util qw/min max reduce/;
use Statistics::Lite qw/mean/;
use Memoize;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%block_features @parsing_features/;

our %block_features;

$block_features{ENTRY} = [
    ['bibstart chunk has high score', [0.8, -0.9]],
    ['bib chunks have high BIBSTART score', [-1, 1]],
    ['indentation changes twice within entry', [-0.4, 0.05]],
    ['resembles surrounding entries', [0.2, -0.3]],
    ['contains year', [0.1, -0.3]],
    ];

our @parsing_features = (
    ['entries have high score', [1, -1]],
    );


my %f;

$f{'contains year'} = sub {
    return $_[0]->{text} =~ /(?<!\d)\d{4}(?!\d)|$re_year_words/i;
};

$f{'indentation changes twice within entry'} = sub {
    my @chunks = @{$_[0]->{chunks}};
    my $changes = 0;
    for my $i (1 .. $#chunks) {
        my $diff = abs($chunks[$i]->{left} - $chunks[$i-1]->{left});
        $changes++ if $diff > 8;
        return 1 if $changes > 1;
    }
    return 0;
};

sub resembles {
    my ($e1, $e2) = @_;
    my $ret = 1;
    if ($e1->{text} =~ /$re_cit_label/
        != $e2->{text} =~ /$re_cit_label/) {
        $ret *= 0.4;
    }
    if ($e1->{text} =~ /\.$/ != $e2->{text} =~ /\.$/) {
        $ret *= 0.6;
    }
    my $ch1 = $e1->{chunks}->[0];
    my $ch2 = $e2->{chunks}->[0];
    if (abs($ch1->{left} - $ch2->{left}) > 10) {
        $ret *= 0.4;
    }
    $ch1 = $e1->{chunks}->[1];
    $ch2 = $e2->{chunks}->[1];
    if ($ch1 && $ch2 && abs($ch1->{left} - $ch2->{left}) > 10) {
        $ret *= 0.4;
    }
    return $ret;
};

$f{'resembles surrounding entries'} = sub {
    my $res1 = $_[0]->{next} ? resembles($_[0], $_[0]->{next}) : 0;
    my $res2 = $_[0]->{prev} ? resembles($_[0], $_[0]->{prev}) : 0;
    if ($res1 && $res2) {
        return ($res1 + $res2)/2;
    }
    if ($res1 && !$res2) {
        return $res1;
    }
    if ($res2 && !$res1) {
        return $res2;
    }
    return 0.5;
};


$f{'bibstart chunk has high score'} = sub {
    my $chunk = $_[0]->{chunks}->[0];
    return $chunk->{p}->('BIBSTART');
};

$f{'bib chunks have high BIBSTART score'} = sub {
    # It wouldn't make much sense to test whether BIB chunks have high
    # BIB score, because the minimum BIB score is 0.51 anyway. The
    # chance that a BIB chunk has been wrongly classified as BIB is
    # rather revealed by p(BIBSTART).
    my @chunks = @{$_[0]->{chunks}};
    shift @chunks;
    return 0.5 unless @chunks;
    my @ps = map { $_->{p}->('BIBSTART') } @chunks;
    my $res = max(@ps);
    # The more BIB lines with high BIBSTART score, the worse:
    foreach my $p (@ps) {
        $res += ($p-0.5)/2;
    }
    return max(0, min(1, $res));
};

$f{'entries have high score'} = sub {
    my @entries = @{$_[0]->{blocks}};
    # This is trickier than for BIBSTART and BIB chunks in an
    # entry: if we simply consider the mean of the $label
    # probability in @entries, we reward merging tricky lines into a
    # single entry, which means that there's only entry with low
    # score as opposed to several. To prevent this, the score is
    # assigned to each line in the entry.
    my @ps;
    foreach my $entry (@entries) {
        my $p = $entry->{p}->('ENTRY');
        foreach (@{$entry->{chunks}}) {
            push @ps, $p;
        }
    }
    #print scalar @entries, " entries, ", scalar @ps, " ps\n";
    #print "min ", min(@ps), " mean ", mean(@ps), "\n";
    return 0.5 * min(@ps) + 0.5 * mean(@ps);
};

compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;

