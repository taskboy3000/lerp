# This (more or less) bag of properties
# can be passed around to objects that need to understand the app configuration
package Plerd::Config;
use strict;
use warnings;

use DateTime::Format::W3CDTF;
use File::Copy;
use Path::Class::Dir;
use Path::Class::File;
use Moo;
use Template;
use URI;
use YAML qw( LoadFile );

#------------
# Attributes
#------------
has author_email => (is => 'ro', lazy => 1, builder => '_build_author_email');
sub _build_author_email { 's.handwich@localhost' }

has author_name => (is => 'ro', lazy => 1, builder => '_build_author_name');
sub _build_author_name { 'Sam Handwich' }

has base_uri => (
    is => 'ro',
    default => sub { 'http://localhost/' },
    coerce => \&_coerce_uri,
);

has config_file => (
    is => 'ro',
    lazy => 1,
    builder => '_build_config_file',
    coerce => \&_coerce_file,
);
sub _build_config_file {
    return "$ENV{HOME}/.plerd.conf";
}

has config_template_dir => (
    is => 'ro',
    default => sub { Path::Class::Dir->new($ENV{PLERD_HOME}, "lib", "Plerd", "Template") }
);

has config_tt => (
    is => 'ro',
    lazy => 1,
    builder => '_build_config_tt',
);
sub _build_config_tt {
    my ($self) = @_;
    my %params = (
        INCLUDE_PATH => $self->config_template_dir,
        ABSOLUTE => 1,
    );
    Template->new(%params);    
}

has 'database_directory' => (
    is => 'ro',
    lazy => 1, 
    builder => '_build_database_directory',
    coerce => \&_coerce_directory,
);
sub _build_database_directory {
    my $self = shift;
    my $dir = Path::Class::Dir->new($self->path, "db");
    if (! -d $dir) {
        $dir->mkpath;
    }
    return $dir;
}

has 'datetime_formatter' => (is => 'ro', default => sub { DateTime::Format::W3CDTF->new });

has 'image' => (is => 'ro', predicate => 1);
has 'image_alt' => (is => 'ro', default => sub { "[image]" });

has facebook_id => (is => 'ro', predicate => 1);

has log_directory => (
    is => 'ro', 
    lazy => 1,
    builder => '_build_log_directory',
    coerce => \&_coerce_directory
);
sub _build_log_directory {
    my ($self) = @_;
    return Path::Class::Dir->new($self->path, "log");
}

has path => (
    is => 'ro', 
    lazy => 1,
    builder => '_build_path',
    coerce => \&_coerce_directory
);
sub _build_path {
    my ($self) = @_;
    return Path::Class::Dir->new("./new-site");
}

has 'publication_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_publication_directory',
    coerce => \&_coerce_directory
);
sub _build_publication_directory {
    my ($self) = shift;
    return Path::Class::Dir->new($self->path, "docroot");
}

has 'run_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_run_directory',
    coerce => \&_coerce_directory    
);
sub _build_run_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "run");
}

has 'source_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_source_directory',
    coerce => \&_coerce_directory
);
sub _build_source_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "source");

}

has 'tags_publication_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_tags_publication_directory',
    coerce => \&_coerce_directory    
);
sub _build_tags_publication_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->publication_directory, "tags");
}

has 'template_directory' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_template_directory',
    coerce => \&_coerce_directory    
);
sub _build_template_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "templates");
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

    return Path::Class::Dir->new($path)->absolute;    
}

sub _coerce_file {
    my ($file) = @_;
    if (ref $file eq 'Path::Class::File') {
        return $file;
    }
    return Path::Class::File->new($file)->absolute;
}

sub _coerce_uri {
    my ($href) = @_;
    if (ref $href eq 'URI') {
        return $href;
    }

    return URI->new($href);
}


#----------------
# Public methods
#----------------

# Create all the configured directories, cfg files and templates
# Will overwrite destinations
sub initialize {
    my ($self) = @_;

    my @messages;
    for my $dir_method (qw[
        path
        publication_directory
        tags_publication_directory
        database_directory
        run_directory
        log_directory
        template_directory
        source_directory
    ]) {
        if (!-d $self->$dir_method) {
            push @messages, "Creating " . $self->$dir_method();
            $self->$dir_method->mkpath; 
        }
    }

    # add default templates
    for my $template (qw[archive feed jsonfeed post tags wrapper]) {
        my $basename = $template . ".tt";
        my $src_file = Path::Class::File->new($self->config_template_dir, $basename);
        if (-e $src_file) {
            my $dst_file = Path::Class::File->new($self->template_directory, $basename);
            if (-e $dst_file) {
                push @messages, "Removing existing $dst_file";
                $dst_file->remove;
            }
            push @messages, "Copying $src_file -> $dst_file";
            copy($src_file, $dst_file) or die("Cannot copy $src_file -> $dst_file: $!");
        }
    }

    # create configuration
    push @messages, "Serializing configuration to " . $self->config_file;
    $self->serialize;

    return @messages;
}

sub unserialize {
    my ($self) = @_;
    if (! -e $self->config_file) {
        return;
    }

    my $config_ref;
    eval {
        $config_ref = LoadFile($self->config_file);
        1;
    } or do {
        die("Cannot read or parse: " . $self->source_file);
    };

    for my $property (keys %$config_ref) {
        if ($self->can($property)) {
            $self->$property( $config_ref->{$property} );
        }
    }
}

sub serialize {
    my ($self) = @_;
    my $template_file = Path::Class::File->new($self->config_template_dir, "config_file.tt");

    my $out;
    unless ($self->config_tt->process($template_file->stringify, { config => $self }, \$out)) {
        die("Could not create config file: " . $self->config_tt->error());
    }

    if (-e $self->config_file) {
        if (-e $self->config_file . ".bak") {
            unlink $self->config_file . ".bak";
        }
        rename $self->config_file, $self->config_file . ".bak";
    }

    $self->config_file->spew(iomode=>'>:encoding(utf8)', $out);
}

1;