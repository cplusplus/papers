#!/bin/sh

. ../../.wiki-cookie

# Read a wiki page:
# curl -s --cookie $WIKI_COOKIE http://wiki.edg.com/bin/view/Wg21sandiego2018/WebHome

wiki=Wg21kona2019
page=$1

if [ -z "$page" ]; then
    echo "usage: $0 pagename" >&2
    exit 1
fi

# Step 1: retrieve "crypttoken" (CSRF prevention)
url="http://wiki.edg.com/bin/edit/$wiki/$page?topicparent=$wiki.LibraryEvolutionWorkingGroup;nowysiwyg=1"

crypttoken=`
curl -s --cookie $WIKI_COOKIE "$url" |
grep 'method="post".*crypttoken' |
sed -e 's/^.*name="crypttoken" value="\([0-9a-f]*\)".*$/\1/'
`

# Step 2: create the page

url=http://wiki.edg.com/bin/save/$wiki/$page

curl -s --cookie $WIKI_COOKIE \
	 --data-urlencode crypttoken=$crypttoken \
	 --data-urlencode text@- \
	 --data-urlencode originalrev=0 \
	 --data-urlencode action_save=Save \
	 --data-urlencode topicparent=LibraryEvolutionWorkingGroup \
	 --data-urlencode newtopic=1 \
	 --data-urlencode nowysiwyg=1 \
	 "$url"
