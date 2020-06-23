package Plerd::Controller::Posts;
use strict;
use warnings;

use Moo;

use Plerd::Model::Post;

has config => (is => 'ro', required);
has template_file => (is => 'ro', default => sub {}); 
sub show {
    my ($app) = @_;
    my ($source_file) = $self->param("source_file");

    my $post = Plerd::Model::Post->new(source_file => $source_file,
                                       config => $app->config);
    return $app->publish($post);
}


1;