# Joe Johnston <jjohn@taskboy.com>
package Plerd::Model::SiteCSS;
use Modern::Perl '2018';

use Path::Class::File;
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
        "/css/site.css", );
}

has 'template_file' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_template_file'
);

sub _build_template_file {
    my ( $self ) = @_;
    Path::Class::File->new( $self->config->template_directory,
        "site_css.tt" );
}

has 'uri' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_uri'
);

sub _build_uri {
    my $self = shift;

    return URI->new( $self->config->base_uri . "css/"
            . $self->publication_file->basename );
}

1;
