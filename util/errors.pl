=item error [MSG or ERRORCODE]

gets or sets current error message.
With string parameter: sets error msg and code and returns undef.
With errorcode parameter: returns the msg for that code. 
Without parameters: returns current error message (or '').

=cut

our $verbosity = 0;

my $error = '';
my $errorcode = 10; # 10 means "no error", should never be returned
my %errors; # overwritten below; Perl complains if undefined
sub error {
   $_ = shift or return $error;
   if ($_ =~ /^\d+$/) {
      return $errors{$_} if exists($errors{$_});
      return 'unknown error';
   }
   $error = $_;
   $errorcode = errorcode($error);
   print "Error $errorcode: $error\n" if $verbosity;
   return undef;
}

=item errorcode [MSG or ERRORCODE]

gets or sets current errorcode.
With errorcode parameter: sets errorcode and msg and returns undef.
With string parameter: returns the code for that string. 
Without parameters: returns current errorcode (or 10 if none).

=cut

sub errorcode {
   $_ = shift or return $errorcode;
   if ($_ !~ /^\d+$/) {
       while (my ($key, $value) = each(%errors)) {
	   return $key if ($_ =~ /^$value/); # suffices that $_ BEGINS WITH $errors{key}
       }
       return 10 if !$_;
       return errorcode('unknown error');
   }
   $errorcode = $_;
   $error = error($_);
   print "Error $errorcode: $error\n" if $verbosity;
   return undef;
}

%errors = (
   10 => 'no error!',

   42 => 'cannot read local file',
   43 => 'cannot save local file',

   50 => 'unknown parser failure',
   51 => 'unsupported filetype',

   59 => 'OCR failed',
   59 => 'gs failed',
   60 => 'pdftohtml produced garbage',
   61 => 'pdftohtml failed',
   62 => 'no text found in converted document',
   63 => 'rtf2pdf failed',
   64 => 'antiword failed',
   65 => 'htmldoc failed',
   66 => 'mozilla2ps failed',
   67 => 'ps2pdf failed',
   68 => 'html2xml failed',
   69 => 'PDF conversion failed',
   70 => 'parser error',
   71 => 'non-UTF8 characters in metadata',

   80 => 'Categosizer failed',
   81 => 'philosophy detector failed',

   99 => 'unknown error',

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
   950 => 'steppingstone to duplicate',

   1000 => 'looks like a subpage with more links',
);

1;
