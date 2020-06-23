package Plerd;
use strict;
use warnings;

use Moo;
use Template;

use Plerd::Config;
use Plerd::Post;

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

# @todo: verify clearer
has source_dir_handle => (is => 'rw', clearer => 1, predicate => 1);

#-----------------
# Public Methods
#-----------------
sub publish_post {
    my ($self, $post) = @_;

    my $tmpl = Path::Class::File->new($self->config->template_directory, "post.tt");

    $self->_publish($tmpl, { post => $post });

    if ($post->has_tags) {
        for my $tag (@{ $post->tags }) {
            $self->publish_tag($tag);
        }
    }

    die("assert");
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
        my $post = $Plerd::Post->new(
            config => $self->config,
            source_file => $source_file
        );
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
        next if -d $file;
        next if $file =~ /\.(md|markdown)$/;

        return $file;
    }

    # Failed to find a source file
    $self->clear_source_dir_handle;
    return;
}

#-----------------
# Private methods
#-----------------
sub _publish {
    my ($self, $template, $target_file, $vars) = @_;

    my $out;
    unless ($self->publisher->process(
                        $template->stringify,
                        $vars,
                        \$out,
                    ) 
    ) {
        die(sprintf("assert[processing %s] %s",
                        $target_file,
                        $self->publisher->error()
                   )
        );
    }

    $target_file->spew(iomode=>'>:encoding(utf8)', $out);

    return 1;
}

1;