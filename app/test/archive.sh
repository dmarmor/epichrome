#!/bin/bash

# args
dir="${1%/}" ; shift

# validate and move to dir
[[ "$dir" ]] || dir='.'
if [[ ! -d "$dir" ]] ; then
    echo "Directory '$dir' not found."
    exit 1
fi
cd "$dir"
dir="$(pwd)"

# set up useful info
dirbase="${dir##*/}"
id="${dirbase##*-}"
if [[ "$id" = "$dirbase" ]] ; then
    echo "Unable to parse ID from directory name."
    exit 1
fi
lib=~/"Library/Application Support/Epichrome/Apps"
engdir="$(cd "$lib/$id/Engine" 2> /dev/null && pwd -P)"

# archive this app
rm -rf *.app && \
    if [[ -d "$engdir" ]] ; then rm -rf "$engdir" ; fi &&
    rm -rf "$lib/$id"
