use strict;
use utf8;
use Encode;
use Data::Dumper;
use LWP;
use HTML::Encoding 'encoding_from_http_message';

our $verbosity = 0;
sub verbosity {
   $verbosity = shift if @_;
   return $verbosity;
}

sub fetch_url {
   $url = shift or die "fetch_url requires url parameter";
   my $ua = _get_ua();
   print "fetching document $url.\n" if $verbosity;
   my $http_res = $ua->get($url);
   $http_res->{url} = $url;
   if (!$http_res->is_success) {
      print "error: ", $http_res->status_line, "\n" if $verbosity;
      return $http_res;
   }
   print "ok, file retrieved\n" if $verbosity;
   $http_res->{filesize} = length($http_res->content);
   $http_res->{filetype} = _get_filetype($http_res);
   print Dumper $http_res if $verbosity >= 7;
   return $http_res;
}

my $_ua;
sub _get_ua {
   if (!$_ua) {
      $_ua = LWP::UserAgent->new;
      $_ua->agent('Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7.5) Gecko/20041107 Firefox/1.0');
      $_ua->parse_head(0); # fixes bug with utf-8 in header: http://www.mail-archive.com/libwww@perl.org/msg06095.html
      $_ua->timeout(20);
      $_ua->max_size(5_000_000);
  }
  return $_ua;
}

sub _get_filetype {
   my $http_res = shift or die "_get_filetype requires http_res parameter";
   my $filetype;
   # trust the following content-type headers:
   if ($http_res->header('content-type') =~ /(pdf|rtf|msword)/i) {
      $filetype = lc($1);
   }
   # for others, file-ending is more reliable (at least if it is a 3-4 character string):
   elsif ($http_res->{url} =~ /\/.+\/.+\.([a-z]{3,4})$/) {
      $filetype = lc($1);
   }
   # no file-ending? ok, treat content-type header with 'htm' in it as HTML:
   elsif ($http_res->header('content-type') =~ /htm/i) { 
   	$filetype = 'html';
   }
   # otherwise just accept whatever the header says, it's unsupported anyway:
   else {
   	$filetype = ($http_res->header('content-type') =~ /.+\/(.+)/i) ? lc($1) : 'none';
   }
   # normalize:
   $filetype =~ s/msword/doc/;
   $filetype =~ s/htm$/html/;
   print "filetype: $filetype\n" if $verbosity;
   return $filetype;
}

sub save {
   my $filename = shift or die 'save requires filename parameter';
   my $content = shift; # or die 'save requires content parameter'; disabled for empty files
   print "saving $filename\n" if $verbosity;
   if (!open FH, '>'.$filename) {
       print "Error: cannot save local file $filename: $!" if $verbosity;
       return 0;
   }
   binmode FH;
   print FH $content;
   close FH;
   return 1;
}

1;
