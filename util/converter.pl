package util::Converter;
use strict;
use utf8;
use Encode;
use Data::Dumper;
our $verbosity = 0;
use Exporter;
use lib '../';
use util::Sysexec;
use util::OCR;
use util::String;
binmode STDOUT, ":utf8";
our @ISA = ('Exporter');
our @EXPORT = qw(&convert2text &convert2pdf &convert2xml);

use constant TEMPDIR 	        => '../temp/';

my $verbosity = 0;
sub verbosity {
   $verbosity = shift if @_;
   return $verbosity;
}


util::OCR::verbosity(4);

my $f = shift;
print pdf2xml($f);

sub convert2text {
    my $filename = shift or die "convert2text requires filename parameter";
    my ($basename, $filetype) = ($filename =~ /^(.*?)\.?([^\.]+)$/);
    my $text;
    print "getting plain text from $filename\n" if $verbosity;
    if (!(-e $filename)) {
	return _conv_error("$filename does not exist");
    }
  SWITCH: for ($filetype) {
      /html/ && do {
	  # strip tags:
	  $text = _readfile($filename);
	  $text =~ s/\s*<(([^>]|\n)*)\s*>//g;
	  last;
      };
      /pdf/ && do { 
	  my $command = '/usr/bin/pdftohtml040'
	      .' -i'        # ignore images
	      .' -enc \'UTF-8\''
	      .' -stdout'   # output to stdout
	      ." $filename" # source file
	      .' 2>&1';     # stderr to stdout
	  print "$command\n" if $verbosity >= 3;
	  $text = sysexec($command, 10, $verbosity);
	  $text = Encode::decode_utf8($text) || $text; # sometimes $text isn't really UTF8, for whatever reson, then decode_utf() returns undef
	  return _conv_error("pdftohtml failed: $text") unless ($text =~ /DOCTYPE/);
	  # insert some linebreaks and strip tags:
	  $text =~ s/<br>\n?|<\/head/\n/gi;
	  $text =~ s/<[^>]+>/ /g; # naive, but pdftohtml is a simple mind
	  if (length($text) < 100 || $text !~ /\p{isAlpha}/) {
	      return _conv_error("no text found in converted document");
	  }
	  last;
      };
      /doc|rtf|ps/ && do {
	  # xxx hack: works, but inefficient:
	  convert2pdf($filename, "$filename.pdf") or return undef;
	  $text = convert2text("$filename.pdf");
	  last;
      };
      /txt/ && do {
	  $text = _readfile($filename);
	  last;
      };
      return _conv_error("convert2text: unsupported filetype ($filetype): $filename");
  }
    print "$text\n" if $verbosity >= 4;
    return $text;
}


sub convert2pdf {
    my $source = shift or die "convert2pdf requires filename parameters";
    my $target = shift or die "convert2pdf requires filename parameters";
    my ($basename, $filetype) = ($source =~ /^(.*?)\.?([^\.]+)$/);
    print "converting $source to pdf\n" if $verbosity;
  SWITCH: for ($filetype) {
      /doc/ && do {
	  my $command = '/usr/bin/antiword'
	      .' -aa4'      # output as PDF in a4 format
	      .' -i1'       # ignore images
	      .' -m 8859-1' # character encoding: antiword doesn't support utf8
	      ." $source"   # source file
	      .' 2>&1';     # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $content = sysexec($command, 10, $verbosity) || '';
	  $content = Encode::decode('iso-8859-1', $content) || $content;
	  return _conv_error("antiword failed: $content") unless ($content && $content =~ /%PDF/);
	  return save($target, $content);
      };
      /rtf/ && do {
	  my $command = '../util/rtf2pdf.sh'
	      ." $source"     # source file
	      ." $target"     # destination file
	      .' 2>&1';       # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $out = sysexec($command, 10, $verbosity);
	  print $out if $verbosity >= 4;
	  return _conv_error("rtf2pdf failed: $out") unless -e $target;
	  return 1;
      };
      /html|txt/ && do {
	  # parse and render with Mozilla and print to ps, then convert to pdf;
	  # unfortunately, it is impossible to extract text from the result. 
	  my $path = `pwd`;
	  chomp($path);
	  my $command = '/usr/bin/xvfb-run'   # spawn fake X-windows for mozilla xulrunner
	      .' -n 99'                  # DISPLAY number
	      .' /opt/xulrunner/xulrunner' # run xulrunner in the xvfb
	      .' /home/wo/mozilla2ps/application.ini' # from http://michele.pupazzo.org/mozilla2ps
	      ." file://$path/$source"   # source
	      ." $path/$target.ps"       # target
	      .' 2>&1';                  # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $out = sysexec($command, 10, $verbosity);
	  print $out if $verbosity >= 4;
	  return _conv_error("mozilla2ps failed: $out") unless -e "$target.ps";
	  convert2pdf("$target.ps", $target) or return undef;
	  unlink "$target.ps" unless $verbosity >= 2;
	  return 1;
      };
      /ps/ && do {
	  my $command = 'ps2pdf'
	      ." $source"     # source file
	      ." $target"     # destination file
	      .' 2>&1';       # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $out = sysexec($command, 10, $verbosity) || '';
	  print $out if $verbosity >= 4;
	  return _conv_error("ps2pdf failed: $out") unless -e $target;
	  return 1;
      };
      return _conv_error("$source has unsupported filetype");
  }
}

sub _readfile {
    my $filename = shift or die "readfile requires filename parameter";
    my $content = '';
    open INPUT, $filename or die $!;
    while (<INPUT>) { $content .= $_; }
    close INPUT;
    return $content;
}

my $error = '';
sub _conv_error {
    return $error unless @_;
    $error = shift;
    print "Error: $error\n" if $verbosity;
    return undef;
}
sub errmsg {
    return $error;
}

1;

