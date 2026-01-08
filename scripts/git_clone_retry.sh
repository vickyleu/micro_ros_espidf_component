#!/usr/bin/env sh
set -eu

url=$1
branch=$2
dest=$3
max=${4:-8}

i=1
while [ "$i" -le "$max" ]; do
    rm -rf "$dest"
    GIT_SSL_NO_VERIFY=1 git \
        -c http.version=HTTP/1.1 \
        -c http.sslVerify=false \
        -c http.lowSpeedLimit=1 \
        -c http.lowSpeedTime=30 \
        -c http.postBuffer=104857600 \
        -c http.maxRequests=5 \
        clone -b "$branch" --depth 1 --filter=blob:none "$url" "$dest" && exit 0
    i=$((i + 1))
    sleep 2
done

echo "Failed to clone $url (branch: $branch)" >&2
exit 1
