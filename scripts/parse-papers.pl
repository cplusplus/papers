#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "cplusplus/papers";
my $milestone = 7;           # FIXME before every import

my $updatems = 1;

my $reqpaper = shift;

if (defined($reqpaper) && $reqpaper eq "-noms") {
    $updatems = 0;
    $reqpaper = shift;
}

local $/;
my $html = <>;

my @p = split /<tr >/, $html;

shift @p;

my %groupnames =
    (
     "WG21" => "info",
     "Evolution Incubator" => "EWGI",
     "EWGI" => "EWGI",
     "Evolution" => "EWG",
     "Core" => "CWG",
     "Library Evolution Incubator" => "LEWGI",
     "LEWGI" => "LEWGI",
     "Library Evolution" => "LEWG",
     "Library" => "LWG",
		   
     "SG1" => "SG1",
     "SG2" => "SG2",
     "SG4" => "SG4",
     "SG5" => "SG5",
     "SG6" => "SG6",
     "SG7" => "SG7",

     "SG12" => "SG12",
     "SG13" => "SG13",
     "SG14" => "SG14",
     "SG15" => "SG15",
     "SG16" => "SG16",
     "SG19" => "SG19",
     "SG20" => "SG20",
     "SG21" => "SG21",
     "SG22" => "SG22");


foreach my $x (@p) {
    my ($dummy, $pnum, $title, $author, $groups) = split /<td > /, $x;

    $pnum =~ s/<a href=".+?">(N[0-9]+|P[0-9]+R[0-9]+)<\/a> *\n.*$/$1/s;
    $title =~ s/ *<\/td>//s;
    $title =~ s/ *\n.*$//s;
    $author =~ s/ *<\/td>//s;
    $author =~ s/ *\n.*$//s;
    $author =~ s/ +/ /g;
    $groups =~ s/ *<\/td>//s;
    $groups =~ s/ *\n.*$//s;

    next if !defined($reqpaper) && $pnum =~ /^N/;

    my $lcpnum = lc $pnum;
    my $pseries = $pnum;
    $pseries =~ s/R.+$//;
    my $rev = $pnum;
    $rev =~ s/^.*R//;

    next if defined($reqpaper) && $pseries ne $reqpaper;

    my @g = split /, */, $groups;

    my @groups;
    foreach my $g (@g) {
	if (exists $groupnames{$g}) {
	    push @groups, $groupnames{$g};
	} else {
	    print STDERR "Cannot map group '$g' for $pnum $title\n";
	}
    }

    # @groups = (qw/LEWGI/);

    my $body = "[$pnum](https://wg21.link/$lcpnum) $title ($author)";

    # Look for an existing issue for this paper.
    my $q = "$pseries is:issue in:title repo:$repo";
    $q =~ s/ /+/g;

    local $/;
    open(F, "./github-get.sh '/search/issues?q=$q'|") || die "cannot GET";
    my $resp = <F>;
    close F;
    sleep 1;
    my $obj = decode_json($resp);
    if (exists $obj->{message} && exists $obj->{documentation_url}) {
	# Some error; probably "API rate limit exceeded"
	next;
    }

    # Make sure the title actually starts with the given paper number.
    my $issue = undef;
    my @i = ();
    foreach my $i (@{$obj->{items}}) {
	if ($i->{title} =~ /^$pseries /) {
	    $issue = $i;
	    push(@i, $i);
	}
    }
    if (@i > 1) {
	print "Duplicate issues for $pseries: ", join(", ", map { $_->{number} } @i), "\n";
	@i = grep { $_->{state} ne "closed" } @i;
	$issue = $i[0];
    }
    if (defined $issue) {
	my $number = $issue->{number};
	    
	print "Found #$number $issue->{title}\n";
	# Skip paper if issue body already contains paper number.
	next if $issue->{body} =~ /^\[$pnum/;
	
	# Step 1: Retrieve existing comments.
	local $/;
	open(F, "./github-get.sh /repos/$repo/issues/$number/comments|") || die "cannot GET comments";
	my $comments = decode_json(<F>);
	close F;

	my $found = 0;
	foreach my $c (@$comments) {
	    $found = 1 if $c->{body} =~ /^\[$pnum/;
	}

	# Step 2: Create a comment with the new paper info.
	# (Skip paper if comment body already has paper number.)
	if ($found == 0) {
	    print "Updating for $pnum\n";
	    open(F, "|./github-post.sh /repos/$repo/issues/$number/comments") || die "cannot POST comment";
	    print F "{\n";
	    print F "  \"body\": \"$body\"";
	    print F "}\n";
	    close F;
	}

	# Step 3: Remove 'needs-revision' label, if present.
	foreach my $l (@{$issue->{labels}}) {
	    if ($l->{name} eq "needs-revision") {
		print "Removing 'needs-revision' label\n";
		system("./github-delete.sh /repos/$repo/issues/$number/labels/needs-revision");
		last;
	    }
	}

	# Do not change the milestone for closed issues.
	next if ($issue->{state} eq "closed");
	
	# Step 4: Update the milestone
	if ($updatems) {
	    open(F, "|./github-post.sh /repos/$repo/issues/$number") || die "cannot POST issue";
	    print F "{\n";
	    # Do not update the group designation, since that's owned by the chairs.
	    # print F "  \"labels\": [ ", join(",", map "\"$_\"", @groups), " ],\n";
	    print F "  \"milestone\": $milestone\n";
	    print F "}\n";
	    close F;
	}

	next;
    }

    if (!defined $reqpaper && @groups == 0) {
	print "No groups assigned; not creating: $pseries $title\n";
	next;
    }

    # create new issue
    print "Creating $pseries $title\n";
    $title =~ s/"/\\"/g;    # escape quotation marks
    $body =~ s/"/\\"/g;    # escape quotation marks
    open(F, "|./github-post.sh /repos/$repo/issues | grep message") || die "cannot POST new issue";
    print F "{\n";
    print F "  \"title\": \"$pseries $title\",\n";
    print F "  \"body\": \"$body\",\n";
    print F "  \"labels\": [ ", join(",", map "\"$_\"", @groups), " ],\n";
    print F "  \"milestone\": $milestone\n";
    print F "}\n";
    close F;

    sleep 10;
}
