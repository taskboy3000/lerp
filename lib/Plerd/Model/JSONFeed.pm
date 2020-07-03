# Joe Johnston <jjohn@taskboy.com>
package Plerd::Model::JSONFeed;
use Modern::Perl '2018';

use Path::Class::File;
use JSON;
use Moo;
use URI;

use Plerd::Config;

#-------------------------
# Attributes and Builders
#-------------------------
has config => ('is' => 'ro', lazy => 1, builder => '_build_config');
sub _build_config {
    Plerd::Config->new();    
}

has 'publication_file' => (
    is => 'ro',
    lazy => 1, 
    predicate => 1, 
    builder => '_build_publication_file'
);
sub _build_publication_file {
    my $self = shift;
    Path::Class::File->new(
        $self->config->publication_directory,
        "feed.json",
    );
}

has 'template_file' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_template_file'
);
sub _build_template_file {
    my ($self) = @_;
    Path::Class::File->new($self->config->template_directory, "jsonfeed.tt");
}

has 'uri' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_uri'
);
sub _build_uri {
    my $self = shift;

    return URI->new_abs(
        $self->publication_file->basename,
        $self->config->base_uri,
    );
}

# See: https://jsonfeed.org/version/1
sub make_feed {
    my ($self, $posts) = @_;

    my %author = ( name => $self->config->author_name );
    if ($self->config->author_email) {
        $author{url} = "mailto:" . $self->config->author_email;
    }

    my @items;
    for my $post (@$posts) {
        push @items, {
            id => $post->uri->as_string,
            url => $post->uri->as_string,
            title => $post->stripped_title,
            content_html => $post->body,
            date_published => $post->published_timestamp,
        };
    }

    my %feed = (
        version => "https://jsonfeed.org/version/1",
        title => $self->config->title,
        home_page_url => $self->config->base_uri->as_string,
        feed_url => $self->uri->as_string,
        author => \%author,
        items => \@items,
    );

    my $json = JSON::to_json(\%feed, {canonical => 1, pretty => 1, utf8 => 0});

    return $json;
}

1;