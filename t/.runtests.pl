#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

BEGIN {
    if (!exists $ENV{PLERD_HOME}) {
        $ENV{PLERD_HOME} = "$FindBin::Bin/..";
    }
}

Main();
exit;

sub Main {
    for my $file (@ARGV) {
        if (-e $file) {
            my @cmd = ($^X, $file);
            print "Running: $file\n";

            system(@cmd);

            if ($? == -1) {
                die("Failed to execute: ", join(" ", @cmd));
            } elsif ($? & 127) {
                die(
                    sprintf("Died with signal: %d", ($? & 127))
                );
            }
        }
    }
}