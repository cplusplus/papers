#!/usr/bin/perl -w
#
# Create lots of dummy closed issues.

use strict;

my $repo = $ENV{GITHUB_REPO};

for (my $i = 1; $i < 200; ++$i) {

    my $pnum = sprintf "P%04d", $i;

    open(F, "|./post.sh /repos/$repo/issues") || die "cannot POST new issue";
    print F "{\n";
    print F "  \"title\": \"P0000\"\n";
    print F "}\n";
    close F;

    sleep 10;
}
