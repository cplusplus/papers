#!/usr/bin/perl -wCIo

use strict;
use warnings;

use XML::LibXML;
use JSON;
use URI::Escape;

my $repo = "cplusplus/nbballot";
my $milestone = 5;

# Replace non-breaking space 0xA0 with regular space before processing!
# sed 's/ / /g' <   cd7-nbcomments.html > cd7x.html

my %xref;

open(my $fh, "<", "xref") || die "cannot open xref";
while(my $line = readline($fh)) {
    chomp $line;
    my ($label, $num) = split / /, $line;
    $xref{$num} = $label;
}
close($fh);

my $dom = XML::LibXML->load_html(location => "../src/cd7-nbcomments.html",
				 recover => 1);

foreach my $node ($dom->findnodes('//tr[@class="row-Table4_1"]')) {
    # print "TR CLASS ", $node->getAttribute('class'), "\n";
    my $state = 0;
    my ($id, $subclause, $kind, $bug, $sugg) = ("", "", "", "", "", "");
    my $label = "";
    my $colno = 0;
  column:
    foreach my $col ($node->findnodes('.//td')) {
        ++$colno;
	foreach my $p ($col->findnodes('.//p')) {
	    my $txt = $p->to_literal();
	    next if $txt =~ /^ *$/;
	    $txt =~ s/^ *//;
	    $txt =~ s/ *$//;
	    if ($colno == 1) {
		if ($txt =~ /^.?[A-Z][A-Z]/) {
		    $txt =~ s/^ *//;
		    $txt =~ s/- /-/;
		    $id = $txt;
		} else {
		    $id .= $txt;
		}
	    }
	    if ($colno == 3) {
		$txt =~ s/^-$//;
		$txt =~ s/[[:blank:]]*$//;
		$txt =~ s/\n*$//;
		$subclause = $txt;
		$label = $xref{$subclause} if exists $xref{$subclause};
		next column;
	    }
	    if ($colno == 4) {
		$txt =~ s/^-$//;
		$txt =~ s/^Paragraph //;
		$txt =~ s/^p//;
		next if $txt =~ /^ *$/;
		if ($txt =~ /^[0-9]+/) {
		    $subclause .= "p" . $txt;
		} else {
		    $subclause .= " " . $txt;
		}
		next column;
	    }
	    if ($colno == 5) {
		if ($txt =~ /^[a-z][a-z]$/i) {
		    $kind = lc($txt);
		    next column;
		} else {
		    next;
		}
	    }
	    if ($colno == 6) {
		$bug .= $txt . "\n ";
		next;
	    }
	    if ($colno == 7) {
		$sugg .= $txt . "\n ";
		next;
	    }
	    # print "NODE " , $p->nodeName(), " ", $p->getAttribute('class'), " ", $p->to_literal(), "\n";
	}
  }
    next if length($id) < 3;
    print "COMMENT $id $kind $subclause $label ", length($bug), " ", length($sugg), "\n";

    # Look for an existing issue for this NB comment.
    my $q = "$id is:issue state:open in:title repo:$repo";
    $q = uri_escape($q);
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

    # Make sure the title actually starts with the given NB comment number.
    my $issue = undef;
    my @i = ();
    foreach my $i (@{$obj->{items}}) {
        if ($i->{title} =~ /^$id /) {
            $issue = $i;
            push(@i, $i);
        }
    }
    if (@i > 1) {
        print "Duplicate issues for $id: ", join(", ", map { $_->{number} } @i), "\n";
        $issue = $i[0];
    }

    if (defined $issue) {
	next;   # do not create duplicate issues
    }

    # Create new issue.
    my $issuetitle = "$id $subclause";
    $issuetitle .= " [$label]" if length($label) > 0;
    print "Creating $issuetitle\n";
    my $body = $bug;
    $body .= "\n" . " Proposed change: \n" . $sugg if length($sugg) > 1;
    $body =~ s/"/\\"/g;    # escape quotation marks
    open(F, "|./github-post.sh /repos/$repo/issues | grep message") || die "cannot POST new issue";
    print F "{\n";
    print F "  \"title\": \"$issuetitle\",\n";
    print F "  \"body\": \"$body\",\n";
    print F "  \"milestone\": $milestone\n";
    print F "}\n";
    close F;

    sleep 10;
}

