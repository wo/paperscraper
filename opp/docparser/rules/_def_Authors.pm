package rules::Authors;
use warnings;
use Text::Names;
use Biblio::Citation::Compare;
use File::Basename;
use Cwd 'abs_path';
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw/extract_names/;

use rules::Keywords;

sub extract_names {
    my $str = shift;
    my @names = Text::Names::parseNames($str);
    return \@names;

    # split string by author separators:
    for my $part (split $re_authors_separator, $str) {
	# strip footnotes and brackets after author:
	$part = tidy($part);
	if ($part !~ /^($re_name_before?)$re_name($re_name_after?)$/) {
	    next;
	}
	my ($pre, $surname, $post) = ($1, $2, $3);
	if ($pre) {
	    $part =~ s/^$re_pre_name//;
	}
	if ($post) {
	    $part =~ s/$re_post_name$//;
	}
	my $lookupname = substr($part,0,1)." $surname";
	if ($self->is_known_author($lookupname)) {
	    print "$lookupname known author|" if $self->verbosity > 2;
	    push @{$bl->{known_authors}}, $part;
	}
	else {
	    print "$part unknown author candidate ($pre)($surname)($post)|" if $self->verbosity > 2;
	    push @{$bl->{unknown_authors}}, $part;
	}
    }
}



1;
