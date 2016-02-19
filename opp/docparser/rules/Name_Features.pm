package rules::Name_Features;
use warnings;
use List::Util qw/min max/;
use rules::Helper;
use rules::Keywords;
use lib '../';
use util::String;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = '@name_features';

our @name_features = (
    ['known author name', [0.8, -0.1]],
    ['known non-name', [-1, 0]],
    ['university location', [-0.8, 0.05]],
    ['name occurs in lower case in article', [-0.4, 0.1]],
    ['first names contain initial', [0.2, 0]],
    ['first names contain common first name', [0.4, -0.1]],
    ['first names contain common word', [-0.3, 0.1]],
    ['surnames contain common surname', [0.4, -0.1]],
    ['surnames contain common word', [-0.3, 0.1]],
    ['surnames contain word', [-0.1, 0.1]],
    ['is first name in line or follows comma or and', [0.1, -0.5]],
    ['follows publication word', [-0.3, 0]],
    ['separated from earlier names by non-names', [-0.3, 0]],
    );

my %f;

$f{'known author name'} = sub {
    return known_authorname($_[0]->{text});
};

$f{'known non-name'} = sub {
    return known_notname($_[0]->{text});
};

$f{'university location'} = sub {
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

$f{'name occurs in lower case in article'} = sub {
    # first test whole name:
    my $str = lc($_[0]->{text});
    # testing '\w $str': in the middle of a sentence
    return undef unless exists($_[0]->{chunk}->{doc});
    return 1 if ($_[0]->{chunk}->{doc}->{text} =~ /\w \Q$str\b/);
    # now test parts of name, but note that e.g. an article by
    # Christian List might well contain 'list':
    my $parts_matched = 0;
    while ($_[0]->{text} =~ /([[:upper:]]\w+)/g) { # upper-case parts
        $str = lc($1);
        if ($_[0]->{chunk}->{doc}->{text} =~ /\b\Q$str(?!@)\b/) {
            $parts_matched++;
        }
    }
    return min(1, $parts_matched/2);
};

my $re_sep = qr/\band\b|&amp;|,|[^\p{isAlpha}\d\.\s\@-]/i;
$f{'is first name in line or follows comma or and'} = sub {
    return 1 unless @{$_[0]->{prev_names}};
    my $name = $_[0]->{text};
    return $_[0]->{chunk}->{plaintext} =~ /$re_sep\s+\Q$name/;
};

$f{'follows publication word'} = sub {
    my $name = $_[0]->{text};
    return $_[0]->{chunk}->{plaintext} =~ /$re_publication_word.*\Q$name/;
};

$f{'separated from earlier names by non-names'} = sub {
    return undef unless @{$_[0]->{prev_names}};
    my $name = $_[0]->{text};
    # {prev_names} is unsorted, so test all:
    for my $prev (@{$_[0]->{prev_names}}) {
        return 0 unless $_[0]->{chunk}->{plaintext} =~ /$prev.*\w{5,}.*\Q$name/;
    }
    return 1;
};

compile(\@name_features, \%f);

1;
