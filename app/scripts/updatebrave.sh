#!/bin/bash
#
#  updatebrave.sh: check for a new version of Brave, download, and manage old versions
#
#  Copyright (C) 2021  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


# URLs
latestUrl='https://brave.com/latest/'
engineUrl='https://laptop-updates.brave.com/latest/osx/release'
# as of Brave 1.27.111, the ARM64 version no longer works on Intel!
#engineUrl='https://laptop-updates.brave.com/latest/osxarm64/release'

shopt -s nullglob

# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi
epipath="$mypath/.."

# ARGUMENTS

# only check for new version, don't try to download
checkOnly=
if [[ "$1" = '--checkonly' ]] ; then
    checkOnly=1
    shift
fi

# path to engines directory
[[ "$1" ]] && enginepath="$1" || enginepath="$epipath/Engines"

# load core.sh
if ! source "$epipath/src/core.sh" ; then
    echo "Unable to load core.sh." 1>&2
    exit 1
fi

# get latest version number from Brave
try 'latestVersion=' /usr/bin/php "$mypath/braveversion.php" "$latestUrl" \
        "Unable to find latest Brave version at $latestUrl"
[[ "$ok" ]] || abort

# get current version number on our system
try '!2' 'curBrave=(n)' /bin/ls -tUr "$enginepath/Brave"* \
        'Unable to read engine directory.'
curBrave="${curBrave[0]}"
if [[ "$curBrave" =~ [0-9]+\.[0-9.]*[0-9] ]] ; then
    curVersion="${BASH_REMATCH[0]}"
else
    abort 'Unable to get version of current engine.'
fi

if [[ "$curVersion" != "$latestVersion" ]] ; then
    
    # if we're in check-only mode, we're done
    if [[ "$checkOnly" ]] ; then
        echo "New Brave $latestVersion found (current Brave engine is $curVersion)."
        cleanexit 2
    fi
    
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
    
    echo "Downloading new Brave $latestVersion (replacing $curVersion)..." 1>&2
    echo '---' 1>&2
    
    # download direct link direct to apps
    try '-2' "$enginepath/../$enginefile<" /usr/bin/curl "$enginelink" \
            'Unable to download latest Brave engine.'
    [[ "$ok" ]] || abort
    
    # move old engines out
    try trash "$enginepath/"*.tgz 'Unable to remove old engine .tgz files.'
    try /bin/mv "$enginepath/Brave"*.dmg "$enginepath/Brave"*.pkg "$enginepath/old" \
            'Unable to move old engine .dmg files out of Engines directory.'
    try /bin/mv "$enginepath/../$enginefile" "$enginepath" \
            'Unable to move new engine file into Engines directory.'
    trimsaves "$enginepath/old" 2 '' 'old engines'
    [[ "$ok" ]] || abort
    
    if [[ "$1" ]] ; then
        # running from Makefile, so spit out filename & version
        echo "$enginepath/$enginefile|$latestVersion"
    else
        # running from newrelease.sh, so just spit out new version
        echo "$latestVersion"
    fi
else
    if [[ "$checkOnly" ]] ; then
        echo "Current Brave engine $curVersion is the latest!"
    else
        echo "Current Brave engine $curVersion is the latest!" 1>&2
    
        if [[ "$1" ]] ; then
            # running from Makefile so spit out filename & version
            echo "$curBrave|$curVersion"
        else
            # running from newrelease.sh, so just spit out current version
            echo "$curVersion"
        fi
    fi
fi

cleanexit
