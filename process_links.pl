#! /usr/bin/perl -w
use strict;
use warnings;
use Carp;
use utf8;
use Encode;
use FindBin qw($Bin);
use Cwd 'abs_path';
use File::Basename 'dirname';
use DBI;
use Digest::MD5;
use HTML::LinkExtractor;
use URI;
use Data::Dumper;
use Getopt::Std;
use util::Io;
use util::Errors;
use util::String;
use Doctidy 'doctidy';
use Spamfilter;
use Converter;
use Extractor;
binmode STDOUT, ":utf8";
chdir(dirname($0));

my %cfg = do 'config.pl';
my $path = dirname(abs_path(__FILE__));

my %opts;
getopts("v:p:nsrh", \%opts);
if ($opts{h}) {
    print <<EOF;

Fetches documents and tries to guess author, title, abstract, etc.,
and whether they are a suitable paper at all.

Usage: $0 [-hns] [-p url or location id] [-v verbosity]

-v        : verbosity level (0-10, default: 1)
-s        : process only one document, then exit
-p        : url or id that will be processed instead of next one
            from the database
-r        : force re-processing of previously processed documents
-n        : dry run, do not write result to DB
-h        : this message

EOF
    exit;
}

my $TEMPDIR = "$path/temp/";
my $CERT_SPAM = 0.8; # don't store documents with higher spam score

my $verbosity = exists($opts{v}) ? $opts{v} : 1;
util::Errors::verbosity($verbosity);
util::Io::verbosity($verbosity > 1 ? $verbosity-1 : 0);

my $lockfile = "$path/.process_links";
if ( -e "$lockfile" ) {
    if ( -M "$lockfile" < 0.005) {
        # modified in the last ~10 mins
        print "process already running (remove $lockfile?)\n"
            if $verbosity;
        exit 1;
    }
    warn "killing previous run!\n";
    system("rm -f '$lockfile'");
    # we are killing ourserlves here!
    system("ps -ef | grep 'process_links' | grep -v grep"
           ." | awk '{print \$2}' | xargs kill -9");
}

system("mkdir -p $TEMPDIR") unless (-e $TEMPDIR);

my $dbh = DBI->connect(
    'DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
    $cfg{'MYSQL_PASS'}, { RaiseError => 1 })
    or die "Couldn't connect to database: " . DBI->errstr;

$dbh->{'mysql_auto_reconnect'} = 1;

my $really = $opts{n} ? "AND 1 = 0" : "";

my $db_verify = $dbh->prepare(
    "UPDATE locations SET last_checked = NOW()"
    ." WHERE location_id = ? $really");

my $db_err = $dbh->prepare(
    "UPDATE locations SET status = ?, last_checked = NOW() "
    ."WHERE location_id = ? $really");

my $db_saveloc = $dbh->prepare(
    "UPDATE locations SET status = 1, filetype = ?, filesize = ?, "
    ."spamminess = ?, document_id = ?, last_checked = NOW() "
    ."WHERE location_id = ? $really");

my $db_savedoc = $dbh->prepare(
    "UPDATE documents SET authors = ?, title = ?, abstract = ?, "
    ."length = ?, meta_confidence = ? WHERE document_id = ? "
    ."$really");

my $db_adddoc = $dbh->prepare(
    "INSERT IGNORE INTO documents "
    ."(found_date, authors, title, abstract, length, "
    ."meta_confidence) VALUES (NOW(),?,?,?,?,?)");

my @abort;
$SIG{INT} = sub {
    print "\nHold on: just finishing this document...\n";
    @abort = @_;
};

my @queue = @{next_locations()};
unless (@queue) {
    print "no unprocessed locations\n" if $verbosity;
    leave(8);
}
while (my $loc = shift @queue) {
    leave(1) if (@abort);
    system("touch '$lockfile'");
    my $err = process($loc);
    system("rm -f '$TEMPDIR*'") unless $verbosity > 1;
    leave(0) if $opts{p} || $opts{s};
}
leave(0);

sub leave {
    my $status = $_[0];
    unlink($lockfile);
    $dbh->disconnect() if $dbh;
    if (@abort) {
        if ($abort[0] eq 'INT') {
            $status = 9;
        }
        else {
            Carp::confess(@abort);
        }
    }
    exit $status;
}

