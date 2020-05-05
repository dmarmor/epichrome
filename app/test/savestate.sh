#!/bin/bash

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

# set up useful info
id="${dir#*-}"
lib=~/"Library/Application Support/Epichrome/Apps"

shopt -s nullglob
app=( *.app )
if [[ "${#app[@]}" -lt 1 ]] ; then
    echo "No app found in '$dir_arg'."
    exit 1
elif [[ "${#app[@]}" -gt 1 ]] ; then
    echo "Multiple apps found in '$dir_arg'."
    exit 1
fi
app="${app[0]}"

# archive
if tar czf "$appzip.NEW" "$app" && \
	tar czf "$datazip.NEW" --cd "$lib" "$id" ; then
    ( [[ ! -f "$appzip" ]] || mv "$appzip" "$appzip.OLD" ) && \
	( [[ ! -f "$datazip" ]] || mv "$datazip" "$datazip.OLD" ) && \
	mv "$appzip.NEW" "$appzip" && \
	mv "$datazip.NEW" "$datazip" && \
	rm -f "$appzip.OLD" "$datazip.OLD" && \
	rm -f library && \
	ln -s "$lib/$id" library
else
    echo "Error archiving app and data directory."
    rm -f "$appzip.NEW" "$datazip.NEW"
    exit 1
fi
