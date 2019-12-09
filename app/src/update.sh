#!/bin/sh
#
#  update.sh: core functions for updating/or creating Epichrome apps
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

# BOOTSTRAP MY VERSION OF RUNTIME.SH

if [[ ! "$1" ]] ; then
    source "${0%/*}/../Runtime/Resources/Scripts/runtime.sh"
    if [[ "$?" != 0 ]] ; then
	ok= ; errmsg='Unable to load runtime script.'
	return
    fi
fi


# GET INFO ON MY VERSION OF EPICHROME

updateEpiInfo=
epichromeinfo 'updateEpiInfo' "$0/../../.."


# FUNCTION DEFINITIONS

# MAKEAPPICONS: wrapper for makeicon.sh
function makeappicons {  # INPUT OUTPUT-DIR app|doc|both
    if [[ "$ok" ]] ; then

	# arguments
	local inFile="$1" ; shift
	local outDir="$1" ; shift
	local iconType="$1" ; shift
	
	# find makeicon.sh
	local makeIconScript="$epiPath/Contents/Resources/Scripts/makeicon.sh"
	[[ -e "$makeIconScript" ]] || abort "Unable to locate makeicon.sh."
	
	# build command-line
	local args=
	local docargs=(-c "$epiPath/Contents/Resources/docbg.png" 256 286 512 "$inFile" "$outDir/$CFBundleTypeIconFile")
	case "$iconType" in
	    app)
		args=(-f "$inFile" "$outDir/$CFBundleIconFile")
		;;
	    doc)
		args=(-f "${docargs[@]}")
		;;
	    both)
		args=(-f -o "$outDir/$CFBundleIconFile" "${docargs[@]}")
		;;
	esac

	# run script
	try 'makeiconerr&=' "$makeIconScript" "${args[@]}" ''
	
	# parse errors
	if [[ ! "$ok" ]] ; then
	    errmsg="${makeiconerr#*Error: }"
	    errmsg="${errmsg%.*}"
	fi
    fi
}


