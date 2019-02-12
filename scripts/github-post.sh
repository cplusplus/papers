#!/bin/sh

. ../../.github-access-token

path=$1
url="https://api.github.com$path"

curl -s -i --cacert cacert.pem -u $GITHUB_AUTH \
     -H "Accept: application/vnd.github.v3.raw+json" \
     --data @- "$url"
