# Joe Johnston <jjohn@taskboy.com>
package Plerd::Model::NoteJSONFeed;
use Modern::Perl '2018';

use Path::Class::File;
use JSON;
use Moo;
use URI;

use Plerd::Config;

#-------------------------
# Attributes and Builders
#-------------------------
has config => ( 'is' => 'ro', lazy => 1, builder => '_build_config' );

sub _build_config {
    Plerd::Config->new();
}

has 'publication_file' => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    builder   => '_build_publication_file'
);

sub _build_publication_file {
    my $self = shift;
    Path::Class::File->new( $self->config->publication_directory,
        "recent_notes.json", );
}

has 'template_file' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_template_file'
);

sub _build_template_file {
    my ( $self ) = @_;
    Path::Class::File->new( $self->config->template_directory,
        "jsonfeed.tt" );
}

has 'uri' => (
    is      => 'ro',
    lazy    => 1,
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
    my ( $self, $notes ) = @_;

    my %author = ( name => $self->config->author_name );
    if ( $self->config->author_email ) {
        $author{ url } = "mailto:" . $self->config->author_email;
    }

    my @items;
    for my $note ( @$notes ) {
        push @items,
            {
            id             => $note->uri->as_string,
            url            => $note->uri->as_string,
            title          => $note->title,
            content_html   => $note->body,
            date_published => $note->published_timestamp,
            };
    }

    my %feed = (
        version       => "https://jsonfeed.org/version/1",
        title         => "Notes from " . $self->config->title,
        home_page_url => $self->config->base_uri->as_string,
        feed_url      => $self->uri->as_string,
        author        => \%author,
        items         => \@items,
    );

    my $json =
        JSON::to_json( \%feed, { canonical => 1, pretty => 1, utf8 => 0 } );

    return $json;
}

1;
