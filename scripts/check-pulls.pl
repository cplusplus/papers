#!/usr/bin/perl -w

# This script checks all pending pull requests in the "cplusplus/draft"
# repository and labels those in need with "needs-rebase".

use strict;
use JSON;

my $repo = "cplusplus/draft";

local $/;

my $q = "is:pr is:open repo:cplusplus/draft -label:\"needs rebase\"";
$q =~ s/ /+/g;

open(F, "./github-get.sh '/search/issues?q=$q&sort=updated&order=desc&per_page=100&page=1'|") || die "cannot GET";

my $resp = <F>;
close F;

my $obj = decode_json($resp);

for my $i (@{$obj->{items}}) {
    my $number = $i->{number};

    next if $i->{title} =~ /^P[0-9]{4}R[0-9]+/;

    local $/;
    open(F, "./github-get.sh '/repos/cplusplus/draft/pulls/$number'|") || die "cannot GET";
    my $resp = <F>;
    close F;

    my $issue = decode_json($resp);

    if ($issue->{mergeable_state} eq "dirty") {
	open(F, "|./github-post.sh /repos/cplusplus/draft/issues/$number/labels > /dev/null") || die "cannot POST comment";
	print F "{\n";
	print F  "\"labels\": [ \"needs rebase\" ]\n";
	print F "}\n";
	close F;

	print "added 'needs rebase' label to #", $i->{number}, " ", $i->{title}, "\n";
    }
}
