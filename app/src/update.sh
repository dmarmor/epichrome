#!/bin/sh
#
#  update.sh: functions for updating/or creating Epichrome apps
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


# PATH TO THIS SCRIPT'S EPICHROME APP BUNDLE

updateEpichromePath="${BASH_SOURCE[0]%/Contents/Resources/Scripts/update.sh}"
updateEpichromeRuntime="$updateEpichromePath/Contents/Resources/Runtime"


# BOOTSTRAP MY VERSION OF CORE.SH

source "$updateEpichromeRuntime/Contents/Resources/Scripts/core.sh"
[[ "$?" = 0 ]] || ( echo "$myLogApp: Unable to load core script into update script." >> "$myLogFile" ; exit 1 )


# FUNCTION DEFINITIONS

# RELAUNCH -- relaunch this app ($$$ MOVE INTO UPDATEAPP???)
function relaunch { # APP-PATH
    
    # launch relaunch daemon  $$$ ADD ARGS HERE??
    try /usr/bin/open "$SSBAppPath/$appHelperPath" --args \
	RELAUNCH "$$" "$myPath" "$myLogPath" "$stderrTempFile" \
	'Update succeeded, but unable to lauch updated app. Try launching it manually.'

    # exit
    [[ "$ok" ]] || abort
    exit 0
}


