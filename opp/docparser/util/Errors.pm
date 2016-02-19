package util::Errors;
use strict;
use warnings;
use utf8;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(&error &errorcode);

my $error = '';
my $errorcode = 10;
my %errors = (
   10 => 'no error!',

   30 => 'process_links terminated during processing',

   42 => 'cannot read local file',
   43 => 'cannot save local file',
   49 => 'Cannot allocate memory',

   50 => 'unknown parser failure',
   51 => 'unsupported filetype',

   58 => 'OCR failed',
   59 => 'gs failed',
   60 => 'pdftohtml produced garbage',
   61 => 'pdftohtml failed',
   62 => 'no text found in converted document',
   63 => 'rtf2pdf failed',
   64 => 'unoconv failed',
   65 => 'htmldoc failed',
   66 => 'wkhtmltopdf failed',
   67 => 'ps2pdf failed',
   68 => 'html2xml failed',
   69 => 'pdf conversion failed',
   70 => 'parser error',
   71 => 'non-UTF8 characters in metadata',

   92 => 'database error',

   100 => 'Continue',
   101 => 'Switching Protocols',
   102 => 'Processing',                      # WebDAV
   200 => 'OK',
   201 => 'Created',
   202 => 'Accepted',
   203 => 'Non-Authoritative Information',
   204 => 'No Content',
   205 => 'Reset Content',
   206 => 'Partial Content',
   207 => 'Multi-Status',                    # WebDAV
   300 => 'Multiple Choices',
   301 => 'Moved Permanently',
   302 => 'Moved Temporarily',
   303 => 'See Other',
   304 => 'Not Modified',
   305 => 'Use Proxy',
   307 => 'Temporary Redirect',
   400 => 'Bad Request',
   401 => 'Unauthorized',
   402 => 'Payment Required',
   403 => 'Forbidden',
   404 => 'Not Found',
   405 => 'Method Not Allowed',
   406 => 'Not Acceptable',
   407 => 'Proxy Authentication Required',
   408 => 'Request Timeout',
   409 => 'Conflict',
   410 => 'Gone',
   411 => 'Length Required',
   412 => 'Precondition Failed',
   413 => 'Request Entity Too Large',
   414 => 'Request-URI Too Large',
   415 => 'Unsupported Media Type',
   416 => 'Request Range Not Satisfiable',
   417 => 'Expectation Failed',
   422 => 'Unprocessable Entity',            # WebDAV
   423 => 'Locked',                          # WebDAV
   424 => 'Failed Dependency',               # WebDAV
   500 => 'Internal Server Error',
   501 => 'Not Implemented',
   502 => 'Bad Gateway',
   503 => 'Service Unavailable',
   504 => 'Gateway Timeout',
   505 => 'HTTP Version Not Supported',
   507 => 'Insufficient Storage',            # WebDAV

   900 => 'cannot fetch document',
   901 => 'document is empty',
   902 => 'Too Many Redirects',
    
   1010 => 'steppingstone to other location',
);

my %errorcodes = reverse %errors;

my $verbosity = 0;
sub verbosity {
   $verbosity = shift if @_;
   return $verbosity;
}

sub error {
   $_ = shift or return $error;
   if ($_ =~ /^\d+$/) {
      return $errors{$_} if exists($errors{$_});
      return 'unknown error';
   }
   $error = $_;
   $errorcode = errorcode($error);
   print "Error $errorcode: $error\n" if verbosity;
   return undef;
}

sub errorcode {
   my $e = shift or return $errorcode;
   if ($e !~ /^\d+$/) {
       $e =~ s/\n/ /g;
       $e =~ s/^\s+//g;
       return 10 if !$e;
       return $errorcodes{$e} if $errorcodes{$e};
       while (my ($key, $value) = each(%errors)) {
	   return $key if ($value && $e =~ /$value/);
       }
       #warn "no error code for $e";
       return 99;
   }
   $errorcode = $e;
   $error = error($e);
   return undef;
}

1;
