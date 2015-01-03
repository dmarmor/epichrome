#!/bin/sh

DATAPATH=$(cd "$(dirname "$0")"; pwd)
DATAPATH=$(dirname "$DATAPATH")"/Paths"

file="${DATAPATH}/last_${2}_path.txt"

if [ "$1" = "get" ] ; then
    if [ -f "$file" ] ; then
	cat "$file"
    fi
else
    # set the last path
    echo "$3" > "$file"
fi
