package util::Estimator;
use strict;
use warnings;
use List::Util qw/max min sum/;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&makeLabeler/;

=head1 NAME

util::Estimator - a simple, score-based, binary classifier

=head1 SYNOPSIS

my $is_heading = Estimator->new();

$is_heading->add_feature(
    'heading tag', # name of feature
    sub { $_[0] =~ /<h.>/ ? 1 : 0 }, # the attribute to test
    [0.5, -0.2],   # scores if attribute present/absent
    );

# Possibly add more features, then estimate probability:

print $is_heading->test("<h1>test</h1>");

# Advanced usage:

my %features;
sub htag { $_[0] =~ /<h.>/ ? 1 : 0 };
$features{HEADING} = [
      ['heading tag', \&htag, [0.5, -0.2]],
      # ...
    ];
$features{PARAGRAPH} = [
      ['heading tag', \&htag, [-0.6, 0.1]],
      # ...
    ];
my $label = makeLabeler($features);
my $p = $label->('<h1>head</h1>');
print $p->('HEADING');

=head1 DESCRIPTION

An old hack: to figure out whether, say, a line of text is a paper
title I consider various features, to which I assign scores. For
example, titles are generally in bold, so if a line is in bold, its
title score is increased, otherwise it is decreased. This class
converts the total score to a "probability", i.e. a value in
[0,1]. This is done in a way that does not assume independence of the
individual features, but it works best if the features are at least
compossible.

The score values should lie between -1 and 1, with 0 meaning neutral,
1 meaning that the feature entails the relevant label, and -1 that it
entails the absence of the label.

=cut

sub new {
    my $class = shift;
    my $self  = {
	features => {},
    };
    bless $self, $class;
    return $self;
}

my $verbose = 0;
sub verbose {
    my $self = shift;
    $verbose = shift if @_;
    return $verbose;
}

sub add_feature {
    my $self = shift;
    my ($name, $func, $scores) = @_;
    $self->{features}->{$name} = [$func, $scores->[0], $scores->[1]];
}

sub test {
    # This is a bit of a hack. The basic idea is that if two features
    # both support a hypothesis, then they are more likely to not be
    # independent than if only one of them supports the hypothesis. So
    # I consider "positive" and "negative" features separately. In
    # each case, I start with 0.5 and then move, for each feature,
    # $score * the remaining distance towards 1 (or 0). Afterwards, I
    # mix the probabilities from the positive and negative features,
    # assigning higher weights to the probability with more extreme
    # components.

    my ($self, $ob) = @_;
    if ($verbose) {
	my $obtxt = UNIVERSAL::isa($ob, "HASH") && exists $ob->{text}?
	    substr($ob->{text}, 0, 100) : $ob;
	print "testing '$obtxt'\n";
    }

    my ($pos, $neg) = (0.5, 0.5);
    my ($pos_w, $neg_w) = (.01, .01); # don't divide by 0

    while (my ($fname, $fvals) = each %{$self->{features}}) {
	my ($attrib, $w1, $w0) = @$fvals;
        print "$fname? " if $verbose;
        my $is = $attrib->($ob);
        unless (defined $is) {
            print " undefined\n" if $verbose;
            next;
        }
        $is = 0 if $is eq '';
	my $score = $is * $w1 + (1-$is) * $w0;
	if ($score >= 0) {
	    $pos += (1-$pos) * $score;
	    $pos_w += exp((0.5+$score) * 5);
	}
	else {
	    $neg += $neg * $score;
	    $neg_w += exp((0.5-$score) * 5);
	}
	print "$is => $score\n" if $verbose;
    }

    my $p = ($pos * $pos_w + $neg * $neg_w) / ($pos_w + $neg_w);
    print "  $pos*$pos_w + $neg*$neg_w => $p\n" if $verbose;
    return $p;
}

sub makeLabeler {
    my ($features, $stage) = @_;

    my %estimators;
    my $estim = sub {
	my $label = shift;
	my $e = __PACKAGE__->new();
	foreach my $f (@{$features->{$label}}) {
	    if (!$f->[3] || ($f->[3] > 0 && $f->[3] <= $stage)
                || ($f->[3] < 0 && $f->[3] >= $stage*-1)) {
		$e->add_feature(@$f);
	    }
	}
	return $e;
    };
    return sub {
	my $object = shift;
	my %p;
	return sub {
	    my $label = shift;
	    if (!defined $p{$label}) {
		print "estimating $label\n" if $verbose;
		if (!defined $estimators{$label}) {
		    $estimators{$label} = $estim->($label);
		}
		$p{$label} = $estimators{$label}->test($object);
	    }
	    return $p{$label};
	}
    }
}

1;
