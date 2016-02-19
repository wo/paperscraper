package rules::Abstract_Features;
use warnings;
use List::Util qw/min max reduce/;
use Statistics::Lite qw/mean/;
use rules::Helper;
use rules::Keywords;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/@block_features/;

our @block_features = (
    ['chunks have high score', [0.8, -0.5]],
    ['reasonably long', [0.2, -0.2]],
    ['begins and ends neatly', [0.1, -0.3]],
    ['first chunk probable ABSTRACTSTART', [0.2, -0.4]],
    ['last chunk probable ABSTRACTEND', [0.2, -0.4]],
    ['contains legalese, publication or acknowledgment words', [-0.4, 0]],
    ['earlier possible abstracts', [-0.3, 0.3]],
    );

my %f;

$f{'chunks have high score'} = sub {
    my @probs = map { $_->{p}->('ABSTRACT') } @{$_[0]};
    my $p = mean(@probs);
    # emphasise differences between 0.5 and 0.1:
    return max(0, 0.4 + ($p-0.5)*1.2);
};

$f{'first chunk probable ABSTRACTSTART'} = sub {
    my $p = $_[0]->[0]->{p}->('ABSTRACTSTART');
    return max(0, 0.35 + ($p-0.5)*1.3);
};

$f{'last chunk probable ABSTRACTEND'} = sub {
    my $p = $_[0]->[-1]->{p}->('ABSTRACTEND');
    return max(0, 0.35 + ($p-0.5)*1.3);
};

# inactive because of OCR trouble and abstracts w/ quotes
$f{'chunks are similar'} = sub {
    my $first = $_[0]->[0];
    foreach my $ch (@{$_[0]}) {
        return 0 if ($ch->{fsize} != $first->{fsize});
    }
    return 1;
};

$f{'reasonably long'} = sub {
    my $str = reduce { $a .' '. $b->{text} } '', @{$_[0]};
    if (length($str) > 1200) {
        return max(0, 1 - (length($str)-1200)/1200);
    }
    if (length($str) < 250) {
        return max(0, 1 - (250-length($str))/100);
    }
    return 1;
};

$f{'earlier possible abstracts'} = sub {
    my $ch = $_[0]->[0];
    my $n = 1;
    while (($ch = $ch->{prev})) {
        $n++ if $ch->{p}->('ABSTRACT') > 0.5;
        last if $n >= 20;
    }
    return $n/20;
};

$f{'begins and ends neatly'} = sub {
    return 0 unless $_[0]->[0]->{plaintext} =~ /^\p{IsUpper}/;
    return 0 unless $_[0]->[-1]->{plaintext} =~ /[\.\?!]\d?$/;
};

$f{'contains legalese, publication or acknowledgment words'} = sub {
    my $count = 0;
    my $badwords = qr/$re_legalese|$re_publication_word|
                     $re_publisher|$re_thanks/x;
    foreach my $chunk (@{$_[0]}) {
        while ($chunk->{plaintext} =~ /($badwords)/g) {
            #print "xxx $1\n";
            $count++;
        }
        return 1 if $count > 3;
    }
    return $count / 4;
};

compile(\@block_features, \%f);

1;
