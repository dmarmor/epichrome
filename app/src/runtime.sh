#!/bin/sh
#
#  runtime.sh: legacy runtime script for updating from older versions of Epichrome
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


# UPDATESSB -- glue to allow update from old versions of Epichrome
function updatessb { # ( SSBAppPath )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # if we're here, we're updating from a pre-2.3.0 version, so set up
    # variables we need, then see if we need to redisplay the update dialog,
    # as the old dialog code has been failing in Mojave
    
    # set app path
    SSBAppPath="$1" ; shift
    
    # try to pull out identifier
    SSBIdentifier="${CFBundleIdentifier#org.epichrome.app.}"
    if [[ "$SSBIdentifier" = "$CFBundleIdentifier" ]] ; then
	ok= ; errmsg="Unable to determine app ID. This app may be too old to update."
	return 1
    fi
    
    # don't overwrite log on core.sh load
    logPreserve=1

    # save old profile path (for restoreoldruntime)
    saveProfilePath="$myProfilePath"
    
    # load update.sh
    if ! source "${BASH_SOURCE[0]%/Runtime/Resources/Scripts/runtime.sh}/Scripts/update.sh" ; then
	ok= ; errmsg='Unable to load update script $mcssbVersion.'
	restoreoldruntime
	return 1
    fi
    
    # we now have core, so set logging ID
    myLogID="$CFBundleName|Update"
    
    # load launch.sh (for launchhelper and writeconfig)
    if ! source "${BASH_SOURCE[0]%/Resources/Scripts/runtime.sh}/Contents/Resources/Scripts/launch.sh" ; then
	ok= ; errmsg='Unable to load launch script $updateVersion.'
	restoreoldruntime
	return 1
    fi
    
    # flag for deciding whether to update
    local doUpdate=Update
    
    # check if the old dialog code is failing
    local asResult=
    try 'asResult&=' /usr/bin/osascript -e \
	'tell application "Finder" to the name extension of ((POSIX file "'"${BASH_SOURCE[0]}"'") as alias)' \
	'FAILED'
    
    # for now, not parsing asResult, would rather risk a double dialog than none
    if [[ ! "$ok" ]] ; then
	
	# OLD DIALOG CODE NOT WORKING, SO SHOW UPDATE DIALOG

	# assume nothing
	doUpdate=
	
	# reset command status
	ok=1
	errmsg=
	
	if [[ "$SSBChromeVersion" != "$chromeVersion" ]] ; then
	    
	    # let the app update its Chrome version first
	    doUpdate=Later
	else
	    
	    local updateMsg="A new version of Epichrome was found ($coreVersion). Would you like to update this app?"
	    local updateBtnUpdate='Update'
	    local updateBtnLater='Later'
	    
	    if visbeta "$coreVersion" ; then
		updateMsg="$updateMsg
			
IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myDataPath) before updating."
		#updateBtnUpdate="-$updateBtnUpdate"
		updateBtnLater="+$updateBtnLater"
	    else
		updateBtnUpdate="+$updateBtnUpdate"
		updateBtnLater="-$updateBtnLater"
	    fi
	    
	    # show the update choice dialog
	    dialog doUpdate \
		   "$updateMsg" \
		   "Update" \
		   "|caution" \
		   "$updateBtnUpdate" \
		   "$updateBtnLater" \
		   "Don't Ask Again For This Version"
	    
	    if [[ ! "$ok" ]] ; then
		alert "A new version of the Epichrome runtime was found ($coreVersion) but the update dialog failed. ($errmsg) Attempting to update now." 'Update' '|caution'
		doUpdate="Update"
		ok=1
		errmsg=
	    fi
	fi
    fi
    if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
        
    if [[ "$doUpdate" = "Update" ]] ; then

	SSBEngineType='external|com.google.Chrome'  # $$$ ABSTRACT THIS FOR DEFAULT EXT ENGINE
	SSBLastRunEngineType="$SSBEngineType"
	
	# run actual update
	updateapp "$SSBAppPath"
	if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
	
	
	# UPDATE DATA DIRECTORY
	
	if [[ ( -d "$myDataPath" ) && ! -d "$myProfilePath" ]] ; then
	    
	    # UPDATE OLD-STYLE PROFILE DIRECTORY
	    
	    # give profile directory temporary name
	    local oldProfilePath="$(tempname "$myDataPath")"
	    
	    # don't use try to avoid logging problems
	    errmsg=
	    /bin/mv "$myDataPath" "$oldProfilePath" || errmsg='Error renaming old profile folder.'

	    if [[ ! "$errmsg" ]] ; then
    		local saveStderrFile="$stderrTempFile"
		local saveLogFile="$myLogFile"
		myLogFile="$oldProfilePath/${myLogFile##*/}"
		stderrTempFile="$oldProfilePath/${stderrTempFile##*/}"
	    else
		ok=
	    fi

	    debuglog "GOT HERE OK: $myLogFile   $stderrTempFile"
	    
	    # make empty directory where old profile was
	    try /bin/mkdir -p "$myDataPath" 'Error creating new data folder.'
	    
	    # move log file back into place
	    if [[ "$ok" ]] ; then
		errmsg=
		/bin/mv "$myLogFile" "$saveLogFile" || \
		    errmsg='Unable to move log file back into place.'
		
		if [[ ! "$errmsg" ]] ; then
    		    myLogFile="$saveLogFile"
    		    stderrTempFile="$saveStderrFile"
		else
		    ok=
		fi
	    fi
	    
	    # move profile directory into new data directory
	    try /bin/mv "$oldProfilePath" "$myDataPath/UserData" \
		'Error moving old profile into new data directory.'
	    
	    # remove External Extensions and NativeMessagingHosts directories from profile
	    try /bin/rm -rf "$myDataPath/UserData/External Extensions" \
		'Unable to remove old external extensions folder.'
	    
	    local nmhDir="$myDataPath/UserData/$nmhDirName"
	    try /bin/rm -f "$nmhDir/org.epichrome."* "$nmhDir/$appNMHFile" \
		'Unable to remove old native messaging host.'
	fi
	
	if [[ ! "$ok" ]] ; then
	    alert "Update complete, but unable to migrate to new data directory structure. ($errmsg) Your user data may be lost." \
		  'Warning' 'caution'
	    ok=1 ; errmsg=
	fi
	
	
	# UPDATE CONFIG & RELAUNCH
	
	# add extra config vars for external engine
	[[ "${SSBEngineType%%|*}" != internal ]] && appConfigVars+=( SSBEngineSourceInfo )
	
	# write out config
	[[ -d "$myDataPath" ]] || try /bin/mkdir -p "$myDataPath" 'Unable to create data directory.'
	writeconfig "$myDataPath/config.sh"
	[[ "$ok" ]] || \
	    abort "Update succeeded, but unable to write new config. ($errmsg) Some settings may be lost on first run."
	
	# launch helper
	launchhelper Relaunch
	
	# if relaunch failed, report it
	[[ "$ok" ]] || \
	    alert "Update succeeded, but updated app didn't launch: $errmsg" \
		  'Update' '|caution'
	
	# no matter what, we have to quit now
	cleanexit
    else
    
	# HANDLE NON-UPDATES
	
	# if we chose not to ask again with this version, update config
	if [[ "$doUpdate" = "Don't Ask Again For This Version" ]] ; then
	    
	    # pretend we're already at the new version
	    SSBVersion="$coreVersion"
	    updateconfig=1
	fi
	
	restoreoldruntime
    fi
    
    # return value
    [[ "$ok" ]] && return 0 || return 1
}


# RESTOREOLDRUNTIME -- roll back to old runtime before exiting updatessb
function restoreoldruntime {

    # restore old profile path
    myProfilePath="$saveProfilePath"
    
    # temporarily turn OK back on & reload old runtime
    if ! source "$SSBAppPath/Contents/Resources/Scripts/runtime.sh" ; then
	ok=
	
	# update error message
	if [[ "$errmsg" ]] ; then
	    errmsg="$errmsg Also unable"
	else
	    errmsg="Unable"
	fi
	errmsg="$errmsg to restore old runtime. You may have to restart the app."
    fi
    
    # deactivate myself for safety
    unset -f restoreoldruntime
    unset saveProfilePath
}