# UPDATEAPP: function that populates an app bundle
function updateapp { # ( appPath [customIconDir epiInfoPath] )
    
    if [[ "$ok" ]] ; then
	
	# arguments
	local appPath="$1" ; shift        # path to the app bundle
	local customIconDir="$1" ; shift  # path to custom icon directory, if any
		
	if [[ "$ok" && ( ! "$SSBEngineType" ) ]] ; then
	    
	    # No engine type in config, so we're updating from an old Google Chrome app

	    # Allow the user to choose which engine to use (Chromium is the default)
	    dialog useChromium \
		   "SOME TEXT ABOUT CHROMIUM ENGINE." \
		   "Choose App Engine" \
		   "|caution" \
		   "+Yes" \
		   "-No"
	    if [[ ! "$ok" ]] ; then
		alert "CHROMIUM ENGINE TEXT but the update dialog failed. Attempting to update with Chromium engine. If this is not what you want, you must abort the app now." 'Update' 'caution'
		doUpdate="Update"
		ok=1
		errmsg=
	    fi
	    
	    if [[ "$useChromium" = No ]] ; then
		SSBEngineType="Google Chrome"
	    else
		SSBEngineType="Chromium"
	    fi
	fi
	
	if [[ "$ok" && ( "$SSBEngineType" = "Google Chrome" ) ]] ; then
	    # Google Chrome engine: make sure we've got Chrome info
	    [[ "$SSBGoogleChromePath" && "$SSBGoogleChromeVersion" ]] || googlechromeinfo
	fi
	
	
	# PERFORM UPDATE
	
	local contentsTmp=
	if [[ "$ok" ]] ; then
	    
	    # put updated bundle in temporary Contents directory
	    contentsTmp="$(tempname "$appPath/Contents")"
	    
	    # copy in the boilerplate for the app
	    try /bin/cp -a "$epiContents/Resources/Runtime" "$contentsTmp" 'Unable to populate app bundle.'
	fi
	
	if [[ "$ok" ]] ; then
	
	    # place custom icon, if any
	    
	    # check if we are copying from an old version of a custom icon
	    local remakeDocIcon=
	    if [[ ( ! "$customIconDir" ) && ( "$SSBCustomIcon" = "Yes" ) ]] ; then
		customIconDir="$appPath/Contents/Resources"
		
		# starting in 2.1.14 we can customize the document icon too
		if vcmp "$SSBVersion" '<' "2.1.14" ; then
		    remakeDocIcon=1
		fi
	    fi
	    
	    # if there's a custom app icon, copy it in
	    if [[ -e "$customIconDir/$CFBundleIconFile" ]] ; then
		# copy in custom icon
		safecopy "$customIconDir/$CFBundleIconFile" "${contentsTmp}/Resources/$CFBundleIconFile" "custom icon"
	    fi
	    
	    # either copy or remake the doc icon
	    if [[ "$remakeDocIcon" ]] ; then
		# remake doc icon now that we can customize that
		makeappicons "$epiPathXXXX" "$customIconDir/$CFBundleIconFile" "${contentsTmp}/Resources" doc
		if [[ ! "$ok" ]] ; then
		    errmsg="Unable to update doc icon ($errmsg)."
		fi
		
	    elif [[ -e "$customIconDir/$CFBundleTypeIconFile" ]] ; then
		# copy in existing custom doc icon
		safecopy "$customIconDir/$CFBundleTypeIconFile" "${contentsTmp}/Resources/$CFBundleTypeIconFile" "custom icon"
	    fi
	fi
	
	if [[ "$ok" ]] ; then
	    
	    # make sure we have a unique identifier for our app & engine
	    
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
		    while [[ 1 ]] ; do
			
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
	fi
	
	if [[ "$ok" ]] ; then
	    
	    # set profile path
	    SSBProfilePath="${appProfileBase}/Apps/$SSBIdentifier"
	    
	    # set up first-run notification
	    if [[ "$SSBVersion" ]] ; then
		SSBFirstRunSinceVersion="$SSBVersion"
	    else
		SSBFirstRunSinceVersion="0.0.0"
	    fi
	    
	    # update SSBVersion & SSBUpdateCheckVersion
	    SSBVersion="$epiVersion"  # $$$$$$ FIX THIS???
	    SSBUpdateCheckVersion="$epiVersion"
	    
	    # clear host install error state
	    SSBHostInstallError=
	fi
	

	# FILTER BOILERPLATE INFO.PLIST WITH APP INFO

	if [[ "$ok" ]] ; then
	    # set up default PlistBuddy commands
	    local filterCommands="
set :CFBundleDisplayName $CFBundleDisplayName
set :CFBundleName $CFBundleName
set :CFBundleIdentifier ${appIDBase}.$SSBIdentifier"

	    # if not registering as browser, delete URI handlers
	    if [[ "$SSBRegisterBrowser" != "Yes" ]] ; then
		filterCommands="$filterCommands
Delete :CFBundleURLTypes"
	    fi
	    
	    # filter boilerplate Info.plist with info for this app
	    filterplist "$contentsTmp/Info.plist.in" \
			"$contentsTmp/Info.plist" \
			"app Info.plist" \
			"$filterCommands"

	    # remove boilerplate input file
	    if [[ "$ok" ]] ; then
		try /bin/rm -f "$contentsTmp/Info.plist.in" \
		    'Unable to remove boilerplate Info.plist.'
	    fi
	    
	    
	    # UPDATE ENGINE PAYLOAD
	    
	    createenginepayload "$contentsTmp"
	    
	    
	    # WRITE OUT CONFIG FILE
	    
	    writeconfig "$contentsTmp" force

	    # $$$ REMOVE THIS WITH AUTH CODE
	    # set ownership of app bundle to this user (only necessary if running as admin)
	    setowner "$appPath" "$contentsTmp" "app bundle Contents directory"
	fi
	
	
	# MOVE CONTENTS TO PERMANENT HOME
	if [[ "$ok" ]] ; then
	    permanent "$contentsTmp" "$appPath/Contents" "app bundle Contents directory"
	elif [[ "$contentsTmp" && -d "$contentsTmp" ]] ; then
	    # remove temp contents on error
	    rmtemp "$contentsTmp" 'Contents folder'
	fi
    fi

    # return code
    [[ "$ok" ]] || return 1
    return 0
}
