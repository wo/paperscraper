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
    ['first names contain common first name', [0.4, -0.1]],
    ['first names contain common word', [-0.3, 0.1]],
    ['surnames contain common surname', [0.4, -0.1]],
    ['surnames contain common word', [-0.3, 0.1]],
    ['surnames contain word', [-0.1, 0.1]],
    ['is first name in line or follows comma or and', [0.1, -0.5]],
    ['separated from earlier names by non-names', [-0.3, 0]],
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

my $re_sep = qr/\band\b|&amp;|,|[^\p{isAlpha}\d\.\s\@-]/i;
$f{'is first name in line or follows comma or and'} = sub {
    return 1 unless @{$_[0]->{prev_names}};
    my $name = $_[0]->{text};
    return $_[0]->{line} =~ /$re_sep\s+$name/;
};
    
$f{'separated from earlier names by non-names'} = sub {
    return undef unless @{$_[0]->{prev_names}};
    my $prev = $_[0]->{prev_names}->[-1];
    my $name = $_[0]->{text};
    return $_[0]->{line} =~ /$prev.*\w{5,}.*$name/;
};

compile(\@name_features, \%f);

1;
