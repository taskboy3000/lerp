# unit test for Plerd::Config;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use Plerd::Config;

Main();
exit;

#-------
# Tests
#-------
sub TestEmptyConfig {
    diag("Testing default config");
    my $Cfg = Plerd::Config->new;

    # properties => default values
    my %baselines = (
        "base_uri" => 'http://plerd.org/',
        "path" => ".",
        "publication_directory" => "docroot",
        "database_directory" => "db",
        "image_alt" => "[image]",
        "source_directory" => "source",
        "tags_publication_directory" => "docroot/tags",
        "title" => "Another Plerd Blog",
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }

    ok(!$Cfg->has_author_email, "author_email is not set (via predicate)");
    ok(!$Cfg->has_author_name, "author_name is not set (via predicate)");
    ok(!$Cfg->has_image, "image is not set (via predicate)");
}

sub TestConfigWithPath {
    diag("Testing config with path");

    my $path = "/somedir";

    my $Cfg = Plerd::Config->new(path => $path);

    # properties => default values
    my %baselines = (
        "path" => $path,
        "publication_directory" => "$path/docroot"
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }
}

sub TestConfigWithPubDir {
    diag("Testing config with publication_directory");

    my $pubDir = "/var/lib/html";
    my $Cfg = Plerd::Config->new(publication_directory => $pubDir);

    # properties => default values
    my %baselines = (
        "path" => ".",
        "publication_directory" => $pubDir,
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }
}

sub TestConfigWithOverrides {
    diag("Testing config with overrides");

    my $baseUri = 'http://taskboy.com/blog/';
    my $author_name = 'Sam Handwich';
    my $author_email = 'sam.handwich@pobox.com';

    my $Cfg = Plerd::Config->new(
        base_uri => $baseUri,
        author_name => $author_name,
        author_email => $author_email,
    );

    # properties => default values
    my %baselines = (
        base_uri => $baseUri,
        author_name => $author_name,
        author_email => $author_email,
    );

    for my $property (keys %baselines) {
        ok($Cfg->$property eq $baselines{$property},
            "Property '$property' has expected default");
    }

    ok($Cfg->has_author_email, "author_email *is* set (via predicate)");
    ok($Cfg->has_author_name, "author_name *is* set (via predicate)");

    
}

#---------
# Helpers
#---------
sub Main {
    setup();

    TestEmptyConfig();
    TestConfigWithPath();
    TestConfigWithPubDir();
    TestConfigWithOverrides();

    teardown();

    done_testing();
}

sub setup {

}

sub teardown {
    
}