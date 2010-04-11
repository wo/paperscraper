#!/usr/bin/perl
package util::Sysexec;
use strict;
use warnings;
use IO::Handle;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(&sysexec);

sub sysexec {
    my $command = shift;
    my $timeout = shift;
    my $verbosity = shift || 0;
    print "sysexec ($timeout): $command\n" if $verbosity;

    my $res = '';

    pipe(READER, WRITER);
    WRITER->autoflush(1);

    my $pid;

    local $SIG{ALRM} = sub {
	kill 15, $pid or die "kill: $!";  # Just SIGTERM.
        print "Timeout!\n" if $verbosity;
	die "Timeout!"
    };

    eval {
        alarm $timeout;
	$pid = fork();
        die "Fork failed: $!" unless defined $pid;
	if ($pid) { 
            # parent: wait for child fork
	    close WRITER;
	    while (<READER>) { $res .= $_; }
	    close READER;
	    waitpid ($pid, 0);
	}
	else { 
            # child:
	    close READER;
	    open(PIPE, "$command |") or die $!;
	    while (<PIPE>) { $res .= $_; };
	    close(PIPE);
	    print WRITER $res;
	    close WRITER;
	    exit;
	}
	alarm 0;
    };
    die $@ if $@ && $@ !~ /^Timeout!/;
    return $res;
}

1;
