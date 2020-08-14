# Joe Johnston <jjohn@taskboy.com>, based on original work from
# Jason McIntosh <jmac@jmac.org>
package Plerd;
use Modern::Perl '2018';

use JSON;
use Moo;
use Template;
use Template::Stash;
use Text::MultiMarkdown qw( markdown );

use Plerd::Config;
use Plerd::Model::Archive;
use Plerd::Model::FrontPage;
use Plerd::Model::JSONFeed;
use Plerd::Model::Note;
use Plerd::Model::NoteJSONFeed;
use Plerd::Model::NotesRoll;
use Plerd::Model::Post;
use Plerd::Model::RSSFeed;
use Plerd::Model::SiteCSS;
use Plerd::Model::SiteJavaScript;
use Plerd::Model::TagIndex;
use Plerd::SmartyPants;
use Plerd::Remembrancer;

#-------------------------------
# Attributes and Builders
# (Please try to keep this alphabetized)
#-------------------------------
has 'archive' => (
    is => 'ro',
    lazy => 1,
    predicate => 1,
    builder => '_build_archive'
);
sub _build_archive {
    my ($self) = @_;
    Plerd::Model::Archive->new(config => $self->config);
}

has 'config' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_config'
);
sub _build_config {
    Plerd::Config->new;
}

has 'front_page' => (
    is => 'ro',
    lazy => 1,
    predicate => 1,
    builder => '_build_front_page'
);
sub _build_front_page {
    my ($self) = @_;
    Plerd::Model::FrontPage->new(config => $self->config);
}

has 'json_feed' => (
    is => 'ro',
    clearer => 1,
    lazy => 1,
    predicate => 1,
    builder => '_build_json_feed',
);
sub _build_json_feed {
    my ($self) = @_;
    Plerd::Model::JSONFeed->new(config => $self->config);
}

has 'notes_json_feed' => (
    is => 'ro',
    builder => '_build_notes_json_feed'
);
sub _build_notes_json_feed {
    my ($self) = @_;
    Plerd::Model::NoteJSONFeed->new(config => $self->config);
}

has 'notes_roll' => (
    is => 'ro',
    builder => '_build_notes_roll'
);
sub _build_notes_roll {
    my ($self) = shift;
    Plerd::Model::NotesRoll->new(config=> $self->config);
}

has 'publisher' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_publisher'
);
sub _build_publisher {
    my ($self) = @_;
    my %params = (
        INCLUDE_PATH => $self->config->template_directory,
        ABSOLUTE => 1,
        PRE_DEFINE => {
            archive => $self->archive,
            config => $self->config,
            frontPage => $self->front_page,
            jsonFeed => $self->json_feed,
            notesJSONFeed => $self->notes_json_feed,
            notesRoll => $self->notes_roll,
            rssFeed => $self->rss_feed,
            siteCSS => $self->site_css,
            siteJS => $self->site_js,
            siteDescription => $self->site_description,
            tagsIndex => $self->tags_index,
            w3validatorURI => URI->new("https://validator.w3.org/nu/"),
        }
    );
    my $json = JSON->new;

    $Template::Stash::HASH_OPS->{json} = sub {
        $json->encode($_[0]);
    };
    $Template::Stash::LIST_OPS->{json} = sub {
        $json->encode($_[0]);
    };

    return Template->new(%params);
}

has 'rss_feed' => (
    is => 'ro',
    clearer => 1,
    lazy => 1,
    predicate => 1,
    builder => '_build_rss_feed',
);
sub _build_rss_feed {
    my ($self) = @_;
    Plerd::Model::RSSFeed->new(config => $self->config);
}

has 'site_css' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_site_css'
);
sub _build_site_css {
    my ($self) = @_;
    Plerd::Model::SiteCSS->new(config => $self->config);
}

has 'site_description' => (
    is => 'ro', 
    lazy => 1,
    builder => '_build_site_description',
    predicate => 1,
);
sub _build_site_description {
    my ($self) = @_;

    my $site_description = $self->config->site_description;
    if ($site_description) {
        return Plerd::SmartyPants::process(markdown($site_description));
    }

    my $author = $self->config->author_name;
    my $email = $self->config->author_email;

    my $default_description = <<"EOT";
This is a blog by [$author](mailto:$email).
EOT

    return markdown($default_description);
}

has 'site_js' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_site_js'
);
sub _build_site_js {
    my ($self) = @_;
    Plerd::Model::SiteJavaScript->new(config => $self->config);
}

