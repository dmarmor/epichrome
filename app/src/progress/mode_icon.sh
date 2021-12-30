#!/bin/bash
#
#  mode_icon.sh: mode script for building app icons in Epichrome.app
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


# PROGRESS BAR SETUP

# step calibration
#stepStart=0

#progressAction='Searching for an icon...'
#progressTotal=10000


# --- MAIN BODY ---

# load makeicon.sh
if ! source "$myScriptPathEpichrome/makeicon.sh" ; then
    ok= ; errmsg="Unable to load $myScriptPathEpichrome/makeicon.sh."
    errlog
    abortreport
fi

if [[ "$epiAutoIconURL" ]] ; then
    
    # SEARCH URL FOR AUTO-ICON
    
    debuglog "Searching URL \"$epiAutoIconURL\" for icons."
    
    echo 'Searching URL for icons...'
    
    # remove any leftover temp directory
    if [[ -e "$epiAutoIconTempDir" ]] ; then
        saferm 'Unable to remove old auto-icon directory.' "$epiAutoIconTempDir"
    fi
    
    debuglog "Removing leftover icon source & creating temp directory."  # $$$
    
    # remove any leftover icon source image
    try /bin/rm -f "$epiIconSource" 'Unable to remove old auto-icon source image.'
    
    # create temp directory
    try /bin/mkdir "$epiAutoIconTempDir" 'Unable to create temporary auto-icon directory.'
    
    [[ "$ok" ]] || abort
    
    # build makeicon command
    autoIconCmd='[
    {
        "action": "autoicon",
        "options": {
            "url": "'"$(escapejson "$epiAutoIconURL")"'",
            "imagePath": "'"$(escapejson "$epiIconSource")"'",
            "tempImageDir": "'"$(escapejson "$epiAutoIconTempDir")"'"
        }
    }
]'
    
    debuglog 'Running makeicon.'  # $$$
    
    autoIconErr=
    try 'autoIconErr=&' /usr/bin/env php "$myScriptPathEpichrome/makeicon.php" \
            "$autoIconCmd" ''
    if [[ ! "$ok" ]] ; then
        errmsg="${autoIconErr#*PHPERR|}"
        errlog
    fi
    
    debuglog 'Removing temporary auto-icon directory.'  # $$$
    
    # remove temp directory no matter what
    myTry=tryalways
    saferm 'Unable to remove temporary auto-icon directory.' \
            "$epiAutoIconTempDir"
    
    [[ "$ok" ]] || abort
fi


# CREATE ICON PREVIEW

# ensure icon source file exists
if [[ ! -e "$epiIconSource" ]] ; then
    ok=
    if [[ "$epiAutoIconURL" ]] ; then
        errmsg='REPORT|Unable to find automatically-downloaded icon.'
        errlog FATAL
    else
        errmsg="Unable to find \"${epiIconSource##*/}\"."
        errlog
    fi
    abort
fi

debuglog "Creating icon preview."

echo 'Creating icon preview...'

makeicon "$epiIconSource" "$epiIconPreviewPath" '' '' \
        "$epiIconCrop" "$epiIconCompSize" "$epiIconCompBG" '' 256 256 \
        sourceSize
[[ "$ok" ]] || abort

# transmit source size
try "$subappErrFile<" echo "SOURCESIZE|${sourceSize[0]},${sourceSize[1]}" \
        'Unable to write icon source dimensions.'
ok=1 ; errmsg=

# success!
cleanexit
