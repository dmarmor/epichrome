#!/bin/bash
#
#  update.sh: functions for updating/or creating Epichrome apps
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


# VERSION

updateVersion='EPIVERSION'


# PATH TO THIS SCRIPT'S EPICHROME APP BUNDLE

updateEpichromePath="${BASH_SOURCE[0]%/Contents/Resources/Scripts/update.sh}"
updateEpichromeRuntime="$updateEpichromePath/Contents/Resources/Runtime"


# BOOTSTRAP MY VERSION OF CORE.SH & LAUNCH.SH

if [[ "$updateVersion" != "$coreVersion" ]] ; then
    if ! source "$updateEpichromeRuntime/Contents/Resources/Scripts/core.sh" "$@" ; then
	ok=
	errmsg="Unable to load core $updateVersion."
	errlog "$errmsg"
    fi
fi

if [[ "$ok" ]] ; then
    if ! source "$updateEpichromeRuntime/Contents/Resources/Scripts/launch.sh" ; then
	ok=
	errmsg="Unable to load launch.sh $updateVersion."
	errlog "$errmsg"
    fi
fi


# FUNCTION DEFINITIONS

# ESCAPEHTML: escape HTML-reserved characters in a string
function escapehtml {  # ( str )

    # argument
    local str="$1" ; shift

    # escape HTML characters & ignore errors
    echo "$str" | try '-1' /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
		      "Unable to escape HTML characters in string '$str'"
    ok=1 ; errmsg=
}