has 'sorted_source_files' => (
    is => 'rw',
    clearer => 1,
    predicate => 1,
);

has 'tags_index' => (
    is => 'ro',
    clearer => 1,
    lazy => 1,
    predicate => 1,
    builder => '_build_tags_index',
);
sub _build_tags_index {
    my ($self) = @_;
    Plerd::Model::TagIndex->new(config => $self->config);
}


#-----------------
# Public Methods
#-----------------
sub publish_post {
    my ($self, $post) = (shift, shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    if (!$post->has_source_file) {
        die("assert - post has no source file");
    }

    # Does this post need to be regenerated?
    my $post_memory = $self->config->post_memory;
    my $post_key = $post->publication_file->basename;

    if (!$opts{force}) {
        if (my $memory = $post_memory->load($post_key)) {
            if ($memory->{mtime} >= $post->source_file->stat->mtime) {
                # the cache is newer than the source.
                # decline to proceed.
                if ($opts{verbose}) {
                    say "Declining to reprocess unchanged " . $post->source_file->basename;
                }
                return;
            }
        }
    }

    if (!$post->source_file_loaded) {
        $post->load_source;
    }

    if (!$post->can_publish) {
        if ($opts{verbose}) {
            say "Post cannot be published without both a title and body."
        }
        return;
    }

    if ($post->attributes_have_changed) {
        $post->serialize_source
    }

    # @todo: make it so that I don't have to do this
    # hydrate tags
    for my $tag (@{ $post->tags }) {
        $tag->config($self->config);
    }

    if ($self->_publish(
            $post->template_file,
            $post->publication_file,
            { post => $post, thisURI => $post->uri })
    ) {
        if ($opts{verbose}) {
            say "Published " . $post->publication_file->basename;
        }

        # @todo: fix orphan tag problem when a post is updated with tags removed
        for my $tag (@{ $post->tags }) {
            $self->tags_index->update_tag_for_post( $tag, $post );
        }
    } else {
        die("assert - Publishing failed for " . $post->source_file);
    }

    # Remember publishing this post
    $post_memory->save(
        $post->publication_file->basename,
        {
            mtime => $post->source_file->stat->mtime,
            source_file => $post->source_file->absolute->stringify,
            tags => [ sort map { $_->name } @{ $post->tags } ]
        }
    );

    return 1;
}

sub publish_note {
    my ($self, $note) = (shift, shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    if (!$note->has_source_file) {
        die("assert - post has no source file");
    }

    if (!$note->source_file_loaded) {
        $note = $note->load();
    }

    # Does this note need to be regenerated?
    my $memory = $self->config->notes_memory;
    my $key = $note->source_file->basename;
    my $record = $memory->load($key);

    if ($record && $record->{publication_file}) {
        $note->publication_file($record->{publication_file});
    }

    my $published_file_exists = (-e $note->publication_file);
    my $must_republish = ($opts{force} || !$published_file_exists);
    if (!$must_republish) {
        # ought I to republish?
        if ($published_file_exists 
            && ($note->publication_file->stat->mtime >= $note->source_file->stat->mtime)
        ) {
            if ($opts{verbose}) {
                say "Declining to reprocess unchanged " . $note->source_file->basename;
            }
            return;
        }
    }

    if (!$note->can_publish) {
        if ($opts{verbose}) {
            say "Note cannot be published without a body."
        }
        return;
    }

    # @todo: make it so that I don't have to do this
    # hydrate tags
    for my $tag (@{ $note->tags }) {
        $tag->config($self->config);
    }

    if ($self->_publish(
            $note->template_file,
            $note->publication_file,
            { note => $note, thisURI => $note->uri, activeSection => "notes_roll" })
    ) {
        if ($opts{verbose}) {
            say "Published " . $note->publication_file->basename;
        }

        # @todo: fix orphan tag problem when a post is updated with tags removed
        for my $tag (@{ $note->tags }) {
            $self->tags_index->update_tag_for_post( $tag, $note );
        }
    } else {
        die("assert - Publishing failed for " . $note->source_file);
    }

    # Remember publishing this post
    if ($record) {
        $record->{mtime} = $note->source_file->stat->mtime;
        $record->{tags} = [ sort map { $_->name } @{ $note->tags } ];
    } else {
        $record = {
            mtime => $note->source_file->stat->mtime,
            publication_file => $note->publication_file->absolute->stringify,
            source_file => $note->source_file->absolute->stringify,
            tags => [ sort map { $_->name } @{ $note->tags } ]
        };
    }
    $memory->save($note->source_file->basename, $record);

    return 1;
}

sub publish_notes_roll {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    my $feed = $self->notes_roll;
    my $memory = $self->config->notes_memory;

    my @notes;

    my @latest_keys = reverse @{ $memory->keys_in_created_order };
    for my $key ( @latest_keys ) {

        my $rec = $memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_note($key => $rec, %opts);
            next;
        }

        my $note = Plerd::Model::Note->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $note = $note->load;
        if ($rec->{publication_file}) {
            $note->publication_file($rec->{publication_file});
        }
        push @notes, $note;
    }

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        { notes => \@notes, thisURI => $feed->uri, activeSection => "notes_roll" }
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }

        return 1;
    }

    die("assert - Publishing failed for notes_roll");
}

