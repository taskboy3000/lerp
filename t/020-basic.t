use warnings;
use strict;
use Test::More;
use Test::Warn;
use Path::Class::Dir;
use Path::Class::File;
use URI;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/../lib";

our $gBLOG_DIR;
our $gPLERD;
our $gSOURCE_DIR;
our $gDOCROOT_DIR;
our $gMODEL_DIR;
our $gYMD;

Main();
exit;

#-------
# Tests
sub TestDefaultPublishAll {
    eval { $gPLERD->publish_all; };
    like ( $@, qr/not in W3C format/, 'Rejected source file with invalid timestamp.' );
}

sub TestRemoveBadDate {
    unlink "$gBLOG_DIR/source/bad-date.md";

    eval { $gPLERD->publish_all; };
    like ( $@, qr/post title/, 'Rejected title-free source file.' );
}

sub TestRemoveNoTitle {
    unlink "$gBLOG_DIR/source/no-title.md";
    my $ok = 0;
    eval { $gPLERD->publish_all; $ok=1};
    ok($ok, "Publishing succeeded after removing problematic no-title.md");
}

sub TestExpectedNumberOfDirs {
    # The "+6" below accounts for the generated recent, archive, and RSS files,
    # a index.html symlink, a JSON feed file, and a tags directory.
    my $expected_docroot_count = scalar( $gSOURCE_DIR->children( no_hidden => 1 ) ) + 6;
    is( scalar( $gDOCROOT_DIR->children ),
                $expected_docroot_count,
                "Correct number of files generated in docroot."
    );
}

sub TestReadingTime {
    my $post = $gPLERD->posts->[-1];
    is ( $post->reading_time, 4, 'Reading time is as expected.' );
}

sub TestDatesAndTimezones {
    my $post = $gPLERD->posts->[-1];
    is ( $post->utc_date->offset, 0, 'Output of utc_date looks correct.' );
}

sub TestFormatting {
    my $post = Path::Class::File->new( $gDOCROOT_DIR, '1999-01-01-backdated.html' )->slurp;
    like ( $post,
        qr{an <em>example</em> of a “backdated},
        'Post title is formatted.'
        );
    my $json = Path::Class::File->new( $gDOCROOT_DIR, 'feed.json' )->slurp;
    like ( $json,
        qr{A good source file},
        'JSON Feed file has HTML-stripped titles.',
        );

}

sub TestFileNaming {
    my $renamed_file =
        Path::Class::File->new( $gDOCROOT_DIR, $gYMD . '-a-good-source-file.html' );
    my $not_renamed_file =
        Path::Class::File->new( $gDOCROOT_DIR, '1999-01-01-backdated.html' );
    is (-e $renamed_file, 1, 'Source file with dateless filename named as expected.' );
    is (-e $not_renamed_file, 1, 'Source file with backdated filename named as expected.' );

    my $renamed_file_with_funky_title =
        Path::Class::File->new(
            $gDOCROOT_DIR,
            $gYMD . '-apostrophes-and-html-shouldnt-turn-into-garbage.html',
        );
    is (
        -e $renamed_file_with_funky_title,
        1,
        'Source file with formatted title received a nice clean published filename.'
    );
}

