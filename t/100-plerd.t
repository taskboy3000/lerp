use Modern::Perl '2018';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Path::Class::File;
use Test::More;

use Plerd;
use Plerd::Model::Post;
use Plerd::Model::TagIndex;

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
    $DB::single=1;
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

    my $tm = $plerd->config->tag_memory;
    for my $tag (@{$post2->tags}) {
        ok($tm->exists($tag->name), 'Tag ' . $tag->name . ' exists');
    }
    ok($config->path->rmtree, "Removed test site");
}


sub TestTagMemory {
    diag(" Testing tag memory");

    my $plerd = Plerd->new();
    $plerd->config->path("init/new-site");
    $plerd->config->initialize();

    my $TIdx = $plerd->tags_index;  

    my $post1 = Plerd::Model::Post->new(
        config => $plerd->config,
        source_file => "$FindBin::Bin/source_model/one_tag.md"
    );
    $post1->load_source;

    my $post2 = Plerd::Model::Post->new(
        config => $plerd->config,
        source_file => "$FindBin::Bin/source_model/two_tags.md"
    );
    $post2->load_source;

    for my $tag (@{$post1->tags}) {
        ok($TIdx->update_tag_for_post($tag, $post1), 
            "Updating tag " . $tag->name . " for post " . $post1->source_file->basename
        );
    }

    for my $tag (@{$post2->tags}) {
        ok($TIdx->update_tag_for_post($tag, $post2),
            "Updating tag " . $tag->name . " for post " . $post2->source_file->basename
        );
    }

    my $links = $TIdx->get_tag_links;
    ok (defined $links, "Got tag links structure");

    for my $letter (sort keys %$links) {
        diag("  $letter");
        for my $tag (sort keys %{$links->{$letter}}) {
            diag("    tag: $tag");
            for my $rec (@{ $links->{$letter}->{$tag} }) {
                diag("      post: $rec->{title}");
            }
        }
    }

    my $foo_tag;
    for my $tag (@{ $post2->tags }) {
        if ($tag->name eq 'foo') {
            $foo_tag = $tag;
        }
    }
    ok($TIdx->remove_tag_from_post($foo_tag, $post2), "Removing tag 'foo' from post " . $post2->source_file->basename);
    $links = $TIdx->get_tag_links;
    
    for my $letter (sort keys %$links) {
        diag("  $letter");
        for my $tag (sort keys %{$links->{$letter}}) {
            diag("    tag: $tag");
            for my $rec (@{ $links->{$letter}->{$tag} }) {
                diag("      post: $rec->{title}");
            }
        }
    }

    $plerd->config->path->rmtree;
}

#---------
# Helpers
#---------
sub Main {
    setup();

    TestInvoked();
    TestSourceListing();
    TestPublishingOnePost();
    TestTagMemory();

    teardown();

    done_testing();
}

sub setup {

}

sub teardown {
    
}