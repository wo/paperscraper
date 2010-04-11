package Converter;
use strict;
use utf8;
use Encode;
use Data::Dumper;
my %cfg = do 'config.pl';

my $verbosity = 0;
sub verbosity {
   $verbosity = shift if @_;
   return $verbosity;
}

sub convert2pdf {
    my $source = shift or die "convert2pdf requires filename parameters";
    my $target = shift or die "convert2pdf requires filename parameters";
    my ($basename, $filetype) = ($source =~ /^(.*?)\.?([^\.]+)$/);
    print "converting $source to pdf\n" if $verbosity;
  SWITCH: for ($filetype) {
      /doc/ && do {
	  my $command = $cfg{ANTIWORD}
	      .' -aa4'      # output as PDF in a4 format
	      .' -i1'       # ignore images
	      .' -m 8859-1.txt' # character encoding: antiword doesn't support utf8
	      ." $source"   # source file
	      .' 2>&1';     # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $content = `$command`;
	  return error("antiword failed: $content") unless ($content =~ /%PDF/);
	  return save($content, $target);
      };
      /rtf/ && do {
	  my $command = 'util/rtf2pdf.sh'
	      ." $source"     # source file
	      ." $target"     # destination file
	      .' 2>&1';       # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $out = `$command`;
	  print $out if $verbosity >= 4;
	  return error("rtf2pdf failed: $out") unless -e $target;
	  return 1;
      };
      /ps/ && do {
	  my $command = $cfg{'ps2pdf'}
	      ." $source"     # source file
	      ." $target"     # destination file
	      .' 2>&1';       # stderr to stdout
	  print "$command\n" if $verbosity >= 2;
	  my $out = `$command`;
	  print $out if $verbosity >= 4;
	  return error("ps2pdf failed: $out") unless -e $target;
	  return 1;
      };
      return error("$source has unsupported filetype");
  }
}

my $error = '';
my $errorcode = 10; # 10 means "no error", should never be returned
sub error {
   $error = shift or return $error;
   print "Error: $error\n" if $verbosity;
   return undef;
}
sub errmsg {
    return $error;
}
