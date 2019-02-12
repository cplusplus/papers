#!/bin/sh

test -n "$GITHUB_AUTH" || echo "Need GITHUB_AUTH" >&2

path=$1
url="https://api.github.com$path"

# cat -
# exit 1


curl -s -i --cacert cacert.pem -u "$GITHUB_AUTH" \
     -H "Accept: application/vnd.github.v3.raw+json" \
     --data @- "$url"
