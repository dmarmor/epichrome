#!/bin/sh

# args
dir="${1%/}" ; shift
variant="$1" ; shift

# validate and move to dir
[[ "$dir" ]] || dir='.'
if [[ ! -d "$dir" ]] ; then
    echo "Directory '$dir' not found."
    exit 1
fi
cd "$dir"
dir="$(pwd)"

# validate and set up variant
[[ "$variant" ]] && variant="_$variant"
appzip="app$variant.zip"
datazip="data$variant.zip"
if [[ "$variant" ]] ; then
    [[ -e "$appzip" ]] || appzip=app.zip
    [[ -e "$datazip" ]] || datazip=data.zip
fi

# set up useful info
dirbase="${dir##*/}"
id="${dirbase##*-}"
if [[ "$id" = "$dirbase" ]] ; then
    echo "Unable to parse ID from directory name."
    exit 1
fi
lib=~/"Library/Application Support/Epichrome/Apps"

# reset
rm -rf *.app && \
    rm -rf "$lib/$id" && \
    tar xzf "$appzip" && \
    tar xzf "$datazip" --cd "$lib"
