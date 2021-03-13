#!/bin/bash

# URLs
latestUrl='https://brave.com/latest/'
engineUrl='https://laptop-updates.brave.com/latest/osxarm64/release'

# path to engines directory
enginepath='../../Engines'

shopt -s nullglob

# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi

# get final path to engines directory
enginepath="$mypath/$enginepath"

# load core.sh
if ! source "$mypath/../../src/core.sh" ; then
    echo "Unable to load core.sh." 1>&2
    exit 1
fi

# get latest version number from Brave
try 'latestVersion=' /usr/bin/php "$mypath/braveversion.php" "$latestUrl" \
        "Unable to find latest Brave version at $latestUrl"
[[ "$ok" ]] || abort

# get current version number on our system
try '!2' 'curBrave=(n)' /bin/ls -tUr "$mypath/../../Engines/Brave"* \
        'Unable to read engine directory.'
curBrave="${curBrave[0]}"
if [[ "$curBrave" =~ [0-9]+\.[0-9.]*[0-9] ]] ; then
    curVersion="${BASH_REMATCH[0]}"
else
    abort 'Unable to get version of current engine.'
fi

if [[ "$curVersion" != "$latestVersion" ]] ; then
    
    # get direct link to latest version
    try '!2' 'enginelink=' /usr/bin/curl "$engineUrl" \
            'Unable to get link to latest Brave version.'
    [[ "$ok" ]] || abort
    
    # parse URL of direct link
    linkre='href="([^"]+)"'
    if [[ "$enginelink" =~ $linkre ]] ; then
        enginelink="${BASH_REMATCH[1]}"
    else
        abort 'Unable to parse link to latest Brave version.'
    fi
    
    # get output filename for engine
    enginefile="${enginelink##*/}"
    enginefile="${enginefile%.*}-$latestVersion.${enginefile##*.}"
    
    echo "Downloading new Brave $latestVersion (replacing $curVersion)..."
    
    # download direct link direct to apps
    try '-2' "$enginepath/../$enginefile<" /usr/bin/curl "$enginelink" \
            'Unable to download latest Brave engine.'
    [[ "$ok" ]] || abort
    
    # move old engines out
    trash "$enginepath/"*.tgz
    /bin/mv "$enginepath/Brave"*.dmg "$enginepath/Brave"*.pkg "$enginepath/old"
    /bin/mv "$enginepath/../$enginefile" "$enginepath"
    
    trimsaves "$enginepath/old" 2 '' 'old engines'
else
    echo "Current Brave engine $curVersion is the latest!"
fi

cleanexit
