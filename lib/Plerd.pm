# Joe Johnston <jjohn@taskboy.com>, based on original work from
# Jason McIntosh <jmac@jmac.org>
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
use Plerd::Model::SiteCSS;
use Plerd::Model::SiteJavaScript;
use Plerd::Model::TagIndex;
use Plerd::Remembrancer;

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
    lazy => 1,
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
            archive => $self->archive,
            config => $self->config,
            frontPage => $self->front_page,
            jsonFeed => $self->json_feed,
            rssFeed => $self->rss_feed,
            siteCSS => $self->site_css,
            siteJS => $self->site_js,
            tagsIndex => $self->tags_index,
            w3validatorURI => URI->new("https://validator.w3.org/nu/"),
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

has 'site_js' => (
    is => 'ro', 
    lazy => 1, 
    builder => '_build_site_js'
);
sub _build_site_js {
    my ($self) = @_;
    Plerd::Model::SiteJavaScript->new(config => $self->config);
}

has source_dir_handle => (
    is => 'rw',
    lazy => 1,
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
            if ($memory->{mtime} >= $post->source_file_mtime) {
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
            mtime => $post->source_file_mtime,
            source_file => $post->source_file->absolute->stringify,
            tags => $post->tags
        }
    );

    return 1;
}

sub publish_tag_page {
    my ($self, $tag) = (shift, shift);
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );
    die("NYI");
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
            { tag_links => $tag_links, thisURI => $tags_index->uri, activeSection => 'tags' }) 
    ) {
        if ($opts{verbose}) {
            say "Published " . $tags_index->publication_file->basename;            
        }
        return 1;
    }

    die("assert - Publishing failed for tag index");
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

    # @todo: allow customization from config
    my $max_posts = 3;
    my @latest_keys = reverse @{ $post_memory->keys };
    for my $key ( @latest_keys ) {
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

    # @todo: allow customization from config
    my $max_posts = 3;
    my @latest_keys = reverse @{ $post_memory->keys };

    for my $key (@latest_keys) {
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
        { posts => \@posts, thisURI => $feed->uri }
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;            
        }
        return 1;
    }
    die("assert - Publishing failed for JSON feed");
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

    # @todo: allow customization from config
    my $max_posts = 3;
    # @fixme - need to regen?

    my $post_memory = $self->config->post_memory;
    my @posts;
    my @latest_keys = reverse @{ $post_memory->keys };
    for my $key ( @latest_keys ) {
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
        { posts => \@posts, thisURI => $feed->uri }
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

    my @latest_keys = reverse @{ $post_memory->keys };
    for my $key ( @latest_keys ) {

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
        { posts => \@posts, thisURI => $feed->uri, activeSection => 'archive' }
    )) {
        if ($opts{verbose}) {
            say "Published " . $feed->publication_file->basename;            
        }
        return 1;
    }
    die("assert - Publishing failed for archive page");
}

sub publish_all {
    my ($self) = shift;
    my (%opts) = (
        'force' => 0,
        'verbose' => 0,
        @_
    );

    my $post_memory = $self->config->post_memory;
    my ($latest_post) = @{ $post_memory->latest_keys };
    my $latest_post_mtime;
    if (defined $latest_post) {
        $latest_post_mtime = $post_memory->load($latest_post)->{mtime};
    }   

    my @source_files;
    while (my $source_file = $self->next_source_file) {
        if (defined $latest_post && !$opts{force}) {
            my $src_mtime = $source_file->stat->mtime;
            if ($src_mtime <= $latest_post_mtime) {
                if ($opts{verbose}) {
                    say "Declining to reprocess old source: " . $source_file->basename;
                }
                next;
            }
        }
        push @source_files, $source_file;
    }

    if (!@source_files) {
        return;
    }

    for my $source_file (@source_files) {
        my $post = Plerd::Model::Post->new(config => $self->config, source_file => $source_file);
        eval {
            $self->publish_post($post, %opts);
            1;
        } or do {
            say $@;
        };
    }

    $self->publish_front_page(%opts);
    $self->publish_archive_page(%opts);
    $self->publish_rss_feed(%opts);
    $self->publish_json_feed(%opts);
    $self->publish_tags_index_page(%opts);

    return 1;
}

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

sub get_recent_posts {
    my ($self) = @_;
    my $max_posts = 5;
    # @fixme - need to regen?

    my $post_memory = $self->config->post_memory;
    my @posts;
    my @latest_keys = reverse @{ $post_memory->keys };
    for my $key ( @latest_keys ) {
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

    return \@posts;
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

    if (!exists $vars->{recent_posts}) {
        $vars->{recent_posts} = $self->get_recent_posts;
    }

    my $tmpl_fh = $template_file->open('<:encoding(UTF-8)');
    my $trg_fh = $target_file->open('>:encoding(UTF-8)');

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