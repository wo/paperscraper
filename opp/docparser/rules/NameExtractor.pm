package rules::NameExtractor;
use strict;
use warnings;
use Exporter;
use utf8;
use List::Util qw/max min/;
use Cwd 'abs_path';
use File::Basename;
use lib '..';
use util::String;
use util::Estimator;
use rules::Keywords;
use rules::Name_Features;
use rules::Helper;
our @ISA = ('Exporter');
our @EXPORT = qw/&parse/;

my $estim = util::Estimator->new();
foreach (@rules::Name_Features::name_features) {
    $estim->add_feature(@$_);
}

my $verbose = 0;
sub verbosity {
   $verbose = shift if @_;
   $estim->verbose($verbose);
}

sub parse {
    my $chunk = shift;
    my $str = $chunk->{plaintext};
    # remove footnote stars *, crosses, etc.: 
    $str =~ s/[\*\x{2217}†‡§]/ /g;
    my %res; # name => probability
    print "--parsing name(s) $str\n" if $verbose;
    my @parts = split($re_name_separator, $str);
    my $skipped = 0;
    while (my ($i, $part) = each @parts) {
        if ($part !~
            /^(?:$re_name_before)?($re_name)(?:$re_name_after)?$/
            || $1 =~ /$re_noname/) {
            print "---skipping $part\n" if $verbose;
            $skipped++;
            next;
        }
        print "parsing |$2|$3|\n" if $verbose;
        my %name = ('text' => $1,
                    'first' => $2,
                    'last' => $3,
                    'prev_names' => [keys(%res)],
                    'chunk' => $chunk);
        my $p = $estim->test(\%name);
        if ($skipped) {
            print "---follows non-name: decreasing probability\n" if $verbose;
            $p *= 0.8;
        }
        if ($p > 0.5) {
            my $fullname = tidy_name($name{text});
            $res{$fullname} = $p;
        }
    }
    return \%res;
}

sub tidy_name {
    my $name = shift;
    # decapitalize 'Thomas SCANLON', but not 'CSI Jenkins' or 'Samuel Wheeler III':
    while ($name =~ /\b([[:upper:]]{2,})\b/g) {
        my $w = $1;
        if (length($w) > 3 || in_dict($w, 'firstnames') || in_dict($w, 'surnames')) {
            $name =~ s/($w)/\u\L$1/g;
        }
    }
    return $name;
}

1;
