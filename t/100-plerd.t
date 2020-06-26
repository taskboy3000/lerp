use Modern::Perl '2018';

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
    ok($plerd->publish_post($post), "Published post without tags");
    ok(-s $post->publication_file, "Published file exists and is non-empty: " . $post->publication_file->basename);
    ok(!$plerd->publish_post($post), "Plerd declined to republish unchanged file");
    $source_file->touch;
    $post->clear_source_file_mtime;
    ok($plerd->publish_post($post), "Plerd republished an updated source file");

    diag("Creating a post with tags");
    my $source_file2 = Path::Class::File->new(
        $config->source_directory,
        'two_tags.md'
    );

    my $post2 = Plerd::Model::Post->new(
        config => $config, 
        source_file => $source_file2
    );
    diag("Src: " . $source_file2);
    ok($plerd->publish_post($post2), "Published post with tags");
    ok(-s $post2->publication_file, "Published file exists and is non-empty: " . $post2->publication_file->basename);

    my $tm = $plerd->tag_memory;
    for my $tag (@{$post2->tags}) {
        ok($tm->exists($tag->name), 'Tag ' . $tag->name . ' exists');
    }
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