sub publish_notes_json_feed {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    my $feed = $self->notes_json_feed;
    my $memory = $self->config->notes_memory;

    my @notes;
    my $max_posts = $self->config->show_max_posts;

    my @latest_keys = reverse @{ $memory->keys_in_created_order };
    for my $key ( @latest_keys ) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_note($key => $rec, %opts);
            next;
        }

        my $note = Plerd::Model::Note->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $note = $note->load;
        if ($rec->{publication_file}) {
            $note->publication_file($rec->{publication_file});
        }
        push @notes, $note;
    }

    my $json = $self->notes_json_feed->make_feed(\@notes);

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        { feed => $json, thisURI => $feed->uri, activeSection => "notes_roll" }
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }

        return 1;
    }
    die("assert - Publishing failed for notes_json_feed");
}

sub publish_tags_index_page {
    my ($self) = (shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    # Get the mtime of the published tags index
    my $tags_index = $self->tags_index;
    if (!$opts{force} && !$tags_index->out_of_date) {
        if ($opts{verbose}) {
            say "Declining to republish tags index";
        }
        return; # no updates needed
    }

    # If any tag memory is newer, regenerate index
    my $tag_links = $tags_index->get_tag_links;
    if ($self->_publish(
            $tags_index->template_file,
            $tags_index->publication_file,
            { tag_links => $tag_links, thisURI => $tags_index->uri,},
            "tags"
            )
    ) {
        if ($opts{verbose}) {
            say "Published " . $tags_index->publication_file->basename;
        }
        return 1;
    }

    die("assert - Publishing failed for tag index");
}


sub publish_json_feed {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    my $feed = $self->json_feed;
    my $post_memory = $self->config->post_memory;

    # @fixme - need to regen?
    my @posts;

    my $max_posts = $self->config->show_max_posts;
    my @latest_keys = sort { $b->[0] cmp $a->[0] } @{ $post_memory->keys };

    for my $key (@latest_keys) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_post($key => $rec, %opts);
            next;
        }

        my $post = Plerd::Model::Post->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $post->load_source;
        push @posts, $post;
    }

    my $json = $feed->make_feed(\@posts);
    my $vars = {
        'thisURI' => $feed->uri,
        'feed' => $json,
    };

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        $vars
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }
        return 1;
    }
    die("assert - Publishing failed for JSON feed");
}


sub publish_rss_feed {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    my $feed = $self->rss_feed;
    my $post_memory = $self->config->post_memory;

    # @fixme - need to regen?                                                              
    my @posts;

    my $max_posts = $self->config->show_max_posts;

    my @latest_keys = sort { $b->[0] cmp $a->[0] } @{ $post_memory->keys };
    for my $key ( @latest_keys ) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_post($key => $rec, %opts);
            next;
        }

        my $post = Plerd::Model::Post->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $post->load_source;
        push @posts, $post;
    }

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        { posts => \@posts, thisURI => $feed->uri }
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }

        return 1;
    }
    die("assert - Publishing failed for rss_feed");
}


# This is the main blog page
sub publish_front_page {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    my $feed = $self->front_page;

    my $max_posts = $self->config->show_max_posts;

    my $post_memory = $self->config->post_memory;
    my @posts;
    my @latest_keys = sort { $b->[0] cmp $a->[0] } @{ $post_memory->keys };
    for my $key ( @latest_keys ) {
        if ($max_posts-- < 1){
            last;
        }

        my $rec = $post_memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_post($key => $rec, %opts);
            next;
        }

        my $post = Plerd::Model::Post->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $post->load_source;
        push @posts, $post;
    }

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        { posts => \@posts, thisURI => $feed->uri },
        "blog"
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }
        return 1;
    }
    die("assert - Publishing failed for archive page");
}

