use Modern::Perl '2018';

use Test::More;
use Path::Class::Dir;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd::Config;
use Plerd::Model::Tag;

our $gCFG;

Main();
exit;

#--------------
# Tests
#--------------
sub TestNameLogic {
    my %baselines = (
        'cat' => 'cat',
        'Dog' => 'dog',
        'Foo BaR' => 'foo_bar',
        'An <em>important</em> LESSON' => 'an_important_lesson',
        '#octothorpe' => 'octothorpe',
    );

    for my $tag (keys %baselines) {
        my $t = Plerd::Model::Tag->new(name => $tag, config => $gCFG);
        ok($t->name eq $baselines{$tag}, "Canonicalized '$tag' to '" . $t->name . "'");
        diag("Tag URI: " . $t->uri);
    } 
}



#--------------
# Helpers
#--------------
sub Main {
    setup();

    TestNameLogic();

    teardown();

    done_testing();
}

sub setup {
    $gCFG = Plerd::Config->new(path => "$FindBin::Bin/init/new-site");
    $gCFG->initialize;
}

sub teardown {
    $gCFG->path->rmtree;
}