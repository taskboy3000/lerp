use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Path::Class::File;
use Test::More;

use Plerd;
use Plerd::Model::Post;

Main();
exit;

#----------------
# Tests
#----------------
sub TestInvoked {
    my $plerd = Plerd->new;
    ok($plerd, "Plerd instantiated");
}

sub TestSourceListing {
    my $plerd = Plerd->new;
    my $config = $plerd->config;
    $config->source_directory("$FindBin::Bin/source_model");

    my $first_fetch = $plerd->next_source_file;
    ok(defined $first_fetch, "next_source_file");

    diag("Src: " . $first_fetch) if defined $first_fetch;
    while (my $source_file = $plerd->next_source_file) {
        diag("Src: " . $source_file);
    }

    ok(1, "Loop appeared to terminate");

    my $refetch = $plerd->next_source_file;
    if (defined $refetch && defined $first_fetch) {
        ok($first_fetch eq $refetch, "Interator restarted correctly");
    }
}

sub TestPublishingOnePost {
    my $plerd = Plerd->new;
    my $config = $plerd->config;
    $config->path("$FindBin::Bin/init/new-site");
    $config->source_directory("$FindBin::Bin/source_model");

    ok($config->initialize, "Creating test site for publication");

    # A post without tags
    my $source_file = Path::Class::File->new(
        $config->source_directory,
        'empty_tags.md'
    );

    my $post = Plerd::Model::Post->new(
        config => $config, 
        source_file => $source_file
    );
    diag("Src: " . $source_file);
    ok($plerd->publish_post($post), "Publish post without tags");
    ok(-s $post->publication_file, "Published file exists and is non-empty: " . $post->publication_file->basename);
    ok($config->path->rmtree, "Removed test site");
}

#---------
# Helpers
#---------
sub Main {
    setup();

    TestInvoked();
    TestSourceListing();
    TestPublishingOnePost();

    teardown();

    done_testing();
}

sub setup {

}

sub teardown {
    
}