package Plerd;
use Modern::Perl '2018';

use JSON;
use Moo;
use Template;
use Template::Stash;

use Plerd::Config;
use Plerd::Model::Archive;
use Plerd::Model::FrontPage;
use Plerd::Model::JSONFeed;
use Plerd::Model::Post;
use Plerd::Model::RSSFeed;
use Plerd::Model::TagIndex;
use Plerd::Remembrancer;

our $VERSION="1.0";

#-------------------------------
# Attributes and Builders
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
    predicate => 1,
    builder => '_build_json_feed',
);
sub _build_json_feed {
    my ($self) = @_;
    Plerd::Model::JSONFeed->new(config => $self->config);
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
            config => $self->config,
            plerd_version => $VERSION,
        }
    );
    my $json = JSON->new->utf8;

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
    predicate => 1,
    builder => '_build_rss_feed',
);
sub _build_rss_feed {
    my ($self) = @_;
    Plerd::Model::RSSFeed->new(config => $self->config);
}

has source_dir_handle => (
    is => 'rw',
    clearer => 1,
    predicate => 1,
);

has 'tags_index' => (
    is => 'ro',
    clearer => 1,
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
    my ($self, $post) = @_;

    if (!$post->has_source_file) {
        die("assert - post has no source file");
    }

    # Does this post need to be regenerated?
    my $post_key = $post->publication_file->basename;

    if (my $memory = $self->config->post_memory->load($post_key)) { 
        if ($memory->{mtime} >= $post->source_file_mtime) {
            # the cache is newer than the source.
            # decline to proceed.
            return;
        }
    }

    if (!$post->source_file_loaded) {
        $post->load_source;
    }

    if ($self->_publish(
            $post->template_file, 
            $post->publication_file, 
            { post => $post }) 
    ) {
        # @todo: fix orphan tag problem when a post is updated with tags removed
        for my $tag (@{ $post->tags }) {
            $self->tags_index->update_tag_for_post( $tag, $post );
        }
    } else {
        die("assert - Publishing failed for " . $post->source_file);
    }

    # Remember publishing this post 
    $self->config->post_memory->save(
        $post->publication_file->basename, 
        {
            mtime => $post->source_file_mtime,
            source_file => $post->source_file->absolute->stringify,
            tags => $post->tags
        }
    );

    return 1;
}


sub publish_tags_index {
    my ($self, $tag) = @_;

    # Get the mtime of the published tags index
    my $tags_index = $self->tags_index;
    if (!$tags_index->out_of_date) {
        return; # no updates needed
    }

    # If any tag memory is newer, regenerate index
    my $tag_links = $tags_index->get_tag_links;
    if ($self->_publish(
            $tags_index->template_file, 
            $tags_index->publication_file, 
            { tag_links => $tag_links }) 
    ) {
        return 1;
    }

    die("assert - Publishing failed for tag index");
}

sub publish_rss_feed {
    my ($self) = @_;
    my $rss_feed = $self->rss_feed;
    my $post_memory = $self->config->post_memory;

    # @fixme - need to regen?
    my @posts;
    # @todo: allow customization from config
    my $max_posts = 3;
    my $latest_keys = $post_memory->latest_keys;

    for my $key (@{ $latest_keys }) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
        my $post = Plerd::Model::Post->new(
            config => $self->config,
            source_file => $rec->{source_file}
        );
        $post->load_source;
        push @posts, $post;
    }

    # @fixme: make the structure in perl,
    # pass to the template like 
    # [% feed.json %]
    if ($self->_publish(
        $rss_feed->template_file,
        $rss_feed->publication_file,
        { posts => \@posts }
    )) {
        return 1;
    }
    die("assert - Publishing failed for rss_feed");
}

sub publish_json_feed {
    my ($self) = @_;
    my $feed = $self->json_feed;
    my $post_memory = $self->config->post_memory;
    # @fixme - need to regen?

    my @posts;
    # @todo: allow customization from config
    my $max_posts = 3;
    my $latest_keys = $post_memory->latest_keys;

    for my $key (@{ $latest_keys }) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
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
        { posts => \@posts }
    )) {
        return 1;
    }
    die("assert - Publishing failed for JSON feed");
}

# This is the main blog page
sub publish_front_page {
    my ($self) = @_;
    my $feed = $self->front_page;

    # @todo: allow customization from config
    my $max_posts = 3;
    # @fixme - need to regen?

    my $post_memory = $self->config->post_memory;
    my @posts;
    my $latest_keys = $post_memory->latest_keys;
    for my $key (@{ $latest_keys }) {
        if ($max_posts-- < 0){
            last;
        }

        my $rec = $post_memory->load($key);
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
        { posts => \@posts }
    )) {
        return 1;
    }
    die("assert - Publishing failed for archive page");

}

sub publish_archive {
    my ($self) = @_;
   
    my $feed = $self->archive;

    # @todo: check to see if this needs to be regenerated

    my $post_memory = $self->config->post_memory;
    my @posts;
    my $latest_keys = $post_memory->latest_keys;
    for my $key (@{ $latest_keys }) {

        my $rec = $post_memory->load($key);
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
        { posts => \@posts }
    )) {
        return 1;
    }
    die("assert - Publishing failed for archive page");
}

sub publish_all {
    my ($self) = @_;

    while (my $source_file = $self->next_source_file) {
        my $post = Plerd::Model::Post->new(config => $self->config);
        $post->source_file($source_file);
        $self->publish_post($post);
    }

    $self->publish_front_page;
    $self->publish_archive_page;
    $self->publish_rss_feed;
    $self->publish_json_feed;
}

# @todo: verify this iterate pattern
sub next_source_file {
    my ($self) = @_;

    if (!$self->has_source_dir_handle()) {
        $self->source_dir_handle($self->config->source_directory->open);
    }

    while (my $file = $self->source_dir_handle()->read) {
        $file = $self->config->source_directory->file($file)->absolute;
        next if -d $file;
        if ($file->stringify =~ /\.(?:md|markdown)$/) {
            return $file;
        }
    }

    # Failed to find a source file
    $self->clear_source_dir_handle;
    return;
}

#-----------------
# Private methods
#-----------------
sub _publish {
    my ($self, $template_file, $target_file, $vars) = @_;

    my $tmpl_fh = $template_file->open('<:encoding(utf8)');
    my $trg_fh = $target_file->open('>:encoding(utf8)');

    unless ($self->publisher->process(
                        $tmpl_fh,
                        $vars,
                        $trg_fh,
                    ) 
    ) {
        die(sprintf("assert[processing %s] %s",
                        $target_file,
                        $self->publisher->error()
                   )
        );
    }

    return 1;
}

1;