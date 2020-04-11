#!/bin/sh

# args
dir="${1%/}" ; shift
variant="$1" ; shift

# validate and move to dir
[[ "$dir" ]] || dir='.'
if [[ ! -d "$dir" ]] ; then
    if [[ "$variant" ]] ; then
	echo "Directory '$dir' not found."
	exit 1
    fi

    # assume the one argument was a variant
    variant="$dir"
    dir='.'
fi
cd "$dir"
dir="$(pwd)"

# validate and set up variant
[[ "$variant" ]] && variant="_$variant"
appzip="app$variant.zip"
datazip="data$variant.zip"
if [[ "$variant" ]] ; then
    if [[ ! -e "$appzip" ]] ; then
	printf "$appzip not found -- " 1>&2
	appzip=app.zip
    fi
    echo "restoring $appzip" 1>&2
    if [[ ! -e "$datazip" ]] ; then
	printf "$datazip not found -- " 1>&2
	datazip=data.zip
    fi
    echo "restoring $datazip" 1>&2
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
