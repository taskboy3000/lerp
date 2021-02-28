# Joe Johnston <jjohn@taskboy.com>, based on original work by
# Jason McIntosh <jmac@jmac.org>
package Plerd::Model::Post;
use Modern::Perl '2018';

use Data::GUID;
use DateTime;
use DateTime::Format::W3CDTF;
use File::Basename;
use HTML::SocialMeta;
use HTML::Strip;
use Digest::SHA qw(sha1_hex);
use Moo;
use Path::Class::File;

use URI;

use Plerd::Config;
use Plerd::Markdown;
use Plerd::Model::Tag;
use Plerd::SmartyPants;

our $gWPM = 200;    # The words-per-minute reading speed to assume

has 'attributes'              => ( is   => 'rw', default => sub { {} } );
has 'attributes_have_changed' => ( 'is' => 'rw', default => sub { 0 } );
has 'body'                    => (
    is        => 'rw',
    predicate => 1,
    coerce    => \&_apply_markdown
);
has 'config' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_config'
);

sub _build_config {
    Plerd::Config->new;
}

# @todo: should have a builder, trigger looks like coersion, but isn't
has 'date' => (
    is      => 'rw',
    handles => [ qw(month month_name day year ymd hms) ],
    lazy    => 1,
    builder => '_build_date',
    trigger => \&_build_utc_date
);

sub _build_date {
    my ( $self ) = @_;

    my ($filename_year, $filename_month,  $filename_day,
        $filename_hour, $filename_minute, $filename_second
        )
        = $self->source_file->basename =~
        /^(\d{4})y(\d{2})m(\d{2})d_(\d{2})h(\d{2})m(\d{2})s/;

# Set the post's date, using these rules:
# * If the post has a time attribute in W3 format, use that
# * Elsif the post's filename asserts a date, use midnight of that date,
#   and also add a time attribute to the file.
# * Else use the mtime of the source file and also add a time attribute to the file.
    my $dt;
    my $now = DateTime->now( time_zone => 'local' );
    if ( $self->attributes->{ time } ) {
        eval {
            $dt = $self->config->datetime_formatter->parse_datetime(
                $self->attributes->{ time } );
            $dt->set_time_zone( 'local' );
            1;
        } or do {
            die 'Error processing ' . $self->source_file . ': '
                . "The 'time' attribute is not in W3C format.\n";
        };
    } elsif ( $filename_year ) {

       # The post specifies its day in the filename, but we still don't have a
       # publication hour.
       # If the filename's date is today (locally), use the current time.
       # Otherwise, use midnight of the provided date.
        $dt = DateTime->new(
            year      => $filename_year,
            month     => $filename_month,
            day       => $filename_day,
            hour      => $filename_hour,
            minute    => $filename_minute,
            second    => $filename_second,
            time_zone => 'local'
        );
        $self->attributes_have_changed( 1 );
    } else {

     # The file doesn't name the time, *and* the file doesn't contain the date
     # in metadata (or else we wouldn't be here), so we'll just use mtime.
        my $mtime = $self->source_file->stat->mtime;

        $dt = DateTime->from_epoch( epoch => $mtime, time_zone => 'local' );
        $self->attributes_have_changed( 1 );
    }

    my $date_string =
        $self->config->datetime_formatter->format_datetime( $dt );

    $self->attributes->{ time } = $date_string;

    return $dt;
}

has 'description' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_description'
);

sub _build_description {
    my ( $self )        = @_;
    my $body            = $self->stripped_body;
    my ( $description ) = $body =~ /^\s*(.*)\n/;
    $description || '';
}

has 'guid' =>
    ( is => 'rw', lazy => 1, builder => '_build_guid', predicate => 1 );

sub _build_guid {
    my ( $self ) = @_;

    if ( $self->attributes->{ guid } ) {
        return $self->attributes->{ guid };
    }
    $self->attributes_have_changed( 1 );
    return Data::GUID->new;
}

has 'id' => (
    is => 'ro',
    lazy => 1,
    builder => '_build_id',
);
sub _build_id {
    my  ($self) = @_;
    return sha1_hex($self->uri);
}


# Inherit from the config
has 'image' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_image',
    coerce  => \&_coerce_image,
);

sub _build_image {
    my $self = shift;

    my $post_image = $self->attributes->{ image };
    if ( $post_image ) {
        return $post_image;
    }

    if ( $self->config->image ) {
        return $self->config->image;
    }

    return;
}

sub _coerce_image {
    my ( $img ) = @_;
    if ( ref $img eq 'URI' ) {
        return $img;
    }
    return URI->new( $img );
}

