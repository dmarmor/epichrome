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


# MYABORT -- exit cleanly on error
function myabort { # [myErrMsg code]
    
    # send only passed error message to stderr (goes back to main.applescript)
    echo "$myErrMsg" 1>&2
    
    abortsilent "$@"
}


# BOOTSTRAP RUNTIME SCRIPT

logNoStderr=1

source "${BASH_SOURCE[0]%/Scripts/*}/Runtime/Resources/Scripts/core.sh"
if [[ "$?" != 0 ]] ; then
    [[ ! "$myLogFile" ]] && myLogFile="$HOME/Library/Application Support/Epichrome/epichrome_log.txt"
    /bin/mkdir -p "${myLogFile%/*}"
    echo 'Unable to load core script.' >> "$myLogFile"
    exit 1
fi
[[ "$ok" ]] || myabort


# HANDLE KILL SIGNALS

trap "myabort 'Received termination signal.' 2" SIGHUP SIGINT SIGTERM


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
