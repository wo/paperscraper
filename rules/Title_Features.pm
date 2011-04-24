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
    ['probable TITLE', [0.8, -0.8]],
    ['adjacent chunks probable title', [-0.5, 0.2]],
    ];

$block_features{AUTHOR} = [
    ['probable AUTHOR', [1, -1]],
    ];

our @parsing_features = (
    ['has title', [0.2, -0.6]],
    ['author parts have high score', [1, -0.9]],
    ['title parts have high score', [1, -0.9]],
    ['good author block missed', [-0.5, 0.5]],
    ['first author near title', [0.1, -0.2]],
    );

my %f;

sub p {
    my $label = shift;
    return sub {
        if (exists $_[0]->{chunks}) {
            return mean(map { $_->{p}->($label) } @{$_[0]->{chunks}});
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

$f{'has title'} = sub {
    foreach (@{$_[0]->{blocks}}) {
        return 1 if $_->{label}->{TITLE};
    }
    return 0;
};

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

sub chunk2block {
    my ($chunk, $blocks) = @_;
    foreach my $bl (@$blocks) {
	return $bl if grep { $chunk == $_ } @{$bl->{chunks}};  
    }
}

$f{'good author block missed'} = sub {
    my $ch0 = $_[0]->{blocks}->[0]->{chunks}->[0];
    foreach my $ch (@{$ch0->{best}->{AUTHOR}}) {
        my $bl = chunk2block($ch, $_[0]->{blocks});
        unless ($bl->{label}->{AUTHOR}) {
            return max(0, ($ch->{p}->(AUTHOR)-0.2)*1.25);
        }
    }
};

$f{'first author near title'} = sub {
    my ($author, $title);
    foreach (@{$_[0]->{blocks}}) {
        $author = $_ if $_->{label}->{AUTHOR};
        $title = $_ if $_->{label}->{TITLE};
    }
    return 0.5 unless $author && $title;
    $author = $author->{chunks}->[0];
    return 0 if $author->{page} != $title->{chunks}->[0]->{page};
    my $dist = $author->{top} < $title->{chunks}->[0]->{top} ?
        $title->{chunks}->[0]->{top} - $author->{bottom} :
        $author->{top} - $title->{chunks}->[-1]->{bottom};
    return min(1, max(0, 1.1 - $dist/100));
};

compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;