has 'image_alt' => (
    is        => 'rw',
    predicate => 1,
    lazy      => 1,
    builder   => '_build_image_alt'
);

sub _build_image_alt {
    my $self = shift;
    $self->config->image_alt;
}

# @todo: document supported attributes
has indieweb_sub => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_indieweb_sub',
    coerce  => \&_coerce_uri,
);

sub _build_indieweb_sub {
    my ( $self ) = @_;
    if ( exists $self->attributes->{ indieweb_sub } ) {
        return $self->attributes->{ indieweb_sub };
    }
    return;
}

# @todo:
#   If next/previous articles are desirable, then a feed of publication order of articles
#   needs to be generated and made amenable to getting this answer.
#
#   Something like what is used for the sidebar now.

has 'publication_file' => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    builder   => '_build_publication_file'
);

sub _build_publication_file {
    my $self = shift;

    if ( !$self->source_file_loaded ) {
        $self->load_source;
    }

    Path::Class::File->new( $self->config->publication_directory,
        $self->published_filename, );
}

# @todo: I am not clear that this is needed
has 'publication_file_mtime' => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    builder   => '_builder_publication_file_mtime'
);

sub _build_publication_file_mtime {
    my ( $self ) = @_;
    if ( -e $self->publication_file->stringify ) {
        my @stat = $self->publication_file->stat;
        return $stat[ 9 ];
    }
    die( "assert" );
}

has 'published_filename' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_published_filename',
    coerce  => \&_coerce_file,
);

sub _build_published_filename {
    my $self = shift;

    if ( !$self->source_file_loaded ) {
        $self->load_source;
    }

    if ( $self->attributes->{ published_filename } ) {
        return $self->attributes->{ published_filename };
    }

    $self->attributes_have_changed( 1 );
    my $filename = $self->source_file->basename;

  # If the source filename already seems Plerdish, just replace its extension.
  # Else, generate a Plerdish filename based on the post's date and title.
    if ( $filename =~ /^\d{4}y\d{2}m\d{2}d_\d{2}h\d{2}m\d{2}s-/ ) {
        $filename =~ s/\..*$/.html/;
    } else {
        $filename = $self->title;
        my $stripper = HTML::Strip->new( emit_spaces => 0 );
        $filename = $stripper->parse( $filename );
        $filename =~ s/\s+/-/g;
        $filename =~ s/--+/-/g;
        $filename =~ s/[^A-Z0-9\-]+//ig;    # \w breaks on smartypants

        $filename = lc $filename;

        # $filename = $self->date->ymd( q{-} ) . q{-} . $filename;
        my $d = $self->date;
        $filename = sprintf(
            "%04dy%02dm%02dd_%02dh%02dm%02ds-%s",
            $d->year,   $d->month,  $d->day, $d->hour,
            $d->minute, $d->second, $filename,
        );
        $filename .= '.html';
    }

    return $filename;
}

has 'published_timestamp' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_published_timestamp'
);

sub _build_published_timestamp {
    my $self = shift;

    # Cannot compute the published filename without
    # consuming source
    if ( !$self->source_file_loaded ) {
        $self->load_source;
    }

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime( $self->date );

    return $timestamp;
}

has 'ordered_attribute_names' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_ordered_attribute_names'
);

sub _build_ordered_attribute_names {
    return [ qw( title time published_filename guid tags) ];
}

has 'raw_body' => ( is => 'rw', default => sub { '' } );

has 'reading_time' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_reading_time'
);

sub _build_reading_time {
    my $self  = shift;
    my @words = $self->stripped_body =~ /(\w+)\W*/g;
    return int( scalar( @words ) / $gWPM ) + 1;
}

has 'social_meta_tags' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_social_meta_tags'
);

sub _build_social_meta_tags {
    my $self = shift;

    my $tags    = '';
    my %targets = (
        twitter   => 'twitter_id',
        opengraph => 'facebook_id',
    );

    if ( $self->socialmeta ) {
        for my $target ( keys %targets ) {
            my $id_method  = $targets{ $target };
            my $has_method = 'has_' . $id_method;

            if ( $self->config->$has_method ) {
                eval {
                    $tags .=
                        $self->socialmeta->$target->create(
                        $self->socialmeta_mode );
                    1;
                } or do {
                    warn "Couldn't create $target meta tags for "
                        . $self->source_file->basename
                        . ": $@\n";
                };
            }
        }
    }

    return $tags;
}

has 'socialmeta' => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    builder   => '_build_socialmeta'
);

