use Modern::Perl '2018';

use Test::More;
use Path::Class::Dir;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd::Model::Tag;

our $gDB_DIR;
our $gSRC_DIR;

Main();
exit;

#--------------
# Tests
#--------------
sub TestNameLogic {
    my %baselines = (
        'cat' => 'cat',
        'Dog' => 'Dog',
        'Foo BaR' => 'Foo_BaR',
        'An <em>important</em> LESSON' => 'An_important_LESSON',
    );

    for my $tag (keys %baselines) {
        my $t = Plerd::Model::Tag->new(name => $tag);
        ok($t->name eq $baselines{$tag}, "Canonicalized '$tag' to '" . $t->name . "'");
    } 
}

sub TestTagsDBCreate {
    my $Tags = Plerd::Model::Tag->new(db_directory => $gDB_DIR);

    # source_file_basename => [tag1, tag2, etc..]
    my %baselines = ('01.md' => ['foo', 'bar bar'],
                     '02.md' => ['bar bar', 'baz'],
                     '03.md' => ['foo', 'baz']
                    );

    while (my ($src_file, $tags) = each %baselines) {
        my $source_file = Path::Class::File->new($gSRC_DIR, $src_file);

        for my $tag (@$tags) {
            ok($Tags->add_source_to_db($tag, $source_file), "Added $source_file -> tag '$tag'");
            ok($Tags->tag_has_source($tag, $source_file), "Verified $source_file is in tag DB");
        }
    }
}

sub TestTagsDBListSources {
    my $Tags = Plerd::Model::Tag->new(db_directory => $gDB_DIR);

    my %baselines = (
        'foo' => [ '01.md', '03.md' ],
        'bar bar' => [ '01.md', '02.md'],
        'baz' => [ '03.md', '02.md' ],
        'nonesuch' => [],
    );

    while (my ($tag, $expected) = each %baselines) {
        $tag = Plerd::Model::Tag->new(name => $tag);
        my $sources = $Tags->get_sources_by_tag($tag);
        ok(defined $sources, "Got " . @$sources . " for tag '" . $tag->name . "'");
        ok(@$expected == @$sources, "  Got the expected number of sources returned");
    
        for my $src (@$expected) {
            my $source_file = Path::Class::File->new($gSRC_DIR, $src);
            my $found = 0;
            for my $got (@$sources) {
                if ($got->stringify eq $source_file->stringify) {
                    $found = 1;
                    last;
                }
            }
            ok($found, "  Found '$src' in '" . $tag->name . "'");
        }
    }
}

sub TestTagsDBRemove {
    my $Tags = Plerd::Model::Tag->new(db_directory => $gDB_DIR);

    # source_file_basename => [tag1, tag2, etc..]
    my %baselines = (
                     'foo' => ['03.md'],
                     'bar bar' => ['02.md']
                    );

    while (my ($tag, $src_files) = each %baselines) {
        for my $src_file (@$src_files) {
            my $s = Path::Class::File->new($gSRC_DIR, $src_file);
            ok($Tags->remove_source_from_db($tag, $s), "Removed '$src_file' from tag '$tag'");
            ok(!$Tags->tag_has_source($tag, $s), "Verified '$tag' no longer has '$src_file'");
        }
    }
}

#--------------
# Helpers
#--------------
sub Main {
    setup();

    TestNameLogic();
    TestTagsDBCreate();
    TestTagsDBListSources();
    TestTagsDBRemove();

    teardown();

    done_testing();
}

sub setup {
    $gDB_DIR = Path::Class::Dir->new($FindBin::Bin, "tag_db");
    if (-d $gDB_DIR) {
        $gDB_DIR->rmtree();
    }
    $gDB_DIR->mkpath(undef, 0755);

    # Purely fictional directory, none of the tags opts need these files to actually exist
    $gSRC_DIR = Path::Class::Dir->new($FindBin::Bin, "tag_source_dir");

}

sub teardown {
    $gDB_DIR->rmtree();
}