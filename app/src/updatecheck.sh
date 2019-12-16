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


# ABORT -- exit cleanly on error
function abort { # [myErrMsg myCode]

    # clean up any temp app bundle we've been working on
    [[ -d "$appTmp" ]] && rmtemp "$appTmp" 'temporary app bundle'
    
    # arguments
    local myErrMsg="$1" ; shift ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    local myCode="$1"   ; shift ; [[ "$myCode"   ]] || myCode=1
    
    # log error message
    local myAbortLog="Aborting: $myErrMsg"
    if [[ "$( type -t errlog )" = function ]] ; then
	errlog "$myAbortLog"
    else
	# send abort message to log
	[[ -w "$logPath" ]] && echo "$myAbortLog" >> "$logPath"

    fi
    
    # send only passed error message to stderr (goes back to main.applescript)
    echo "$myErrMsg" 1>&2
    
    exit "$myCode"
}


# HANDLE KILL SIGNALS

trap "abort 'Unexpected termination.' 2" SIGHUP SIGINT SIGTERM


# BOOTSTRAP RUNTIME SCRIPT

logNoStderr=1

source "${BASH_SOURCE[0]%/Scripts/*}/Runtime/Resources/Scripts/runtime.sh"
[[ "$?" != 0 ]] && abort 'Unable to load runtime script.'
[[ "$ok" ]] || abort

myPath="${BASH_SOURCE[0]%/Contents/*}"


# GET INFO ON MY INSTANCE OF EPICHROME

# myEpichrome=
# epichromeinfo "$myPath"


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
	
	checkepichromeversion "$myPath/Contents/Resources/Runtime" "$1"
    fi
fi

[[ "$ok" ]] || abort