sub next_locations {
    if ($opts{p}) {
        # document specified on command-line
        my ($url, $id);
        if ($opts{p} =~ /^\d+$/) {
            $id = $opts{p};
            my $qu = "SELECT *, UNIX_TIMESTAMP(last_checked)"
                ." AS last_checked FROM locations"
                ." WHERE location_id = $opts{p}";
            return $dbh->selectall_arrayref($qu, { Slice => {} });
        }
        $url = $opts{p};
        ($id) = $dbh->selectrow_array("SELECT location_id"
                ." FROM locations WHERE url = '$opts{p}'");
        $id = 0;
        $opts{n} = 1;
        return [{ location_id => $id, url => $url }];
    }
    else {
        # get documents from database:
        my $NUM_LOCS = $opts{s} ? 1 : 10;
        my $fetch = sub {
            my $where = shift;
            my $qu = "SELECT *, UNIX_TIMESTAMP(last_checked)"
                ." AS last_checked"
                ." FROM locations WHERE $where"
                ." ORDER BY last_checked, location_id"
                ." LIMIT $NUM_LOCS";
            return $dbh->selectall_arrayref($qu, { Slice => {} });
        };
        # Do we have unprocessed locations?
        my $where = $opts{r} ? "0 = 0" : "status = 0";
        my @locations = @{$fetch->($where)};
        if (!@locations) {
            print "no new locations.\n" if $verbosity;
            my $where;
            my $min_age = time() - 24*60*60;
            # No. Toss a coin to decide whether to (a) verify old
            # papers and re-check locations with HTTP errors, or (b)
            # give old spam and parser errors a new chance. Mostly we
            # want to do (a). 
            if (rand(10) <= 9) {
                # (a) re-process old papers and HTTP errors:
                $where = "(status NOT BETWEEN 2 AND 99) AND"
                    ." NOT spamminess > 0.5 AND"
                    ." last_checked < $min_age";
            }
            else {
                # (b) give old spam and parser errors a second chance:
                $where = "last_checked < $min_age AND"
                    ." ((status = 1 AND spamminess > 0.5) OR"
                    ." (status BETWEEN 2 AND 99))";
            }
            @locations = @{$fetch->($where)};
        }
        return [@locations];
    }
}


