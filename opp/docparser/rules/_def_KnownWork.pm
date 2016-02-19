package rules::KnownWork;
use strict;
use warnings;
use Exporter;
use DBI;
use File::Basename;
use Cwd 'abs_path';
use Biblio::Citation::Compare 'sameWork';
our @ISA = ('Exporter');
our @EXPORT_OK = qw(&known_work);

my $path = dirname(abs_path(__FILE__));

my $dbh;
sub dbh {
    return $dbh if $dbh;
    my %cfg = do "$path/../config.pl";
    $dbh = DBI->connect(
        'DBI:mysql:'.$cfg{'MYSQL_DB'}, 
        $cfg{'MYSQL_USER'},
        $cfg{'MYSQL_PASS'}, { RaiseError => 1 })
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
            date => undef
        };
        if (sameWork(\%args, $work)) {
            return $id;
        }
    }
    return 0;
}

1;
