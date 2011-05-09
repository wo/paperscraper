package rules::Helper;
use strict;
use warnings;
use Exporter;
use List::Util qw/max min/;
use Cwd 'abs_path';
use File::Basename;
use lib '..';
use util::Io;
use util::Functools qw/someof allof/;
use util::String;
use rules::Keywords;
our @ISA = ('Exporter');
our @EXPORT = qw(&in_dict &extract_names &compile $or $and $not);

my $path = dirname(abs_path(__FILE__));

sub compile {
    my ($features, $f) = @_;
    if (ref($features) eq 'HASH') {
        while (my ($key, $val) = each(%$features)) {
            compile($features->{$key}, $f);
        }
        return;
    }
    foreach my $i (0 .. $#$features) {
        my ($id, $weights, $stage) = @{$features->[$i]};
        my $func;
        if (ref($id)) {
            ($func, $id) = compose($f, @$id);
        }
        else {
            $func = $f->{$id};
            die "attribute '$id' not defined" unless $func;
        }
        $features->[$i] = [$id, $func, $weights, $stage];
    }
}

sub compose {
    my ($f, $op, @args) = @_;
    my (@funcs, @ids);
    foreach my $id (@args) {
        if (ref($id)) {
            my ($f, $i) = compose($f, @$id);
            push @funcs, $f;
            push @ids, $i;
        }
        else {
            push @funcs, $f->{$id};
            push @ids, $id;
        }
    }
    if ($op eq 'OR') {
        return (someof(@funcs), '('.join(' OR ', @ids).')');
    }
    if ($op eq 'AND') {
        return (allof(@funcs), '('.join(' AND ', @ids).')');
    }
    if ($op eq 'NOT') {
#       return (not(@funcs), 'NOT '.join @ids);
    }
}

our $or = sub {
    return ['OR', @_];
};

our $and = sub {
    return ['AND', @_];
};

our $not = sub {
    return ['NOT', @_];
};

my %dicts;
sub in_dict {
    my ($str, $dict) = @_;
    $str = lc($str);
    unless ($dicts{$dict}) {
        my $map = {};
        open INPUT, '<:encoding(utf8)', "$path/$dict.txt" or die $!;
        while (<INPUT>) {
            unless (/^#/) {
                chomp($_);
                $map->{$_} = 1;
            }
        }
        close INPUT;
        $dicts{$dict} = $map;
    }
    #print " $str @ $dict ? ", exists($dicts{$dict}->{$str}), "\n";
    return $dicts{$dict}->{$str} ? 1 : 0;
}

sub extract_names {
    my $str = shift;
    my %res; # name => probability
    my @parts = split($re_name_separator, $str);
    foreach my $part (@parts) {
        if ($part !~
            /^(?:$re_name_before)?($re_name)(?:$re_name_after)?$/
            || $1 =~ /$re_noname/) {
            next;
        }
        my $p = 0.5;
        my ($name, $first, $last) = ($1, $2, $3);
        foreach my $w (split /\s+/, $first) {
            if ($w =~ /^\p{IsUpper}\.?$/) {
                $p += 0.1;
            }
            elsif (in_dict($w, 'firstnames')) {
                $p += 0.2;
            }
            elsif (in_dict($w, 'commonwords')) {
                $p -= 0.2
            }
        }
        foreach my $w (split /\s+/, $last) {
            if (in_dict($w, 'surnames')) {
                $p += 0.3;
            }
            elsif (in_dict($w, 'commonwords')) {
                $p -= 0.2
            }
            elsif (is_word($w)) {
                $p -= 0.1;
            }
        }
        next if $p < 0.4;
        if ($p < 0.8) {
            my $freebase_query = 
                'https://api.freebase.com/api/service/mqlread?'
                .'query={"query":[{"*":null,"limit":1,"name":"'
                .$name.'","type":"/people/person"}]}'; 
            my $http_res = fetch_url($freebase_query);
            if ($http_res->{content}) {
                if ($http_res->{content} =~ /"id":/) {
                    $p += 0.3;
                }
                else {
                    $p -= 0.1;
                }
            }
        }
        $res{$name} = min($p, 1);
    }
    return \%res;
}

sub in_google {
    my $self = shift;
    my $str = shift;
    $str =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg; # urlencode
    print "looking up '$str' on google.\n" if $self->verbosity > 2;
    my $url = "http://www.google.com/search?q=\"$str\"";
    util::Io::verbosity($self->verbosity > 3 ? 1 : 0);
    my $http_res = fetch_url($url);
    if (!$http_res->is_success) {
        $self->confidence(-0.5, "google lookup error ".$http_res->status_line);
        return 1;
    }
    if ($http_res->{content} =~ /did not match any|No results found for/) {
        print "nothing found.\n" if $self->verbosity > 2;
        return 0;
    }
    print "found.\n" if $self->verbosity > 2;
    return 1;
}


1;
