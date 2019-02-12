#!/usr/bin/perl -w

use strict;
use JSON;

my $repo = "jensmaurer/papers";

my $pnumber = shift;
my @labels = @ARGV;

die "usage: $0 Pnumber label..." if !defined $pnumber;

my $q = "is:issue is:open in:title repo:$repo $pnumber";
$q =~ s/ /+/g;

local $/;
open(F, "./github-get.sh '/search/issues?q=$q'|") || die "cannot GET";
my $resp = <F>;
close F;

my $obj = decode_json($resp);

if (exists $obj->{message} && exists $obj->{documentation_url}) {
    # Some error; probably "API rate limit exceeded"
    die $resp;
}

foreach my $i (@{$obj->{items}}) {
    next if $i->{title} !~ /^$pnumber/;

    my $number = $i->{number};

    local $/;
    open(F, "|./github-post.sh '/repos/$repo/issues/$number") || die "cannot POST";
    print "{\n";
    print "\"labels\" : [ ", join(",", map "\"$_\"", @labels), " ]\n";
    print "}\n";
    close F;
}
