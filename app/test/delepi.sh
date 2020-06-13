#!/bin/bash

# args
app="$1" ; shift

# get ID

if [[ ! -e "$app/Contents/Resources/script" ]] ; then
    echo "Main executable not found." 1>&2
    exit 1
fi

id="$(sed -En 's/SSBIdentifier='\''(.+)'\''/\1/p' "$app/Contents/Resources/script")"

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
