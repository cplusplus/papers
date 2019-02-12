#!/bin/sh

. ../../.github-access-token

path=$1
url="https://api.github.com$path"

curl -s --cacert cacert.pem -u "$GITHUB_AUTH" \
     -H "Accept: application/vnd.github.v3.raw+json" \
     -H "Accept: application/vnd.github.mockingbird-preview" \
     -H "Accept: application/vnd.github.inertia-preview+json" \
     -H "Accept: application/vnd.github.starfox-preview+json" \
     "$url"
