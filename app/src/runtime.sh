#!/bin/sh
#
#  runtime.sh: legacy runtime script for updating from older versions of Epichrome
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

# UPDATESSB -- glue to allow update from old versions of Epichrome
function updatessb { # curAppPath
    
    #  (IN UPDATESSB??)
    # $$$$ LOAD UPDATE.SH
    safesource "${epiRuntime[$e_contents]}/Resources/Scripts/update.sh" 'update script' NORUNTIMELOAD
    # $$$$ POPULATE EPIRUNTIME
    
    if [[ "$ok" ]] ; then

	# if we're here, we're updating from a pre-2.3.0 version, so set up
	# variables we need, then see if we need to redisplay the update dialog,
	# as the old dialog code has been failing in Mojave
	
	# arguments
	local curAppPath="$1"
	
	local doUpdate=Update

	# set up dialog icon
	appDialogIcon="$curAppPath/Contents/Resources/app.icns"
	
	# set up new-style logging
	myLogApp="$CFBundleName"
	# myLogFile="$epiDataPath/epichrome_log.txt"
	# stderrTempFile="$epiDataPath/stderr.txt"
	initlog
	
	# get our version of Epichrome
	local epiVersion="${epiRuntime[$e_version]}"
	if [[ ! "$epiVersion" ]] ; then
	    ok= ; errmsg="Unable to get Epichrome version for update."
	fi
	
	if [[ "$ok" ]] ; then
	    
	    # check if the old dialog code is failing
	    local asResult=
	    try 'asResult&=' /usr/bin/osascript -e \
		'tell application "Finder" to the name extension of ((POSIX file "'"${BASH_SOURCE[0]}"'") as alias)' \
		'FAILED'
	    
	    # for now, not parsing asResult, would rather risk a double dialog than none
	    if [[ ! "$ok" ]] ; then

		# assume nothing
		doUpdate=
		
		# reset command status
		ok=1
		errmsg=

		if [[ "$SSBChromeVersion" != "$chromeVersion" ]] ; then
		    
		    # let the app update its Chrome version first
		    doUpdate=Later
		else
		    
		    local updateMsg="A new version of Epichrome was found ($epiVersion). Would you like to update this app?"
		    local updateBtnUpdate='Update'
		    local updateBtnLater='Later'
		    
		    if visbeta "$epiVersion" ; then
			updateMsg="$updateMsg
			
IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myProfilePath) before updating."
			updateBtnUpdate="-$updateBtnUpdate"
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
			alert "A new version of the Epichrome runtime was found ($epiVersion) but the update dialog failed. ($errmsg) Attempting to update now." 'Update' '|caution'
			doUpdate="Update"
			ok=1
			errmsg=
		    fi
		fi
	    fi
	    
	    if [[ "$ok" && ( "$doUpdate" = "Update" ) ]] ; then
				
		# data path variable name change
		SSBDataPath="$SSBProfilePath"
		
		# ask user to choose  which engine to use (sticking with Google Chrome is the default)
		local useChromium=
		dialog SSBEngineType \
		       "Switch app engine to Chromium or continue to use Google Chrome?

NOTE: If you don't know what this question means, choose Google Chrome.

Switching an existing app to the Chromium engine will likely log you out of any existing sessions in the app and may require you to reactivate extensions and/or lose extension data.

In the long run, switching to the Chromium engine has many advantages, including more reliable link routing, preventing intermittent loss of custom icon/app name, ability to give the app individual access to camera and microphone, and more reliable interaction with AppleScript and Keyboard Maestro.

The main advantage of continuing to use the Google Chrome engine is if your app must run on a signed browser (mainly needed for extensions like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension)." \
		       "Choose App Engine" \
		       "|caution" \
		       "-Chromium" \
		       "+Google Chrome"
		if [[ ! "$ok" ]] ; then
		    alert "The app engine choice dialog failed. Attempting to update the app with the existing Google Chrome engine. If this is not what you want, you must abort the app now." 'Update' '|caution'
		    SSBEngineType="Google Chrome"
		    ok=1
		    errmsg=
		fi
		
		# run actual update
		[[ "$ok" ]] && updateapp "$@"
		
		if [[ "$ok" ]] ; then

		    # update existing data directory to new structure
		    if [[ ( -d "$myProfilePath" ) && ( ! -d "$myProfilePath/$appDataProfileBase" ) ]] ; then
			
			# what was the Chrome profile path is now our base data directory
			local myDataPath="$myProfilePath"
			
			# give profile directory temporary name
			local oldProfilePath="$(tempname "$myProfilePath")"
			try /bin/mv "$myProfilePath" "$oldProfilePath" \
			    'Error renaming old profile directory.'
			
			# make empty directory where old profile was
			try /bin/mkdir -p "$myDataPath" \
			    'Error creating new data directory.'
			
			# move profile directory into new data directory
			try /bin/mv "$oldProfilePath" "$myDataPath/$appDataProfileBase" \
			    'Error moving old profile into new data directory.'

			# $$$ FIX UP NMH & EXTENSION DIRECTORIES? DELETE OLD NMH SCRIPT FROM NMH DIR AT LEAST
		    fi
		    
		    if [[ ! "$ok" ]] ; then
			alert "Update complete, but unable to migrate to new data directory structure. ($errmsg) Your user data may be lost." \
			      'Warning' 'caution'
			ok=1 ; errmsg=
		    fi
		fi
		
		# relaunch after a delay
		if [[ "$ok" ]] ; then
		    relaunch "$curAppPath" 1 &
		    disown -ar
		    exit 0
		fi
	    fi
	fi
    fi
    
    # handle a failed update or non-update

    if [[ ( ! "$ok" ) || ( "$doUpdate" != "Update" ) ]] ; then

	# if we chose not to ask again with this version, update config
	if [[ "$doUpdate" = "Don't Ask Again For This Version" ]] ; then
	    
	    # pretend we're already at the new version
	    SSBVersion="$epiVersion"
	    updateconfig=1
	fi
	
	# turn this option off again as it interferes with unset in old try function
	shopt -u nullglob
	
	# temporarily turn OK back on & reload old runtime
	local oldErrmsg="$errmsg" ; errmsg=
	local oldOK="$ok" ; ok=1
	safesource "$curAppPath/Contents/Resources/Scripts/runtime.sh" "runtime script $SSBVersion"
	[[ "$ok" ]] && ok="$oldOK"
	
	# update error message
	if [[ "$oldErrmsg" && "$errmsg" ]] ; then
	    errmsg="$oldErrmsg $errmsg"
	elif [[ "$oldErrmsg" ]] ; then
	    errmsg="$oldErrmsg"
	fi
    fi
    
    # return value
    [[ "$ok" ]] || return 1
    return 0
}
