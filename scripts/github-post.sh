#!/bin/sh

token=`cat ../../.github-access-token`

path=$1
url="https://api.github.com$path"
echo "$url"

curl -s -i --cacert cacert.pem -u jensmaurer:$token \
     -H "Accept: application/vnd.github.v3.raw+json" \
     --data @- "$url"
