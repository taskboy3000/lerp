package Plerd::Post;

use Data::GUID;
use DateTime;
use DateTime::Format::W3CDTF;
use HTML::SocialMeta;
use HTML::Strip;
use JSON;
use Moo;
use Path::Class::File;
use Text::MultiMarkdown qw( markdown );
use URI;

use Plerd::SmartyPants;

our $gWPM = 200; # The words-per-minute reading speed to assume

has 'attributes' => (is => 'rw', default => sub { {} });
has 'body' => (is => 'rw');
has 'date' => (is => 'rw', handles => [qw(month month_name day year ymd hms)], trigger => \&_build_utc_date);
has 'description' => (is => 'rw', default => '',);
has 'guid' => (is => 'rw');
sub _build_guid {
    my $self = shift;

    return Data::GUID->new;
}

has 'image' => (is => 'rw', default => undef);
has 'image_alt' => (is => 'rw', default => undef);
has 'json' => (is => 'ro', default => sub { JSON->new->convert_blessed });
has 'newer_post' => (is => 'ro', lazy => 1, builder => '_build_newer_post');
sub _build_newer_post {
    my $self = shift;

    my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

    my $newer_post;
    if ( $index - 1 >= 0 ) {
        $newer_post = $self->plerd->posts->[ $index - 1 ];
    }

    return $newer_post;
}
has 'older_post' => (is => 'ro', lazy => 1, builder => '_build_older_post');
sub _build_older_post {
    my $self = shift;

    my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

    my $older_post = $self->plerd->posts->[ $index + 1 ];

    return $older_post;
}

has 'plerd' => (is => 'ro', required => 1, weak_ref => 1);
has 'publication_file' => (is => 'ro',lazy => 1, predicate => 1, builder => '_build_publication_file');
sub _build_publication_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->plerd->publication_directory,
        $self->published_filename,
    );
}

has 'publication_file_mtime' => (is => 'ro', lazy => 1, builder => '_builder_publication_file');
sub _build_publication_file_mtime {
    my ($self) = @_;
    if (-e $self->publication_file->stringify) {
        my @stat = $self->publication_file->stat;
        return $stat[9];
    }

    return;
}

has 'published_filename' => (is => 'rw', lazy => 1, builder => '_build_published_filename');
sub _build_published_filename {
    my $self = shift;

    my $filename = $self->source_file->basename;

    # If the source filename already seems Plerdish, just replace its extension.
    # Else, generate a Plerdish filename based on the post's date and title.
    if ( $filename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
        $filename =~ s/\..*$/.html/;
    }
    else {
        $filename = $self->title;
        my $stripper = HTML::Strip->new( emit_spaces => 0 );
        $filename = $stripper->parse( $filename );
        $filename =~ s/\s+/-/g;
        $filename =~ s/--+/-/g;
        $filename =~ s/[^\w\-]+//g;
        $filename = lc $filename;
        $filename = $self->date->ymd( q{-} ) . q{-} . $filename;
        $filename .= '.html';
    }

    return $filename;
}
has 'published_timestamp' => (is => 'ro', lazy => 1, builder => '_build_published_timestamp');
sub _build_published_timestamp {
    my $self = shift;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime( $self->date );

    return $timestamp;
}

has 'reading_time' => (is => 'ro', lazy => 1, builder => '_build_reading_time');
sub _build_reading_time {
    my $self = shift;

    my @words = $self->stripped_body =~ /(\w+)\W*/g;

    return int ( scalar(@words) / $gWPM ) + 1;
}

