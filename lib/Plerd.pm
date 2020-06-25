package Plerd;
use strict;
use warnings;

use Moo;
use Template;

use Plerd::Config;
use Plerd::Model::Post;

our $VERSION="1.0";

has 'config' => (
    is => 'ro', 
    lazy => 1, 
    builder => '_build_config'
);
sub _build_config {
    Plerd::Config->new;    
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

    return Template->new(%params);   
}

has source_dir_handle => (
    is => 'rw',
    clearer => 1,
    predicate => 1
);

#-----------------
# Public Methods
#-----------------
sub publish_post {
    my ($self, $post) = @_;

    if (!$post->has_source_file) {
        die("assert - post has no source file");
    }

    if (!$post->source_file_loaded) {
        $post->load_source;
    }

    my $tmpl = Path::Class::File->new($self->config->template_directory, "post.tt");
    if ($self->_publish($tmpl, $post->publication_file, { post => $post }) ) {
        if (@{ $post->tags }) {
            for my $tag (@{ $post->tags }) {
                $self->publish_tag($tag);
            }
        }
    } else {
        die("assert - Publishing failed for " . $post->source_file);
    }

    return 1;
}

sub publish_tag {
    my ($self, $tag) = @_;
    die("assert");
}

sub publish_rss_feed {
    my ($self, $tag) = @_;
    die("assert");
}

sub publish_json_feed {
    my ($self, $tag) = @_;
    die("assert");
}

sub publish_recent_page {
    my ($self, $tag) = @_;
    die("assert");
}

sub publish_archive_page {
    my ($self, $tag) = @_;
    die("assert");
}

sub publish_all {
    my ($self) = @_;

    while (my $source_file = $self->next_source_file) {
        my $post = $Plerd::Model::Post->new(config => $self->config);
        $post->source_file($source_file);
        $self->publish_post($post);
    }

    $self->publish_recent_page;
    $self->publish_archive_page;
    $self->publish_rss_feed;
    $self->publish_json_feed;
}

# @todo: verify this iterate pattern
sub next_source_file {
    my ($self) = @_;

    if (!$self->has_source_dir_handle) {
        $self->source_dir_handle($self->config->source_directory->open);
    }

    my $file;
    while ($file = $self->source_dir_handle->read) {
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