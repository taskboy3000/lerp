# This class is a primative hash on disk.
#
# keys are files relative to some base dir.
# values are the contents of those files.
# empty values are allowable.
#
package Plerd::Remembrancer;
use strict;
use warnings;

use Path::Class::Dir;
use Path::Class::File;

use Moo;
use YAML;

# Needs to be set by the caller
has database_directory => (
    is => 'ro', 
    required => 1, 
    coerce => \&_coerce_directory
);
sub _coerce_directory {
    my ($path) = @_;
    if (ref $path eq 'Path::Class::Dir') {
        return $path->absolute;
    }

    return Path::Class::Dir->new($path)->absolute;    
}

#----------------------
# Public Methods
#----------------------
# If key is an arrary ref, consider it to be nested keys
# $key => [ 'foo', 'bar' , 'baz' ] =>
#   DB_DIR/foo/bar/
#      with a key file called 'baz'
sub save {
    my ($self, $key, $payload) = @_;

    my $entry = $self->_key_to_entry($key);
    if (!-d $entry->parent) {
        if (-e $entry->parent) {
            die("Declining to overwrite existing key: " . $entry->parent);
        } else {
            $entry->parent->mkpath;
        }   
    }

    if (ref $payload eq ref {}) {
        $entry->spew(iomode => '>:encoding(UTF-8)', Dump($payload));
    } else {
        $entry->touch;
    }

    return 1;
}

sub exists {
    my ($self, $key) = @_;
    my $entry = $self->_key_to_entry($key);
    return -e $entry;
}

sub load {
    my ($self, $key) = @_;
    my $entry = $self->_key_to_entry($key);

    if (-e $entry) {
        if (-s $entry) {
            my $yaml = $entry->slurp(iomode => '<:encoding(UTF-8)');
            return Load($yaml);
        } else {
            return 1;
        }
    }

    return;
}

# Directory walk through DB dir, return keys as an array suitable for load();
sub keys {
    my ($self) = @_;
die("assert");
    # $entry->parent - $self->database_directory ?
    # key1/key2 ?
    my @keys;

    my @files = _dir_walk($self->database_directory);


    return [ map { $self->_entry_to_key($_) } @files ];
}

sub remove {
    my ($self, $keys) = @_;
    my $entry = $self->_key_to_entry;

    return if !-e $entry;

    $entry->remove;
    return 1;
}

sub _key_to_entry {
    my ($self, $key) = @_;

    # Make a copy of $key array so as not to maul the caller
    my @copy;
    if (ref $key eq ref []) {
        @copy = @$key;
    } else {
        @copy = ($key);
    }

    my $entry = Path::Class::File->new($self->database_directory, @copy);

    return $entry;
}

sub _entry_to_key {
    my ($self, $entry) = @_;
    return if !$entry;

    my $rel = $entry->relative($self->database_directory);
    my @parts = $rel->components;

    if ($parts[0] eq ".") {
        shift @parts;
    }

    return \@parts;
}

# not a method
sub _dir_walk {
    my ($dir, $opt_subdirs_only) = @_;

    my @found;
    while (my $thing = $dir->next) {
        # No dot files allowed
        next if substr($thing, 0, 1) eq '.';

        if (-d $thing) {
            push @found, $thing if $opt_subdirs_only;
            push @found, _dir_walk($thing, $opt_subdirs_only);
        } else {
            push @found, $thing if !$opt_subdirs_only;
        }
    }

    return sort { $a->stringify cmp $b->stringify } @found;     
}

1;