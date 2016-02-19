package rules::Doctype_Features;
use warnings;
use rules::Helper;
use rules::Keywords;
use lib '../';
use List::Util qw/min max reduce/;
use FindBin qw($Bin);
use Cwd 'abs_path';
use File::Basename;
use util::Io;
use util::String;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/%features/;

our %features;

$features{REVIEW} = [
    ['short', [0.1, -0.4]],
    ['beginning contains "review"', [0.3, -0.2]],
    ['url contains review keywords', [0.3, -0.05]],
    ['beginning contains "Press"', [0.2, -0.1]],
    ['beginning contains "hardcover"', [0.3, 0]],
    ['beginning contains price', [0.2, -0.1]],
    ['beginning contains ISIN', [0.2, 0]],
    ['beginning contains page number info', [0.3, -0.1]],
    ['no large font', [0.2, 0]],
    ['contains bibliography section', [-0.1, 0.1]],
    ];

     
my %f;

$f{'short'} = sub {
    return min(1, max(0, (15-$_[0]->{numpages})/10));
};

sub in_beginning {
    my $re = shift;
    return sub {
        return undef unless defined($_[0]->{text}) && $_[0]->{text};
        my $start = $_[0]->{text};
        $start = substr($start, 0, min(5000,length($start)));
        return $start =~ /$re/i;
    };
}

$f{'beginning contains "review"'} = in_beginning('\breview');

$f{'beginning contains "Press"'} = in_beginning(' Press\b');

$f{'beginning contains "hardcover"'} = in_beginning('\bhardcover');

$f{'beginning contains ISIN'} = in_beginning('[\d\s]{12}');

$f{'beginning contains page number info'} = in_beginning('\b\d{3,4}(?: ?pp| pages)');

$f{'beginning contains price'} = in_beginning('\b\d{2,4}\.\d\d');

$f{'no large font'} = sub {
    return ($_[0]->{largest_font} < 5);
}; 

$f{'url contains review keywords'} = sub {
    return $_[0]->{url} =~ /\breview|ndpr\.nd\.edu/i;
};
    
$f{'contains bibliography section'} = sub {
    return undef unless defined($_[0]->{text}) && $_[0]->{text};
    return $_[0]->{text} =~ /\n$re_bib_heading\n/ ? 1 : 0;
};

compile(\%features, \%f);

1;