sub TestTags {
    my $tag_index_file =
        Path::Class::File->new( $gDOCROOT_DIR, 'tags', 'index.html' );
    my $tag_detail_file =
        Path::Class::File->new( $gDOCROOT_DIR, 'tags', 'bar with spaces.html' );

    is (-e $tag_index_file, 1, 'Tag index file created.');
    is (-e $tag_detail_file, 1, 'Tag detail file created.');

    is ($gPLERD->has_tags, 1, 'The blog knows that it has tags.');

    my $tag_index_content = $tag_index_file->slurp;
    like(
        $tag_index_content,
        qr{<h1>All Tags.*<li>.*<li>.*</ul>.*sidebar"}s,
        "The tag-index page links to two tags.",
    );
}

sub TestPlerdProperties {
    my $thisPlerd = shift;
    my @optional_properties = qw[
        image
    ];

    for my $property (@optional_properties) {
        my $predicate = "has_$property";
        if ($thisPlerd->$predicate) {
            ok($thisPlerd->$property, "optional $property is initialized");
        } else {
            ok(1, "optional $property is not initialized");
        }
    }

    my @properties = qw[
        path
        archive_file
        archive_template_file
        author_email
        author_name
        base_uri
        datetime_formatter
        directory
        image_alt
        jsonfeed_file
        jsonfeed_template_file
        post_parsing_errors
        post_template_file
        publication_path
        publication_directory
        recent_file
        recent_posts_maxsize
        rss_file
        rss_template_file
        tag_case_conflicts
        tags_index_uri
        tags_map
        tags_publication_path
        tags_publication_directory
        tags_template_file
        template
        template_path
        template_directory
        title
        database_path 
        database_directory 
        source_path 
        source_directory
        ];

    for my $property (@properties) {
        # diag("$property => " . $thisPlerd->$property);
        ok($thisPlerd->$property, "$property is initialized");
    }
}

sub TestListSources {
    my ($thisPlerd) = @_;

    diag("Examining " . $thisPlerd->source_directory . " for source files");
    my $sourceFiles = $thisPlerd->get_source_files;
    diag("Found " . @$sourceFiles . " source files");

#    for my $sourceFile (@$sourceFiles) {
#        diag($sourceFile);
#    }

    ok(@$sourceFiles, "Got list of sorted source files");
}

sub TestGetPosts {
    my ($thisPlerd) = @_;
    my $posts = $thisPlerd->get_posts;
    for my $errorPair (@{ $thisPlerd->post_parsing_errors }) {
        my ($src, $error) = @$errorPair;
        diag("Broken source: $src - $error");
    }
    diag("Found " . @$posts . " valid posts");

#    for my $post (@{$posts}) {
#        diag($post->source_file);
#    }

    ok(@$posts, "Got a list of posts");

    my $sourceFiles = $thisPlerd->get_source_files;
    ok(@$sourceFiles > @$posts, "Number of plerd posts is less than the number of source files");
}

sub TestSortPosts {
    my ($thisPlerd) = @_;
    my $posts = $thisPlerd->sort_posts;
#    for my $post (@$posts) {
#        diag($post->source_file);
#    }

    ok(@$posts, "Got sorted posts");

    # First post is always "today", which is not stable for testing
    my $second_post_basename = $posts->[1]->source_file->basename;
    my $expected_second_post_basename = 'empty_tags.md';

    my $last_post_basename = $posts->[-1]->source_file->basename;
    my $expected_last_post_basename = '1999-01-01-backdated.md';

    ok($second_post_basename eq $expected_second_post_basename, "Expected second post '$expected_second_post_basename', got: " . $second_post_basename);
    ok($last_post_basename eq $expected_last_post_basename, "Got expected last post: " . $last_post_basename);

    $posts = $thisPlerd->sort_posts([ @$posts[3,2,1,5] ]);
#    for my $post (@$posts) {
#        diag($post->source_file);
#    }
    ok(@$posts == 4, "Got expected reduced number of sorted posts");

    my $first_post_basename = $posts->[0]->source_file->basename;
    my $expected_first_post_basename = 'good-source-file.md';

    $last_post_basename = $posts->[-1]->source_file->basename;
    $expected_last_post_basename = 'metatag-setup.md';

    ok($first_post_basename eq $expected_first_post_basename, "Got expected first post: " . $first_post_basename);
    ok($last_post_basename eq $expected_last_post_basename, "Expected last post '$expected_last_post_basename'; got: " . $last_post_basename);
}

#---------
# Helpers
sub Main {
    setup();

    TestPlerdProperties($gPLERD);
    TestListSources($gPLERD);
    TestGetPosts($gPLERD);
    TestSortPosts($gPLERD);

    if (0) {
        TestDefaultPublishAll();
        TestRemoveBadDate();
        TestRemoveNoTitle();
        TestExpectedNumberOfDirs();
        TestReadingTime();
        TestDatesAndTimezones();
        TestFormatting();
        TestFileNaming();
        TestTags();
    }

    teardown();

    done_testing();
}

sub setup {
    use_ok( 'Plerd' );
    require Plerd::Init;
    Plerd::Init->import();

    $gBLOG_DIR  = Path::Class::Dir->new( "$FindBin::Bin/testblog" );
    $gBLOG_DIR->rmtree;

    my $init_messages_ref = Plerd::Init::initialize( $gBLOG_DIR->stringify, 0 );
    unless (-e $gBLOG_DIR) {
        die "Failed to create $gBLOG_DIR: @$init_messages_ref\n";
    }

    my $now = DateTime->now( time_zone => 'local' );
    $gYMD = $now->ymd;

    # @fixme: all these dirs need to be global
    $gSOURCE_DIR = Path::Class::Dir->new( $gBLOG_DIR, 'source' );
    $gDOCROOT_DIR = Path::Class::Dir->new( $gBLOG_DIR, 'docroot' );
    $gMODEL_DIR = Path::Class::Dir->new( "$FindBin::Bin/source_model" );
    foreach ( Path::Class::Dir->new( "$FindBin::Bin/source_model" )->children ) {
        my $filename = $_->basename;
        $filename =~ s/TODAY/$gYMD/;
        my $destination = Path::Class::File->new( $gSOURCE_DIR, $filename );
        $_->copy_to( $destination );
    }

    # Now try to make a Plerd object, and send it through its paces.
    $gPLERD = _setup_make_plerd();
}

sub _setup_make_plerd {
    return Plerd->new(
                path         => $gBLOG_DIR->stringify,
                title        => 'Test Blog',
                author_name  => 'Nobody',
                author_email => 'nobody@example.com',
                base_uri     => URI->new ( 'http://blog.example.com/' ),
        )
}

sub teardown {
    $gBLOG_DIR->rmtree if $gBLOG_DIR;
}

=pod


### Test warns when tags have case conflicts.
{
my $naughty_file = Path::Class::File->new( $gSOURCE_DIR, 'bad_case.md' );
$naughty_file->spew(qq{title: Naughty tag!
tags: FOO

Oh no, this post has a tag whose case conflicts with an existing one.
});
$plerd->publish_all;
warning_like {$plerd->publish_all} qr/conflicts/,
    'Tag case-conflicts generate a warning';
unlink $naughty_file;
}

### Make sure re-titling posts works as expected
{
my $source_file = Path::Class::File->new( $gSOURCE_DIR, 'good-source-file.md' );
my $text = $source_file->slurp;
$text =~ s/title: A good source file/title: A retitled source file/;
$source_file->spew( $text );

$plerd->publish_all;

my $welcome_file = Path::Class::File->new(
    $gDOCROOT_DIR,
    $gYMD . '-a-good-source-file.html',
);
my $unwelcome_file = Path::Class::File->new(
    $gDOCROOT_DIR,
    $gYMD . '-a-retitled-source-file.html',
);

is ( $gDOCROOT_DIR->contains( $welcome_file ),
     1,
     'A file named after the old title is still there.',
);
isnt ( $gDOCROOT_DIR->contains( $unwelcome_file ),
     1,
     'A file named after the new title is not there.',
);

$text =~ s/-a-good-source-file/-a-retitled-source-file/;
$source_file->spew( $text );

$plerd->publish_all;
is ( $gDOCROOT_DIR->contains( $unwelcome_file ),
     1,
     'A file named after the new title is there now.',
);

### Test GUIDs
$plerd->publish_all;
like ( $source_file->slurp,
       qr/guid: /,
       'Source file contains a GUID, as expected.',
);

### Make sure descriptions work in different cases.
is ( $plerd->post_with_url( "http://blog.example.com/$gYMD-metatags.html" )->description,
     'Fun with social metatags.',
     'Manually-set post description works.',
);
like ( $plerd->post_with_url( "http://blog.example.com/$gYMD-metatags-with-image.html" )->description,
    qr/This file sets up some attributes/,
    'Automatically derived description works.',
);
like ( $plerd->post_with_url( "http://blog.example.com/$gYMD-metatags-with-image-and-alt.html" )->description,
    qr/This file, which is awesome, sets up some attributes/,
    'Automatically derived description works, with leading image tag present.',
);

# make sure that multimarkdown tables work
like ( $plerd->post_with_url( "http://blog.example.com/$gYMD-markdown-table.html")->body,
    qr{<td>Pizza</td>},
    'Markdown tables are rendered.',
);

### Test miscellaneous-attribute pass-through
# We need to edit the post template so it'll do something with a received
# pass-through attribute.
my $post_template =
    Path::Class::File->new(
        $gBLOG_DIR,
        'templates',
        'post.tt',
    );
my $post_template_content = $post_template->slurp;
$post_template_content =~
    s{<div class="body e-content">}
    {<div class="byline">[% post.attributes.byline %]</div><div class="body e-content">};
$post_template->spew( $post_template_content );
$plerd->publish_all;

my $byline_post =
    Path::Class::File->new(
        $gDOCROOT_DIR,
        '2000-01-01-this-post-has-extra-headers.html',
    );

like( $byline_post->slurp,
      qr/"byline">Sam Handwich/,
      'Miscellaneous header passed through to the template',
);

### Test newer / older post links
  # (Including robustness after new posts are added)
my $new_post =
    Path::Class::File->new(
        $gSOURCE_DIR,
        'another_post.md',
    );
$new_post->spew( "title:Blah\n\nWords, words, words." );
$expected_docroot_count++;
$plerd->publish_all;

my $first_post = $plerd->posts->[0];
my $second_post = $plerd->posts->[1];
my $third_post = $plerd->posts->[2];
my $last_post = $plerd->posts->[-1];
my $penultimate_post = $plerd->posts->[-2];
is( $first_post->newer_post, undef, 'First post has no newer post.' );
is( $first_post->older_post,
    $second_post,
    'First post has correct older post.'
);
is( $second_post->newer_post,
    $first_post,
    'Second post has correct newer post.'
);
is( $second_post->older_post,
    $third_post,
    'Second post has correct older post.'
);
is( $last_post->older_post,
    undef,
    'Last post has no older post.'
);
is( $last_post->newer_post,
    $penultimate_post,
    'Last post has correct newer post.'
);

}

### Test trailing no slash on base_uri
{
my $plerd = Plerd->new(
    path         => $gBLOG_DIR->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://www.example.com/blog' ),
);

$plerd->publish_all;
like ( Path::Class::File->new( $gDOCROOT_DIR, 'recent.html' )->slurp,
     qr{http://www.example.com/blog/\d{4}-\d{2}-\d{2}-blah.html},
     'Base URIs missing trailing slashes work',
);

}

### Test using alternate config paths
{
$gDOCROOT_DIR->rmtree;
$gDOCROOT_DIR->mkpath;

my $alt_config_plerd = Plerd->new(
    source_path       => "$gBLOG_DIR/source",
    publication_path  => "$gBLOG_DIR/docroot",
    template_path     => "$gBLOG_DIR/templates",
    database_path     => "$gBLOG_DIR/db",
    title             => 'Test Blog',
    author_name       => 'Nobody',
    author_email      => 'nobody@example.com',
    base_uri          => URI->new ( 'http://blog.example.com/' ),
);

$alt_config_plerd->publish_all;
is( scalar( $gDOCROOT_DIR->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);
}

### Test social-media metatags.
{
my $social_plerd = Plerd->new(
    path         => $gBLOG_DIR->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
    image        => URI->new ( 'http://blog.example.com/logo.png' ),
    facebook_id  => 'This is a fake Facebook ID',
    twitter_id   => 'This is a fake Twitter ID',
);

$social_plerd->publish_all;

my $post = Path::Class::File->new( $gDOCROOT_DIR, "$gYMD-metatags.html" )->slurp;
my $image_post = Path::Class::File->new( $gDOCROOT_DIR, "$gYMD-metatags-with-image.html" )->slurp;
my $alt_image_post = Path::Class::File->new( $gDOCROOT_DIR, "$gYMD-metatags-with-image-and-alt.html" )->slurp;


like( $post,
    qr{name="twitter:image" content="http://blog.example.com/logo.png"},
    'Metatags: Default image',
);
like( $image_post,
    qr{name="twitter:image" content="http://blog.example.com/example.png"},
    'Metatags: Post image',
);
like( $alt_image_post,
    qr{name="twitter:image:alt" content="A lovely bunch of coconuts."},
    'Metatags: Post-specific alt-text',
);
like( $image_post,
    qr{name="twitter:image:alt" content=""},
    'Metatags: Empty default alt-text',
);

like( $post,
    qr{name="twitter:card" content="summary"},
    'Metatags: Default image is a thumbnail',
);
like( $image_post,
    qr{name="twitter:card" content="summary_large_image"},
    'Metatags: Post image is full-sized',
);

like( $post,
    qr{name="twitter:description" content="Fun with social metatags.},
    'Metatags: Defined description',
);

like ( $image_post,
    qr{name="twitter:description" content="This file sets up some attributes},
    'Metatags: Default description (with markup stripped)',
);

# Now add some alt text...
$social_plerd = Plerd->new(
    path         => $gBLOG_DIR->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
    image        => URI->new ( 'http://blog.example.com/logo.png' ),
    facebook_id  => 'This is a fake Facebook ID',
    twitter_id   => 'This is a fake Twitter ID',
    image_alt    => 'Just a test image.',
);

$social_plerd->publish_all;
$post = Path::Class::File->new( $gDOCROOT_DIR, "$gYMD-metatags.html" )->slurp;
like( $post,
    qr{name="twitter:image:alt" content="Just a test image."},
    'Metatags: Defined default alt-text',
);

}

done_testing();
