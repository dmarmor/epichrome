#!/bin/zsh

archs="$(lipo -archs "$1" 2> /dev/null)"
if [[ "$?" = 0 ]] ; then
    if [[ "$archs" != *'arm64'* ]] ; then
        echo -n "**** "
    fi
    echo "$archs [${1##*/}]"
fi
