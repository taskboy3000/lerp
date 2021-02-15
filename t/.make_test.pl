#!/usr/bin/env perl
use Modern::Perl '2018';

use FindBin;

BEGIN {
    if ( !exists $ENV{ PLERD_HOME } ) {
        $ENV{ PLERD_HOME } = "$FindBin::Bin/..";
    }
}

use Path::Class::File;

Main();
exit;

#-------------------
# Subroutines
#-------------------
sub Main {

    if ( !$ARGV[ 0 ] ) {
        say( "Usage: $0 [TEST_FILE]" );
        exit;
    }

    my $file = Path::Class::File->new( $FindBin::Bin, $ARGV[ 0 ] );

    if ( -e $file ) {
        die( "Declining to overwrite:  " . $file );
    }

    $file->spew( iomode => '>:encoding(UTF-8)', test_tmpl() );

    say( "Created " . $file );
}

sub test_tmpl {
    return <<"EOT";
use Modern::Perl '2018';

use FindBin;
BEGIN {
    \$::gLIBDIR="$FindBin::Bin/../lib";
}
use lib \$::gLIBDIR;

use Test::More;

Main();
exit;

#-----------
# Tests
#-----------
sub TestDefault {
    ok(1 == 1, "One appears to equal one, under these conditions");
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
EOT
}
