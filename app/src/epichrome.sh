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
    
    
elif [[ "$epiAction" = 'read' ]] ; then
    
    # ACTION: READ EXISTING APP

    # error prefix
    myErrPrefix="Error reading ${epiAppPath##*/}"
    
    # main app settings locations
    myOldConfigPath="$epiAppPath/Contents/Resources/Scripts/config.sh"
    myConfigPath="$epiAppPath/Contents/Resources/script"
    
    if [[ -e "$myOldConfigPath" ]] ; then
	abort "$myErrPrefix: Editing of pre-2.3 apps not yet implemented."
    elif [[ ! -e "$myConfigPath" ]] ; then
	abort "$myErrPrefix: This does not appear to be an Epichrome app."
    else

	# read in app config
	myConfigScript=
	try 'myConfigScript=' /bin/cat "$myConfigPath" "$myErrPrefix: Unable to read app data."
	[[ "$ok" ]] || abort
	
	# pull config from current flavor of app
	myConfigPart="${myConfigScript#*# CORE APP INFO}"
	myConfig="${myConfigPart%%# CORE APP VARIABLES*}"
	
	# if either delimiter string wasn't found, that's an error
	if [[ ( "$myConfigPart" = "$myConfigScript" ) || \
		  ( "$myConfig" = "$myConfigPart" ) ]] ; then
	    abort "$myErrPrefix: Unexpected app configuration."
	fi
	
	# remove any trailing export statement
	# myConfig="${myConfig%%$'\n'export*}"
	
	# read in config variables
	try eval "$myConfig" "$myErrPrefix: Unable to parse app configuration."
	[[ "$ok" ]] || abort
    fi
    
    
    # SANITY-CHECK CORE APP INFO
    
    # basic info
    ynRe='^(Yes|No)$'
    if [[ ! ( "$SSBVersion" && "$SSBIdentifier" && \
		  "$CFBundleDisplayName" && "$CFBundleName" && \
		  ( "$SSBCustomIcon" =~ $ynRe ) && \
		  ( ( ! "$SSBRegisterBrowser" ) || ( "$SSBRegisterBrowser" =~ $ynRe ) ) ) ]] ; then
	abort "$myErrPrefix: Basic app info is missing or corrupt."
    fi
    
    # engine type
    engRe='^(in|ex)ternal\|'
    if [[ ! ( "$SSBEngineType" =~ $engRe ) ]] ; then
	
	# $$$$ HANDLE MISSING ENGINE & OLD ENGINE TYPES HERE
	abort "$myErrPrefix: App engine type is missing or unreadable."
    fi
    
    # command line
    if ( ! isarray SSBCommandLine ) || [[ "${#SSBCommandLine[@]}" -lt 1 ]] ; then
	abort "$myErrPrefix: App URLs are missing or unreadable."
    fi
    
    # fill in register browser if missing
    if [[ ! "$SSBRegisterBrowser" ]] ; then
	try '!12' /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$epiAppPath/Contents/Info.plist" ''
	if [[ "$ok" ]] ; then
	    SSBRegisterBrowser=Yes	    
	else
	    ok=1 ; errmsg=
	    SSBRegisterBrowser=No
	fi
    fi


    # GET PATH TO ICON
    myAppIcon=
    try 'myAppIcon=' /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' \
	"$epiAppPath/Contents/Info.plist" \
	"$myErrPrefix: Unable to find icon file in Info.plist"
    if [[ "$ok" ]] ; then
	myAppIcon="$epiAppPath/Contents/Resources/$myAppIcon"
	if [[ -e "$myAppIcon" ]] ; then
	    myAppIcon="
    \"appIconPath\": \"$(escapejson "$myAppIcon")\","
	else
	    myAppIcon=
	fi
    else
	# fail silently, and we just won't use a custom icon in dialogs
	ok=1 ; errmsg=
	myAppIcon=
    fi
    
    
    # EXPORT INFO BACK TO MAIN.JS

    # escape each command-line URL for JSON
    cmdLineJson=()
    for url in "${SSBCommandLine[@]}" ; do
	cmdLineJson+=( "\"$(escapejson "$url")\"" )
    done

    # export JSON
    echo "{$myAppIcon
    \"appInfo\": {
        \"version\": \"$(escapejson "$SSBVersion")\",
    	\"identifier\": \"$(escapejson "$SSBIdentifier")\",
	\"displayName\": \"$(escapejson "$CFBundleDisplayName")\",
	\"shortName\": \"$(escapejson "$CFBundleName")\",
        \"registerBrowser\": \"$(escapejson "$SSBRegisterBrowser")\",
        \"customIcon\": \"$(escapejson "$SSBCustomIcon")\",
        \"engineTypeID\": \"$(escapejson "$SSBEngineType")\",
        \"commandLine\": [
            $(join_array ','$'\n''        ' "${cmdLineJson[@]}")
        ]
    }
}"
    
    
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

    # ACTION: EDIT (AND POSSIBLY UPDATE) EXISTING APP
    
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
    
    
    # populate the app bundle
    updateapp "$epiAppPath"
    [[ "$ok" ]] || abort
    

    # capture post-update action warnings
    warnings=()
    
    # MOVE DATA FOLDER IF ID CHANGED
    
    if [[ "$epiOldIdentifier" && \
	      ( "$epiOldIdentifier" != "$SSBIdentifier" ) && \
	      (  -e "$appDataPathBase/$epiOldIdentifier" ) ]] ; then
	
	# common warning prefix
	warnPrefix="WARN:Unable to migrate app data to new ID $SSBIdentifier"
	
	if [[ -e "$appDataPathBase/$SSBIdentifier" ]] ; then
	    warnings+=( "$warnPrefix: App data with that ID already exists. This app will use that data." )
	else
	    permanent "$appDataPathBase/$epiOldIdentifier" \
		      "$appDataPathBase/$SSBIdentifier" "app bundle"
	    [[ "$ok" ]] || warnings+=( "$warnPrefix: $errmsg This app will create a new data directory on first run." )
	fi
    fi

    
    # MOVE TO NEW NAME IF DISPLAYNAME CHANGED
    
    if [[ "$epiNewAppPath" && \
	      ( "$epiNewAppPath" != "$epiAppPath" ) ]] ; then
	
	# common warning prefix & postfix
	warnPrefix="WARN:Unable to rename app"
	warnPostfix="The app is intact under the old name of ${epiAppPath##*/}."
	
	if [[ -e "$epiNewPath" ]] ; then
	    warnings+=( "$warnPrefix: ${epiNewPath##*/} already exists. $warnPostfix" )
	else
	    permanent "$epiAppPath" "$epiNewAppPath" "app bundle"
	    [[ "$ok" ]] || warnings+=( "$warnPrefix: $errmsg $warnPostfix" )
	fi
    fi
    
    
    # IF ANY WARNINGS FOUND, REPORT THEM
    
    [[ "${warnings[*]}" ]] && abort "$(join_array $'\n' "${warnings[@]}")"
    
else
    abort "Unable to perform action '$epiAction'."
fi

cleanexit
