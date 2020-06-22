#!/bin/bash
#
#  epichrome.sh: interface script for Epichrome main.js
#
#  Copyright (C) 2020  David Marmor
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


# GET PATH TO MY PARENT EPICHROME RESOURCES

myResourcesPath="${BASH_SOURCE[0]%/Scripts/epichrome.sh}"
myRuntimeScriptsPath="$myResourcesPath/Runtime/Contents/Resources/Scripts"


# LOAD UPDATE SCRIPT (THIS ALSO LOADS CORE AND LAUNCH)

source "$myRuntimeScriptsPath/core.sh" 'coreContext=epichrome' "$@" || exit 1
[[ "$ok" ]] || abort


# DETERMINE REQUESTED ACTION

# abort if no action sent
[[ "$epiAction" ]] || abort "No action found."

if [[ "$epiAction" = 'init' ]] ; then

    # ACTION: INITIALIZE
    
    # initialize log file and report info back to Epichrome
    initlogfile
    echo "$myDataPath"
    echo "$myLogFile"

    
elif [[ "$epiAction" = 'log' ]] ; then
    
    # ACTION: LOG
    
    if [[ "$epiLogMsg" ]] ; then
	if [[ "$epiLogType" = 'debug' ]] ; then
	    debuglog "$epiLogMsg"
	elif [[ "$epiLogType" ]] ; then
	    errlog "$epiLogType" "$epiLogMsg"
	else
	    errlog "$epiLogMsg"
	fi
    fi
    
    
elif [[ "$epiAction" = 'updatecheck' ]] ; then
    
    # ACTION: CHECK FOR UPDATES ON GITHUB
    
    # load launch.sh
    if ! source "$myRuntimeScriptsPath/launch.sh" ; then
	ok=
	errmsg="Unable to load launch.sh."
	errlog "$errmsg"
	abort
    fi
    
    # compare supplied versions
    if vcmp "$epiUpdateCheckVersion" '<' "$epiVersion" ; then
	echo 'MYVERSION'
	epiUpdateCheckVersion="$epiVersion"
    fi

    # compare latest supplied version against github
    local newVersion=
    checkgithubversion "$epiUpdateCheckVersion" newVersion
    [[ "$ok" ]] || abort
    
    # if we got here, check succeeded, so submit result back to main.js
    echo 'OK'
    [[ "$newVersion" ]] && echo "$newVersion"
    
    
elif [[ "$epiAction" = 'build' ]] ; then

    # ACTION: BUILD NEW APP
    
    # load update.sh
    if ! source "$myResourcesPath/Scripts/update.sh" ; then
	ok=
	errmsg="Unable to load update.sh."
	errlog "$errmsg"
	abort
    fi

    
    # CLEANUP -- clean up any half-made app
    function cleanup {
	
	# clean up any temp app bundle we've been working on
	if [[ -d "$appTmp" ]] ; then

	    # try to remove temp app bundle
	    if [[ "$(type -t rmtemp)" = function ]] ; then
		rmtemp "$appTmp" 'temporary app bundle'
	    else
		if ! /bin/rm -rf "$appTmp" 2> /dev/null ; then
		    echo "$myLogID: Unable to remove temporary app bundle." >> "$myLogFile"
		    echo 'Unable to remove temporary app bundle.' 1>&2
		fi
	    fi
	fi    
    }
    
    
    # CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

    debuglog "Starting build for '$epiAppPath'."
    
    # create the app directory in a temporary location
    appTmp=$(tempname "$epiAppPath")
    cmdtext=$(/bin/mkdir -p "$appTmp" 2>&1)
    if [[ "$?" != 0 ]] ; then
	# if we don't have permission, let the app know to try for admin privileges
	errRe='Permission denied$'
	[[ "$cmdtext" =~ $errRe ]] && abort 'PERMISSION' 2

	# regular error
	abort 'Unable to create temporary app bundle.' 1
    fi

    # set ownership of app bundle to this user (only necessary if running as admin)
    try /usr/sbin/chown -R "$USER" "$appTmp" 'Unable to set ownership of app bundle.'
    [[ "$ok" ]] || abort


    # POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

    # populate the app bundle
    updateapp "$appTmp"
    [[ "$ok" ]] || abort

    # move new app to permanent location (overwriting any old app)
    permanent "$appTmp" "$epiAppPath" "app bundle"
    [[ "$ok" ]] || abort

elif [[ "$epiAction" = 'edit' ]] ; then

    # load update.sh
    if ! source "$myResourcesPath/Scripts/update.sh" ; then
	ok=
	errmsg="Unable to load update.sh."
	errlog "$errmsg"
	abort
    fi
    
    
    # CLEANUP -- clean up any half-finished edit
    function cleanup {
	
	# clean up from any aborted update
	[[ "$(type -t updatecleanup)" = 'function' ]] && updatecleanup	
    }
    
    # EDIT (AND POSSIBLY UPDATE) THIS APP
    
    # populate the app bundle
    updateapp "$epiAppPath"
    [[ "$ok" ]] || abort
    
    # $$$$ MOVE DATA FOLDER IF ID CHANGED
    
    # $$$$ MOVE TO NEW NAME IF DISPLAYNAME CHANGED
    
else
    abort "Unable to perform action '$epiAction'."
fi

cleanexit