sub _build_socialmeta {
    my $self = shift;

    my %args = (
        site_name   => $self->config->title,
        title       => $self->title,
        description => $self->description,
        url         => $self->uri->as_string,
    );

    if ( $self->image ) {
        $args{ image } = $self->image->as_string;
        if ( $args{ image_alt } ) {
            $args{ image_alt } = $self->image_alt->as_string;
        }
    } else {
        return;
    }

    my $has_silo = 0;
    if ( $self->config->has_facebook_id ) {
        $args{ fb_app_id } = $self->config->facebook_id;
        $has_silo = 1;
    }

    if ( $self->config->twitter_id ) {
        $args{ site } = '@' . $self->config->twitter_id;
        $has_silo = 1;
    }

    return if !$has_silo;

    my $socialmeta;
    eval {
        $socialmeta = HTML::SocialMeta->new( %args );
        1;
    } or do {
        warn "Couldn't build an HTML::SocialMeta object for post "
            . $self->source_file->basename
            . ": $@\n";
    };

    return $socialmeta;
}

has 'socialmeta_mode' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_socialmeta_mode',
    default => sub { 'summary' },
);

sub _build_socialmeta_mode {
    my ( $self ) = @_;

    my $mode = 'summary';
    if ( $self->image ) {
        $mode = 'featured_image';
    }

    return $mode;
}

has 'source_file' => (
    is        => 'rw',
    predicate => 1,
    coerce    => \&_coerce_file
);
has 'source_file_loaded' => ( is => 'rw', default => sub { 0 } );

has 'stripped_body' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_stripped_body'
);

sub _build_stripped_body {
    my $self = shift;
    return $self->_strip_html( $self->body );
}

has 'stripped_title' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_stripped_title'
);

sub _build_stripped_title {
    my $self = shift;
    return $self->_strip_html( $self->title );
}

has 'tags' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_tags',
    coerce  => \&_coerce_tags
);

sub _build_tags {
    my ( $self ) = @_;
    return $self->attributes->{ tags };
}

sub _coerce_tags {
    my ( $value ) = @_;
    my @tags;
    if ( ref $value eq [] ) {
        for my $val ( @$value ) {
            if ( ref $val eq 'Plerd::Model::Tag' ) {
                push @tags, $val;
            } else {
                push @tags, Plerd::Model::Tag->new( name => $val );
            }
        }
    } elsif ( $value ) {
        my @tmp = split /\s*,\s*/, $value;
        for ( @tmp ) {
            push @tags, Plerd::Model::Tag->new( name => $_ );
        }
    }

    return \@tags;
}

has 'template_file' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_template_file'
);

sub _build_template_file {
    my ( $self ) = @_;
    Path::Class::File->new( $self->config->template_directory,
        "single_post.tt" );
}

has 'title' => (
    is        => 'rw',
    predicate => 1,
    lazy      => 1,
    builder   => '_build_title',
    coerce    => \&_coerce_title,
);

sub _build_title {
    my ( $self ) = @_;
    basename( $self->source_file->basename, "\.md", "\.markdown" );
}

has 'updated_timestamp' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_updated_timestamp'
);

sub _build_updated_timestamp {
    my $self = shift;

    my $mtime = $self->source_file->stat->mtime;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime(
        DateTime->from_epoch(
            epoch     => $mtime,
            time_zone => 'local',
        ),
    );

    return $timestamp;
}

has 'uri' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_uri'
);

sub _build_uri {
    my $self = shift;

    my $base_uri = $self->config->base_uri;
    if ( $base_uri =~ /[^\/]$/ ) {
        $base_uri .= '/';
    }

    return URI->new_abs( $self->published_filename, $base_uri, );
}

has 'utc_date' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_utc_date'
);

sub _build_utc_date {
    my $self = shift;

    my $dt = $self->date->clone;
    $dt->set_time_zone( 'UTC' );
    return $dt;
}

has 'webmentions_display_uri' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_webmentions_display_uri',
);

sub _build_webmentions_display_uri {
    my $self = shift;
    if ( !$self->config->webmention_endpoint ) {
        return;
    }

    # WARNING: This assumes web mentions use whim
    #   https://github.com/jmacdotorg/whim
    my $clone = $self->config->webmention_endpoint->clone;
    $clone->path( $clone->path . 'display_wms' );
    $clone->query_form( 'url' => $self->uri );

    return $clone;
}

has 'webmentions_summary_uri' => (
    is      => 'rw',
    lazy    => 1,
    builder => '_build_webmentions_summary_uri',
);

