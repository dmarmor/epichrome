#!/bin/bash

# args
app="$1" ; shift

# get ID

main="$app/Contents/Resources/Scripts/main.sh"

if [[ ! -e "$main" ]] ; then
    main="$app/Contents/Resources/script"
    
    if [[ ! -e "$main" ]] ; then
        echo "Main executable not found." 1>&2
        exit 1
    fi
fi

id="$(sed -En 's/SSBIdentifier='\''(.+)'\''/\1/p' "$main")"

if [[ ! "$id" ]] ; then
    echo "No ID found." 1>&2
    exit 1
fi

datadir="${HOME}/Library/Application Support/Epichrome/Apps/$id"

if [[ -d "$datadir/Engine" ]] ; then
    engdir="$(cd "$datadir/Engine" && pwd -P)"
    if [[ "$?" != 0 ]] ; then
	echo "Unable to get engine directory path." 1>&2
	exit 1
    fi
else
    engdir=
fi

# delete everything
rm -rf "$app" && \
    if [[ -d "$engdir" ]] ; then rm -rf "$engdir" ; fi &&
    rm -rf "$datadir"
