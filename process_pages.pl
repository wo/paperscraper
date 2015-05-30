#! /usr/bin/perl -w
use strict;
use warnings;
use Carp;
use DBI;
use URI::URL;
use HTML::LinkExtractor;
use Data::Dumper;
use Time::Piece;
use POSIX qw(_exit);
use Getopt::Std;
use Encode qw(decode encode decode_utf8);
use FindBin qw($Bin);
use Cwd 'abs_path';
use File::Basename 'dirname';
use util::Io;
use util::String;
use util::Errors;
use rules::Keywords;
binmode STDOUT, ":utf8";
$| = 1; # auto flush stdout

my %cfg = do 'config.pl';
my $path = dirname(abs_path(__FILE__));

my %opts;
getopts("v:p:sh", \%opts);
if ($opts{h}) {
    print <<EOF;

Fetches source pages and stores new links found there in the
database.

Usage: $0 [-sh] [-p url or id] [-v verbosity]

-v        : verbosity level (0-10), default: 1
-p        : url that will be processed (result not written to DB) or id
-n        : do not write result to DB  
-h        : this message

EOF
    exit;
}

our $verbosity = exists($opts{v}) ? $opts{v} : 1;
util::Io::verbosity($verbosity ? $verbosity-1 : 0);

my $lockfile = "$path/.process_pages";
if (-e "$lockfile") {
    if (-M "$lockfile" < 0.005) {
        # modified in the last ~10 mins
        print "process already running (remove $lockfile?)\n"
            if $verbosity;
        exit 1;
    }
    print "killing previous run!\n";
    system("rm -f '$lockfile'");
    # we are killing ourserlves here!
    system("ps -ef | grep 'process_pages' | grep -v grep"
           ." | awk '{print \$2}' | xargs kill -9");
}

my $dbh = DBI->connect(
    'DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
    $cfg{'MYSQL_PASS'}, { RaiseError => 1 })
    or die "Couldn't connect to database: " . DBI->errstr;

$dbh->{'mysql_auto_reconnect'} = 1;
$dbh->{'mysql_enable_utf8'} = 1;
$dbh->do("SET NAMES 'utf8'");

my $pg_ping = $dbh->prepare(
    "UPDATE sources SET last_checked = NOW(), status = ? "
    ."WHERE source_id = ?")
    or die "Couldn't connect to database: " . DBI->errstr;

my $pg_update = $dbh->prepare(
    "UPDATE sources SET last_checked = NOW(), status = ?, content = ? "
    ."WHERE source_id = ?")
    or die "Couldn't connect to database: " . DBI->errstr;

my $db_insert_location = $dbh->prepare(
    "INSERT IGNORE INTO locations (url, status) VALUES (?,0)")
    or die "Couldn't connect to database: " . DBI->errstr;

my $db_insert_link = $dbh->prepare(
    "INSERT IGNORE INTO links (source_id, location_id, anchortext) "
    ."VALUES (?,?,?)")
    or die "Couldn't connect to database: " . DBI->errstr;

my @abort;
$SIG{INT} = sub {
    @abort = @_;
};

my @queue = @{next_pages()};
unless (@queue) {
    print "all pages recently checked\n" if $verbosity;
    leave(0);
}
while (my $loc = shift @queue) {
    leave(1) if (@abort);
    system("touch '$lockfile'");
    process($loc);
    leave(0) if $opts{p};
}
leave(0);

sub leave {
    my $status = $_[0];
    unlink($lockfile);
    if ($dbh) {
        $dbh->disconnect() or die("$DBI::errstr $DBI::err\n");
    }
    if (@abort) {
        if ($abort[0] eq 'INT') {
            $status = 9;
        }
        else {
            Carp::confess(@abort);
        }
    }
    POSIX::_exit($status);
}

sub next_pages {
    if ($opts{p}) {
        my ($url, $id);
        if ($opts{p} =~ /^\d+$/) {
            $id = $opts{p};
            ($url) = $dbh->selectrow_array("SELECT url FROM sources WHERE source_id = $id");
            die "no source with id $id" unless $url;
        }
        else {
            $url = $opts{p};
            ($id) = $dbh->selectrow_array("SELECT source_id FROM sources WHERE url = '$url'");
            unless ($id) {
                $opts{n} = 1;
                $id = 0;
            }
        }
        return [{ source_id => $id, url => $url, content => '', last_checked => 0 }];
    }
    my $NUM_URLS = 10;
    my $min_age = gmtime()-(12*60*60);
    my $query = "SELECT source_id, url, content, UNIX_TIMESTAMP(last_checked) "
        ."AS last_checked FROM sources "
        ."WHERE last_checked < '".($min_age->ymd)." ".($min_age->hms)."' "
        ."OR last_checked IS NULL ORDER BY last_checked "
        ."LIMIT $NUM_URLS";
    print "$query\n" if $verbosity > 1;
    my $pages = $dbh->selectall_arrayref($query, { Columns=>{} });
    return $pages;
}