sub _build_webmentions_summary_uri {
    my $self = shift;
    if ( !$self->config->webmention_endpoint ) {
        return;
    }

    # WARNING: This assumes web mentions use whim
    #   https://github.com/jmacdotorg/whim
    my $clone = $self->config->webmention_endpoint->clone;
    $clone->path( $clone->path . 'summarize_wms' );
    $clone->query_form( 'url' => $self->uri );

    return $clone;
}

#-------------------
# "Public" methods
#-------------------
sub load_source {
    my ( $self, $source_file ) = @_;

    if ( defined $source_file ) {
        $self->source_file( $source_file );
    }

    if ( !-e $self->source_file ) {
        die( "Cannot find source file: " . $self->source_file );
    }

    my $fh = $self->source_file->openr;
    my @ordered_attribute_names =
        qw( title time published_filename guid tags );
    my $line;
    while ( $line = <$fh> ) {
        chomp $line;

        my ( $key, $value ) = $line =~ /^\s*(\w+?)\s*:\s*(.*?)\s*$/;
        if ( $key ) {
            $key = lc $key;
            $self->attributes->{ $key } = $value;

            if ( $self->can( $key ) ) {
                $self->$key( $value );
            }

            if ( !grep { $_ eq $key } @{ $self->ordered_attribute_names } ) {
                push @{ $self->ordered_attribute_names }, $key;
            }
        } else {
            last;
        }
    }

    if ( !$self->has_guid ) {
        $self->guid;    # force one to be generated
        $self->attributes_have_changed( 1 );
    }

    my $body;

    $body = "$line\n" if length( $line ) > 0;
    while ( <$fh> ) {
        $body .= $_;
    }

    close $fh;
    $self->raw_body( $body );    # @thinkie: raw_title?
    $self->body( $body );        # this converts MD to HTML
    $self->source_file_loaded( 1 );
    return 1;
}

sub get_updated_source {
    my ( $self ) = @_;

    # if $self->attributes_have_changed...
    my $new_content = '';

    for my $attribute_name ( @{ $self->ordered_attribute_names } ) {
        if ( $self->can( $attribute_name ) ) {
            my $val = $self->$attribute_name();

            if ( ref $val eq 'ARRAY' ) {
                $val = join( ', ', @$val );
            } elsif ( ref $val eq 'HASH' ) {
                my @tmp;
                for my $k ( sort keys %$val ) {
                    push @tmp, sprintf( "(%s=%s)", $k, $val->{ $k } );
                }
                $val = join( ', ', @tmp );
            } elsif ( ref $val eq 'Path::Class::File' ) {
                $val = "$val";
            } elsif ( ref $val eq 'Data::GUID' ) {
                $val = "$val";
            } elsif ( ref $val && $val->isa( 'URI' ) ) {
                $val = "$val";
            } elsif ( ref $val ) {
                die("cannot serialize ref type '@{[ref $val]}' for attribute '$attribute_name'\n"
                );
            }

            if ( length( $val ) > 0 ) {
                $new_content .= sprintf( "%s: %s\n", $attribute_name, $val );
            }
        }
    }

    if ( $new_content ) {

# Have added back new attributes; ensure there is a space between headers and content
        $new_content .= "\n";
    }

    return $new_content . $self->raw_body;
}

sub serialize_source {
    my ( $self ) = @_;

    $self->source_file->spew( $self->get_updated_source );
}

sub can_publish {
    my ( $self ) = @_;

    if ( $self->has_title && $self->has_body ) {
        return 1;
    }

    return;
}

#-------------------
# "Private" methods
#-------------------
sub _apply_markdown {
    my ( $string ) = @_;
    my $md = Plerd::Markdown->new();
    return Plerd::SmartyPants::process( $md->markdown( $string || '' ), 'qdeqw' );
}

sub _coerce_file {
    my ( $thing ) = @_;

    if ( ref $thing eq 'Path::Class::File' ) {
        return $thing;
    }

    return Path::Class::File->new( $thing );
}

sub _coerce_title {
    my ( $string ) = @_;

    $string = _apply_markdown( $string );
    $string =~ s{</?(em|strong)>}{}g;
    $string =~ s{</?p>\s*}{}g;

    return $string;
}

sub _coerce_uri {
    my ( $string ) = @_;
    return unless $string;
    if ( ref $string eq 'URI' ) {
        return $string;
    }
    return URI->new( $string );
}

sub _strip_html {
    my ( $self, $raw_text ) = @_;

    my $stripped = HTML::Strip->new->parse( $raw_text );

    # Clean up apparently orphaned punctuation
    $stripped =~ s{ ([;.,\?\!])}{$1}g;

    return $stripped;
}

1;
