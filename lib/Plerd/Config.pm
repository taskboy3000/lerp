# This (more or less) bag of properties
# can be passed around to objects that need to understand the app configuration
package Plerd::Config;
use strict;
use warnings;

use DateTime::Format::W3CDTF;
use Moo;
use Path::Class::Dir;
use URI;

has author_email => (is => 'ro', predicate => 1);
has author_name => (is => 'ro', predicate => 1);

has base_uri => (
    is => 'ro',
    default => sub { 'http://plerd.org/' },
    coerce => \&_coerce_uri,
);

has 'database_directory' => (
    is => 'ro',
    lazy => 1, 
    builder => '_build_database_directory',
    coerce => \&_coerce_directory,
);
sub _build_database_directory {
    my $self = shift;
    Path::Class::Dir->new($self->path, "db");
}

has 'datetime_formatter' => (is => 'ro', default => sub { DateTime::Format::W3CDTF->new });

has 'image' => (is => 'ro', predicate => 1);
has 'image_alt' => (is => 'ro', default => sub { "[image]" });

has facebook_id => (is => 'ro', predicate => 1);

has path => (
    is => 'ro', 
    default => sub { '.' }, 
    coerce => \&_coerce_directory
);

has 'publication_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_publication_directory',
    coerce => \&_coerce_directory
);
sub _build_publication_directory {
    my ($self) = shift;
    Path::Class::Dir->new($self->path, "docroot");
}

has 'source_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_source_directory',
    coerce => \&_coerce_directory
);
sub _build_source_directory {
    my $self = shift;
    Path::Class::Dir->new($self->path, "source");
}

has 'tags_publication_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_tags_publication_directory',
    coerce => \&_coerce_directory    
);
sub _build_tags_publication_directory {
    my $self = shift;
    Path::Class::Dir->new($self->publication_directory, "tags");
}

has 'title' => (is => 'ro', default => sub { "Another Plerd Blog" });
has twitter_id => (is => 'ro', predicate => 1);

#------------
# Coersions
#-------------
sub _coerce_directory {
    my ($path) = @_;
    if (ref $path eq 'Path::Class::Dir') {
        return $path;
    }

    return Path::Class::Dir->new($path);    
}

sub _coerce_uri {
    my ($href) = @_;
    if (ref $href eq 'URI') {
        return $href;
    }

    return URI->new($href);
}

1;