use warnings;
use strict;
use Path::Class::File;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd::Config;
use Plerd::Model::Post;

Main();
exit;

#--------------
# Tests
#--------------
sub TestEmptyPost {
    ok(Plerd::Model::Post->new(source_file => "./first_post.md"), "Created an empty post object");
}

sub TestPostWithEmptySource {
    my $source_file = Path::Class::File->new("$FindBin::Bin", "source_model", "no-title.md");
    my $post = Plerd::Model::Post->new(source_file => $source_file);
    diag("Source file: " . $source_file);

    ok($post->load_source, "Loading source file");
    ok(!$post->has_title, "Post has no title");
    ok($post->has_body, "Post does have a body");
    ok(!$post->can_publish, "Post cannot be published");
    diag("Published filename would be: " . $post->published_filename);
}

sub TestPostWithFormatedTitle {
    my $source_file = Path::Class::File->new("$FindBin::Bin", "source_model", "formatted-title.md");
    my $post = Plerd::Model::Post->new(source_file => $source_file);
    diag("Source file: " . $source_file);

    ok($post->load_source, "Loading source file");
    ok($post->has_title, "Post has title: " . $post->title);
    ok($post->has_body, "Post does have a body");
    ok($post->can_publish, "Post can be published");
    diag("Published filename would be: " . $post->published_filename);
}

sub TestPostAttributeSerialization {

    my $source_file = Path::Class::File->new("$FindBin::Bin", "source_model", "extra-headers.md");
    my $config = Plerd::Config->new(database_directory => "$FindBin::Bin/init/db");
    my $post = Plerd::Model::Post->new(source_file => $source_file, config => $config);
    ok($post->load_source, "Loading source file");
    my $attrs = $post->attributes;
    ok($post->_store($attrs), "Storing post attributes (" . keys(%$attrs) . " keys)");
    my $got_attrs = $post->_retrieve;
    diag("Dumping stored attributes");
    for my $key (sort keys %$got_attrs) {
        diag(sprintf("  %s => %s", $key, $got_attrs->{$key}));
    }
    ok(scalar (keys %$attrs) == scalar (keys %$got_attrs), "Retrieved stored keys");
    $config->database_directory->rmtree;
}
#--------------
# Helpers
#--------------
sub Main {
    setup();

    TestEmptyPost();
    TestPostWithEmptySource();
    TestPostWithFormatedTitle();
    TestPostAttributeSerialization();
    
    teardown();

    done_testing();
}

sub setup {
}

sub teardown {
}