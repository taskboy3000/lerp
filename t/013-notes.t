use Modern::Perl '2018';

use FindBin;
BEGIN {
    $::gLIBDIR="/Users/jjohn/src/plerd_taskboy3000/t/../lib";
}
use lib $::gLIBDIR;

use Test::More;

use Plerd::Model::Note;

Main();
exit;

#-----------
# Tests
#-----------
sub TestNotesParsing {
    diag("Testing note parsing with strings");

    my @baselines =
        (
            [
qq[I hate Mondays. ☹️
#mondays #rainydays],
q[I hate Mondays. ☹️
<a href="tags.html#tag-mondays-list">#mondays</a> <a href="tags.html#tag-rainydays-list">#rainydays</a>],
            ],      
            [
q[ Acrostics
 Simply
 Satisfy
 Humans
 Ordinarily
 Living like
mE
],
q[ Acrostics
 Simply
 Satisfy
 Humans
 Ordinarily
 Living like
mE]
            ],
            [
q[Why do I like cats?

Please see https://icanhas.cheezburger.com
#cats],
q[Why do I like cats?

Please see <a rel="noopener noreferrer" href="https://icanhas.cheezburger.com">https://icanhas.cheezburger.com</a>
<a href="tags.html#tag-cats-list">#cats</a>],
            ],
            [
q[Spaces   is  there   *ANYTHING*   more futile?


No.],
q[Spaces   is  there   *ANYTHING*   more futile?


No.],
            ],
            [
q[->  http://facebook.com/
This garbage site is garbage.],
q[<div class="h-cite u-in-reply-to reply-to">In reply to: <a rel="noopener noreferrer" href="http://facebook.com/">http://facebook.com/</a></div>
This garbage site is garbage.]
            ],
            [
q[^https://twitter.com/
Although it too is a garbage site, I rather prefer it to others.],
q[<div class="h-cite u-like-of like"><abbr title="I like the following post">👍</abbr>: <a rel="noopener noreferrer" class="" href="https://twitter.com/">https://twitter.com/</a></div>
Although it too is a garbage site, I rather prefer it to others.]                
            ],
        );

    my $N = Plerd::Model::Note->new;
    for my $pair (@baselines) {
        my ($test, $expected) = @$pair;
        my $got = $N->parse($test);
        ok($got eq $expected, "parse test");
        if ($got ne $expected) {
            say "RAW RESPONSE:\n$got|";
            $expected =~ s/ /./g;
            $got =~ s/ /./g;
            say "Expected (@{[length($expected)]}):\n$expected|";
            say "---\nGot (@{[length($got)]}):\n$got|";
        }
    }       
}

sub TestNotesModel {
    diag("Testing models from source files");

    my $N = Plerd::Model::Note->new;
    $N->config->source_notes_directory("$FindBin::Bin/source_notes");
    while (my $file = $N->config->source_notes_directory->next) {
        next if -d $file;
        diag("Loading $file");
        my $note = $N->load($file);
        ok($note, "loaded file");
        ok($note->uri, "URI: " . $note->uri);
        ok($note->title, "Title: " . $note->title);
        diag("Tags: ", join(", ", map { $_->name } @{$note->tags}));
        ok(defined($note->body), "Body");
        diag("---processed body---");
        diag($note->body);
        diag("--------------------");
        diag("="x75);
    }    
}

#------------
# Helpers
#------------
sub Main {
    # Initialize globals as needed
    setup();

    # Invoke tests here
    TestNotesParsing();
    TestNotesModel();

    # Clean up as needed
    teardown();

    done_testing();
}

sub setup {

}

sub teardown {

}
