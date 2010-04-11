#!/usr/bin/perl
# stopafter - run a command with a timeout
my $time = shift;
alarm($time);
exec @ARGV;
die "Couldn't exec @ARGV: $!; aborting";