sub process {
    my $loc = shift;
    my $loc_id = $loc->{location_id};
    binmode STDOUT, ":utf8";
    print "\nchecking location $loc_id: $loc->{url}\n" if $verbosity;

    # If we crash during processing, that should be marked in the DB:
    $db_err->execute(30, $loc_id);

    # fetch document:
    my $check_304 = $opts{r} ? 0 : 1;
    my $res = fetch_document($loc, $check_304) or return 0;
    $loc->{filesize} = $res->{filesize};
    $loc->{filetype} = $res->{filetype};
    $loc->{content} = $res->{content};

    # save local copy:
    my $hashname = Digest::MD5::md5_hex(''.$loc->{url});
    my $file = $TEMPDIR.$hashname.'.'.$loc->{filetype};
    my $is_text = 0;
    if ($loc->{filetype} eq 'html') {
        $is_text = 1;
        # we save as UTF-8, so remove original encoding tags:
        $loc->{content} =~ s/<meta[^>]+content-type[^>]+>//gi;
        $loc->{text} = strip_tags($loc->{content});
    }
    if (!save($file, $loc->{content}, $is_text)) {
        error("cannot save local file");
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return errorcode();
    }

    # check if this is a subpage with further links to papers:
    if (is_subpage($loc)) {
        # is_supage stores the subpage in the 'sources' table, so
        # we only need to indicate in 'locations' that this isn't
        # a document URL; we use the status field for that:
        error("subpage with more links");
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return 0;
    }

    # check if this is an intermediate page leading to the actual paper:
    my $target = check_steppingstone($loc, $res);
    if ($target) {
        my ($is_dupe) = $dbh->selectrow_array(
            "SELECT 1 FROM locations WHERE url = ".$dbh->quote($target));
        if ($is_dupe) {
            error("steppingstone to already known location");
            $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
            return 0;
        }
        print "adding target link to queue: $target.\n" if $verbosity;
        $loc->{url} = $target;
        push @queue, $loc;
        # We could alternatively replace the URL in the database, but
        # then we'd constantly rediscover the steppingstone link in
        # the source page and treat it as new. Perhaps the cleanest
        # response would be to add the target location separately to
        # the database, with a link to the redirecting location
        # $loc. (Without such a link, the location would appear to be
        # an orphan.) To find the source page of an article, one would
        # then have to retrieve a source page linking to a parent of
        # (a parent of ...) a location of the document. That's
        # cumbersome, so instead I simply overwrite the current
        # location, but keep its URL.
        return 0;
    }

    # get anchor text and default author from source pages:
    # TODO: this assumes there is only one source page.
    $loc->{anchortext} = '';
    $loc->{default_author} = '';
    if ($loc_id) {
        ($loc->{anchortext}, $loc->{default_author}) =
            $dbh->selectrow_array(
                "SELECT links.anchortext, sources.default_author "
                ."FROM links INNER JOIN sources ON "
                ."links.source_id = sources.source_id "
                ."WHERE links.location_id = $loc_id LIMIT 1");
    }

    # Except for html documents, we don't have the text content
    # yet, but we nevertheless do a preliminary spam test now,
    # so that we can stop processing if something is clear spam:
    my $spamminess = 0;
    Spamfilter::verbosity($verbosity > 1 ? $verbosity-1 : 0);
    eval {
        $spamminess = Spamfilter::classify($loc);
    };
    if ($@) {
        error($@);
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return errorcode();
    }
    if ($spamminess > 0.5) {
        if (defined $loc->{spamminess} && $loc->{spamminess} > 0.5) {
            print "was previously recognized as spam, "
                ."still looks like that\n" if $verbosity;
            $db_verify->execute($loc_id);
            return 0;
        }
        if ($spamminess >= $CERT_SPAM) {
            print "spam score $spamminess, "
                ."not checking any further\n" if $verbosity;
            $db_saveloc->execute($loc->{filetype}, $loc->{filesize}, 
                                 $spamminess, undef, $loc_id)
                or warn DBI->errstr;
            return 0;
        }
    }
    $loc->{spamminess} = $spamminess;

    # convert file to xml:
    Converter::verbosity($verbosity > 1 ? $verbosity-1 : 0);
    eval {
        convert2xml($file);
        doctidy("$file.xml");
    };
    if ($@) {
        error("$@");
        error("parser error") if errorcode() == 99;
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return errorcode();
    }
    add_meta("$file.xml", 'anchortext', $loc->{anchortext});
    add_meta("$file.xml", 'sourceauthor', $loc->{default_author});

    # extract author, title, abstract:
    my $result = Extractor->new();
    $result->verbosity($verbosity > 1 ? $verbosity-1 : 0);
    eval {
        $result->init("$file.xml");
        $result->extract(qw/authors title abstract/);
    };
    if ($@ || (!$result->{title})) {
        error($@ || "document seems to have no title");
        error("parser error") if errorcode() == 99;
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return errorcode();
    }

    $loc->{authors} = force_utf8(join ', ', @{$result->{authors}});
    $loc->{title} = force_utf8($result->{title});
    $loc->{abstract} = force_utf8($result->{abstract});
    $loc->{confidence} = $result->{confidence};
    $loc->{length} = $result->{numpages};
    $loc->{text} = $result->{text};
    # TODO: these should be added to the XML file by the extractor,
    # and used by the spam filter.

    # guess spamminess again, now that we have the text content:
    eval {
        $loc->{spamminess} = Spamfilter::classify($loc);
    };
    if ($loc->{spamminess} >= $CERT_SPAM) {
        print "spam score $loc->{spamminess}, "
            ."not storing document\n" if $verbosity;
        $db_saveloc->execute($loc->{filetype}, $loc->{filesize},
                             $loc->{spamminess}, undef, $loc_id)
            or warn DBI->errstr;
        return 0;
    }
    
    binmode STDOUT, ":utf8";
    print <<EOD if $verbosity;
=========== RESULT ===========
authors:    $loc->{authors}
title:      $loc->{title}
filetype:   $loc->{filetype}
spamminess: $loc->{spamminess}
confidence: $loc->{confidence}
abstract: 
$loc->{abstract}
==============================
EOD

    # store result in database:
    my $doc_id = $loc->{document_id};
    if ($doc_id) {
        print "updating records for document $doc_id.\n" if $verbosity;
        $db_savedoc->execute(
            $loc->{authors}, $loc->{title}, $loc->{abstract}, 
            $loc->{length}, $loc->{confidence}, $doc_id)
            or warn DBI->errstr;
    }
    else {
        # check if we already have this paper:
        my $abstract_piece = (length($loc->{abstract}) > 40) ?
                              substr($loc->{abstract}, 20, 20) : '';
        my ($o_id, $o_url, $o_confidence) = $dbh->selectrow_array(
            "SELECT documents.document_id, url, meta_confidence "
            ."FROM documents INNER JOIN locations "
            ."ON documents.document_id = locations.document_id "
            ."WHERE status = 1 AND location_id != $loc_id "
            ."AND authors = ".$dbh->quote($loc->{authors})." "
            ."AND title = ".$dbh->quote($loc->{title})." "
            ."AND abstract LIKE ".$dbh->quote("%$abstract_piece%")." "
            ."LIMIT 1");
        # better, with  the MySQL levenshtein UDF from joshdrew.com:
        # ."AND levenshtein(authors,".$dbh->quote($loc->{authors}).") < 4 "
        # ."AND levenshtein(title,".$dbh->quote($loc->{title}).") < 4 "
        # ."AND levenshtein(abstract,".$dbh->quote($loc->{abstract}).") < 15 "
        if ($o_id) {
            print "document already known as $o_id, $o_url.\n"
                if $verbosity;
            if ($loc->{confidence} > $o_confidence) {
                print "new confidence exceeds old: $o_confidence.\n"
                    if $verbosity;
                $db_savedoc->execute(
                    $loc->{authors}, $loc->{title}, $loc->{abstract}, 
                    $loc->{length}, $loc->{confidence}, $o_id)
                    or warn DBI->errstr;
            }
            $doc_id = $o_id;
        }
        elsif (!$opts{n}) {
            # add document to database:
            $db_adddoc->execute(
                $loc->{authors}, $loc->{title}, $loc->{abstract}, 
                $loc->{length}, $loc->{confidence})
                or warn DBI->errstr;
            $doc_id = $db_adddoc->{mysql_insertid};
            print "document added as id $doc_id\n" if $verbosity;
        }
    }
    $db_saveloc->execute(
        $loc->{filetype}, $loc->{filesize},
        $loc->{spamminess}, $doc_id, $loc_id)
        or warn DBI->errstr;
}

