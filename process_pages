#! /usr/bin/perl -w
use strict;
#use warnings;
use DBI;
use URI::URL;
use HTML::LinkExtractor;
use Data::Dumper;
use Getopt::Std;
binmode STDOUT, ":utf8";
use lib '../';
use util::Io;
use util::Errors;

my %cfg = do 'config.pl';

my %opts;
getopts("v:p:nh", \%opts);
if ($opts{h}) {
    print <<EOF;

Fetches pages from the database, stores new links on them in the docs
database. Run as a cronjob without arguments, or with arguments for
testing and debugging:

Usage: $0 [-h] [-p url] [-v verbosity]

-p        : url that will be processed
-v        : verbosity level (0-10)
-h        : this message

EOF
    exit;
}

our $verbosity = $opts{v} || 0;
util::Io::verbosity($verbosity);

# ignore urls that match this RE:
my $ignore_url_re = qr{
    \#|
    ^mailto|
    ^javascript|
    ^.+//[^/]+/?$|          # TLD
    twitter\.com|
    \.(?:css|mp3|avi|jpg|gif)$
}xi;

# ignore these session ids in urls:
my $session_id_re = qr{
    \bs\w*id=\w+    |
    halsid=\w+       |
}xi;

# get urls from db:
my $dbh = DBI->connect('DBI:mysql:'.$cfg{'MYSQL_DB'}, $cfg{'MYSQL_USER'},
    $cfg{'MYSQL_PASS'}, { RaiseError => 1 }) 
    or die "Couldn't connect to database: " . DBI->errstr;
my $query = "SELECT id, url, UNIX_TIMESTAMP(last_checked) AS last_checked "
    ."FROM pages ORDER BY last_checked LIMIT ".$cfg{'NUM_URLS'};
my $pages = $dbh->selectall_arrayref($query, { Columns=>{} });
$pages = [({ id => 0, orig_id => $opts{o}, url => $opts{p}, 
             last_checked =>1213937107 })] if $opts{p};

# process pages:
my $pg_update = $dbh->prepare(
    "UPDATE pages SET last_checked = NOW(), status = ? WHERE id = ?");
my $db_insert = $dbh->prepare(
    "INSERT IGNORE INTO docs (url, page, anchortext, status, found) "
    ."VALUES (?,?,?,0,NOW())");
my $db_insert_as_old = $dbh->prepare(
    "INSERT IGNORE INTO docs (url, page, anchortext, status, found) "
    ."VALUES (?,?,?,0,'2008-01-01')");
foreach my $page (@{$pages}) {
   print "checking page $page->{url}\n" if $verbosity;
   my $mtime = (defined $page->{last_checked}) ? $page->{last_checked} : 0;
   my $res = fetch_url($page->{url}, $mtime);
   if ($res && $res->code == 304) {
       print "not modified.\n" if $verbosity;
       $pg_update->execute(1, $page->{id});
       next;
   }
   if (!$res || !$res->is_success || !$res->{content}) {
      print "error:\n   ", ($res ? $res->status_line : ''), "\n" if $verbosity;
      $pg_update->execute($res ? $res->code : 900, $page->{id});
      next;
   }
   # also check for 404 errors without proper HTTP status:
   if ($res->{content} =~ /Error 404/) {
      print "page contains 404 error message\n" if $verbosity;
      $pg_update->execute('404', $page->{id});
      next;
   }
   # fetch currently stored links from db:
   my $old_links = $dbh->selectcol_arrayref(
       "SELECT url FROM docs WHERE page = $page->{id}");
   my @old_links = @{$old_links};
   # parse for links and add them to DB if new:
   my $link_extractor = new HTML::LinkExtractor(undef, $res->base, 1);
   eval {
     $link_extractor->parse(\$res->{content});
   };

   my @hrefs = map($$_{href} ? "$$_{href}" : "", @{$link_extractor->links});
   LINKS: 
   foreach my $new_link (@{$link_extractor->links}) {
      next unless $$new_link{tag} eq 'a'; 
      my $href = $$new_link{href};
      my $text = $$new_link{_TEXT};
      print "checking link: $href ($text)\n" if ($verbosity > 1);
      # $new_link = url($new_link, $res->base)->abs->as_string;
      next if ($href eq $page->{url});
      if ($href =~ /$ignore_url_re/) {
	  print "URL ignored.\n"  if ($verbosity > 1);
	  next;
      }
      if (grep /\Q$href\E/, @old_links) {
	  print "URL already in DB.\n" if ($verbosity > 1);
	  next;
      }
      # check for session variants:
      if ($href =~ /$session_id_re/) {
	  my $href2 = $href;
	  $href2 =~ s/$session_id_re//;
	  foreach my $old_link (@old_links) {
	      next unless ($old_link =~ /$session_id_re/);
	      $old_link =~ s/$session_id_re//;
	      if ($href2 eq $old_link) {
		  print "session variant of $old_link\n" if ($verbosity > 1);
		  next LINKS;
	      }
	  }
      }
      # check for filetype variants:
      my ($basename, $filetype) = ($href =~ /^(.*?)\.?([^\.]+)$/);
      if ($basename && $filetype) {
	  my @dupes = grep(/\Q$basename\E/, @hrefs);
	  foreach my $dupe (@dupes) {
	      my ($dupetype) = ($dupe =~ /^.*?\.?([^\.]+)$/);
	      if (filetype_rank($dupetype) < filetype_rank($filetype)) {
		  print "filetype variant of $dupe.\n" if ($verbosity > 1);
		  next LINKS;
	      }
	  }
      }
      $href =~ s/\s/%20/g; # fix links with whitespace
      print "new link: $href ($text)\n" if $verbosity;
      push @old_links, $href;
      # if this whole page is new, don't list papers as recently found:
      if ($mtime) {
	  $db_insert->execute($href, $page->{id}, $text);
      }
      else {
	  $db_insert->execute($href, $page->{id}, $text);
      }
   }
   $pg_update->execute(1, $page->{id});
}

$dbh->disconnect();


sub filetype_rank {
    my %ranking = ( 'pdf' => 1, 'ps' => 2, 'html' => 3, 'htm' => 4, 'doc' => 5, 'rtf' => 6);
    $_ = shift;
    return 10 unless defined $ranking{$_};
    return $ranking{$_};
}