sub publish_archive_page {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    my $feed = $self->archive;

    my $post_memory = $self->config->post_memory;
    my @posts;

    for my $key ( @{ $post_memory->keys } ) {
        my $rec = $post_memory->load($key);
        if (!-e $rec->{source_file}) {
            $self->forget_post($key => $rec);
        } else {
            my $post = Plerd::Model::Post->new(
                config => $self->config,
                source_file => $rec->{source_file}
            );
            $post->load_source;
            push @posts, $post;
        }
    }

    # put these in publication order
    @posts = sort { $a->publication_file->basename cmp $b->publication_file->basename } @posts;

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        { posts => \@posts, thisURI => $feed->uri},
        "archive"
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }
        return 1;
    }
    die("assert - Publishing failed for archive page");
}

sub publish_site_css_page {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    my $feed = $self->site_css;

    my $parent = $feed->publication_file->parent;
    if (!-d $parent) {
        $parent->mkpath;
    }

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        {},
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }
        return 1;
    }
    die("assert - Publishing failed for site css page");
}

sub publish_site_js_page {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    my $feed = $self->site_js;

    my $parent = $feed->publication_file->parent;
    if (!-d $parent) {
        $parent->mkpath;
    }

    if ($self->_publish(
        $feed->template_file,
        $feed->publication_file,
        {}
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;
        }
        return 1;
    }
    die("assert - Publishing failed for site css page");
}

sub publish_support_files {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    $self->publish_site_css_page(%opts);
    $self->publish_site_js_page(%opts);

    return 1;
}


sub publish_all {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        'only_notes' => 0,
        'only_posts' => 0,
        @_
    );


    my ($did_publish_posts, $did_publish_notes) = (0, 0);

    if (!$opts{only_notes}) {
        if ($opts{verbose}) {
            say "Looking for new post files in " . $self->config->source_directory;
        }

        if (-e $self->config->source_directory) {
            for (my $source_file = $self->first_source_file;
                defined($source_file);
                $source_file = $self->next_source_file)
            {
                my $post;
                eval {
                    $post = Plerd::Model::Post->new(
                        config => $self->config,
                        source_file => $source_file
                    );
                    1;
                } or do {
                    say $@;
                    next;
                };

                if ($self->should_publish_post($post) || $opts{force}) {
                    eval {
                        $self->publish_post($post, %opts);
                        $did_publish_posts = 1;
                        1;
                    } or do {
                        say $@;
                    };

                } else {
                    if ($opts{verbose}) {
                        say "Declining to reprocess old source: " . $source_file->basename;
                    }
                }
            }
        }
    }


    if (!$opts{only_posts}) {
        if ($opts{verbose}) {
            say "Looking for new notes files in " . $self->config->source_notes_directory;
        }

        if (-d $self->config->source_notes_directory) {        
            # @todo: sort source by mtime
            while (my $file = $self->config->source_notes_directory->next) {
                next if -d $file;
                my $note = Plerd::Model::Note->new(
                    config => $self->config,
                    source_file => $file,
                );

                if ($self->should_publish_note($note) || $opts{force}) {
                    eval {
                        $self->publish_note($note, %opts);
                        $did_publish_notes = 1;
                        1;
                    } or do {
                        say $@;
                    };
                } else {
                    if ($opts{verbose}) {
                        say "Declining to reprocess old note: " . $file->basename;
                    }
                    next;                    

                }
            }
        }
    }

    if (!$opts{force}
        && (!$did_publish_posts && !$did_publish_notes)) {
        return;
    }

    # @todo: make this a call to publish_support_files
    if ($did_publish_posts) {
        $self->publish_front_page(%opts);
        $self->publish_archive_page(%opts);
        $self->publish_rss_feed(%opts);
        $self->publish_json_feed(%opts);
    }

    if ($did_publish_notes) {
        $self->publish_notes_json_feed(%opts);
        $self->publish_notes_roll(%opts);
    }

    # Cannot get to this point unless there is new content
    # always republish these
    $self->publish_tags_index_page(%opts);
    $self->publish_support_files(%opts);

    return 1;
}