sub fetch_document {
    my $loc = shift;
    my $check_304 = shift;
    my $loc_id = $loc->{location_id};

    my $mtime = ($check_304 && defined $loc->{last_checked}) ? 
        $loc->{last_checked} : 0;
    my $res = fetch_url($loc->{url}, $mtime);

    if ($res && $res->code == 304 && defined $loc->{last_checked}) {
        print "not modified.\n" if $verbosity;
        $db_verify->execute($loc_id) or warn DBI->errstr;
        return;
    }

    if (!$res || !$res->is_success) {
        my $status = $res ? $res->code : 900;
        print "status $status\n" if $verbosity == 1;
        $db_err->execute($status, $loc_id) or warn DBI->errstr;
        return;
    }

    if (!$res->content || !$res->{filesize}) {
        error("document is empty");
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return;
    }

    print "file retrieved, $res->{filesize} bytes\n" if $verbosity > 1;

    # We want to make sure that we only update an old link if it
    # has really (substantially) changed. HTTP headers are not to
    # be trusted on this. So we also check for changes in
    # filesize:
    my $old_filesize = defined $loc->{filesize} ? $loc->{filesize} : 0;
    if (!$opts{r} && $old_filesize && 
        abs($old_filesize-$res->{filesize}) / $res->{filesize} < 0.2) {
        print "no substantial change in filesize.\n" if $verbosity;
        $db_verify->execute($loc_id) or warn DBI->errstr;
        return;
    }

    # check if filetype is supported:
    unless (grep {$res->{filetype} eq $_ } @{$cfg{'FILETYPES'}}) {
        error("unsupported filetype ".$res->{filetype}."\n"); 
        $db_err->execute(errorcode(), $loc_id) or warn DBI->errstr;
        return;
    }

    return $res;
}

