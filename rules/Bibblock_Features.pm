package rules::Bibblock_Features;
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
    ['bibstart chunks have high score', [1, -1]],
    ['bib chunks have high score', [1, -1]],
    #['chunks are consecutive', [0.1, -1]],
    #['chunks have same font size', [0.3, -0.3]],
    #['chunks have same alignment', [0.3, -0.6]],
    ];

our @parsing_features = (
    ['entries have high mean score', [1, -1]],
#    ['author parts resemble each other', [0.2, -0.4]],
    );


my %f;

sub min_prob {
    my $label = shift;
    return sub {
        return min(map { $_->{p}->($label) } @{$_[0]->{chunks}});
    };
}

$f{'(min) probability BIB'} = min_prob('BIB');

$f{'(min) probability BIBSTART'} = min_prob('BIBSTART');

sub p {
    my $label = shift;
    return sub {
        if (exists $_[0]->{chunks}) {
            return min(map { $_->{p}->($label) } @{$_[0]->{chunks}});
        }
        return $_[0]->{p}->($label);
    };
}

foreach (qw/BIB BIBSTART ENTRY/) {
    $f{"probable $_"} = p($_);
}

sub ok_chunks {
    my $label = shift;
    return sub {
        my @chunks = grep { $_->{label}->{$label} }
                    @{$_[0]->{chunks}};
        return 0.5 unless @chunks;
        return min(map { $_->{p}->($label) } @chunks);
    };
}

$f{'bibstart chunks have high score'} = ok_chunks('BIBSTART');

$f{'bib chunks have high score'} = ok_chunks('BIB');

sub ok_parts {
    my $label = shift;
    return sub {
        my @parts = grep { $_->{label}->{$label} }
                    @{$_[0]->{blocks}};
        return 0.5 unless @parts;
        return mean(map { $_->{p}->($label) } @parts);
    };
}

$f{'entries have high mean score'} = ok_parts('ENTRY');


compile(\%block_features, \%f);
compile(\@parsing_features, \%f);

1;

