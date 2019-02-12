#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "jensmaurer/papers";

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

    $i->{title} =~ /^(P[0-9]+) /;
    print $1, "\n";
}
