#!/bin/sh

token=`cat ../../.github-access-token`

path=$1
url="https://api.github.com$path"

#mediatype="application/vnd.github.v3.raw+json"
#mediatype="application/vnd.github.inertia-preview+json"
mediatype="application/vnd.github.mockingbird-preview"   # timeline
#mediatype="application/vnd.github.starfox-preview+json"

curl -s --cacert cacert.pem -u jensmaurer:$token \
     -H "Accept: $mediatype" \
     -H "Accept: application/vnd.github.inertia-preview+json" \
     -H "Accept: application/vnd.github.starfox-preview+json" \
     "$url"