sub process {
    my $page = shift;
    print "\nchecking page $page->{url}\n" if $verbosity;
    my $page_id = $page->{source_id};
    my $mtime = (defined $page->{last_checked}) ? $page->{last_checked} : 0;
    my $res = fetch_url($page->{url}, $mtime);
    if ($res && $res->code == 304) {
        print "not modified.\n" if $verbosity;
        $pg_ping->execute(1, $page_id) unless $opts{n};
        return;
    }
    if (!$res || !$res->is_success || !$res->{content}) {
        print "error:\n   ", ($res ? $res->status_line : ''), "\n" if $verbosity;
        $pg_ping->execute($res ? $res->code : 900, $page_id) unless $opts{n};
        return;
    }
    # also check for 404 errors without proper HTTP status:
    if ($res->{content} =~ /Error 404/) {
        print "page contains 404 error message\n" if $verbosity;
        $pg_ping->execute('404', $page_id) unless $opts{n};
        return;
    }
    print "\n $res->{content}\n" if $verbosity > 5;
    
    # fetch currently stored links from db:
    my $old_urls = $dbh->selectcol_arrayref(
        "SELECT url FROM links INNER JOIN locations "
        ."ON links.location_id = locations.location_id "
        ."WHERE source_id = $page_id");
    my @old_urls = @{$old_urls};
    print "old links: \n", join("\n",@old_urls), "\n" if $verbosity > 3;
    
    # extract links from page and add them to DB if new:
    my @links;
    my $base = ($res->{content} =~ /<base href=['"]?(\w.+?)['"]?>/) ? 
        $1 : $res->base();
    eval {
        my $link_ex = new HTML::LinkExtractor(undef, $base, 1);
        my $decoded_content = Encode::decode_utf8($res->{content});
        $link_ex->parse(\$decoded_content);
        @links = grep { $_->{href} } @{$link_ex->links};
        for my $link (@links) {
            $link->{href} = tidy_url($link->{href});
        }
    };
        
    my @urls = map $_->{href}, @links;

  LINKS:
    foreach my $new_link (@links) {
        my $url = $$new_link{href};
        my $text = $$new_link{_TEXT} || ''; # e.g., 'pdf' img link
        binmode STDOUT, ":utf8"; # why oh why?
        print "checking link: $url ($text)\n" if $verbosity > 2;
        next if ($url eq $page->{url});
        if ($url =~ /$re_ignore_url/) {
            print "link ignored.\n"  if $verbosity > 2;
            next;
        }
        if (grep /\Q$url\E/, @old_urls) {
            print "link already in DB.\n" if $verbosity > 2;
            next;
        }
        # check for session variants:
        if ($url =~ /$re_session_id/) {
            my $url2 = $url;
            $url2 =~ s/$re_session_id//;
            foreach my $old_url (@old_urls) {
                next unless ($old_url =~ /$re_session_id/);
                my $old_url_fragment = $old_url;
                $old_url_fragment =~ s/$re_session_id//;
                if ($url2 eq $old_url_fragment) {
                    print "session variant of $old_url\n" if $verbosity > 2;
                    next LINKS;
                }
            }
        }
        print "new link: $url ($text)\n" if $verbosity;
        next LINKS if $opts{n};
        my $loc_id;
        my $res = $db_insert_location->execute($url)
            or print DBI->errstr;
        if ($res eq '0E0') {
            # insert ignored due to duplicate url
            print "location already in database\n" if $verbosity;
            my $qu = "SELECT location_id FROM locations WHERE url = ?";
            $loc_id = $dbh->selectrow_array($qu, undef, $url);
        }
        else {
            $loc_id = $db_insert_location->{mysql_insertid};
        }
        $db_insert_link->execute($page_id, $loc_id, $text);
        push @old_urls, $url;
    }
    
    # remove disappeared links:
    foreach my $old_url (@old_urls) {
        remove_link($old_url, $page_id)
            unless (grep /\Q$old_url\E/, @urls);
    }

    my $pg_content = force_utf8(strip_tags($res->{content}));
    $pg_content =~ s/\s+/ /g;
    my $old_content = $page->{content} || '';
    if ($verbosity > 1 && $pg_content ne $old_content) {
        print "page content used to be:\n$old_content\n\n";
        print "new page content:\n$pg_content\n\n";
    }
    print "updating page $page_id records\n" if $verbosity;
    $pg_update->execute(1, $pg_content, $page_id);
}

#sub force_utf8 {
#    # brute force -- transliterate to ascii:
#    return unidecode($_[0]);
#}

sub remove_link {
    my $url = shift;
    my $page_id = shift;
    print "no more link to $url.\n" if $verbosity;
    my ($loc_id, $doc_id) = $dbh->selectrow_array(
        "SELECT location_id, document_id FROM locations "
        ."WHERE url = ".$dbh->quote($url));
    return 0 unless $loc_id;
    $dbh->do(
        "DELETE FROM links WHERE location_id = $loc_id "
        ."AND source_id = $page_id");
    my ($links_left) = $dbh->selectrow_array(
        "SELECT source_id FROM links WHERE location_id = $loc_id");
    return 1;
    # deleting orphaned locations currently disabled as it leads to
    # papers being rediscovered as new after outages.
    if (!$links_left || $links_left eq '0') {
        print "deleting orphaned location $loc_id.\n" if $verbosity;
        # Occasionally an orphaned location still leads to a valuable
        # paper. So ideally we might not delete the location or the
        # document here and instead do that in process_links, when the
        # location eventually goes dead. But then we'd have to check
        # in process_links for every spammy or dead location whether
        # it is orphaned so that it can be removed.
        $dbh->do("DELETE FROM locations WHERE location_id = $loc_id");
	if ($doc_id) {
	    my ($locs_left) = $dbh->selectrow_array(
		"SELECT location_id FROM locations "
                ."WHERE document_id = $doc_id");
	    if (!$locs_left || $locs_left eq '0') {
		print "deleting orphaned document $doc_id.\n"
                    if $verbosity;
		$dbh->do("DELETE FROM documents WHERE "
                         ."document_id = $doc_id");
	    }
	}
    }
    return 1;
}

sub tidy_url {
    my $url = shift;
    $url =~ s/%7e/~/i; # unescape tilde character
    $url =~ s/\s/%20/g; # fix whitespace
    return $url;
}