has 'social_meta_tags' => (is => 'ro', lazy => 1, builder => '_build_social_meta_tags');
sub _build_social_meta_tags {
    my $self = shift;

    my $tags = '';

    my %targets = (
        twitter => 'twitter_id',
        opengraph => 'facebook_id',
    );

    if ( $self->socialmeta ) {
        for my $target ( keys %targets ) {
            my $id_method = $targets{ $target };
            if ( $self->plerd->$id_method ) {
                eval {
                    $tags .=
                        $self->socialmeta->$target->create(
                            $self->socialmeta_mode
                        );
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

has 'socialmeta' => (is => 'ro', lazy => 1, builder => '_build_socialmeta');
sub _build_socialmeta {
    my $self = shift;

    unless ( $self->image ) {
        # Neither this post nor this whole blog defines an image URL.
        # So, no social meta-tags for this post.
        return;
    }

    my %args = (
        site_name   => $self->plerd->title,
        title       => $self->title,
        description => $self->description,
        image       => $self->image->as_string,
        url         => $self->uri->as_string,
        fb_app_id   => $self->plerd->facebook_id || '',
        site        => $self->plerd->twitter_id || '',
        image_alt   => $self->image_alt,
    );

    $args{ site } = '@' . $args{ site } if $args{ site };

    my $socialmeta;

    eval {
        $socialmeta = HTML::SocialMeta->new( %args );
        1
    } or do {
        warn "Couldn't build an HTML::SocialMeta object for post "
             . $self->source_file->basename
             . ": $@\n";
    };

    return $socialmeta;
}

has 'socialmeta_mode' => (is => 'rw', default => sub {'summary'});

has 'source_file' => (is => 'ro', required => 1, trigger => \&_process_source_file,); # @fixme

has 'source_file_mtime' => (is => 'ro', lazy => 1, builder => '_build_source_file_mtime');
sub _build_source_file_mtime {
    my ($self) = @_;
    if (-e $self->source_file->stringify) {
        my @stat = $self->source_file->stat;
        return $stat[9];
    }
    return;
}

has 'stripped_body' => (is => 'ro', lazy => 1, builder => '_build_stripped_body');
sub _build_stripped_body {
    my $self = shift;

    return $self->_strip_html( $self->body );
}

has 'stripped_title' => (is => 'ro', lazy => 1, builder => '_build_stripped_title');
sub _build_stripped_title {
    my $self = shift;

    return $self->_strip_html( $self->title );
}

has 'tag_objects' => (is => 'rw', lazy => 1, builder => '_build_tag_objects');
sub  _build_tag_objects { [] }
 
has 'title' => (is => 'rw');
has 'updated_timestamp' => (is => 'ro', lazy => 1, builder => '_build_updated_timestamp');
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

has 'uri' => (is => 'ro', lazy => 1, builder => '_build_uri');
sub _build_uri {
    my $self = shift;

    my $base_uri = $self->plerd->base_uri;
    if ($base_uri =~ /[^\/]$/) {
        $base_uri .= '/';
    }
    return URI->new_abs(
        $self->published_filename,
        $base_uri,
    );
}

has 'utc_date' => (is => 'rw', lazy => 1, builder => '_build_utc_date');
sub _build_utc_date {
    my $self = shift;

    my $dt = $self->date->clone;
    $dt->set_time_zone( 'UTC' );
    return $dt;
}

#-------------------
# "Public" methods
#-------------------
sub publish {
    my $self = shift;

    # Make <title>-ready text free of possible Markdown-generated HTML tags.
    my $stripped_title = $self->title;
    $stripped_title =~ s{</?(em|strong)>}{}g;

    my $html_fh = $self->publication_file->openw;
    my $template_fh = $self->plerd->post_template_file->openr;
    for ( $html_fh, $template_fh ) {
	    $_->binmode(':utf8');
    }

    $self->plerd->template->process(
        $template_fh,
        {
            plerd => $self->plerd,
            posts => [ $self ],
            title => $stripped_title,
            context_post => $self,
        },
	    $html_fh,
    ) || $self->plerd->_throw_template_exception( $self->plerd->post_template_file );

    $self->publication_file_mtime;
    $self->update_tag_db;
}

sub tags {
    my $self = shift;

    return [ map { $_->name } @{ $self->tag_objects } ];
}

sub update_tag_db {
    my $self = shift;
    my $tags = $self->tags;

    @$tags 
}

#-------------------
# "Private" methods
#-------------------
sub _strip_html {
    my ($self, $raw_text) = @_;

    my $stripped = HTML::Strip->new->parse( $raw_text );

    # Clean up apparently orphaned punctuation
    $stripped =~ s{ ([;.,\?\!])}{$1}g;

    return $stripped;
}

# This next internal method does a bunch of stuff.
# It's called via Moose-trigger when the object's source_file attribute is set.
# * Read and store the file's data (body) and metadata
# * Figure out the publication timestamp, based on possible (not guaranteed!)
#   presence of date in the filename AND/OR "time" metadata attribute
# * If the file lacks a various required attributes, rewrite the file so that
#   it has them.
sub _process_source_file {
    my $self = shift;

    # Slurp the file, storing the title and time metadata, and the body.
    my $fh = $self->source_file->open('<:encoding(utf8)');
    my %attributes;
    my @ordered_attribute_names = qw( title time published_filename guid tags);
    while ( my $line = <$fh> ) {
        chomp $line;
        last unless $line =~ /\S/;
        my ($key, $value) = $line =~ /^\s*(\w+?)\s*:\s*(.*?)\s*$/;
        if ( $key ) {
            $key = lc $key;
            $attributes{ $key } = $value;
            unless ( grep { $_ eq $key } @ordered_attribute_names ) {
                push @ordered_attribute_names, $key;
            }
        }
    }

    $self->attributes( \%attributes );

    my $body;
    while ( <$fh> ) {
        $body .= $_;
    }

    close $fh;

    if ( $attributes{ title } ) {
        $self->title( $attributes{ title } );
    }
    else {
        die 'Error processing ' . $self->source_file . ': '
            . 'File content does not define a post title.'
        ;
    }
    $self->body( $body );

    foreach ( qw( title body ) ) {
        if ( defined( $self->$_ ) ) {
            $self->$_( Plerd::SmartyPants::process( markdown( $self->$_ ) ) );
        }
    }

    # Strip unnecessary <p> tags that the markdown processor just added to the title.
    my $stripped_title = $self->title;
    $stripped_title =~ s{</?p>\s*}{}g;
    $self->title( $stripped_title );

    # Check and tune attributes used to render social-media metatags.
    if ( $attributes{ description } ) {
        $self->description( $attributes{ description } );
    }
    else {
        my $body = $self->stripped_body;
        my ( $description ) = $body =~ /^\s*(.*)\n/;
        $self->description( $description || '' );
    }

    if ( $attributes{ image } ) {
        $self->image( URI->new( $attributes{ image } ) );
        $self->image_alt( $attributes{ image_alt } || '' );
        $self->socialmeta_mode( 'featured_image' );
    }
    else {
        $self->image( $self->plerd->image );
        $self->image_alt( $self->plerd->image_alt || '' );
    }

    # Note whether the filename asserts the post's publication date.
    my ( $filename_year, $filename_month, $filename_day ) =
        $self->source_file->basename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;

    # Set the post's date, using these rules:
    # * If the post has a time attribute in W3 format, use that
    # * Elsif the post's filename asserts a date, use midnight of that date,
    #   and also add a time attribute to the file.
    # * Else use right now, and also add a time attribute to the file.
    my $attributes_need_to_be_written_out = 0;
    if ( $attributes{ time } ) {
        eval {
            $self->date(
                $self->plerd->datetime_formatter->parse_datetime( $attributes{ time } )
            );
            $self->date->set_time_zone( 'local' );
        };
        unless ( $self->date ) {
            die 'Error processing ' . $self->source_file . ': '
                . 'The "time" attribute is not in W3C format.'
            ;
        }
    }
    else {
        my $publication_dt;

        if ( $filename_year ) {
            # The post specifies its day in the filename, but we still don't have a
            # publication hour.
            # If the filename's date is today (locally), use the current time.
            # Otherwise, use midnight of the provided date.
            my $now = DateTime->now( time_zone => 'local' );
            my $ymd = $now->ymd( q{-} );
            if ( $self->source_file->basename =~ /^$ymd/ ) {
                $publication_dt = $now;
            }
            else {
                $publication_dt = DateTime->new(
                    year => $filename_year,
                    month => $filename_month,
                    day => $filename_day,
                    time_zone => 'local',
                );
            }
        }
        else {
            # The file doesn't name the time, *and* the file doesn't contain the date
            # in metadata (or else we wouldn't be here), so we'll just use right-now.
            $publication_dt = DateTime->now( time_zone => 'local' );
        }

        $self->date( $publication_dt );

        my $date_string =
            $self->plerd->datetime_formatter->format_datetime( $publication_dt );

        $attributes{ time } = $date_string;
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes{ tags } ) {
        my @tag_names = split /\s*,\s*/, $attributes{ tags };
        for my $tag_name (@tag_names) {
            my $tag = $self->plerd->tag_named( $tag_name );
            $tag->add_post( $self );
            push @{ $self->tag_objects }, $tag;
        }
    }

    if ( $attributes{ published_filename } ) {
        $self->published_filename( $attributes{ published_filename } );
    }
    else {
        $attributes{ published_filename } = $self->published_filename;
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes{ guid } ) {
        $self->guid( Data::GUID->from_string( $attributes{ guid } ) );
    }
    else {
        $attributes{ guid } = Data::GUID->new;
        $self->guid( $attributes{ guid } );
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes_need_to_be_written_out ) {
        my $new_content = '';
        for my $attribute_name ( @ordered_attribute_names ) {
            if (defined $attributes{ $attribute_name } ) {
                $new_content .= "$attribute_name: $attributes{ $attribute_name }\n";
            }
        }
        $new_content .= "\n$body\n";
        $self->source_file->spew( iomode=>'>:encoding(utf8)', $new_content );
    }
}

sub _store {
    my $self = shift;
    my ($filename, $data_ref) = @_;

    my $post_dir =  Path::Class::Dir->new(
        $self->plerd->database_directory,
        $self->guid,
    );

    unless ( -e $post_dir ) {
        $post_dir->mkpath;
    }

    my $file = Path::Class::File->new(
        $post_dir,
        $filename,
    );
    $file->spew( $self->json->utf8->encode( $data_ref ) );
}

sub _retrieve {
    my $self = shift;
    my ($filename) = @_;

    my $file = Path::Class::File->new(
        $self->plerd->database_directory,
        $self->guid,
        $filename,
    );

    if ( -e $file ) {
        return $self->json->utf8->decode( $file->slurp );
    }
    else {
        return undef;
    }
}

1;