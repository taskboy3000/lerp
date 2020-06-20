use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use Capture::Tiny ':all';

use FindBin;
use lib "$FindBin::Bin/../lib";

our $gPLERDALL_BIN = "$FindBin::Bin/../bin/plerdall";
our $gINIT_DIR;
our $gCONFIG_FILE;

Main();
exit;

#--------
# Tests
#--------
sub TestRunAtDefaultLocation {
    run_init();
    check_wrapper( 'plerd' );
}

sub TestRunAtSpecifiedLocation {
    run_init( 'foobar' );
    check_wrapper( 'foobar' );
}


#----------
# Helpers
sub Main {
    setup();

    TestRunAtDefaultLocation();
    TestRunAtSpecifiedLocation();

    teardown();
    done_testing();
}

sub run_init {
    my ($init_target) = @_;

    my $init_arg = '--init';
    if ( defined $init_target ) {
        $init_arg .= "=$init_target";
    }

    # Capture these, even though we don't do anything with them (yet)
    my ($stdout, $stderr, $exit) = capture {
        system(
            $^X,
            '-I', "$FindBin::Bin/../lib/",
            $gPLERDALL_BIN,
            $init_arg,
            "--config=$gCONFIG_FILE",
        );
    }
}

# check_wrapper: Just check for the existence of templates/wrapper.tt,
#                and make sure it seems to have expected content.
sub check_wrapper {
    my ( $subdir ) = @_;
    my $wrapper = Path::Class::File->new(
        $gINIT_DIR, $subdir, 'templates', 'wrapper.tt'
    );

    ok (-e $wrapper, "Wrapper template exists under '$subdir'.");
    my $wrapper_content = $wrapper->slurp;
    like(
        $wrapper_content,
        qr{<h1>Hello</h1>},
        "Wrapper content looks okay.",
    );
}

sub setup {
    $gINIT_DIR = Path::Class::Dir->new( "$FindBin::Bin/init" );
    $gINIT_DIR->rmtree;
    $gINIT_DIR->mkpath;
    chdir $gINIT_DIR or die "Can't chdir to $gINIT_DIR: $!";

    $gCONFIG_FILE = Path::Class::File->new(
        $FindBin::Bin,
        'test.conf',
    );
    $gCONFIG_FILE->spew( '' );

}

sub teardown {

}

