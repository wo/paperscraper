package util::Estimator;
use strict;
use warnings;
use List::Util qw/max min sum/;

=head1 NAME

util::Estimator - a simple, score-based, binary classifier

=head1 SYNOPSIS

my $is_heading = Estimator->new();

$is_heading->add_feature(
    sub { $_[0] =~ /<h.>/ ? 1 : 0 }, # the attribute to test
    0.3,                             # score if attribute present
    -0.1,                            # score if attribute absent
    'h* tag'                         # (optional) name of feature
    );

print $is_heading->p("<h1>test</h1>"); # prints estim. probability

=head1 DESCRIPTION

An old hack: to figure out whether, say, a line of text is a paper
title I consider various features, to which I assign scores. For
example, titles are generally in bold, so if a line is in bold, its
title score is increased by 0.2, otherwise it is decreased by
0.3. This class converts the total score to a "probability", i.e. a
value in [0,1]. This is done in a way that does not assume
independence of the individual features, but it works best if the
features are at least compossible.

The absolute score values are unimportant, but I tend to follow this
rule: if I were completely undecided (P=0.5) whether something is a
title, and then learnt that it is (or is not) bold, how much would my
credence increase?

=cut

sub new {
    my $class = shift;
    my $self  = {
	features => {},
	verbose => 0,
	_min => 0,
	_max => 0,
    };
    bless $self, $class;
    return $self;
}

sub verbose {
    my $self = shift;
    $self->{verbose} = shift if @_;
    return $self->{verbose};
}

sub add_feature {
    my $self = shift;
    my ($func, $w1, $w0, $name) = @_;
    $name ||= str($func);
    $self->{features}->{$name} = [$func, $w1, $w0];
    $self->update_extremes();
}

sub update_extremes {
    my $self = shift;
    # min and max possible score:
    my @fvals = values %{$self->{features}};
    $self->{_min} = sum (map { min($_->[1], $_->[2]) } @fvals);
    $self->{_max} = sum (map { max($_->[1], $_->[2]) } @fvals);
}

sub scale {
    # scale a score to [0,1]:
    my $self = shift;
    my $score = shift;
    my $frac = $score / ($score > 0 ? $self->{_max} : $self->{_min});
    my $frac_log = log (1 + $frac * 1.6); # 1.6 = e, minus a bit
    return 0.5 + $frac_log/2 * ($score > 0 ? 1 : -1);
}

sub p {
    my $self = shift;
    my $ob = shift;
    my $score = 0;

    # calculate sum of feature scores:
    while (my ($fname, $fvals) = each %{$self->{features}}) {
	my ($attrib, $w1, $w0) = @$fvals;
	my $is = $attrib->($ob);
	print "$ob is $fname: $is\n" if $self->{verbose};
	$score += $is * $w1 + (1-$is) * $w0;
    };

    return $self->scale($score);
}

1;
