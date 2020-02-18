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
    
    # set up new-style logging, but for now log to main Epichrome log
    myDataPath="$HOME/Library/Application Support/Epichrome"
    myLogApp="$CFBundleName|Update"
    myLogFile="$myDataPath/epichrome_log.txt"
    logPreserve=1
    
    # load update.sh & launch.sh (for launchhelper and writeconfig)
    safesource "${BASH_SOURCE[0]%/Runtime/Resources/Scripts/runtime.sh}/Scripts/update.sh" \
	       "update script $mcssbVersion"
    safesource "${BASH_SOURCE[0]%/Resources/Scripts/runtime.sh}/Contents/Resources/Scripts/launch.sh" \
	       "launch script $mcssbVersion"
    if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
    
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
			
IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myProfilePath) before updating."
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

	SSBEngineType='com.google.Chrome'  # $$$ ABSTRACT THIS FOR DEFAULT EXT ENGINE
	
	# $$$$ PROBABLY DELETE THIS
	# ask user to choose  which engine to use (sticking with Google Chrome is the default)
# 	local useChromium=
# 	dialog SSBEngineType \
# 	       "Continue to use Google Chrome app engine, or switch to Chromium?

# NOTE: If you don't know what this question means, choose Google Chrome.

# Switching an existing app to the Chromium engine will likely log you out of any existing sessions in the app and may require you to reactivate extensions and/or lose extension data.

# In the long run, switching to the Chromium engine has many advantages, including more reliable link routing, preventing intermittent loss of custom icon/app name, ability to give the app individual access to camera and microphone, and more reliable interaction with AppleScript and Keyboard Maestro.

# The main advantage of continuing to use the Google Chrome engine is if your app must run on a signed browser (mainly needed for extensions like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension)." \
# 	       "Choose App Engine" \
# 	       "|caution" \
# 	       "+Google Chrome" \
# 	       "Chromium"
# 	if [[ ! "$ok" ]] ; then
# 	    alert "The app engine choice dialog failed. Attempting to update the app with the existing Google Chrome engine. If this is not what you want, you must abort the app now." 'Update' '|caution'
# 	    SSBEngineType='com.google.Chrome'
# 	    ok=1
# 	    errmsg=
# 	fi
	
	# run actual update
	updateapp "$SSBAppPath"
	if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
	
	
	# UPDATE DATA DIRECTORY
	
	# path to data directory
	myDataPath="$HOME/Library/Application Support/Epichrome/Apps/$SSBIdentifier"
	
	if [[ "$myDataPath" != "$myProfilePath" ]] ; then
	    ok= ; errmsg='Unable to find old profile folder.'
	elif [[ -d "$myDataPath" && ! -d "$myDataPath/UserData" ]] ; then
	    
	    # UPDATE OLD-STYLE PROFILE DIRECTORY
	    
	    # give profile directory temporary name
	    local oldProfilePath="$(tempname "$myProfilePath")"
	    try /bin/mv "$myProfilePath" "$oldProfilePath" \
		'Error renaming old profile folder.'
	    
	    # make empty directory where old profile was
	    try /bin/mkdir -p "$myDataPath" \
		'Error creating new data folder.'
	    
	    # move profile directory into new data directory
	    try /bin/mv "$oldProfilePath" "$myDataPath/UserData" \
		'Error moving old profile into new data directory.'
	    
	    # remove External Extensions and NativeMessagingHosts directories from profile
	    try /bin/rm -rf "$myDataPath/UserData/External Extensions" \
		'Unable to remove old external extensions folder.'
	    
	    local nmhDir="$myDataPath/UserData/NativeMessagingHosts"
	    try /bin/rm -f "$nmhDir/org.epichrome."* "$nmhDir/epichromeruntimehost.py" \
		'Unable to remove old native messaging host.'
	fi
	
	if [[ ! "$ok" ]] ; then
	    alert "Update complete, but unable to migrate to new data directory structure. ($errmsg) Your user data may be lost." \
		  'Warning' 'caution'
	    ok=1 ; errmsg=
	fi
	
	
	# UPDATE CONFIG & RELAUNCH
	
	# add extra config vars for external engine
	[[ "$SSBEngineType" != internal ]] && appConfigVars+=( SSBEngineSource )
	
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
    
    # temporarily turn OK back on & reload old runtime
    local oldErrmsg="$errmsg" ; errmsg=
    local oldOK="$ok" ; ok=1
    safesource "$SSBAppPath/Contents/Resources/Scripts/runtime.sh" "runtime script $SSBVersion"
    [[ "$ok" ]] && ok="$oldOK"
    
    # update error message
    if [[ "$oldErrmsg" && "$errmsg" ]] ; then
	errmsg="$oldErrmsg $errmsg"
    elif [[ "$oldErrmsg" ]] ; then
	errmsg="$oldErrmsg"
    fi
    
    # deactivate myself for safety
    unset -f restoreoldruntime
}
