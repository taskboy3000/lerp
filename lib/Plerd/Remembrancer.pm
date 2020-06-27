# This class is a primative hash on disk.
#
# keys are files relative to some base dir.
# values are the contents of those files.
# empty values are allowable.
#
package Plerd::Remembrancer;
use Modern::Perl '2018';

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

    if (ref $payload) {
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

sub updated_at {
    my ($self, $key) = @_;
    my $entry = $self->_key_to_entry($key);
    if (-e $entry) { 
        my $stat = $entry->stat();
        return $stat->mtime;
    }

    return;
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

# Alpha sorted keys;
sub keys {
    my ($self) = @_;

    my $filter = sub {
        my ($files) = @_;

        return sort { $a->stringify cmp $b->stringify } @$files;
    };

    my @files = _dir_walk($self->database_directory, $filter);

    return [ map { $self->_entry_to_key($_) } @files ];
}

# Reverse chrono keys
sub earliest_keys {
    my ($self) = @_;

    my $filter = sub {
        my ($files) = @_;

        return sort { $a->stat->mtime <=> $b->stat->mtime } @$files;
    };
    my @files = _dir_walk($self->database_directory, $filter);

    return [ map { $self->_entry_to_key($_) } @files ];
}

# Chrono keys
sub latest_keys {
    my ($self) = @_;

    my $filter = sub {
        my ($files) = @_;

        return sort { $b->stat->mtime <=> $a->stat->mtime } @$files;
    };
    my @files = _dir_walk($self->database_directory, $filter);

    return [ map { $self->_entry_to_key($_) } @files ];
}


sub remove {
    my ($self, $keys) = @_;
    my $entry = $self->_key_to_entry;

    return if !-e $entry;

    $entry->remove;
    return 1;
}

#----------------------
# Private keys
#-----------------------
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
    my ($dir, $filter_coderef) = @_;
 
    if (!-d $dir) {
        return;
    }

    my @found;
    while (my $thing = $dir->next) {
        # No dot files allowed
        if (substr($thing->basename, 0, 1) eq '.') {
            next;
        }

        if ($thing->is_dir) {
            push @found, _dir_walk($thing); # pass along filter? 
        } else {
            push @found, $thing;
        }
    }

    if (defined $filter_coderef) {
        return $filter_coderef->(\@found);        
    }

    return @found;
}

1;