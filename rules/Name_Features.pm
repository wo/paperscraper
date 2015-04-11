package rules::Name_Features;
use warnings;
use rules::Helper;
use rules::Keywords;
use lib '../';
use util::String;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = '@name_features';

our @name_features = (
    ['contains university location', [-0.8, 0.05]],
    ['first names contain initial', [0.2, 0]],
    ['first names contain common first name', [0.5, -0.1]],
    ['first names contain common word', [-0.3, 0.1]],
    ['surnames contain common surname', [0.5, -0.1]],
    ['surnames contain common word', [-0.3, 0.1]],
    ['surnames contain word', [-0.1, 0.1]],
    );

my %f;

$f{'contains university location'} = sub {
    return in_dict($_[0]->{text}, 'locations');
};

$f{'first names contain initial'} = sub {
    my $first = $_[0]->{first};
    return ($first =~ /\b\p{IsUpper}\.?\b/) ? 1 : 0;
};

$f{'first names contain common first name'} = sub {
    my $first = $_[0]->{first};
    foreach my $w (split /\s+/, $first) {
        if (in_dict($w, 'firstnames')) {
            return 1;
        }
    }
    return 0;
};

$f{'first names contain common word'} = sub {
    my $first = $_[0]->{first};
    foreach my $w (split /\s+/, $first) {
        if (in_dict($w, 'commonwords')) {
            return 1;
        }
    }
    return 0;
};

$f{'surnames contain common surname'} = sub {
    my $last = $_[0]->{last};
    foreach my $w (split /\s+/, $last) {
        if (in_dict($w, 'surnames')) {
            return 1;
        }
    }
    return 0;
};

$f{'surnames contain common word'} = sub {
    my $last = $_[0]->{last};
    foreach my $w (split /\s+/, $last) {
        if (in_dict($w, 'commonwords')) {
            return 1;
        }
    }
    return 0;
};

$f{'surnames contain word'} = sub {
    my $last = $_[0]->{last};
    foreach my $w (split /\s+/, $last) {
        if (is_word($w)) {
            return 1;
        }
    }
    return 0;
};

compile(\@name_features, \%f);

1;
