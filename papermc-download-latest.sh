#!/bin/bash
# Script implementing papermc API v2 to get latest release of give project version (paper / velocity / waterfall / ...)
# Author: Michael Gebetsroither <michael@mgeb.org>
# License: Apache 2
# Usage:
#   MC_VERSION=1.21 MC_NAME=paper bash ~/papermc-download-latest.sh

# config
name_="${MC_NAME:-paper}"
version_="${MC_VERSION:-1.20}"

# internal
version_group_="$version_"
api_="https://api.papermc.io/v2/projects/$name_"
## old prefix used api which was retired at 1.21.4 build 68 (arround 2024-12-31)
#api_=https://papermc.io/api/v2
#prefix_="$api_/projects/$name_"

die() {
    echo "## ERROR: $*" >&2
    exit 1
}

# get json from latest release from $version_group defined above
latest_build_json_="$(curl -sX GET "$api_/version_group/$version_group_/builds" | jq '.builds [-1]')"

# extract info
latest_build_="$(echo "$latest_build_json_" |jq -r '.build')"
latest_version_="$(echo "$latest_build_json_" |jq -r '.version')"

# write json file
filename_="$(echo "$latest_build_json_" |jq -r '.downloads.application.name')"
if [[ "$filename_" == "" ]]; then
    echo "## WARNING: could not extract version information, abort"
    exit 1
else
    test -e "$filename_.json" || echo "$latest_build_json_" |jq . >"$filename_.json"
fi

# write sha256sum file
sha256_="$(echo "$latest_build_json_" |jq -r '.downloads.application.sha256')"
test -e "$filename_.sha256sum" || echo "$sha256_  $filename_" >"$filename_.sha256sum"

# download & check sha256sum file
download_url_="$api_/versions/$latest_version_/builds/$latest_build_/downloads/$filename_";
if ! sha256sum --status -c "$filename_.sha256sum" &>/dev/null; then
    wget --no-verbose "$download_url_" -O "$filename_"
    if ! sha256sum --status -c "$filename_.sha256sum"; then
        echo "## WARNING: sha256sum of $filename_ does not match, renaming it, manual intervention necessary!"
        mv "$filename_" "$filename_.fixme"
        exit 1
    fi
else
    echo "## $filename_ already successfully downloaded"
fi

# activate
test -l server.jar && ln -sfn "$filename_" server.jar
