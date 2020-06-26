use Modern::Perl '2018';

use Test::More;
use Path::Class::Dir;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd::Model::Tag;

our $gDB_DIR;
our $gSRC_DIR;

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
    );

    for my $tag (keys %baselines) {
        my $t = Plerd::Model::Tag->new(name => $tag);
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
    $gDB_DIR = Path::Class::Dir->new($FindBin::Bin, "tag_db");
    if (-d $gDB_DIR) {
        $gDB_DIR->rmtree();
    }
    $gDB_DIR->mkpath(undef, 0755);

    # Purely fictional directory, none of the tags opts need these files to actually exist
    $gSRC_DIR = Path::Class::Dir->new($FindBin::Bin, "tag_source_dir");

}

sub teardown {
    $gDB_DIR->rmtree();
}