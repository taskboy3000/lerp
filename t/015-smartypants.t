use Modern::Perl '2018';

use FindBin;
BEGIN {
    $::gLIBDIR="/Users/jjohn/src/plerd_taskboy3000/t/../lib";
}
use lib $::gLIBDIR;

use Plerd::SmartyPants;

use Test::More;

Main();
exit;

#-----------
# Tests
#-----------
sub TestDefault {
    my %baselines = (
        "-- Russia, with love" => q[— Russia, with love],
        q[My "smartquotes"] => q[My “smartquotes”],
    );

    for my $test (sort keys %baselines) {
        my $got = Plerd::SmartyPants->process($test);
        ok($got eq $baselines{$test}, $test);

        # say "> $test";
        # say "----";
        # say "< $got";
    }
}

#------------
# Helpers
#------------
sub Main {
    # Initialize globals as needed
    setup();

    # Invoke tests here
    TestDefault();

    # Clean up as needed
    teardown();

    done_testing();
}

sub setup {

}

sub teardown {

}
