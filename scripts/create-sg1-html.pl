#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "cplusplus/papers";

# EWG Kona: /projects/2142630
# SG1 Kona: /projects/2179564

local $/;
open(F, "./github-get.sh /projects/2179564/columns |") || die "cannot GET";
my $resp = <F>;
close F;

my $obj = decode_json($resp);

# if (exists $obj->{message} && exists $obj->{documentation_url}) {
#    # Some error; probably "API rate limit exceeded"
#    die $resp;
# }

foreach my $c (@$obj) {

    my $daytitle = $c->{name};
    $daytitle =~ s/^EWG//;
    my $colid = $c->{id};

    print "---++ $daytitle\n\n";

    print "<table border=\"1\">\n";
    print "<tr><th></th><th>Title</th><th>Author</th><th>Minutes</th><th>github issue</th></tr>\n";

    local $/;
    open(F, "./github-get.sh /projects/columns/$colid/cards |") || die "cannot GET";
    my $resp = <F>;
    close F;

    my $obj = decode_json($resp);
    
    for my $card (@$obj) {
	my $ino = $card->{content_url};

	if (!defined $ino) {

	    print "<tr>\n";
	    print "  <td></td>\n";
	    print "  <td>$card->{note}</td>\n";
	    print "  <td></td>\n";
	    print "  <td></td>\n";
	    print "  <td></td>\n";
	    print "</tr>\n\n";

	    next;
	}

	$ino =~ s/^.*\/([0-9]+)$/$1/;

	open(F, "./github-get.sh /repos/$repo/issues/$ino |") || die "cannot GET";
	my $resp = <F>;
	close F;

	my $i = decode_json($resp);

	my $number = $i->{number};
	my $github = $i->{html_url};
	my $title = $i->{title};
	my $paper = $i->{title};
	$paper =~ s/^(P[0-9]+) .*$/$1/;
	my $latestpaper = $i->{body};

	if ($i->{comments} > 0) {
	    local $/;
	    open(F, "./github-get.sh '/repos/$repo/issues/$number/comments'|") || die "cannot GET";
	    my $resp = <F>;
	    close F;

	    my $comments = decode_json($resp);
	    my $latest = undef;
	    foreach my $c (@$comments) {
		$latestpaper = $c->{body} if $c->{body} =~ /^\[${paper}R[0-9]+\]/;
	    }
	}

	# [PxxxxRy](url) Title (Authors)
	$latestpaper =~ /^\[(P[0-9]+R[0-9]+)\]\(([^)]+)\) (.*) \(([^)]+)\).*$/s;
	
	my $pnum = $1;           # PxxxxRy
	my $summary = $3;        # title
	my $purl = $2;    # url
	my $authors = $4;  # authors

	print "<tr>\n";
	print "  <td><a href=\"$purl\">$pnum</a></td>\n";
	print "  <td>$summary</td>\n";
	print "  <td>$authors</td>\n";
	print "  <td>[[$pnum-SG1]]</td>\n";
	print "  <td><a href=\"$github\">#$number</a></td>\n";
	print "</tr>\n\n";
	sleep 1;
    }

    print "</table>\n\n";
}
