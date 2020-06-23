use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use Plerd;

Main();
exit;

#----------------
# Tests
#----------------
sub TestInvoked {
    my $plerd = Plerd->new;
    ok($plerd, "Plerd instantiated");
}

#---------
# Helpers
#---------
sub Main {
    setup();

    TestInvoked();

    teardown();

    done_testing();
}

sub setup {

}

sub teardown {
    
}