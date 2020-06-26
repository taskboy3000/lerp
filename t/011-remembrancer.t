use Modern::Perl '2018';

use FindBin;
BEGIN {
    $::gLIBDIR="$FindBin::Bin/../lib";
}
use lib $::gLIBDIR;

use Test::More;

use Plerd::Remembrancer;

Main();
exit;

#---------------
# Tests
#---------------
sub TestNonExistingKeyFetch {
    my ($R) = @_;
    ok(!$R->load("foo"), "Attempting to load non-existing scalar key");
    ok(!$R->load(["bar"]), "Attempting to load non-existing array key (1 element)");
    ok(!$R->load(["foo", "bar"]), "Attempting to load non-existing array key (2 elements)");
}

sub TestPayloadKeyStore {
    my ($R) = @_;
    my @baselines = (
        [
            "Store scalar with no payload",
            [ "foo" => 0 ],
        ],
        [
            "Store 1 element array key with payload",
            [
                ["bar"] => { prop1 => "a", prop2 => "b" },
            ]
        ],
        [
            "Store 2 element array key with no payload",
            [
                ["baz", "bar"] => 0,
            ]
        ],
        [
            "Store 2 element array key with payload",
            [
                ["baz", "foo"] => {prop3 => "c", prop4 => "d"}
            ]
        ]
    );

    for my $pair (@baselines) {
        my ($description, $data) = @$pair;
        my ($key, $payload) = @$data;

        my $got_entry = $R->_key_to_entry($key);
        ok($got_entry, "Converted key to an DB entry: " . $got_entry);
        my $got_key = $R->_entry_to_key($got_entry);
        my $test_key = ref $key ? $key : [ $key ];

        for (my $i=0; $i < @$test_key; $i++) {
            ok($test_key->[$i] eq $got_key->[$i], 
                "  Retrieved key part matched original key: " . $test_key->[$i]
            );            
        }

        my $rc = eval { $R->save($key, $payload) };
        ok($rc, "  $description");
        sleep(1); # introduce variations in mtimes
    }

    my $rc = eval { $R->save(["foo", "bar"]) };
    ok(!$rc, "Ensuring accidental key overwrites do not happen");
    if ($@) {
        diag($@);
    }
}

sub TestKeyExistence {
    my ($R) = @_;
    my @baselines = (
        [
            "Exists with scalar key",
            [ "foo" ],
        ],
        [
            "Exists 2 element array key",
            [
                ["baz", "bar"],
            ]
        ],
    );

    for my $pair (@baselines) {
        my ($description, $data) = @$pair;
        my ($key) = @$data;
        ok($R->exists($key), $description);
        my $updated_at = $R->updated_at($key);
        ok($updated_at, "Key was updated: " . localtime($updated_at));
    }

    ok(!$R->exists(["foo", "bar"]), "Non-existing key does not exist");
    ok(!defined $R->updated_at(["foo", "bar"]), "Non-existing key does not have an updated timestamp");
}

sub TestKeys {
    my ($R) = @_;

    my $list = $R->keys();
    ok(@$list == 4, "Got expected list of keys");
    for my $entry (@$list) {
        diag("  " . join("/", @$entry));
    }

    my $earliest = $R->earliest_keys;
    ok(@$earliest, "Got earliest keys");
    for my $entry (@$earliest) {
        diag("  " . join("/", @$entry));
    }
    my $latest = $R->latest_keys;
    ok(@$latest, "Got latest keys");
    for my $entry (@$latest) {
        diag("  " . join("/", @$entry));
    }

    ok(join(",",@{$earliest->[0]}) ne join(",", @{$latest->[0]}), 
        "Ealiest list appears to be different from latest list"
    );
}

sub TestPayloadRetrieval {
    my ($R) = @_;

    my @baselines = (
        [
            "Retrieve scalar with no payload",
            [ "foo" => 1 ],
        ],
        [
            "Retrive 1 element array key with payload",
            [
                ["bar"] => { prop1 => "a", prop2 => "b" },
            ]
        ],
        [
            "Retrieve 2 element array key with no payload",
            [
                ["baz", "bar"] => 1,
            ]
        ],
    );

    for my $pair (@baselines) {
        my ($description, $data) = @$pair;
        my ($key, $expected) = @$data;

        my $ret = $R->load($key);
        ok(defined $ret, $description);

        if (ref $expected eq ref {}) {
            while (my ($got_key, $got_value) = each %$ret) {
                ok($ret->{$got_key} eq $expected->{$got_key},
                    "  Key '$got_key' had expected value"
                );
            }
        } else {
            ok($ret == $expected, "  Got a payload with an expected value");
        }
    }

    # Test non-existent key retrieval
    ok(!$R->load(['nonsuch']), "Non-existing key returned a false value");
}

sub TestKeyRemoval {
    my ($R) = @_;
    my @baselines = (
        [
            "Remove scalar key",
            [ "foo" ],
        ],
        [
            "Remove 2 element array key",
            [
                ["foo", "bar"],
            ]
        ],
    );

    for my $pair (@baselines) {
        my ($description, $data) = @$pair;
        my ($key) = @$data;
        ok($R->remove($key), $description);
    }
}

#---------
# Helpers
#---------
sub Main {
    my $Remembrancer = setup();

    TestNonExistingKeyFetch($Remembrancer);
    TestPayloadKeyStore($Remembrancer);
    TestKeyExistence($Remembrancer);
    TestKeys($Remembrancer);
    TestPayloadRetrieval($Remembrancer);
    TestKeyRemoval($Remembrancer);

    teardown($Remembrancer);

    done_testing();
}

sub setup {
    my $db_dir = Path::Class::Dir->new($FindBin::Bin, "init", "rstore");
    if (-d $db_dir) {
        $db_dir->rmtree;
    }

    return Plerd::Remembrancer->new(database_directory => $db_dir);
}

sub teardown {
    my ($R) = @_;
    $R->database_directory->rmtree;
}
