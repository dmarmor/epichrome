#!/bin/sh
#
#  updatecheck.sh: Check for updates to Epichrome
#  
#  Copyright (C) 2020  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
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

# FLAG A CLEAN EXIT

doCleanExit=


# MYABORT -- exit cleanly on error
function myabort { # [myErrMsg code]

    # get error message
    local myErrMsg="$1" ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    
    # send only passed error message to stderr (goes back to main.applescript)
    echo "$myErrMsg" 1>&2

    doCleanExit=1
    
    abortsilent "$@"
}


# LOGGING INFO

myLogApp="$myLogApp|${BASH_SOURCE[0]##*/}"


# BOOTSTRAP RUNTIME SCRIPTS

source "${BASH_SOURCE[0]%/Scripts/*}/Runtime/Contents/Resources/Scripts/core.sh"
[[ "$?" = 0 ]] || ( echo '[$$]$myLogApp: Unable to load core script.' >> "$myLogFile" ; doCleanExit=1 ; exit 1 )
[[ "$ok" ]] || myabort
safesource "${BASH_SOURCE[0]%/Scripts/*}/Runtime/Contents/Resources/Scripts/launch.sh"


# HANDLE KILL SIGNALS

function handleexitsignal {
    if [[ ! "$doCleanExit" ]] ; then
	echo "$myLogApp: Unexpected termination." >> "$myLogFile"
	echo 'Unexpected termination.' 1>&2
    fi
}
trap "handleexitsignal" EXIT


myPath="${BASH_SOURCE[0]%/Contents/*}"


# GET INFO ON MY INSTANCE OF EPICHROME

# myEpichrome=
# getepichromeinfo "$myPath"  $$$$$$ FIX THIS


# COMPARE VERSIONS

if [[ "$ok" ]] ; then
    if [[ "$2" ]] ; then
	
	# compare two versions & echo the latest
	
	if vcmp "$1" '<' "$2" ; then
	    echo "$2"
	else
	    echo "$1"
	fi
    else

	# compare the supplied version against the latest on GitHub
	
	checkgithubversion "$1"
    fi
fi

[[ "$ok" ]] || myabort

doCleanExit=1 ; exit 0
