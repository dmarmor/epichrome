#!/bin/bash
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
    
    # save old profile path (for restoreoldruntime)
    saveProfilePath="$myProfilePath"
    unset myProfilePath
    
    # load update.sh (which loads core.sh & launch.sh)
    if ! source "${BASH_SOURCE[0]%/Runtime/Resources/Scripts/runtime.sh}/Scripts/update.sh" ; then
	ok= ; errmsg='Unable to load update script $mcssbVersion.'
	restoreoldruntime
	return 1
    fi

    # set up log file
    initlogfile
    
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

	errlog "Old app was unable to display update dialog."
	
	# assume nothing
	doUpdate=
	
	# reset command status
	ok=1
	errmsg=
	
	local updateMsg="A new version of Epichrome was found ($coreVersion).  This app is using version $SSBVersion. Would you like to update it?"
	local updateBtnUpdate='Update'
	local updateBtnLater='Later'
	local updateButtonList=( )
	
	if visbeta "$coreVersion" ; then
	    updateMsg="$updateMsg
			
IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myDataPath) before updating."
	    updateButtonList=( "+$updateBtnLater" "$updateBtnUpdate" )
	else
	    updateButtonList=( "+$updateBtnUpdate" "-$updateBtnLater" )
	fi
	updateButtonList+=( "Don't Ask Again For This Version" )
	
	# show the update choice dialog
	dialog doUpdate \
	       "$updateMsg" \
	       "Update" \
	       "|caution" \
	       "${updateButtonList[@]}"
	
	if [[ ! "$ok" ]] ; then
	    alert "Epichrome version $coreVersion was found (this app is using version $SSBVersion) but the update dialog failed. ($errmsg) If you don't want to update the app, you'll need to use Activity Monitor to quit now." 'Update' '|caution'
	    doUpdate="Update"
	    ok=1
	    errmsg=
	fi	
    fi
    if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
        
    if [[ "$doUpdate" = "Update" ]] ; then

	# set up necessary current variables
	SSBLastRunVersion="$SSBVersion"
	SSBEngineType='external|com.google.Chrome'
	getbrowserinfo SSBEngineSourceInfo
	SSBLastRunEngineType="$SSBEngineType"
	
	# run actual update
	updateapp "$SSBAppPath" NORELAUNCH
	if [[ ! "$ok" ]] ; then restoreoldruntime ; return 1 ; fi
	
	
	# UPDATE DATA DIRECTORY
	
	if [[ ( -d "$myDataPath" ) && ! -d "$myProfilePath" ]] ; then
	    
	    # UPDATE OLD-STYLE PROFILE DIRECTORY
	    
	    # remove old NativeMessagingHosts directory
	    try /bin/rm -rf "$myDataPath/$nmhDirName" \
		'Unable to remove old native messaging hosts directory.'
	    
	    # create profile directory
	    try /bin/mkdir -p "$myProfilePath" 'Unable to create profile directory.'
	    
	    # move to data directory
	    try '!1' pushd "$myDataPath" 'Unable to move to data directory.'

	    if [[ "$ok" ]] ; then
		
		# turn on extended glob
		local shoptState=
		shoptset shoptState extglob
		
		# find all except new log & profile directories
		local allExcept="!(Logs|${myProfilePath##*/}|${stdoutTempFile##*/}|${stderrTempFile##*/})"
		
		# move everything into profile directory
		try /bin/mv $allExcept "$myProfilePath" \
		    'Unable to migrate to new profile directory.'
		
		# restore extended glob
		shoptrestore shoptState
		
		# leave data directory no matter what
		if [[ "$ok" ]] ; then
		    
		    # nonfatal if this doesn't work
		    try '!1' popd 'Unable to restore working directory.'
		    ok=1 ; errmsg=
		else

		    # try to leave even on error
		    tryalways '!1' popd 'Unable to restore working directory.'
		fi
	    fi
	    
	    if [[ ! "$ok" ]] ; then
		alert "Update complete, but unable to migrate to new data directory structure. ($errmsg) Your user data may be lost." \
		      'Warning' 'caution'
		ok=1 ; errmsg=
	    fi
	fi
	
	
	# UPDATE CONFIG & RELAUNCH
	
	# add extra config vars for external engine
	[[ "${SSBEngineType%%|*}" != internal ]] && appConfigVars+=( SSBEngineSourceInfo )
	
	# write out config
	[[ -d "$myDataPath" ]] || try /bin/mkdir -p "$myDataPath" 'Unable to create data directory.'

	# relaunch updated app
	updaterelaunch
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
