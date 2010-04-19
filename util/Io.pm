package util::Io;
use strict;
use utf8;
use Encode;
use Data::Dumper;
use LWP;
use HTTP::Date;
use HTML::Encoding 'encoding_from_http_message';
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(&fetch_url &save &readfile);

our $verbosity = 0;
sub verbosity {
   $verbosity = shift if @_;
   return $verbosity;
}

sub fetch_url {
   my $url = shift or die "fetch_url requires url parameter";
   my $if_modified_since = shift || 0;
   my $ua = _get_ua();
   print "fetching document $url.\n" if $verbosity;
   my %headers = ( 'If-Modified-Since' => HTTP::Date::time2str($if_modified_since) );
   my $response;
   $response = _ua_get($ua, $url, \%headers);
   $response->{url} = $url;
   # Follow redirects, but don't loop.
   my @locations = ($url);
   while ($response->code eq "301" or $response->code eq "302") {
       $url = $response->header('Location');
       print "Redirected to $url\n" if $verbosity;
       if (grep { $url eq $_ } @locations) {
	   print "Redirect loop!\n" if $verbosity;
	   last;
       }
       push(@locations, $url);
       eval {
	   $response = $ua->get($url, %headers);
       };
   }
   if (!$response->is_success) {
      print "status ", $response->status_line, "\n" if $verbosity;
      return $response;
   }
   print "ok, file retrieved\n" if $verbosity;
   $response->{filesize} = length($response->content);
   $response->{filetype} = _get_filetype($response);
   # convert to utf8:
   $response->{content} = $response->decoded_content if ($response->decoded_content);
   # sometimes when a server wrongly sends "Partial Content", ->{content} is empty and
   # ->{_content} has all the content; so we copy it over:
   #if (($response->content eq '') and defined($response->{_content})) {
   #    $response->{content} = $response->{_content};
   #}
   print Dumper $response if $verbosity >= 7;
   return $response;
}

sub _ua_get {
<<<<<<< HEAD:util/Io.pm
    # oh man. Otherwise we get a warning due to perl's y2038 bug when handling cookies
=======
    # Otherwise we get a warning due to perl's y2038 bug when handling cookies
>>>>>>> develop:util/Io.pm
    my ($ua, $url, $headers) = @_;
    my %headers = %{$headers};
    open OLDERR,     ">&", \*STDERR or die "Can't dup STDERR: $!";
    select OLDERR;
<<<<<<< HEAD:util/Io.pm
    open STDERR, ">/dev/null"     or die "Can't change STDERR: $!";
=======
    open STDERR, ">/dev/null"       or die "Can't change STDERR: $!";
>>>>>>> develop:util/Io.pm
    select STDERR; $| = 1;
    open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
    select STDOUT; $| = 1;
    my $response = $ua->get($url, %headers);
    open STDERR, ">&OLDERR"    or die "Can't dup OLDERR: $!";
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";
    return $response;
}

my $_ua;
sub _get_ua {
   if (!$_ua) {
      $_ua = LWP::UserAgent->new;
      $_ua->agent('Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9) Gecko/2008052906 Firefox/3.0');
      $_ua->cookie_jar({}); # allow cookies e.g. for google sites redirects
      $_ua->parse_head(0); # fixes bug with utf-8 in header: http://www.mail-archive.com/libwww@perl.org/msg06095.html
      $_ua->timeout(20);
      $_ua->max_size(20000000); # breaks homepage.mac.com => error 416 Requested range not satisfiable
      # xxx otoh, we break at the 515 MB file http://www.infra.kth.se/~gryne/ACEpaper.pdf
  }
  return $_ua;
}

sub _get_filetype {
   my $response = shift or die "_get_filetype requires response parameter";
   my $filetype;
   # trust the following content-type headers:
   if ($response->header('content-type') =~ /(pdf|rtf|msword|html?)/i) {
      $filetype = lc($1);
   }
   # for others, file-ending is more reliable (at least if it is a 2-4 character string):
   elsif ($response->{url} =~ /\/.+\/.+\.([a-z]{2,4})$/) {
      $filetype = lc($1);
   }
   # otherwise just accept whatever the header says:
   else {
   	$filetype = ($response->header('content-type') =~ /.+\/(.+)/i) ? lc($1) : 'none';
   }
   # normalize:
   $filetype =~ s/msword/doc/;
   $filetype =~ s/htm$/html/;
   $filetype =~ s/text/txt/;
   print "filetype: $filetype\n" if $verbosity;
   return $filetype;
}

sub save {
   my $filename = shift or die 'save requires filename parameter';
   my $content = shift; # or die 'save requires content parameter'; disabled for empty files
   my $textmode = shift;
   print "saving $filename\n" if $verbosity;
   if (!open FH, '>'.$filename) {
       print "Error: cannot save local file $filename: $!" if $verbosity;
       return 0;
   }
   if ($textmode) { 
       binmode(FH, ":utf8");
   }
   else {
       binmode(FH);
   }
   print FH $content;
   close FH;
   return 1;
}

<<<<<<< HEAD:util/Io.pm
=======
sub readfile {
    my $filename = shift or die "readfile requires filename parameter";
    my $content = '';
    open INPUT, $filename or die $!;
    while (<INPUT>) { $content .= $_; }
    close INPUT;
    return $content;
}

>>>>>>> develop:util/Io.pm
1;
