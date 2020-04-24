#!/usr/bin/perl -w

# Parse the sd-1.htm document, but use only the "Adopted" remarks
# to close issues.  Do not create or otherwise update issues.

use strict;
use JSON;

my $repo = "cplusplus/papers";

local $/;
my $html = <>;

my @p = split /<tr >/, $html;

shift @p;


foreach my $x (@p) {
    $x =~ s,\s*</td>\s*\n,,gs;
    $x =~ s,\s*</tr>\s*,,gs;
    my ($dummy, $pnum, $title, $author, $date, $mailing, $prev, $groups, $adopted) = split /<td > */, $x;

    $pnum =~ s/(N[0-9]+|P[0-9]+R[0-9]+).*$/$1/s;
    $title =~ s/\n//gs;
    $title =~ s/\s*$//s;
    $author =~ s/ +/ /g;

    next if $pnum =~ /^N/;

    my $lcpnum = lc $pnum;
    my $pseries = $pnum;
    $pseries =~ s/R.+$//;
    my $rev = $pnum;
    $rev =~ s/^.*R//;

    my $body = "[$pnum](https://wg21.link/$lcpnum) $title ($author)";

    next if !defined $adopted;
    next unless $adopted =~ /^Adopted 2020-02/;

    print "$adopted $pnum $title\n";

    # Look for an existing issue for this paper.
    my $q = "$pseries is:open is:issue in:title repo:$repo";
    $q =~ s/ /+/g;

    local $/;
    open(F, "./github-get.sh '/search/issues?q=$q'|") || die "cannot GET";
    my $resp = <F>;
    close F;
    my $obj = decode_json($resp);

    # Make sure the title actually starts with the given paper number.
    my $issue = undef;
    foreach my $i (@{$obj->{items}}) {
	if ($i->{title} =~ /^$pseries /) {
	    $issue = $i;
	    last;
	}
    }

    next if !defined $issue;   # Issue not found
    
    my $number = $issue->{number};
	    
    # Step 1: Retrieve existing comments.
    local $/;
    open(F, "./github-get.sh /repos/$repo/issues/$number/comments|") || die "cannot GET comments";
    my $comments = decode_json(<F>);
    close F;

    my $found = 0;
    foreach my $c (@$comments) {
	$found = 1 if $c->{body} =~ /^Adopted/;
    }
    # Skip paper if comment body already has "Adopted" remark.
    next if $found;

    # Step 2: Create a comment with the new paper info.
    open(F, "|./github-post.sh /repos/$repo/issues/$number/comments") || die "cannot POST comment";
    print F "{\n";
    print F "  \"body\": \"$adopted.\"";
    print F "}\n";
    close F;

    # Step 3: Close the issue.
    open(F, "|./github-post.sh /repos/$repo/issues/$number") || die "cannot POST issue";
    print F "{\n";
    print F "  \"state\": \"closed\"\n";
    print F "}\n";
    close F;

    print "Closed $adopted $pnum $title\n";

    sleep 10;
}
