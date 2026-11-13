#!/bin/bash
# Script implementing the PaperMC Fill API v3 to download the latest stable build
# of a given project version (paper / velocity / folia / ...)
# Author: Michael Gebetsroither <michael@mgeb.org>
# License: Apache 2
# Usage:
#   MC_VERSION=1.21 MC_NAME=paper bash ~/papermc-download-latest.sh
#
# MC_VERSION may be a version group (eg. "1.21", "26.3"), which selects the newest
# version in that group with a stable build, or an exact version (eg. "1.21.11").
# Version groups take precedence, so "1.21" never selects the release 1.21 itself.

set -o pipefail

# config
name_="${MC_NAME:-paper}"
version_="${MC_VERSION:-1.21}"
channel_="${MC_CHANNEL:-STABLE}"
java_="${MC_JAVA:-java}"

# internal
## API v2 (https://api.papermc.io/v2) was sunset in 2026 and only returns HTTP 410
api_="https://fill.papermc.io/v3/projects/$name_"
user_agent_="papermc-download-latest.sh (https://github.com/gebi/minecraft-server)"

die() {
    echo "## ERROR: $*" >&2
    exit 1
}

api_get() {
    curl -fsS --max-time 30 -A "$user_agent_" "$api_$1"
}

# latest build json of a given version in the configured channel, empty if none
latest_build() {
    api_get "/versions/$1/builds?channel=$channel_" | jq -ce '.[0] // empty'
}

command -v jq >/dev/null || die "jq not found"

project_json_="$(api_get "")" || die "could not get project info for $name_ from $api_"

# resolve version: a version group (newest version in it with a build in channel) takes
# precedence over an exact version, as eg. "1.21" is both a group and a version
candidates_="$(echo "$project_json_" | jq -r --arg v "$version_" '.versions[$v] // empty | .[]')"
if [[ -z "$candidates_" ]]; then
    echo "$project_json_" | jq -e --arg v "$version_" '[.versions[][]] | index($v)' >/dev/null \
        || die "no version or version group '$version_' found for $name_"
    candidates_="$version_"
fi

latest_version_=""
latest_build_json_=""
for v_ in $candidates_; do
    if latest_build_json_="$(latest_build "$v_")" && [[ -n "$latest_build_json_" ]]; then
        latest_version_="$v_"
        break
    fi
done
[[ -n "$latest_version_" ]] || die "no $channel_ build found for $name_ $version_"

# extract info
latest_build_="$(echo "$latest_build_json_" | jq -r '.id')"
filename_="$(echo "$latest_build_json_" | jq -r '.downloads."server:default".name // empty')"
download_url_="$(echo "$latest_build_json_" | jq -r '.downloads."server:default".url // empty')"
sha256_="$(echo "$latest_build_json_" | jq -r '.downloads."server:default".checksums.sha256 // empty')"
if [[ -z "$filename_" || -z "$download_url_" || -z "$sha256_" || "$filename_" == */* ]]; then
    die "could not extract download information for $name_ $latest_version_ build $latest_build_"
fi

# write json file
test -e "$filename_.json" || echo "$latest_build_json_" | jq . >"$filename_.json"

# write sha256sum file
test -e "$filename_.sha256sum" || echo "$sha256_  $filename_" >"$filename_.sha256sum"

# download & check sha256sum file
if ! sha256sum --status -c "$filename_.sha256sum" &>/dev/null; then
    wget --no-verbose -U "$user_agent_" "$download_url_" -O "$filename_" \
        || die "download of $download_url_ failed"
    if ! sha256sum --status -c "$filename_.sha256sum"; then
        echo "## WARNING: sha256sum of $filename_ does not match, renaming it, manual intervention necessary!"
        mv "$filename_" "$filename_.fixme"
        exit 1
    fi
else
    echo "## $filename_ already successfully downloaded"
fi

# check required java version before activating
java_required_="$(api_get "/versions/$latest_version_" | jq -r '.version.java.version.minimum // empty')"
java_installed_="$("$java_" -version 2>&1 | sed -nE '1s/.*version "([0-9]+)(\.[^"]*)?".*/\1/p')"
if [[ -n "$java_required_" ]]; then
    if [[ -z "$java_installed_" ]]; then
        die "could not determine installed java version ($java_), $filename_ requires java >= $java_required_, not activating"
    elif (( java_installed_ < java_required_ )); then
        die "$filename_ requires java >= $java_required_ but java $java_installed_ is installed, not activating"
    fi
fi

# activate (only if server.jar is a symlink or does not exist yet)
if [[ -L server.jar || ! -e server.jar ]]; then
    if [[ "$(readlink server.jar)" != "$filename_" ]]; then
        ln -sfn "$filename_" server.jar
        echo "## activated $filename_"
    fi
else
    echo "## server.jar is not a symlink, not activating $filename_"
fi
