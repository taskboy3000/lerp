use Modern::Perl '2018';

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Path::Class::Dir;
use Test::More;

use Plerd::Config;

our $gBaseDir = Path::Class::Dir->new( "$FindBin::Bin/init" );

Main();
exit;

#--------
# Tests
#--------
sub TestEmptyConfig {
    diag( "Testing default config" );
    my $Cfg = Plerd::Config->new;

    # properties => default values
    my %baselines = (
        author_email => 's.handwich@localhost',
        author_name  => 'Sam Handwich',
        base_uri     => 'http://localhost/',
        image_alt    => '[image]',
        title        => 'Another Plerd Blog',
        config_file  => "$ENV{HOME}/.plerd.conf"
    );

    for my $property ( keys %baselines ) {
        ok( $Cfg->$property eq $baselines{ $property },
            "Property '$property' has expected default"
        );
    }

    ok( !$Cfg->has_image, "image is not set (via predicate)" );
}

sub TestConfigWithPubDir {
    diag( "Testing config with publication_directory" );

    my $pubDir      = "/var/lib/html";
    my $notesPubDir = "/var/lib/html/notes";
    my $Cfg         = Plerd::Config->new( publication_directory => $pubDir );

    # properties => default values
    my %baselines = (
        "publication_directory"       => $pubDir,
        "notes_publication_directory" => $notesPubDir,
    );

    for my $property ( keys %baselines ) {
        ok( $Cfg->$property eq $baselines{ $property },
            "Property '$property' has expected default"
        );
    }
}

sub TestRunAtDefaultLocation {
    diag( "Testing Run At Default Location" );
    my $config = Plerd::Config->new(
        config_file => "$FindBin::Bin/init/new-site.conf" );
    $config->initialize();
    ok( -d $config->path, "Default site directory exists: " . $config->path );
    ok( -e $config->config_file,
        "Site config file was created: " . $config->config_file );

    my $reread_config = Plerd::Config->new(
        config_file => "$FindBin::Bin/init/new-site.conf" );
    ok( $reread_config->unserialize, "Unserialized new config" );
    for my $property (
        qw(
        path publication_directory source_directory
        database_directory template_directory run_directory log_directory
        )
        )
    {
        ok( $config->$property eq $reread_config->$property,
            "Property $property is the same" );

        # diag($config->$property . " => " . $reread_config->$property);
    }
    ok( defined $config->custom_nav_items, 'Custom nav items present' );
    $config->config_file->remove;
    $config->path->rmtree;
}

sub TestRunAtSpecifiedLocation {
    my $config = Plerd::Config->new(
        config_file => "$FindBin::Bin/init/new-site2.conf",
        path        => "$FindBin::Bin/init/new-site2"
    );
    $config->initialize();
    ok( -d $config->path, "Default site directory 'new-site2' exists" );
    ok( -e $config->config_file, "Site config was created" );
    $config->config_file->remove;
    $config->path->rmtree;
}

sub TestCustomNavItems {
    my $config = Plerd::Config->new(
        config_file      => "$FindBin::Bin/init/new-site3.conf",
        path             => "$FindBin::Bin/init/new-site3",
        custom_nav_items => [
            {   title => "Now",
                uri   => "/now.html",
            },
            {   title => "About",
                uri   => "http://localhost/about.html"
            }
        ]
    );

    $config->initialize();
    ok( -d $config->path, "Default site directory 'new-site3' exists" );
    ok( -e $config->config_file, "Site config was created" );

    my $reread_config = Plerd::Config->new(
        config_file => "$FindBin::Bin/init/new-site3.conf" );
    ok( $reread_config->unserialize, "Unserialized new config" );
    ok( @{ $reread_config->custom_nav_items } == 2,
        "Got 2 custom nav items" );
    for my $nav_item ( @{ $reread_config->custom_nav_items } ) {
        diag( "$nav_item->{title} => $nav_item->{uri}" );
    }

    $config->config_file->remove;
    $config->path->rmtree;
}

#----------
# Helpers
sub Main {
    setup();

    TestEmptyConfig();
    TestConfigWithPubDir();
    TestRunAtDefaultLocation();
    TestRunAtSpecifiedLocation();
    TestCustomNavItems();

    teardown();
    done_testing();
}

sub setup {
}

sub teardown {
}

