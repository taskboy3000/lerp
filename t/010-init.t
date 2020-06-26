use Modern::Perl '2018';

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Path::Class::Dir;
use Test::More;

use Plerd::Config;

our $gBaseDir = Path::Class::Dir->new("$FindBin::Bin/init_tests");

Main();
exit;

#--------
# Tests
#--------
sub TestEmptyConfig {
    diag("Testing default config");
    my $Cfg = Plerd::Config->new;

    # properties => default values
    my %baselines = (
        author_email => 's.handwich@localhost',
        author_name => 'Sam Handwich',
        base_uri => 'http://localhost/',
        image_alt => '[image]',
        title => 'Another Plerd Blog',
        config_file => "$ENV{HOME}/.plerd.conf"
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }

    ok(!$Cfg->has_image, "image is not set (via predicate)");
}

sub TestConfigWithPubDir {
    diag("Testing config with publication_directory");

    my $pubDir = "/var/lib/html";
    my $Cfg = Plerd::Config->new(publication_directory => $pubDir);

    # properties => default values
    my %baselines = (
        "publication_directory" => $pubDir,
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }
}


sub TestRunAtDefaultLocation {
    my $config = Plerd::Config->new(config_file => "./new-site.conf");
    $config->initialize();
    ok(-d "new-site", "Default site directory 'new-site' exists");
    ok(-e "./new-site.conf", "Site config was created");   

    my $reread_config = Plerd::Config->new(config_file => "./new-site.conf");
    ok($reread_config->unserialize, "Unserialized new config");
    for my $property (qw(
                path publication_directory source_directory
                database_directory template_directory run_directory log_directory
    )) {
        ok($config->$property eq $reread_config->$property, "Property $property is the same");
        # diag($config->$property . " => " . $reread_config->$property);
    }
}

sub TestRunAtSpecifiedLocation {
    my $config = Plerd::Config->new(config_file => "./new-site2.conf", path => "./new-site2");
    $config->initialize();
    ok(-d "new-site2", "Default site directory 'new-site2' exists");
    ok(-e "./new-site2.conf", "Site config was created");   
}

#----------
# Helpers
sub Main {
    setup();

    TestEmptyConfig();
    TestConfigWithPubDir(); 
    TestRunAtDefaultLocation();
    TestRunAtSpecifiedLocation();

    teardown();
    done_testing();
}

sub setup {
    if (-d $gBaseDir) {
        $gBaseDir->rmtree;
    }

    $gBaseDir->mkpath;
    chdir $gBaseDir || die("assert");
}

sub teardown {
    chdir "..";
    $gBaseDir->rmtree;
}

