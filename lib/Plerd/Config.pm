# This (more or less) bag of properties
# can be passed around to objects that need to understand the app configuration
#
# Joe Johnston <jjohn@taskboy.com>
#
package Plerd::Config;
use Modern::Perl '2018';

use DateTime::Format::W3CDTF;
use File::Copy;
use Path::Class::Dir;
use Path::Class::File;
use Moo;
use Template;
use URI;
use YAML qw( LoadFile );

BEGIN {
    if (! exists $ENV{PLERD_HOME}) {
        die("Please set the PLERD_HOME environment variable");
    }
    if (! -d $ENV{PLERD_HOME}) {
        die("PLERD_HOME '$ENV{PLERD_HOME}' does not appear to exist");
    }
}
use lib "$ENV{PLERD_HOME}/lib";

use Plerd::Remembrancer;

our $VERSION="1.0";

#------------
# Attributes
#------------
has author_email => (is => 'rw', lazy => 1, builder => '_build_author_email');
sub _build_author_email { 's.handwich@localhost' }

has author_name => (is => 'rw', lazy => 1, builder => '_build_author_name');
sub _build_author_name { 'Sam Handwich' }

has base_uri => (
    is => 'rw',
    default => sub { 'http://localhost/' },
    coerce => \&_coerce_uri,
);

has config_file => (
    is => 'rw',
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
        RELATIVE => 1,
    );
    Template->new(%params);    
}

has 'custom_nav_items' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_custom_nav_items',
);
sub _build_custom_nav_items {
    return [];
}

has 'database_directory' => (
    is => 'rw',
    lazy => 1, 
    builder => '_build_database_directory',
    coerce => \&_coerce_directory,
);
sub _build_database_directory {
    my $self = shift;
    my $dir = Path::Class::Dir->new($self->path, "db");
}

has 'datetime_formatter' => (is => 'ro', default => sub { DateTime::Format::W3CDTF->new });

has 'engine_name' => (is => 'ro', default => sub { "Taskboy Plerd"});
has 'engine_uri' => (is => 'ro', default => sub { URI->new('https://github.com/taskboy3000/plerd') });
has 'engine_version' => (is => 'ro', default => sub { $VERSION });

has 'image' => (is => 'rw', predicate => 1, coerce => \&_coerce_image);
has 'image_alt' => (is => 'rw', default => sub { "[image]" });

has facebook_id => (is => 'rw', predicate => 1);

has log_directory => (
    is => 'rw', 
    lazy => 1,
    builder => '_build_log_directory',
    coerce => \&_coerce_directory
);
sub _build_log_directory {
    my ($self) = @_;
    return Path::Class::Dir->new($self->path, "log");
}

has 'notes_publication_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_notes_publication_directory',
    coerce => \&_coerce_directory        
);
sub _build_notes_publication_directory {
    my ($self) = @_;
    return Path::Class::Dir->new($self->publication_directory, "notes");    
}

has path => (
    is => 'rw', 
    lazy => 1,
    builder => '_build_path',
    coerce => \&_coerce_directory
);
sub _build_path {
    my ($self) = @_;
    return Path::Class::Dir->new("./new-site");
}

has post_memory => (
    is => 'ro',
    lazy => 1,
    builder => '_build_post_memory',
);
sub _build_post_memory {
    my ($self) = @_;
    my $db_dir = Path::Class::Dir->new($self->database_directory, 'posts');
    return Plerd::Remembrancer->new(database_directory => $db_dir);
}

has 'publication_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_publication_directory',
    coerce => \&_coerce_directory
);
sub _build_publication_directory {
    my ($self) = shift;
    return Path::Class::Dir->new($self->path, "docroot");
}

has 'run_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_run_directory',
    coerce => \&_coerce_directory    
);
sub _build_run_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "run");
}

has 'site_description' => (is => 'rw', predicate => 1);

has 'show_max_posts' => (is => 'rw', default => sub { 5 });

has 'source_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_source_directory',
    coerce => \&_coerce_directory
);
sub _build_source_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "source");
}

has 'source_notes_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_source_notes_directory',
    coerce => \&_coerce_directory

);
sub _build_source_notes_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "source", "notes");
}

has tag_memory => (
    is => 'ro',
    lazy => 1,
    builder => '_build_tag_memory',
);
sub _build_tag_memory {
    my ($self) = @_;
    my $db_dir = Path::Class::Dir->new($self->database_directory, 'tags');
    return Plerd::Remembrancer->new(database_directory => $db_dir);
}


has 'template_directory' => (
    is => 'rw',
    lazy => 1,
    builder => '_build_template_directory',
    coerce => \&_coerce_directory    
);
sub _build_template_directory {
    my $self = shift;
    return Path::Class::Dir->new($self->path, "templates");
}

has 'title' => (is => 'rw', default => sub { "Another Plerd Blog" });
has twitter_id => (is => 'rw', predicate => 1);

#------------
# Coersions
#-------------
sub _coerce_directory {
    my ($path) = @_;
    return if !defined $path;

    if (ref $path eq 'Path::Class::Dir') {
        return $path->absolute;
    }

    my $dir = Path::Class::Dir->new($path); 
    if (!$dir) {
        die("assert - could not convert '$path' to Path. exists? "
        . (-d $path ? "yes" : "no")
        );
    }
    return $dir->absolute;    
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

sub _coerce_image {
    my ($img) = @_;
    if (ref $img eq 'URI') {
        return $img;
    }
    return URI->new( $img );
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
        database_directory
        publication_directory
        log_directory
        notes_publication_directory
        template_directory
        source_directory
        source_notes_directory
        run_directory
    ]) {
        if (!-d $self->$dir_method) {
            push @messages, "Creating " . $self->$dir_method();
            $self->$dir_method->mkpath; 
        }
    }

    # add default templates 
    my $src_template_dir = Path::Class::Dir->new($ENV{PLERD_HOME}, "lib", "Plerd", "Template");
    while (my $src_file = $src_template_dir->next) {
        next if substr($src_file, -3, 3) ne '.tt';

        my $dst_file = Path::Class::File->new($self->template_directory, $src_file->basename);
        if (-e $dst_file) {
            push @messages, "Removing existing $dst_file";
            $dst_file->remove;
        }
        push @messages, "Copying $src_file -> $dst_file";
        copy($src_file, $dst_file) or die("Cannot copy $src_file -> $dst_file: $!");
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

    # In the config file, there are *_path values that need to 
    # get mapped to *_directory properties here. 
    for my $property (keys %$config_ref) {
        my $method = $property;
        if ((my $base_prop = $property) =~ /^(\w+)_path$/) {
            $method = $1 . "_directory";
        }

        if ($self->can($method)) {
            $self->$method( $config_ref->{$property} );
        }
    }
    return 1;
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

    $self->config_file->spew($out);
}

1;