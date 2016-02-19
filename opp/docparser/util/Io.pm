package util::Io;
use strict;
no warnings 'utf8';
use Data::Dumper;
use LWP;
use URI;
use Encode;
use Encode 'is_utf8';
use HTTP::Date;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(&fetch_url &save &readfile &add_meta);

our $verbosity = 0;
sub verbosity {
    $verbosity = shift if @_;
    return $verbosity;
}

sub fetch_url {
    my $url = shift or die "fetch_url requires url parameter";
    my $if_modified_since = shift || 0;
    my $ua = _get_ua();
    print "fetching document $url.\n" if $verbosity > 1;
    my %headers = ();
    if ($if_modified_since) {
        $headers{'If-Modified-Since'} = HTTP::Date::time2str($if_modified_since);
    }
    my $response = _ua_get($ua, $url, \%headers);
    print Dumper $response if $verbosity > 7;
    $response->{url} = $url;
    # Follow redirects, but don't loop.
    my @locations = ($url);
    while ($response->code eq "301" or $response->code eq "302") {
        $url = $response->header('Location');
        # fix invalid relative redirects:
        $url = URI->new_abs($url, $response->base)->canonical();
        print "Redirected to $url\n" if $verbosity;
        if (grep { $url eq $_ } @locations) {
            print "Redirect loop!\n" if $verbosity;
            last;
        }
        push(@locations, $url);
        eval {
            $response = _ua_get($ua, $url, \%headers);
       };
    }
    if (!$response->is_success) {
        print "status ", $response->status_line, "\n" if $verbosity;
        return $response;
    }
    print "ok, file retrieved\n" if $verbosity > 1;
    $response->{filesize} = length($response->content);
    $response->{filetype} = _get_filetype($response);
    my $content;
    eval {
        $content = $response->decoded_content(raise_error => 1);
    };
    if ($@ || !$content || !is_utf8($content)) {
        print "decode failed: $@\n" if $verbosity > 1;
        if (defined($response->{_content})) {
            $content = $response->{_content};
        }
    }
    if ($response->{filetype} eq 'html') {
        # without this, Perl crashes when applying regexes
        # (e.g. /\n$re_bib_heading\n/):
        $content =~ s/[\t\r]/ /g;
        $content =~ s/\n\n+/\n/g;
    }
    $response->{content} = $content;
    return $response;
}

sub _ua_get {
    my ($ua, $url, $headers) = @_;
    my %headers = %{$headers};
    # Emulate a web browser profile:
    $headers{'accept'} = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
    $headers{'accept-language'} = 'en-US,en;q=0.5';
    # block 'TE' header:
    push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, SendTE => 0, PeerHTTPVersion => "1.1");
    # Without the following voodoo we get a warning due to perl's
    # y2038 bug when handling cookies:
    open OLDERR,     ">&", \*STDERR or die "Can't dup STDERR: $!";
    select OLDERR;
    open STDERR, ">/dev/null"       or die "Can't change STDERR: $!";
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
        $_ua = LWP::UserAgent->new(keep_alive=>1);
        $_ua->agent('Mozilla/5.0 (X11; Linux x86_64; rv:37.0) Gecko/20100101 Firefox/37.0');
        # allow cookies e.g. for google sites redirects
        $_ua->cookie_jar({});
        # fix bug with utf-8 in header, see
        # http://www.mail-archive.com/libwww@perl.org/msg06095.html:
        $_ua->parse_head(0);
        $_ua->timeout(20);
        # setting max_size breaks homepage.mac.com, which then returns
        # with "error 416 Requested range not satisfiable". OTOH,
        # leaving it off means we get stuck e.g. at the 515 MB file
        # http://www.infra.kth.se/~gryne/ACEpaper.pdf
        $_ua->max_size(20000000); 
    }
    return $_ua;
}

sub _get_filetype {
    my $response = shift;
    my $filetype;
    # trust the following content-type headers:
    my $ctype = $response->header('content-type') || '';
    if ($ctype =~ /(pdf|rtf|msword|html?)/i) {
        $filetype = lc($1);
    }
    # for others, first check if content has pdf signature:
    elsif (defined($response->{_content}) && $response->{_content} =~ /^%PDF-/) {
        $filetype = 'pdf';
    }
    # otherwise use file-ending, if it is a 2-4 character string:
    elsif ($response->{url} =~ /\/.+\/.+\.([a-z]{2,4})$/) {
        $filetype = lc($1);
    }
    # otherwise just accept whatever the header says:
    else {
   	$filetype = ($ctype =~ /.+\/(.+)/i) ? lc($1) : 'none';
    }
    # normalize:
    $filetype =~ s/msword|docx/doc/;
    $filetype =~ s/htm$/html/;
    $filetype =~ s/text/txt/;
    print "filetype: $filetype\n" if $verbosity > 1;
    return $filetype;
}

sub save {
    my $filename = shift;
    my $content = shift;
    my $textmode = shift;
    print "saving $filename\n" if $verbosity > 1;
    if (!open FH, '>', $filename) {
        die "Error: cannot save local file $filename: $!\n";
    }
    if ($textmode) {
        binmode(FH, ":encoding(UTF-8)");
    }
    else {
        binmode(FH, ":raw");
    }
    print FH $content;
    close FH;
    return 1;
}

sub readfile {
    my $filename = shift;
    my $content = '';
    open INPUT, '<:encoding(UTF-8)', $filename or die $!;
    while (<INPUT>) { $content .= $_; }
    close INPUT;
    return $content;
}

sub add_meta {
    # add metadata elements to XML file.
    my ($file, $element, $content) = @_;
    $content ||= '';
    
    open IN, '<:utf8', $file or die $!;
    open OUT, '>:utf8', "$file.new" or die $!;
    my $done = 0;
    while (<IN>) {
        $_ = Encode::decode_utf8($_);
        print OUT $_;
        if (/^<\w/ && !$done) { 
            print OUT "<$element>$content</$element>\n";
            $done = 1;
        }
    }
    close IN;
    close OUT;
    rename "$file.new", "$file";
}

1;
