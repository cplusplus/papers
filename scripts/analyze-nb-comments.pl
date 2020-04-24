#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "cplusplus/nbballot";

# die "You are overwriting wiki pages, likely!  Update the TWIKISID, too.";

my $choice = shift;

die "usage: $0 choice (Pnumber or label:blah)" if !defined $choice;

my $q = "is:issue is:closed repo:$repo $choice";
$q =~ s/ /+/g;

my $page = 1;

while (1) {
    local $/;
    open(F, "./github-get.sh '/search/issues?per_page=100&page=$page&q=$q'|") || die "cannot GET";
    my $resp = <F>;
    close F;

    ++$page;

    my $obj = decode_json($resp);

    if (exists $obj->{message} && exists $obj->{documentation_url}) {
	# Some error; probably "API rate limit exceeded"
	die $resp;
    }

    last if scalar(@{$obj->{items}}) == 0;

    foreach my $i (@{$obj->{items}}) {

	my %var;

	my $number = $i->{number};
	$var{github} = $i->{html_url};
	my $title = $i->{title};
	next if $title =~ /^Late-/;
	my $nb = $title;
	$nb =~ s/^([A-Z][A-Z][0-9]+) .*$/$1/;
	
	my $dispo = undef;
	
	if ($i->{comments} > 0) {
	    local $/;
	    open(F, "./github-get.sh '/repos/$repo/issues/$number/comments'|") || die "cannot GET";
	    my $resp = <F>;
	    close F;
	    
	    my $comments = decode_json($resp);
	    foreach my $c (@$comments) {
		$dispo = $c->{body} if $c->{body} =~ /Duplicate|Accepted|Rejected/;
	    }
	}
	
	if (!defined $dispo) {
	    print STDERR "UNKNOWN $title\n";
	    next;
	}

	$dispo =~ s/\r\n/ /g;

	print "$nb $dispo\n";
    }
}
