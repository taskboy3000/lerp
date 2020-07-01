# Joe Johnston <jjohn@taskboy.com>
package Plerd::Model::Tag;
use Modern::Perl '2018';

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

has 'name' => (
    is => 'rw',
    coerce => \&_canonicalize_tag
);

has 'source_file' => (
    is => 'ro',
    predicate => 1,
    coerce => \&_coerce_source_file,
);
sub _coerce_source_file {
    my ($file) = @_;
    if (ref $file eq 'Path::Class::File') {
        return $file;
    } 
    return Path::Class::File->new($file);
}

has 'template_file' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_template_file'
);
sub _build_template_file {
    my ($self) = @_;
    Path::Class::File->new($self->config->template_directory, "tags.tt");
}

has 'uri' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_uri'
);
sub _build_uri {
    my $self = shift;

    # @todo: ensure name is URL safe
    return URI->new_abs(
        'tags.html#tag-' . $self->name . '-list',
        $self->config->base_uri,
    );
}

#-----------
# Coersions
#-----------
sub _canonicalize_tag {
    my ($tag) = @_;

    chomp($tag);

    # no html
    if ($tag =~ /[<>]/) {
        $tag =~ s{(</?[^>]+>)}{}g;
    }

    # no spaces
    $tag =~ s/\s+/_/g;

    # remove octothorpes
    $tag =~ s/#//g;

    return lc($tag);
}

1;

