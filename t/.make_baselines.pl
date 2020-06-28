#!/usr/bin/env perl
use Modern::Perl '2018';

use File::Copy;
use FindBin;
BEGIN {
    if (!exists $ENV{PLERD_HOME}) {
        $ENV{PLERD_HOME} = "$FindBin::Bin/..";
    }
}
use lib "$ENV{PLERD_HOME}/lib";

use Path::Class::Dir;

use Plerd;

Main();
exit;

#-------------------
# Subroutines
#-------------------
sub Main {
    my $plerd = Plerd->new;
    $plerd->config->path("$FindBin::Bin/init/new-site");
    
    if (-d $plerd->config->path) {
        $plerd->config->path->rmtree;
    }
    say "Creating a default temp site";
    $plerd->config->initialize;

    say "Copying in source models";
    my $sources = Path::Class::Dir->new($FindBin::Bin, "source_model");
    for my $src ($sources->children) {
        copy $src, $plerd->config->source_directory;
    }

    say "Publishing temp site";
    $plerd->publish_all(verbose => 1);

    my $baseline_dir = Path::Class::Dir->new($FindBin::Bin, "baselines/new-site/docroot");
    say "Removing old baselines";
    $baseline_dir->rmtree;
    $baseline_dir->mkpath;

    say "Moving published docroot to " . $baseline_dir;
    for my $pub ($plerd->config->publication_directory->children) {
        next if -d $pub;
        my $trg = Path::Class::File->new($baseline_dir, $pub->basename);
        say "$pub -> $trg";
        copy($pub, $trg) || die ("assert: $!")
    }
    
    say "Removing temp site";
    $plerd->config->path->rmtree;

    say "Remember to check new baselines into git"
}
