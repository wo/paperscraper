package rules::Helper;
use strict;
use warnings;
use Exporter;
use List::Util qw/max min/;
use Cwd 'abs_path';
use File::Basename;
use DBI;
use Config::JSON;
use lib '..';
use util::Io;
use util::Functools qw/someof allof/;
use util::String;
use rules::Keywords;
our @ISA = ('Exporter');
our @EXPORT = qw(&in_dict &extract_names &compile &known_work &known_authorname &known_notname $or $and $not);

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
                $map->{lc($_)} = 1;
            }
        }
        close INPUT;
        $dicts{$dict} = $map;
    }
    #print " $str @ $dict ? ", exists($dicts{$dict}->{$str}), "\n";
    return $dicts{$dict}->{$str} ? 1 : 0;
}

my $dbh;
sub dbh {
    return $dbh if $dbh;
    my $cfg = Config::JSON->new("$path/../../../config.json");
    $dbh = DBI->connect(
        'DBI:mysql:database='.$cfg->get('mysql/db').';host='.$cfg->get('mysql/host'),
        $cfg->get('mysql/user'),
        $cfg->get('mysql/pass'),
        { RaiseError => 1 })
        or die "Couldn't connect to database: " . DBI->errstr;
    $dbh->{'mysql_auto_reconnect'} = 1;
    return $dbh;
}

sub known_work {
    my %args = @_;
    my $author_str = $args{authors}->[0];
    my $title_str = $args{title};
    # only test surname of first author:
    $author_str =~ s/(.+),.*/$1/;
    # test two consecutive words from title: 
    $title_str =~ s/.*(\pL{3,}\s+\pL{3,}).*/$1/;

    my $db = dbh();
    my $query = "SELECT document_id, authors, title FROM documents"
        ." WHERE authors LIKE ".$db->quote("%$author_str%")
        ." AND title LIKE ".$db->quote("%$title_str%")
        ." LIMIT 20";
    my $sth = $db->prepare($query);
    $sth->execute();
    while (my ($id, $authors, $title) = $sth->fetchrow_array()) {
        my $work = {
            authors => [ split(/, /, $authors) ], 
            title => $title,
            date => ''
        };
        if (sameWork(\%args, $work)) {
            return $id;
        }
    }
    return 0;
}

sub known_authorname {
    my $str = shift;
    my $db = dbh();
    # (mysql where comparison is case-insensitive)
    my $query = "SELECT 1 FROM author_names"
        ." WHERE name = ".$db->quote($str)
        ." AND is_name = 1 LIMIT 1";
    my $sth = $db->prepare($query);
    $sth->execute();
    my ($yep) = $sth->fetchrow_array();
    return $yep ? 1 : 0 
}

sub known_notname {
    my $str = shift;
    my $db = dbh();
    my $query = "SELECT 1 FROM author_names"
        ." WHERE name = ".$db->quote($str)
        ." AND is_name = 0 LIMIT 1";
    my $sth = $db->prepare($query);
    $sth->execute();
    my ($yep) = $sth->fetchrow_array();
    return $yep ? 1 : 0 
}


1;
