#! /usr/bin/perl -w
use strict;
use warnings;

use lib "..";
use DBI;
use LWP;
use Data::Dumper;
use Doc;

my $usage = <<EOD;
Arguments:
   -f <docfile>           parse <docfile>
   -f <docfile> -s        parse <docfile> and set result as reference value
   -a                     run all testcases (not implemented!)
   -v <verbosity>         set verbosity
EOD

die $usage unless (@ARGV);
my $args = join ' ', @ARGV;
my $verbosity = ($args =~ /-v (\d)/) ? $1 : 1;
if ($args =~ /-f ([^-]\S*)/) {
   my $docfile = $1;
   testdoc($docfile, ($args =~ /-s\b/ ? 1 : 0));
}
elsif ($args =~ /-a\b/) {
   testall();
}
else {
   die $usage;
}

{ # load/save reference values from/to dumped file testing/_ref_values.txt
   my $ref_values;
   sub get_ref_values {
      if (!$ref_values) {
         open FILE, 'testing/_ref_values.txt' or die $!;
         my $text;
         { local($/), $text = <FILE> };
         eval($text);
      }
      return $ref_values;
   }
   sub set_ref_values {
      my $ref_values = shift;
      open FILE, '>testing/_ref_values.txt' or die $!;
      print FILE Data::Dumper->Dump([$ref_values], ['ref_values']);
      1;
   }
}

sub testdoc {
   my $docfile = shift;
   my $save_ref = shift;
   my $doc = Doc->new(localfile => $docfile, verbosity => $verbosity);
   my $result = $doc->parse();
   return print $doc->error."\n" if (!$result);
   print Data::Dumper->Dump([$result], ['result']) if ($verbosity > 0);
   my $ref_values = get_ref_values();
   my $ref_res = $ref_values->{$docfile};
   if ($ref_res) {
      my $ok = 1;
      foreach (keys %{$ref_res}) {
         my $val1 = ($_ eq 'authors') ? join ', ', @{$result->{$_}} : $result->{$_};
         my $val2 = ($_ eq 'authors') ? join ', ', @{$ref_res->{$_}} : $ref_res->{$_};
         next if ($val1 eq $val2);
         print "$_ is wrong:\nIS:    $val1\nOUGHT: $val2\n";
         $ok = 0;
      }
      print "OK: matches ref value\n" if ($ok);
   }
   else {
      print "no reference value for $docfile\n";
   }
   if ($save_ref) {
      $ref_values->{$docfile} = $result;
      set_ref_values($ref_values) && print "ref value saved\n";
   }
   open RES, ">testing/_result.html" or die $!;
   print RES <<EOD;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<title></title>
</head>
<pre>
EOD
   print RES "AUTHORS: ".join ", ", @{$result->{authors}};
   print RES "\n\nTITLE: ".$result->{title};
   print RES "\n\nABSTRACT: ".$result->{abstract};
   print RES "</pre>\n";
   print "result written to testing/_result.html\n\n" if ($verbosity > 0);
}