# UPDATEAPP: function that populates an app bundle
function updateapp { # ( updateAppPath )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local updateAppPath="$1" ; shift  # path to the app bundle to update

    
    # LOAD FILTER.SH

    safesource "$updateEpichromeRuntime/Contents/Resources/Scripts/filter.sh"
    [[ "$ok" ]] || return 1
    
    
    # SET UNIQUE APP ID
    
    if [[ ! "$SSBIdentifier" ]] ; then
	
	# no ID found
	
	# if we're coming from an old version, try pulling from CFBundleIdentifier
	local idre="^${appIDBase//./\\.}"		    
	if [[ "$CFBundleIdentifier" && ( "$CFBundleIdentifier" =~ $idre ) ]] ; then
	    
	    # pull ID from our CFBundleIdentifier
	    SSBIdentifier="${CFBundleIdentifier##*.}"
	else
	    
	    # no CFBundleIdentifier, so create a new ID
	    
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
    local myAppID="$appIDBase.$SSBIdentifier"
    
    
    # SET APP VERSION
    
    SSBVersion="$coreVersion"
    
    
    # BEGIN POPULATING APP BUNDLE
    
    # put updated bundle in temporary Contents directory
    local contentsTmp="$(tempname "$updateAppPath/Contents")"
    
    # copy in the boilerplate for the app
    try /bin/cp -a "$updateEpichromeRuntime/Contents" "$contentsTmp" 'Unable to populate app bundle.'
    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi


    # FILTER APP INFO.PLIST INTO PLACE
    
    # set up default PlistBuddy commands
    local filterCommands=( "set :CFBundleDisplayName $CFBundleDisplayName" \
			       "set :CFBundleName $CFBundleName" \
			       "set :CFBundleIdentifier $myAppID" )
    
    # if not registering as browser, delete URI handlers
    [[ "$SSBRegisterBrowser" = "No" ]] && \
	filterCommands+=( "Delete :CFBundleURLTypes" )
    
    # filter boilerplate Info.plist with info for this app
    filterplist "$updateEpichromeRuntime/Filter/Info.plist.app" \
		"$contentsTmp/Info.plist" \
		"app Info.plist" \
		"${filterCommands[@]}"


    # FILTER APP EXECUTABLE INTO PLACE
    
    filterfile "$updateEpichromeRuntime/Filter/Epichrome" \
	       "$contentsTmp/MacOS/Epichrome" \
	       'app executable' \
	       APPID "$SSBIdentifier" \
	       APPENGINETYPE "$SSBEngineType" \
	       APPDISPLAYNAME "$CFBundleDisplayName" \
	       APPBUNDLENAME "$CFBundleName" \
	       APPCOMMANDLINE "$(formatarray "${SSBCommandLine[@]}")"
    
    
    # GET ICON SOURCE

    # determine source of icons
    local iconSourcePath=
    if [[ "$SSBCustomIcon" ]] ; then
	iconSourcePath="$updateAppPath/Contents/Resources"
    else
	iconSourcePath="$updateEpichromeRuntime/Icons"
    fi
    
    
    # COPY ICONS TO MAIN APP
    
    safecopy "$iconSourcePath/$CFBundleIconFile" \
	     "$contentsTmp/Resources/$CFBundleIconFile" "app icon"
    safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
	     "$contentsTmp/Resources/$CFBundleTypeIconFile" "document icon"
    
    
    # FILTER NATIVE MESSAGING HOST INTO PLACE

    filterfile "$updateEpichromeRuntime/Filter/$appNMHFile" \
	       "$contentsTmp/Resources/NMH/$appNMHFile" \
	       'native messaging host' \
	       APPBUNDLEID "$myAppID" \
	       APPDISPLAYNAME "$CFBundleDisplayName" \
	       APPBUNDLENAME "$CFBundleName" )

    if [[ ! "$ok" ]] ; then rmtemp "$contentsTmp" 'Contents folder' ; return 1 ; fi


    
    # for Chromium engine, copy icons to engine as well
    if [[ "$SSBEngineType" != 'Google Chrome' ]] ; then

	# copy icons to new app engine placeholder
	safecopy "$iconSourcePath/$CFBundleIconFile" \
		 "$contentsTmp/$appEnginePlaceholderPath/Resources/$CFBundleIconFile" \
		 "engine placeholder app icon"
	safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
		 "$contentsTmp/$appEnginePlaceholderPath/Resources/$CFBundleTypeIconFile" \
		 "engine placeholder document icon"
	
	# copy icons to new Chromium app engine payload
	safecopy "$iconSourcePath/$CFBundleIconFile" \
		 "$contentsTmp/$appEnginePayloadPath/Resources/$CFBundleIconFile" \
		 "engine app icon"
	safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
		 "$contentsTmp/$appEnginePayloadPath/Resources/$CFBundleTypeIconFile" \
		 "engine app icon"
    fi

    # $$$$$$$$$ FILTER EPICHROME EXECUTABLE

    # $$$$$$$$ FILTER MULTIPLE INFO.PLISTS

    # $$$$$$$$ FILTER PLACEHOLDER EXECUTABLE INTO PLACE

    # $$$$$$$$ CHROMIUM: FILTER LPROJ FILES AND CREATE ENGINE PAYLOAD
	# filter Info.plist with app info
	filterplist "$myEnginePath/Filter/Info.plist.in" \
		    "$myEnginePayloadPath/Info.plist" \
		    "app engine Info.plist" \
		    "Set :CFBundleDisplayName $CFBundleDisplayName" \
		    "Set :CFBundleName $CFBundleName" \
		    "Set :CFBundleIdentifier ${appEngineIDBase}.$SSBIdentifier" \
		    "Delete :CFBundleDocumentTypes" \
		    "Delete :CFBundleURLTypes"
	
	# filter localization strings
	filterlproj "$curPayloadContentsPath/Resources" 'app engine' Chromium
	

    
    # FILTER BOILERPLATE INFO.PLIST WITH APP INFO

    if [[ "$ok" ]] ; then

	
	# $$$ INITIALIZE SSBAppPath???

	# $$$ building host script:
	#    "s/APPBUNDLEID/$myAppID/;
        # s/APPDISPLAYNAME/$CFBundleDisplayName/;
        # s/APPBUNDLENAME/$CFBundleName/;
        # s/APPLOGPATH/${myLogFile//\//\/}/;" \

    fi
    
    
    # MOVE CONTENTS TO PERMANENT HOME

    if [[ "$ok" ]] ; then
	permanent "$contentsTmp" "$updateAppPath/Contents" "app bundle Contents directory"
    elif [[ "$contentsTmp" && -d "$contentsTmp" ]] ; then
	# remove temp contents on error
	rmtemp "$contentsTmp" 'Contents folder'
    fi

    # return code
    [[ "$ok" ]] || return 1
    return 0
}
