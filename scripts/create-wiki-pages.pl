#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "cplusplus/papers";

die "You are overwriting wiki pages, likely!  Update the TWIKISID, too.";

my $choice = shift;

die "usage: $0 choice (Pnumber or label:blah)" if !defined $choice;

my $q = "is:issue is:open in:title repo:$repo $choice";
$q =~ s/ /+/g;

local $/;
open(F, "./github-get.sh '/search/issues?per_page=100&q=$q'|") || die "cannot GET";
my $resp = <F>;
close F;

my $obj = decode_json($resp);

if (exists $obj->{message} && exists $obj->{documentation_url}) {
    # Some error; probably "API rate limit exceeded"
    die $resp;
}

foreach my $i (@{$obj->{items}}) {
    next if $choice =~ /^P/ && $i->{title} !~ /^$choice/;

    my %var;

    my $number = $i->{number};
    $var{github} = $i->{html_url};
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

    $var{pnum} = $1;           # PxxxxRy
    $var{summary} = $3;        # title
    $var{latestPaper} = $2;    # url
    $var{presenterName} = $4;  # authors

    open(F, "lewg-page.txt");
    my $tmpl = <F>;
    close F;

    foreach my $k (keys %var) {
	$tmpl =~ s/\{\{issue.$k\}\}/$var{$k}/g;
    }

    print "Creating wiki page for $paper\n";

    open(F, "|./create-wiki-page.sh $paper") || die "cannot create wiki page";
    print F $tmpl;
    close F;
}
