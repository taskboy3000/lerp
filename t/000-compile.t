use warnings;
use strict;
use FindBin;
BEGIN {
    $::gLIBDIR="$FindBin::Bin/../lib";
    $::gBINDIR="$FindBin::Bin/../bin";
}
use lib $::gLIBDIR;

use Test::More;

Main();
exit;


#-------
# Tests
#-------
sub TestCompileModules {
    my @classFiles = sort glob("$::gLIBDIR/*.pm"), 
    glob("$::gLIBDIR/*/*.pm"),
    glob("$::gLIBDIR/*/*/*.pm");

    for my $classFile (@classFiles) {
        my @cmd = ($^X, "-I$::gLIBDIR", "-wc", $classFile, "2>/dev/null");
        # diag(join(" ", @cmd)); 

        system(join(" ", @cmd));

        my $ok=0;
        if ($? == -1) {
            printf("Could not execute: %s\n", join(" ", @cmd));
        } elsif ($? && 127) {
            # Expected with bad compiles 
        } else {
            $ok=1;
        }

        ok($ok, "Compiling : $classFile");
    }
}


sub TestCompileExecuteables {
    my @binFiles = sort glob("$::gBINDIR/*");

    for my $binFile (@binFiles) {
        my @cmd = ($^X, "-I$::gLIBDIR", "-wc", $binFile, ) ; # "2>/dev/null");
        
        system(join(" ", @cmd));

        my $ok=0;
        if ($? == -1) {
            printf("Could not execute: %s\n", join(" ", @cmd));
        } elsif ($? && 127) {
            # Expected with bad compiles
        } else {
            $ok=1;
        }

        ok($ok, "Compiling : $binFile");
    }

}

sub Main {

    TestCompileModules();
    # TestCompileExecuteables();

    done_testing();
}