sub get_recent_posts {
    my $self = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    my $max_posts = 5;
    # @fixme - need to regen?

    my $post_memory = $self->config->post_memory;
    my @posts;

    # This is imperfect, since publising two posts on the same day
    # returns a list in alpha, not published order.

    my $keys = $post_memory->keys;
    my @latest_keys = sort { $b->[0] cmp $a->[0] } @{ $keys };
    for my $key ( @latest_keys ) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
        if (! -e $rec->{source_file}) {
            $self->forget_post($key => $rec, %opts);
        } else {
            my $post = Plerd::Model::Post->new(
                config => $self->config,
                source_file => $rec->{source_file}
            );
            $post->load_source;
            push @posts, $post;
        }
    }

    return \@posts;
}

sub forget_post {
    my ($self, $key, $rec) = (shift, shift, shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    if ($opts{verbose}) {
        say "Forgetting old post: $rec->{source_file}";
    }

    $self->config->post_memory->remove($key);
    for my $tag (@{$rec->{tags} || []}) {
        $self->tags_index->remove_tag_from_post($tag, $rec->{source_file});
    }

    my $file = Path::Class::File->new(
        $self->config->publication_directory,
        @$key
    );

    if (-e $file) {
        if ($opts{verbose}) {
            say "Removing published post: " . $file;
        }

        $file->remove;
    }
    return 1;
}


sub forget_note {
    my ($self, $key, $rec) = (shift, shift, shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    if ($opts{verbose}) {
        say "Forgetting old note: $rec->{source_file}";
    }

    $self->config->notes_memory->remove($key);

    my $file = Path::Class::File->new(
        $self->config->publication_directory,
        @$key
    );

    if (-e $file) {
        if ($opts{verbose}) {
            say "Removing published note: " . $file;
        }

        $file->remove;
    }

    return 1;
}

sub should_publish_post {
    my ($self, $post) = @_;
    return if !$post;

    my $memory = $self->config->post_memory;
    if (!$post->source_file_loaded) {
        eval {
            $post->load_source;
            $post->publication_file; # tests bad dates
            1;
        } or do {
            say $@;
            return;
        }
    }

    my $record = $memory->load($post->publication_file->basename);
    if (!$record) {
        return 1;
    }

    if (! -e $post->publication_file) {
        return 1;
    }

    if ($post->source_file->stat->mtime > $post->publication_file->stat->mtime) {
        return 1;
    }

    return;
}

sub should_publish_note {
    my ($self, $note) = @_;
    return if !$note;

    my $memory = $self->config->notes_memory;
    my $record = $memory->load($note->source_file->basename);
    if (!$record) {
        # Don't remember publishing this note
        return 1;
    }

    # This note looks familiar...
    if ($record->{publication_file}) {
        my $pub_file = Path::Class::File->new($record->{publication_file});
        if (!-e $pub_file) {
            # Someone deleted this from docroot?
            $note->publication_file($pub_file); # keep the old name
            return 1;
        }

        if ($pub_file->stat->mtime < $note->source_file->stat->mtime) {
            # The note's source was updated
            $note->publication_file($pub_file); # keep the old name
            return 1;
        }
    }

    # The source has not changed for this published file
    return;
}

sub first_source_file {
    my ($self) = @_;
    $self->clear_sorted_source_files;
    my @files;
    while (my $file = $self->config->source_directory->next) {
        next if -d $file;
        if ($file->stringify =~ /\.(?:md|markdown)$/) {
            push @files, $file;
        }
    }

    @files = sort { $a->stat->mtime <=> $b->stat->mtime } @files;
    $self->sorted_source_files(\@files);
    return shift @files;
}

sub next_source_file {
    my ($self) = @_;

    if (!$self->has_sorted_source_files) {
        return;
    }

    if (@{ $self->sorted_source_files } == 0) {
        return;
    }

    return shift @{ $self->sorted_source_files };
}


#-----------------
# Private methods
#-----------------
sub _publish {
    my ($self, $template_file, $target_file, $vars, $section) = @_;
    $section //= "blog";
    if (!exists $vars->{activeSection}) {
        $vars->{activeSection} = $section;
    }

    if (!-d $target_file->parent) {
        $target_file->parent->mkpath;
    }

    my $tmpl_fh = $template_file->openr;
    my $trg_fh = $target_file->openw;

    unless ($self->publisher->process(
                        $tmpl_fh,
                        $vars,
                        $trg_fh,
                    )
    ) {
        die(sprintf("assert[processing %s] %s\n",
                        $target_file,
                        $self->publisher->error()
                   )
        );
    }

    return 1;
}

1;