# UPDATEAPP: populate an app bundle
function updateapp { # ( updateAppPath [NORELAUNCH] )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local updateAppPath="$1" ; shift
    local noRelaunch="$1" ; shift
    
    # make sure we're logging
    [[ "$myLogFile" ]] || initlogfile
    
    # on engine change, restore last-run engine for update purposes
    if [[ "${myStatusEngineChange[0]}" ]] ; then	
	SSBLastRunEngineType="${myStatusEngineChange[0]}"
    fi
    
    
    # ALLOW ENGINE SWITCH FOR ADVANCED USERS ($$$ UNTIL APP EDITING IS IMPLEMENTED)
    
    if [[ "$SSBAllowEngineSwitch" ]] ; then
	
	# ask user to choose  which engine to use (sticking with current is the default)
	if [[ "${SSBEngineType%%|*}" = internal ]] ; then
	    local keepButton="+Keep Built-In (${epiEngineSource[$iName]})"
	    local changeButton='Switch to External (Chrome)'
	    local keepText="built-in ${epiEngineSource[$iName]}"
	    local changeText='external Google Chrome'
	else
	    local keepButton='+Keep External (Chrome)'
	    local changeButton="Switch to Built-In (${epiEngineSource[$iName]})"
	    local keepText='external Google Chrome'
	    local changeText="built-in ${epiEngineSource[$iName]}"
	fi
	local engineChoice=
	dialog engineChoice \
	       "Keep using $keepText app engine, or switch to $changeText engine?

NOTE: If you don't know what this question means, choose Keep.

Switching an existing app's engine will log you out of any existing sessions in the app and require you to reinstall all your extensions. (The first time you run the updated app, it will open the Chrome Web Store page for each extension you had installed to give you a chance to reinstall them. Once reinstalled, any extension settings should reappear.)

The built-in ${epiEngineSource[$iName]} engine has many advantages, including more reliable link routing, preventing intermittent loss of custom icon/app name, ability to give the app individual access to camera and microphone, and more reliable interaction with AppleScript and Keyboard Maestro.

The main advantage of the external Google Chrome engine is if your app must run on a signed browser (mainly needed for extensions like the 1Password desktop extension--it is not needed for the 1PasswordX extension)." \
	       "Choose App Engine" \
	       "|caution" \
	       "$keepButton" \
	       "$changeButton"
	if [[ "$ok" ]] ; then
	    if [[ "$engineChoice" = "$changeButton" ]] ; then
		
		if [[ "${SSBEngineType%%|*}" = internal ]] ; then
		    SSBEngineType='external|com.google.Chrome'
		else
		    SSBEngineType="internal|${epiEngineSource[$iID]}"
		    SSBEngineSourceInfo=( "${epiEngineSource[@]}" )		    
		fi
	    fi
	else
	    alert "The app engine choice dialog failed. Attempting to update the app with the existing $keepText engine. If this is not what you want, you must abort the app now." 'Update' '|caution'
	    ok=1
	    errmsg=
	fi
	
    fi
    
    
    # LOAD FILTER.SH

    safesource "$updateEpichromeRuntime/Contents/Resources/Scripts/filter.sh"
    [[ "$ok" ]] || return 1
    
    
    # SET UNIQUE APP ID
    
    if [[ ! "$SSBIdentifier" ]] ; then
	
	# no ID found
	
	# see if we can pull it from CFBundleIdentifier
	SSBIdentifier="${CFBundleIdentifier#$appIDBase.}"
	if [[ "$SSBIdentifier" = "$CFBundleIdentifier" ]] ; then
	    
	    # no identifier found, so create a new ID
	    
	    # get max length for SSBIdentifier, given that CFBundleIdentifier
	    # must be 30 characters or less (the extra 1 accounts for the .
	    # we will need to add to the base
	    
	    local maxidlength=$((30 - \
				    ((${#appIDBase} > ${#appEngineIDBase} ? \
						    ${#appIDBase} : \
						    ${#appEngineIDBase} ) + 1) ))
	    
	    # first attempt is to just use the bundle name with
	    # illegal characters removed
	    SSBIdentifier="${CFBundleName//[^-a-zA-Z0-9_]/}"
	    
	    # if trimmed away to nothing, use a default name
	    [ ! "$SSBIdentifier" ] && SSBIdentifier="generic"
	    
	    # trim down to max length
	    SSBIdentifier="${SSBIdentifier::$maxidlength}"
	    
	    # check for any apps that already have this ID
	    
	    # get a length that's the smaller of the length of the
	    # full ID or the max allowed length - 3 to accommodate
	    # adding random digits at the end
	    local idbaselength="${SSBIdentifier::$(($maxidlength - 3))}"
	    idbaselength="${#idbaselength}"
	    
	    # initialize status variables
	    local appidfound=
	    local engineidfound=
	    local randext=
	    
	    # determine if Spotlight is enabled for the root volume
	    local spotlight=$(mdutil -s / 2> /dev/null)
	    if [[ "$spotlight" =~ 'Indexing enabled' ]] ; then
		spotlight=1
	    else
		spotlight=
	    fi
	    
	    # loop until we randomly hit a unique ID
	    while true ; do
		
		if [[ "$spotlight" ]] ; then
		    try 'appidfound=' mdfind \
			"kMDItemCFBundleIdentifier == '$appIDBase.$SSBIdentifier'" \
			'Unable to search system for app bundle identifier.'
		    try 'engineidfound=' mdfind \
			"kMDItemCFBundleIdentifier == '$appEngineIDBase.$SSBIdentifier'" \
			'Unable to search system for engine bundle identifier.'
		    
		    # exit loop on error, or on not finding this ID
		    [[ "$ok" && ( "$appidfound" || "$engineidfound" ) ]] || break
		fi
		
		# try to create a new unique ID
		randext=$(((${RANDOM} * 100 / 3279) + 1000))  # 1000-1999
		
		SSBIdentifier="${SSBIdentifier::$idbaselength}${randext:1:3}"
		
		# if we don't have spotlight we'll just use the first randomly-generated ID
		[[ ! "$spotlight" ]] && break
		
	    done
	    
	    # if we got out of the loop, we have a unique-ish ID (or we got an error)
	fi
    fi
    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi
    
    # set app bundle ID
    local myAppBundleID="$appIDBase.$SSBIdentifier"
    

    # SET APP VERSION
    
    SSBVersion="$coreVersion"
    
    
    # BEGIN POPULATING APP BUNDLE
    
    # put updated bundle in temporary Contents directory
    local contentsTmp="$(tempname "$updateAppPath/Contents")"
    
    # copy in the boilerplate for the app
    try /bin/cp -PR "$updateEpichromeRuntime/Contents" "$contentsTmp" 'Unable to populate app bundle.'
    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi

    # copy executable into place
    safecopy "$updateEpichromeRuntime/Exec/Epichrome" \
	     "$contentsTmp/MacOS/Epichrome" \
	     'app executable.'
    
    
    # FILTER APP INFO.PLIST INTO PLACE
    
    # set up default PlistBuddy commands
    local filterCommands=( "set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
			       "set :CFBundleName $(escape "$CFBundleName" "\"'")" \
			       "set :CFBundleIdentifier $myAppBundleID" )
    
    # if not registering as browser, delete URI handlers
    [[ "$SSBRegisterBrowser" = "No" ]] && \
	filterCommands+=( "Delete :CFBundleURLTypes" )
    
    # filter boilerplate Info.plist with info for this app
    filterplist "$updateEpichromeRuntime/Filter/Info.plist" \
		"$contentsTmp/Info.plist" \
		"app Info.plist" \
		"${filterCommands[@]}"

    
    # FILTER APP MAIN SCRIPT INTO PLACE

    local appExecEngineSource=
    [[ "${SSBEngineType%%|*}" = internal ]] && \
	appExecEngineSource="SSBEngineSourceInfo=$(formatarray "${SSBEngineSourceInfo[@]}")"
    filterfile "$updateEpichromeRuntime/Filter/AppExec" \
	       "$contentsTmp/Resources/script" \
	       'app executable' \
	       APPID "$(formatscalar "$SSBIdentifier")" \
	       APPDISPLAYNAME "$(formatscalar "$CFBundleDisplayName")" \
	       APPBUNDLENAME "$(formatscalar "$CFBundleName")" \
	       APPCUSTOMICON "$(formatscalar "$SSBCustomIcon")" \
	       APPCOMMANDLINE "$(formatarray "${SSBCommandLine[@]}")" \
	       APPENGINETYPE "$(formatscalar "$SSBEngineType")" \
	       APPENGINESOURCE "$appExecEngineSource"
    
    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi

    
    # COPY IN CUSTOM APP ICONS
    
    if [[ "$SSBCustomIcon" = Yes ]] ; then
	
	# MAIN ICONS
	
	local iconSourcePath="$updateAppPath/Contents/Resources"	
	safecopy "$iconSourcePath/$CFBundleIconFile" \
		 "$contentsTmp/Resources/$CFBundleIconFile" "app icon"
	safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
		 "$contentsTmp/Resources/$CFBundleTypeIconFile" "document icon"
	if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi


	# WELCOME PAGE ICON
	
	local welcomeIconBase="$appWelcomePath/img/app_icon.png"
	local welcomeIconSourcePath="$updateAppPath/Contents/$welcomeIconBase"
	local tempIconset=
	
	# check if welcome icon exists in bundle
	if [[ ! -f "$welcomeIconSourcePath" ]] ; then
	    
	    # welcome icon not found, so try to create one
	    debuglog 'Extracting icon image for welcome page.'
	    
	    # fallback to generic icon already in bundle
	    welcomeIconSourcePath=
	    
	    # create iconset from app icon
	    tempIconset="$(tempname "$contentsTmp/$appWelcomePath/img/app" ".iconset")"
	    try /usr/bin/iconutil -c iconset \
		-o "$tempIconset" \
		"$iconSourcePath/$CFBundleIconFile" \
		'Unable to convert app icon to iconset.'
	    
	    if [[ "$ok" ]] ; then
		
		# pull out the PNG closest to 128x128
		local f=
		local curMax=()
		local curSize=
		local iconRe='icon_([0-9]+)x[0-9]+(@2x)?\.png$'
		for f in "$tempIconset"/* ; do
		    if [[ "$f" =~ $iconRe ]] ; then

			# get actual size of this image
			curSize="${BASH_REMATCH[1]}"
			[[ "${BASH_REMATCH[2]}" ]] && curSize=$(($curSize * 2))

			# see if this is a better match
			if [[ (! "${curMax[0]}" ) || \
				  ( ( "${curMax[0]}" -lt 128 ) && \
					( "$curSize" -gt "${curMax[0]}" ) ) || \
				  ( ( "$curSize" -ge 128 ) && \
					( "$curSize" -lt "${curMax[0]}" ) ) ]] ; then
			    curMax=( "$curSize" "$f" )
			fi
		    fi
		done
		
		# if we found a suitable image, use it
		[[ -f "${curMax[1]}" ]] && welcomeIconSourcePath="${curMax[1]}"
		
	    else
		# fail silently, we'll just use the default
		ok=1 ; errmsg=
	    fi
	else
	    debuglog 'Found existing icon image for welcome page.'
	fi

	# copy welcome icon
	if [[ "$welcomeIconSourcePath" ]] ; then
	    safecopy "$welcomeIconSourcePath" \
		     "$contentsTmp/$welcomeIconBase" \
		     'Unable to add app icon to welcome page.'
	fi
	
	# get rid of any temp iconset we created
	[[ "$tempIconset" && -e "$tempIconset" ]] && \
	    tryalways /bin/rm -rf "$tempIconset" \
		      'Unable to remove temporary iconset.'
	
	# welcome page icon error is nonfatal, just log it
	if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi
    fi
    
        
    # FILTER NATIVE MESSAGING HOST INTO PLACE
    
    local updateNMHFile="$contentsTmp/Resources/NMH/$appNMHFile"
    filterfile "$updateEpichromeRuntime/Filter/$appNMHFile" \
	       "$updateNMHFile" \
	       'native messaging host' \
	       APPID "$(escapejson "$SSBIdentifier")" \
	       APPDISPLAYNAME "$(escapejson "$CFBundleDisplayName")" \
	       APPBUNDLENAME "$(escapejson "$CFBundleName")"
    try /bin/chmod 755 "$updateNMHFile" \
	'Unable to set permissions for native messaging host.'

    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi


    # FILTER WELCOME PAGE INTO PLACE
    
    filterfile "$updateEpichromeRuntime/Filter/$appWelcomePage" \
	       "$contentsTmp/$appWelcomePath/$appWelcomePage" \
	       'welcome page' \
	       APPBUNDLENAME "$(escapehtml "$CFBundleName")" \
	       APPDISPLAYNAME "$(escapehtml "$CFBundleDisplayName")"


    # SELECT MASTER PREFS

    # select different prefs if we're creating an app with no URL
    local nourl=
    [[ "${#SSBCommandLine[@]}" = 0 ]] && nourl='_nourl'

    # copy correct prefs file into app bundle
    local engineID="${SSBEngineType#*|}"
    safecopy "$updateEpichromeRuntime/Filter/Prefs/prefs${nourl}_${engineID//./_}.json" \
	"$contentsTmp/$appMasterPrefsPath" \
	'Unable to create app master prefs.'
    
    
    # FILTER PROFILE BOOKMARKS FILE INTO PLACE
    
    filterfile "$updateEpichromeRuntime/Filter/$appBookmarksFile" \
	       "$contentsTmp/$appBookmarksPath" \
	       'bookmarks template' \
	       APPBUNDLENAME "$(escapejson "$CFBundleName")"
    
    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi
    

    # POPULATE ENGINE
    
    # path to engine
    local updateEnginePath="$contentsTmp/Resources/Engine"
    
    # create engine directory
    try mkdir -p "$updateEnginePath" 'Unable to create app engine.'
    
    if [[ "${SSBEngineType%%|*}" != internal ]] ; then
	
	# EXTERNAL ENGINE
	
	# filter placeholder executable into place
	filterfile "$updateEpichromeRuntime/Engine/Filter/PlaceholderExec" \
		   "$updateEnginePath/PlaceholderExec" \
		   "${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder executable" \
		   APPID "$(formatscalar "$SSBIdentifier")" \
		   APPBUNDLEID "$(formatscalar "$myAppBundleID")"
	try /bin/chmod 755 "$updateEnginePath/PlaceholderExec" \
	    "Unable to set permissions for ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder executable."
	
	# copy in core script
	try /bin/mkdir -p "$updateEnginePath/Scripts" \
	    "Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder scripts."
	try /bin/cp "$updateEpichromeRuntime/Contents/Resources/Scripts/core.sh" \
	    "$updateEnginePath/Scripts" \
	    "Unable to copy core to ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder."

    else
	
	# INTERNAL ENGINE

	# CREATE PAYLOAD
	
	# copy in main payload
	try /bin/cp -PR "$updateEpichromeRuntime/Engine/Payload" \
	    "$updateEnginePath" \
	    'Unable to populate app engine payload.'

	# path to payload
	local updatePayloadPath="$updateEnginePath/Payload"
	
	# copy executable into place
	safecopy "$updateEpichromeRuntime/Engine/Exec/${SSBEngineSourceInfo[$iExecutable]}" \
	    "$updatePayloadPath/MacOS/${SSBEngineSourceInfo[$iExecutable]}" \
	    'app engine payload executable'
	
	# filter payload Info.plist into place
	filterplist "$updateEpichromeRuntime/Engine/Filter/Info.plist" \
		    "$updatePayloadPath/Info.plist" \
		    "app engine payload Info.plist" \
		    "Set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
		    "Set :CFBundleName $(escape "$CFBundleName" "\"'")" \
		    "Set :CFBundleIdentifier ${appEngineIDBase}.$SSBIdentifier"
	
	# filter localization strings in place
	filterlproj "$updatePayloadPath/Resources" 'app engine' \
		    "${SSBEngineSourceInfo[$iName]}"
	
	
	# CREATE PLACEHOLDER
	
	# path to placeholder
	local updatePlaceholderPath="$updateEnginePath/Placeholder"
	
	# make sure placeholder exists
	try /bin/mkdir -p "$updatePlaceholderPath/MacOS" \
	    'Unable to create app engine placeholder.'
	
	# filter placeholder Info.plist from payload
	filterplist "$updatePayloadPath/Info.plist" \
		    "$updatePlaceholderPath/Info.plist" \
		"app engine placeholder Info.plist" \
		'Add :LSUIElement bool true'
	
	# filter placeholder executable into place
	local updatePlaceholderExec="$updatePlaceholderPath/MacOS/${SSBEngineSourceInfo[$iExecutable]}"
	filterfile "$updateEpichromeRuntime/Engine/Filter/PlaceholderExec" \
		   "$updatePlaceholderExec" \
		   'app engine placeholder executable' \
		   APPID "$(formatscalar "$SSBIdentifier")" \
		   APPBUNDLEID "$(formatscalar "$myAppBundleID")"
	try /bin/chmod 755 "$updatePlaceholderExec" \
	    'Unable to set permissions for app engine placeholder executable.'
    fi
    
    
    # MOVE CONTENTS TO PERMANENT HOME
    
    if [[ "$ok" ]] ; then
	permanent "$contentsTmp" "$updateAppPath/Contents" "app bundle Contents directory"
    else
	# remove temp contents on error
	[[ "$contentsTmp" && -d "$contentsTmp" ]] && rmtemp "$contentsTmp" 'Contents folder'

	# return
	return 1
    fi
    
    
    # RUNNING IN APP -- UPDATE CONFIG & RELAUNCH
    
    if [[ ( "$coreContext" = 'app' ) && ( ! "$noRelaunch" ) ]] ; then
	updaterelaunch  # this will always quit
    fi


    # RUNNING IN EPICHROME -- RETURN SUCCESS
    return 0
}


# UPDATERELAUNCH -- relaunch an updated app
function updaterelaunch {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # write out config
    writeconfig "$myConfigFile" FORCE
    local myCleanupErr=
    if [[ ! "$ok" ]] ; then
	tryalways /bin/rm -f "$myConfigFile" \
		  'Unable to delete old config file.'
	myCleanupErr="Update succeeded, but unable to update settings. ($errmsg) The welcome page will not have accurate info about the update."
	ok=1 ; errmsg=
    fi
    
    # launch helper
    launchhelper Relaunch
    
    # if relaunch failed, report it
    if [[ ! "$ok" ]] ; then
	[[ "$myCleanupErr" ]] && myCleanupErr+=' Also, ' || myCleanupErr='Update succeeded, but'
	myCleanupErr+="$myCleanupErr the updated app didn't launch. ($errmsg)"
    fi
    
    # show alert with any errors
    [[ "$myCleanupErr" ]] && alert "$myCleanupErr" 'Update' '|caution'
    
    # no matter what, we quit now
    cleanexit
}
