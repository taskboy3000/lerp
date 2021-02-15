# Joe Johnston <jjohn@taskboy.com>
package Plerd::Model::NotesRoll;
use Modern::Perl '2018';

use Path::Class::File;
use Moo;
use URI;

use Plerd::Config;
use Plerd::Remembrancer;

#-------------------------
# Attributes and Builders
#-------------------------
has 'config' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_config'
);

sub _build_config {
    Plerd::Config->new();
}

has 'publication_file' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_publication_file'
);

sub _build_publication_file {
    my ( $self ) = @_;

    Path::Class::File->new( $self->config->publication_directory,
        "notes_roll.html" );
}

has 'template_file' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_template_file'
);

sub _build_template_file {
    my ( $self ) = @_;
    Path::Class::File->new( $self->config->template_directory,
        "notes_roll.tt" );
}

has 'uri' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_uri'
);

sub _build_uri {
    my ( $self ) = @_;
    my $base_uri = $self->config->base_uri;
    return URI->new( $base_uri . $self->publication_file->basename );
}

1;
