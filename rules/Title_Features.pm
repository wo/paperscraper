package rules::Title_Features;
use warnings;
use List::Util qw/min max reduce/;
use Statistics::Lite qw/mean/;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%block_features @parsing_features/;

our %block_features;

$block_features{TITLE} = [
    ['probable TITLE', [1, -1]],
    #['chunks are consecutive', [0.1, -1]],
    #['chunks have same font size', [0.3, -0.3]],
    #['chunks have same alignment', [0.3, -0.6]],
    ['adjacent chunks probable title', [-0.3, 0.1]],
    ];

$block_features{AUTHOR} = [
    ['probable AUTHOR', [1, -1]],
    ];

our @parsing_features = (
    ['author parts have high score', [1, -1]],
    ['title parts have high score', [1, -1]],
#    ['author parts resemble each other', [0.2, -0.4]],
    );

my %f;

sub ok_parts {
    my $label = shift;
    return sub {
        my @parts = grep { $_->{label}->{$label} }
                    @{$_[0]->{blocks}};
        return 0.5 unless @parts;
        my @probs = map { $_->{p}->($label) } @parts;
        my $p = (min(@probs) + mean(@probs))/2;
        # emphasise differences between 0.5 and 0.1:
        return max(0, 0.35 + ($p-0.5)*1.3);
    };
}

$f{'author parts have high score'} = ok_parts('AUTHOR');

$f{'title parts have high score'} = ok_parts('TITLE');

sub p {
    my $label = shift;
    return sub {
        if (exists $_[0]->{chunks}) {
            return min(map { $_->{p}->($label) } @{$_[0]->{chunks}});
        }
        return $_[0]->{p}->($label);
    };
}

foreach (qw/TITLE AUTHOR/) {
    $f{"probable $_"} = p($_);
}

$f{'adjacent chunks probable title'} = sub {
    my $ch = $_[0]->{chunks}->[0]->{prev};
    my $p = $ch ? $ch->{p}->('TITLE') : 0;
    $ch = $_[0]->{chunks}->[-1]->{next};
    $p = max($p, $ch ? $ch->{p}->('TITLE') : 0);
    return $p;
};


compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;
