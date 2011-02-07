package util::Functools;
use strict;
use warnings;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw/&reduce/;

sub reduce {
    # This does exactly the same thing as List::Util::reduce, except
    # it doesn't reassign $a and $b, and doesn't throw obscure
    # semi-panic warnings.
    my $code = shift;
    my $val = shift;
    foreach (@_) {
	$val = $code->($val, $_);
    }
    return $val;
}