sub is_subpage {
    my $loc = shift;
    return unless $loc->{location_id} && $loc->{filetype} eq 'html';

    print "checking: subpage with further links?\n" if $verbosity > 1; 

    # subpage must have high link density:
    my $numlinks = 0;
    $numlinks++ while ($loc->{content} =~ /<a\s+href/gi);
    my $textlen = length($loc->{text});
    unless ($numlinks > 4 && $numlinks/$textlen > 0.005) {
        print "no: link density $numlinks/$textlen\n" if $verbosity > 1;
        return 0;
    }

    # subpage must have at least three links of paper filetypes:
    $numlinks = 0;
    $numlinks++ while ($loc->{content} =~ /\.pdf|\.doc/gi);
    unless ($numlinks > 2) {
        print "no: $numlinks links to paper files\n" if $verbosity > 1;
        return 0;
    }

    # fetch potential parent pages:
    my $qu = "SELECT sources.* FROM links "
        ."INNER JOIN sources ON links.source_id = sources.source_id "
        ."WHERE links.location_id = $loc->{location_id}";
    my @sources = @{$dbh->selectall_arrayref($qu, { Slice => {} })};
    my @parents;
    foreach my $source (@sources) {
        # subpage must be located at same host and path as parent:
        my $source_path = $source->{url};
        $source_path =~ s/[^\/]+\.[^\/]+$//; # strip filename
        next unless $loc->{url} =~ /^$source_path/;
        # parent page must allow crawling:
        next if $source->{crawl_depth} == 0;
        push @parents, $source;
    }
    unless (@parents) {
        print "no: no suitable parent page\n" if $verbosity > 1;
        return 0;
    }
    # We can't properly handle subpages with multiple parents:
    if (scalar @parents > 1) {
        print "Oops, more than one candidate parent page!\n";
        return 0;
    }

    # Store page as new source:
    my $parent = pop @parents;
    print "yes: adding as subpage of $parent->{source_id}\n"
        if $verbosity > 1;
    my $db_addsub = $dbh->prepare(
        "INSERT IGNORE into sources "
        ."(url, status, parent_id, crawl_depth, default_author) "
        ."VALUES(?, 0, ?, ?, ?)");
    $db_addsub->execute(
        $loc->{url}, $parent->{source_id}, $parent->{crawl_depth}-1, 
        $parent->{default_author})
        or warn DBI->errstr;
    return 1;
}

sub check_steppingstone {
    my $loc = shift;
    my $http_res = shift;
    return 0 unless $loc->{filetype} eq 'html';
    # catch intermediate pages that redirect with meta refresh
    # (e.g. http://www.princeton.edu/~graff/papers/ucsbhandout.html):
    my $target = '';
    if ($loc->{content} =~ 
        /<meta.*http-equiv.*refresh.*content.*\n*url=([^\'\">]+)/i) {
        print "address redirects to $1.\n" if $verbosity;
        $target = URI->new($1);
        $target = $target->abs(URI->new($loc->{url}));
        $target =~ s/\s/%20/g; # fix links with whitespace
        return $target if length($target) < 256;
    }
    # other intermediate pages are short and have at least one link to
    # a pdf file:
    return 0 if $loc->{filesize} > 5000;
    return 0 if $loc->{content} !~ /\.pdf/i;
    # prevent loops with redirects to login?req=foo.pdf
    return 0 if $loc->{url} =~ m/\.pdf$/i;
    print "might be a steppingstone page?\n" if $verbosity > 1;
    my $link_extractor = 
        new HTML::LinkExtractor(undef, $http_res->base, 1);
    eval {
        $link_extractor->parse(\$http_res->{content});
    };
    my @as = grep { $$_{tag} eq 'a' && $$_{href} =~ /\.pdf$/ }
                  @{$link_extractor->links};
    print Dumper @as if $verbosity > 1;
    return 0 if @as != 1; # want exactly one pdf link
    $target = ${$as[0]}{href};
    $target =~ s/\s/%20/g; # fix links with whitespace
    return $target if length($target) < 256;
}

sub force_utf8 {
    # when parsing PDFs, we sometimes get mess that is not valid
    # UTF-8, which can make the HTML/RSS invalid.
    my $str = shift;
    return $str if (Encode::is_utf8($str, 1));
    $str = decode 'utf8', $str;
    return $str if (Encode::is_utf8($str, 1));
    $str =~ s/[^\x{21}-\x{7E}]//g;
    return $str if (Encode::is_utf8($str, 1));
    return "";
}
