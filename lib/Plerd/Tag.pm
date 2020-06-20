package Plerd::Tag;

use Moo;
use URI;

has 'plerd' => (
    is => 'ro',
    required => 1,
    weak_ref => 1,
);

has 'posts' => (
    is => 'ro',
    default => sub { [] },
);

has 'name' => (
    is => 'rw',
    required => 1,
);

has 'uri' => (
    is => 'ro',
    lazy => 1,
);

sub add_post {
    my ($self, $post) = @_;

    my $added = 0;
    if ( @{$self->posts} ) {
        for (my $index = 0; $index <= @{$self->posts} - 1; $index++ ) {
            if ( $self->posts->[$index]->date < $post->date ) {
                splice @{$self->posts}, $index, 0, $post;
                $added = 1;
                last;
            }
        }
    }

    unless ($added) {
        push @{$self->posts}, $post;
    }
}

sub ponder_new_name {
    my ($self, $new_name) = @_;

    my $current_name = $self->name;

    if ( $current_name eq $new_name ) {
        return;
    }
    else {
        $self->plerd->add_tag_case_conflict( $new_name, $current_name );
        if ( not ($current_name =~ /[[:upper:]]/) ) {
            $self->name( $new_name );

        }
    }
}

sub _build_uri {
    my $self = shift;

    return URI->new_abs(
        'tags/' . $self->name . '.html',
        $self->plerd->base_uri,
    );
}

1;

