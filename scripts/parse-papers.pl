#!/usr/bin/perl -w

use strict;
use JSON;
use HTML::Entities;

my $repo = "cplusplus/papers";
my $milestone = 10;    # 2023-telecon       # FIXME before every import

my $reqpaper = shift;

local $/;
my $html = <>;

my @p = split /<tr >/, $html;

shift @p;

my %groupnames =
    (
     "WG21" => "info",
     "EWGI SG17: EWG Incubator" => "EWGI",
     "EWGI" => "EWGI",
     "Evolution" => "EWG",
     "Core" => "CWG",
     "LEWGI SG18: LEWG Incubator" => "LEWGI",
     "LEWGI" => "LEWGI",
     "Library Evolution" => "LEWG",
     "Library" => "LWG",

     "Direction Group" => "DG",
		   
     "SG1 Concurrency and Parallelism" => "SG1",
     "SG2" => "SG2",
     "SG4" => "SG4 Networking",
     "SG5 Transactional Memory" => "SG5",
     "SG6 Numerics" => "SG6",
     "SG7 Reflection" => "SG7",
     "SG9 Ranges" => "SG9",
     "SG10" => "SG10",

     "SG12 Undefined and Unspecified Behavior" => "SG12",
     "SG13" => "SG13",
     "SG14 Low Latency" => "SG14",
     "SG15 Tooling" => "SG15",
     "SG16 Unicode" => "SG16",
     "SG19 Machine Learning" => "SG19",
     "SG20" => "SG20",
     "SG21 Contracts" => "SG21",
     "SG22 Compatability" => "SG22",
     "SG23 Safety and Security" => "SG23");


foreach my $x (@p) {
    my ($dummy, $pnum, $title, $author, $date, $mailing, $prior, $groups) = split /<td > /, $x;

    $pnum =~ s/<a href=".+?">(N[0-9]+|P[0-9]+R[0-9]+)<\/a> *\n.*$/$1/s;
    $pnum =~ s/ *<\/td>//s;
    $pnum =~ s/ *\n.*$//s;
    $title =~ s/ *<\/td>//s;
    $title =~ s/ *\n.*$//s;
    $title =~ s/"/'/g;
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

    my $issuetitle = "$pseries R$rev $title";

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

    # print "$pnum $title $author $groups\n";
    # exit 1;

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
	open(F, "./github-get.sh /repos/$repo/issues/$number/comments?per_page=100|") || die "cannot GET comments";
	my $comments = decode_json(<F>);
	close F;

	my $found = grep { $_->{body} =~ /^\[$pnum/ } @$comments;

	# Step 2: Create a comment with the new paper info.
	# (Skip paper if comment body already has paper number.)
	if ($found == 0) {
	    open(F, "|./github-post.sh /repos/$repo/issues/$number/comments >/dev/null") || die "cannot POST comment";
	    print F "{\n";
	    print F "  \"body\": \"$body\"";
	    print F "}\n";
	    close F;
	}

	# Step 3: Remove 'needs-revision' label, if present.
	foreach my $l (@{$issue->{labels}}) {
	    if ($l->{name} eq "needs-revision") {
		print "Removing 'needs-revision' label\n";
		system("./github-delete.sh /repos/$repo/issues/$number/labels/needs-revision >/dev/null");
		last;
	    }
	}

	# Step 4: Update the title and mileston; re-open the issue, if needed.
	# Do not update the group designation, since that's owned by the chairs.
	open(F, "|./github-post.sh /repos/$repo/issues/$number > /dev/null") || die "cannot POST issue";
	print F "{\n";
	my $needcomma = 0;
	if ($issue->{title} ne $issuetitle) {
	    print F "  \"title\": \"$issuetitle\"\n";
	    $needcomma = 1;
	}
	my $plenary_approved =
	    grep { $_->{name} eq "plenary-approved" } @{$issue->{labels}};
	if (!$plenary_approved) {
	    print F "," if $needcomma;
	    print F "  \"state\": \"open\",\n" if $issue->{state} eq "closed";
	    print F "  \"milestone\": $milestone\n";
	}
	print F "}\n";
	close F;

	my @u = ();
	push @u, "paper" if $found == 0;
	push @u, "title" if $needcomma;
	push @u, "status" if !$plenary_approved && $issue->{state} eq "closed";

	print "Updated ", join(", ", @u), " for $pnum $title\n" if @u;

	next;
    }

    if (!defined $reqpaper && @groups == 0) {
	print "No groups assigned; not creating: $pnum $title\n";
	next;
    }

    # create new issue
    print "Creating $pnum $title\n";
    $body =~ s/"/\\"/g;    # escape quotation marks
    open(F, "|./github-post.sh /repos/$repo/issues | grep message") || die "cannot POST new issue";
    print F "{\n";
    print F "  \"title\": \"$issuetitle\",\n";
    print F "  \"body\": \"$body\",\n";
    print F "  \"labels\": [ ", join(",", map "\"$_\"", @groups), " ],\n";
    print F "  \"milestone\": $milestone\n";
    print F "}\n";
    close F;

    sleep 10;
}
