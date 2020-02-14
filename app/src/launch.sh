#!/bin/sh
#
#  launch.sh: utility functions for building and launching an Epichrome engine
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


# REQUIRES FILTER.SH

safesource "${BASH_SOURCE[0]%launch.sh}filter.sh"


# CONSTANTS

appEnginePathBase='EpichromeEngines.noindex'


# EPICHROME VERSION-CHECKING FUNCTIONS

# VISBETA -- if version is a beta, return 0, else return 1
function visbeta { # ( version )
    [[ "$1" =~ [bB] ]] && return 0
    return 1
}


# VCMP -- if V1 OP V2 is true, return 0, else return 1
function vcmp { # ( version1 operator version2 )

    # arguments
    local v1="$1" ; shift
    local op="$1" ; shift ; [[ "$op" ]] || op='=='
    local v2="$1" ; shift
    
    # turn operator into a numeric comparator
    case "$op" in
	'>')
	    op='-gt'
	    ;;
	'<')
	    op='-lt'
	    ;;
	'>=')
	    op='-ge'
	    ;;
	'<=')
	    op='-le'
	    ;;
	'='|'==')
	    op='-eq'
	    ;;
    esac
    
    # munge version numbers into comparable integers
    local vre='^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?$'
    local vnums=() ; local i=0
    local curv=
    for curv in "$v1" "$v2" ; do
	if [[ "$curv" =~ $vre ]] ; then

	    # munge main part of version number
	    vnums[$i]=$(( ( ${BASH_REMATCH[1]} * 1000000000 ) \
			      + ( ${BASH_REMATCH[2]} * 1000000 ) \
			      + ( ${BASH_REMATCH[3]} * 1000 ) ))
	    if [[ "${BASH_REMATCH[4]}" ]] ; then
		# beta version
		vnums[$i]=$(( ${vnums[$i]} + ${BASH_REMATCH[5]} ))
	    else
		# release version
		vnums[$i]=$(( ${vnums[$i]} + ${BASH_REMATCH[5]} + 999 ))
	    fi
	else
	    # no version
	    vnums[$i]=0
	fi
	
	i=$(( $i + 1 ))
    done
        
    # compare versions using the operator & return the result
    eval "[[ ${vnums[0]} $op ${vnums[1]} ]]"
}


# GETEPICHROMEINFO: find Epichrome instances on the system & get info on them
function getepichromeinfo {
    # populates the following globals (if found):
    #    epiCurrentPath -- path to version of Epichrome that corresponds to this app
    #    epiLatestVersion -- version of the latest Epichrome found
    #    epiLatestPath -- path to the latest Epichrome found
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # default global return values
    epiCurrentPath= ; epiLatestVersion= ; epiLatestPath=
    
    # start with preferred install locations
    local preferred=()
    [[ -d "$SSBEnginePath" ]] && preferred+=( "${SSBEnginePath%/$appEnginePathBase/*}" )
    preferred+=( ~/'Applications/Epichrome/Epichrome.app' \
		   '/Applications/Epichrome/Epichrome.app' )
    
    # use spotlight to search the system for Epichrome instances
    local spotlight=()
    try 'spotlight=(n)' /usr/bin/mdfind \
	"kMDItemCFBundleIdentifier == '${appIDRoot}.Epichrome'" \
	'error'
    if [[ ! "$ok" ]] ; then
	# ignore mdfind errors
	ok=1
	errmsg=
    fi
    
    # merge spotlight instances with preferred ones
    local instances=()
    local pref=

    # go through preferred paths
    for pref in "${preferred[@]}" ; do
	
	# check current preferred path against each spotlight path
	local i=0 ; local path= ; local found=
	for path in "${spotlight[@]}" ; do

	    # path found by spotlight
	    if [[ "$pref" = "$path" ]] ; then
		found="$i"
		break
	    fi
	    
	    i=$(($i + 1))
	done

	if [[ "$found" ]] ; then
	    
	    # remove matching path from spotlight list & add to instances
	    instances+=( "$pref" )
	    spotlight=( "${spotlight[@]::$found}" "${spotlight[@]:$(($found + 1))}" )
	    
	elif [[ -d "$pref" ]] ; then

	    # path not found by spotlight, but it exists, so check it
	    instances+=( "$pref" )
	fi
	
    done
    
    # add all remaining spotlight paths
    instances+=( "${spotlight[@]}" )
    
    # check instances of Epichrome to find the current and latest
    local curInstance= ; local curVersion=
    for curInstance in "${instances[@]}" ; do
	if [[ -d "$curInstance" ]] ; then
	    
	    # get this instance's version
	    curVersion="$( safesource "$curInstance/Contents/Resources/Scripts/version.sh" && echo "$epiVersion" )"
	    if [[ ( "$?" != 0 ) || ( ! "$curVersion" ) ]] ; then
		curVersion=0.0.0
	    fi
	    
	    if vcmp "$curVersion" '>' 0.0.0 ; then
		
		debuglog "Found Epichrome $curVersion at '$curInstance'."
		
		# see if this is newer than the current latest Epichrome
		if [[ ! "$epiLatestPath" ]] || \
		       vcmp "$epiLatestVersion" '<' "$curVersion" ; then
		    epiLatestPath="$(canonicalize "$curInstance")"
		    epiLatestVersion="$curVersion"
		fi
		
		# see if this is the first instance we've found of the current version
		if [[ ! "$epiCurrentPath" ]] && vcmp "$curVersion" '==' "$SSBVersion" ; then
		    epiCurrentPath="$(canonicalize "$curInstance")"
		fi
		
	    else
		
		# failed to get version, so assume this isn't really a version of Epichrome
		debuglog "Epichrome at '$curInstance' is either older than this app or damaged."
	    fi
	fi
    done
    
    # log versions found
    if [[ "$debug" ]] ; then
	[[ "$epiCurrentPath" ]] && \
	    errlog "Current version of Epichrome ($SSBVersion) found at '$epiCurrentPath'"
	[[ "$epiLatestPath" && ( "$epiLatestPath" != "$epiCurrentPath" ) ]] && \
	    errlog "Latest version of Epichrome ($epiLatestVersion) found at '$epiLatestPath'"
    fi
    
    # return code based on what we found
    if [[ "$epiCurrentPath" && "$epiLatestPath" ]] ; then
	return 0
    elif [[ "$epiLatestPath" ]] ; then
	return 2
    else
	return 1
    fi	
}


# CHECKGITHUBVERSION: function that checks for a new version of Epichrome on GitHub
function checkgithubversion { # ( curVersion )

    [[ "$ok" ]] || return 1
    
    # set current version to compare against
    local curVersion="$1" ; shift

    # regex for pulling out version
    local versionRe='"tag_name": +"v([0-9.bB]+)",'
    
    # check github for the latest version
    local latestVersion=
    latestVersion="$(/usr/bin/curl --connect-timeout 3 --max-time 5 'https://api.github.com/repos/dmarmor/epichrome/releases/latest' 2> /dev/null)"
    
    if [[ "$?" != 0 ]] ; then
	
	# curl returned an error
	ok=
	errmsg="Error retrieving data."
	
    elif [[ "$latestVersion" =~ $versionRe ]] ; then

	# extract version number from regex
	latestVersion="${BASH_REMATCH[1]}"
	
	# compare versions
	if vcmp "$curVersion" '<' "$latestVersion" ; then
	    
	    # output new available version number & download URL
	    echo "$latestVersion"
	    echo 'https://github.com/dmarmor/epichrome/releases/latest'
	else
	    debuglog "Latest Epichrome version on GitHub ($latestVersion) is not newer than $curVersion."
	fi
    else

	# no version found
	ok=
	errmsg='No version information found.'
    fi
    
    # return value tells us if we had any errors
    [[ "$ok" ]] && return 0 || return 1
}


# CHECKAPPUPDATE -- check for a new version of Epichrome and offer to update app
function checkappupdate {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # if no Epichrome on the system, we're done
    [[ "$epiLatestVersion" ]] || return 0
    
    # assume success
    local result=0

    # compare versions and possibly offer update
    if vcmp "$SSBUpdateVersion" '<' "$epiLatestVersion" ; then

	# by default, don't update
	local doUpdate=Later

	# set dialog info
	local updateMsg="A new version of Epichrome was found ($epiLatestVersion). Would you like to update this app?"
	local updateBtnUpdate='Update'
	local updateBtnLater='Later'
	local updateButtonList=( )

	# update dialog info if the new version is beta
	if visbeta "$epiLatestVersion" ; then
	    updateMsg="$updateMsg

IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myDataPath) before updating."
	    updateButtonList=( "+$updateBtnLater" "$updateBtnUpdate" )
	else
	    updateButtonList=( "+$updateBtnUpdate" "-$updateBtnLater" )
	fi
	
	# if the Epichrome version corresponding to this app's version is not found, and
	# the app uses the Chromium engine, don't allow the user to ignore this version
	if [[ "$epiCurrentPath" || ( "$SSBEngineType" != 'Chromium' ) ]] ; then
	    updateButtonList+=( "Don't Ask Again For This Version" )
	fi
	
	# display update dialog
	dialog doUpdate \
	       "$updateMsg" \
	       "Update" \
	       "|caution" \
	       "${updateButtonList[@]}"
	if [[ ! "$ok" ]] ; then
	    alert "A new version of the Epichrome runtime was found ($epiLatestVersion) but the update dialog failed. Attempting to update now." 'Update' '|caution'
	    doUpdate="Update"
	    ok=1
	    errmsg=
	fi
	
	# act based on dialog
	case "$doUpdate" in
	    Update)
		
		# read in the new runtime
		safesource "${epiLatestPath}/Contents/Resources/Scripts/update.sh" \
			   "update script $epiLatestVersion"
		
		# use new runtime to update the app
		updateapp "$SSBAppPath"
		
		if [[ "$ok" ]] ; then

		    # UPDATE CONFIG & RELAUNCH
		    
		    # write out config
		    writeconfig "$myConfigFile"
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
		    
		    # UPDATE FAILED -- reload my runtime
		    
		    # temporarily turn OK back on & reload old runtime
		    oldErrmsg="$errmsg" ; errmsg=
		    oldOK="$ok" ; ok=1
		    safesource "$SSBAppPath/Contents/Resources/Scripts/core.sh" "core script $SSBVersion"
		    if [[ "$ok" ]] ; then

			# fatal error
			errmsg="Update failed and unable to reload current app. ($errmsg)"
			return 1
		    fi
		    
		    # restore OK state
		    ok="$oldOK"
		    
		    # update error messages
		    if [[ "$oldErrmsg" && "$errmsg" ]] ; then
			errmsg="$oldErrmsg $errmsg"
		    elif [[ "$oldErrmsg" ]] ; then
			errmsg="$oldErrmsg"
		    fi
		    
		    # alert the user to any error, but don't throw an exception
		    ok=1
		    [[ "$errmsg" ]] && errmsg="Unable to complete update. ($errmsg)"
		    result=1
		fi
		;;
	    
	    Later)
		# don't update
		doUpdate=
		;;

	    *)
		# pretend we're already at the new version
		SSBUpdateVersion="$epiLatestVersion"
		;;
	esac
    fi

    return "$result"
}


# CHECK FOR A NEW VERSION OF EPICHROME ON GITHUB

# CHECKGITHUBUPDATE -- check if there's a new version of Epichrome on GitHub and offer to download
function checkgithubupdate {

    # only run if we're OK
    [[ "$ok" ]] || return 1

    # get current date
    try 'curDate=' /bin/date '+%s' 'Unable to get date for Epichrome update check.'
    [[ "$ok" ]] || return 1
    
    # check for updates if we've never run a check, or if the next check date is in the past
    if [[ ( ! "$SSBUpdateCheckDate" ) || ( "$SSBUpdateCheckDate" -lt "$curDate" ) ]] ; then
	
	# set next update for 7 days from now
	SSBUpdateCheckDate=$(($curDate + (7 * 24 * 60 * 60)))
	
	# make sure the version to check against is at least the latest on the system
	vcmp "$SSBUpdateCheckVersion" '>=' "$epiLatestVersion" || \
	    SSBUpdateCheckVersion="$epiLatestVersion"
	
	# check if there's a new version on Github
	try 'updateResult=(n)' checkgithubversion "$SSBUpdateCheckVersion" ''
	[[ "$ok" ]] || return 1
	
	# if there's an update available, display a dialog
	if [[ "${updateResult[*]}" ]] ; then
	    
	    # display dialog
	    dialog doEpichromeUpdate \
		   "A new version of Epichrome (${updateResult[0]}) is available on GitHub." \
		   "Update Available" \
		   "|caution" \
		   "+Download" \
		   "-Later" \
		   "Ignore This Version"
	    [[ "$ok" ]] || return 1
	    
	    # act based on dialog
	    case "$doEpichromeUpdate" in
		Download)
		    # open the update URL
		    try /usr/bin/open "${updateResult[1]}" 'Unable to open update URL.'
		    [[ "$ok" ]] || return 1
		    ;;
		
		Later)
		    # do nothing
		    doEpichromeUpdate=
		    ;;
		*)
		    # pretend we're already at the new version
		    SSBUpdateCheckVersion="${updateResult[0]}"
		    ;;
	    esac
	fi
    fi
    
    return 0
}


# CANONICALIZE -- canonicalize a path
function canonicalize { # ( path )
    local rp=
    local result=$(unset CDPATH && try '!12' cd "$1" '' && try 'rp=' pwd -P '' && echo "$rp")
    [[ "$result" ]] && echo "$result" || echo "$1"
}


# ISSAMEDEVICE -- check that two paths are on the same device
function issamedevice { # ( path1 path2 )
    
    # arguments
    local path1="$1" ; shift
    local path2="$1" ; shift

    # get path devices
    local device1=
    local device2=
    try 'device1=' /usr/bin/stat -f '%d' "$path1" ''
    try 'device2=' /usr/bin/stat -f '%d' "$path2" ''

    # unable to get one or both devices
    if [[ ! "$ok" ]] ; then
	ok=1 ; errmsg=
	return 1
    fi

    # compare devices
    [[ "$device1" = "$device2" ]] && return 0 || return 1
}


# LINKTREE: hard link to a directory or file
function linktree { # ( sourceDir destDir sourceErrID destErrID items ... )

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local sourceDir="$1"   ; shift
    local destDir="$1"     ; shift
    local sourceErrID="$1" ; shift
    local destErrID="$1"   ; shift
    local items=( "$@" )
    
    # pushd to source directory
    try '!1' pushd "$sourceDir" "Unable to navigate to $sourceErrID"
    [[ "$ok" ]] || return 1
    
    # if no items passed, link all items in source directory
    local shoptState=
    shoptset shoptState nullglob
    [[ "${items[*]}" ]] || items=( * )
    shoptrestore shoptState
    
    # loop through items creating hard links
    for curFile in "${items[@]}" ; do	
	try /bin/pax -rwlpp "$curFile" "$destDir" \
	    "Unable to link $sourceErrID $curFile to $destErrID."
    done
    
    # popd back from source directory
    try '!1' popd "Unable to navigate away from $sourceErrID."
}


# GETGOOGLECHROMEINFO: find Google Chrome on the system & get info on it
#                      sets the following variables:
#                         SSBGoogleChromePath, SSBGoogleChromeVersion
#                         googleChromeExecutable, googleChromeAppIconPath, googleChromeDocIconPath
function getgooglechromeinfo { # ( [myGoogleChromePath] )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # argument
    local myGoogleChromePath="$1" ; shift
    
    # set up list of search locations/methods
    local searchList=()
    if [[ "$myGoogleChromePath" ]] ; then

	# if we were passed a specific path, only check that
	searchList=( "$myGoogleChromePath" FAIL )
    else
	# otherwise, search known locations & spotlight
	searchList=( "$HOME/Applications/Google Chrome.app" \
			 '/Applications/Google Chrome.app' \
			 SPOTLIGHT FAIL )
    fi
    
    # try various methods to find & validate Chrome
    SSBGoogleChromePath=
    for curPath in "${searchList[@]}" ; do
	
	[[ "$SSBGoogleChromePath" ]] && debuglog "Google Chrome not found at '$SSBGoogleChromePath'."
	
	# assume failure
	SSBGoogleChromePath=
	SSBGoogleChromeVersion=
	googleChromeAppIconPath=
	googleChromeDocIconPath=
	
	if [[ "$curPath" = FAIL ]] ; then

	    # failure
	    debuglog 'Google Chrome not found.'
	    break
	    
	elif [[ "$curPath" = SPOTLIGHT ]] ; then
		
	    # search spotlight
	    try 'SSBGoogleChromePath=()' /usr/bin/mdfind "kMDItemCFBundleIdentifier == '$googleChromeID'" ''
	    if [[ "$ok" ]] ; then
		# use the first instance
		SSBGoogleChromePath="${SSBGoogleChromePath[0]}"
	    else
		SSBGoogleChromePath=
		ok=1 ; errmsg=
	    fi
	else
	    
	    # regular path, so check it
	    if [[ -d "$curPath" ]] ; then
		SSBGoogleChromePath="$curPath"
	    fi
	fi
	    
	# if nothing found, try next
	[[ "$SSBGoogleChromePath" ]] || continue
	
	# validate any found path
	
	# check that Info.plist exists
	[[ -e "$SSBGoogleChromePath/Contents/Info.plist" ]] || continue
	
	# parse Info.plist
	local infoPlist=()
	try 'infoPlist=(n)' /usr/libexec/PlistBuddy \
	    -c 'Print CFBundleIdentifier' \
	    -c 'Print CFBundleExecutable' \
	    -c 'Print CFBundleShortVersionString' \
	    -c 'Print CFBundleIconFile' \
	    -c 'Print CFBundleDocumentTypes:0:CFBundleTypeIconFile' \
	    "$SSBGoogleChromePath/Contents/Info.plist" ''
	if [[ ! "$ok" ]] ; then
	    ok=1 ; errmsg=
	    continue
	fi
	
	# check bundle ID
	[[ "${infoPlist[0]}" = "$googleChromeID" ]] || continue
	
	# make sure the executable is in place
	local curExecPath="$SSBGoogleChromePath/Contents/MacOS/${infoPlist[1]}"
	[[ -f "$curExecPath" && -x "$curExecPath" ]] || continue
	
	# if we got here, we have a complete copy of Chrome, so set globals & break out
	googleChromeExecutable="${infoPlist[1]}"
	SSBGoogleChromeVersion="${infoPlist[2]}"
	googleChromeAppIconPath="${infoPlist[3]}"
	googleChromeDocIconPath="${infoPlist[4]}"

	debuglog "Google Chrome $SSBGoogleChromeVersion found at '$SSBGoogleChromePath'."

	break	
    done
}


# POPULATEDATADIR -- make sure an app's data directory is populated
function populatedatadir { # ( [FORCE] )
    #  returns:
    #    0 on success
    #    1 on fatal error
    #    2 on error installing extension
    #    3 on error installing native messaging host
    
    [[ "$ok" ]] || return 1

    local result=0
    
    # collect all error messages
    local myErrMsg=
    
    # force an update?
    local force="$1" ; shift
    
    
    # SET UP PROFILE DIRECTORY

    # path to First Run file
    local firstRunFile="$myProfilePath/First Run"
    
    # make sure directory exists and is minimally populated
    if [[ ! -e "$firstRunFile" ]] ; then
	
	# ensure data & profile directories exists
	try /bin/mkdir -p "$myProfilePath" 'Unable to create app engine profile folder.'
	
	if [[ "$ok" ]] ; then
	    
	    # $$$ GET RID OF THIS AND USE MASTER PREFS??
	    
	    # set First Run file so Chrome/Chromium doesn't think it's a new profile (fail silently)
	    try /usr/bin/touch "$myProfilePath/First Run" 'Unable to create first run marker.'
	    
	    # non-fatal
	    if [[ ! "$ok" ]] ; then
		errlog "$errmsg"
		ok=1 ; errmsg=
	    fi
	fi
    fi
    
    # if we couldn't create the directory, that's a fatal error
    [[ "$ok" ]] || return 1


    # MOVE EXTENSION-INSTALLATION SCRIPT INTO PLACE ONLY ON FORCE
    
    if [[ "$force" ]] ; then

	# $$$ temporary -- remove old engine directory
	debuglog "Removing old engine directory."
	try /bin/rm -rf "$myDataPath/Engine.noindex" \
	    'Unable to remove old engine directory'
	if [[ ! "$ok" ]] ; then
	    errlog "$errmsg"
	    ok=1 ; errmsg=
	fi
	
	debuglog "Forcing data directory update. Installing external extensions."

	# set up useful variables
	local extDir="External Extensions"
	
	# if we need to copy the extension install directory, do it now
	safecopy "$SSBAppPath/Contents/Resources/$extDir" "$myProfilePath/$extDir" \
		 'installation directory'
	
	# clear ok state, but keep error message
	if [[ ! "$ok" ]] ; then
	    myErrMsg="$errmsg"
	    ok=1 ; errmsg=

	    # flag error installing extension
	    result=2
	fi
    fi
    
    # INSTALL OR UPDATE NATIVE MESSAGING HOST

    # we need to do this if we're updating everything, or if the app has moved
    if [[ "$force" || ( "$SSBAppPath" != "$configSSBAppPath" ) ]] ; then

        debuglog "Updating native messaging host manifests."
	
	# set up NMH file paths
	local hostSourcePath="$SSBAppPath/Contents/Resources/NMH"
	
	local hostScriptPath="$hostSourcePath/$appNMHFile"

	local hostManifestNewID="org.epichrome.runtime"
	local hostManifestNewFile="$hostManifestNewID.json"
	local hostManifestOldID="org.epichrome.helper"
	local hostManifestOldFile="$hostManifestOldID.json"
	local hostManifestDestPath="$myProfilePath/NativeMessagingHosts"
	
	# create the install directory if necessary
	if [[ ! -d "$hostManifestDestPath" ]] ; then
	    try /bin/mkdir -p "$hostManifestDestPath" \
		'Unable to create native messaging host folder.'
	fi
	
	# paths to destination for host manifests with new and old IDs
	local hostManifestNewDest="$hostManifestDestPath/$hostManifestNewFile"
	local hostManifestOldDest="$hostManifestDestPath/$hostManifestOldFile"
	
	# stream-edit the new manifest into place  $$$$ ESCAPE DOUBLE QUOTES IN PATH??
	if [[ "$force" || ! -e "$hostManifestNewDest" ]] ; then
	    filterfile "$hostSourcePath/$hostManifestNewFile" "$hostManifestNewDest" \
		       'native messaging host manifest' \
		       APPHOSTPATH "$hostScriptPath"
	fi
	
	# duplicate the new manifest with the old ID
	if [[ "$force" || ! -e "$hostManifestOldDest" ]] ; then
	    filterfile "$hostManifestNewDest" "$hostManifestOldDest" \
		       'old native messaging host manifest' \
		       "$hostManifestNewID" "$hostManifestOldID"
	fi
    fi
    
    # flag error installing native messaging host
    [[ "$ok" ]] || result=3
    
    
    # HANDLE ERROR MESSAGING AND RETURN CODE
    
    if [[ "$result" != 0 ]] ; then
		
	# pass along error messages but clear error state
	if [[ "$myErrMsg" ]] ; then
	    errmsg="$myErrMsg Also: $errmsg"
	else
	    errmsg="$errmsg"
	fi
	
	ok=1
    fi
    
    return "$result"
}


# LINKTONMH -- link to Google Chrome and Chromium native message hosts
function linktonmh {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # turn on nullglob
    local shoptState=
    shoptset shoptState nullglob
    
    # name for profile NMH folder
    local nmhDir=NativeMessagingHosts
    
    # get paths to source and destination NMH manifest directories
    local googleChromeHostDir="${HOME}/Library/Application Support/Google/Chrome/$nmhDir"
    local chromiumHostDir="${HOME}/Library/Application Support/Chromium/$nmhDir"
    local myHostDir="$myProfilePath/$nmhDir"
    
    # favor hosts from whichever browser our engine is using
    if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	hostDirs=( "$chromiumHostDir" "$googleChromeHostDir" )
    else
	hostDirs=( "$googleChromeHostDir" "$chromiumHostDir" )
    fi
    
    # navigate to our host directory
    try '!1' pushd "$myHostDir" "Unable to navigate to '$myHostDir'."
    
    # get list of host files currently installed
    hostFiles=( * )

    # remove dead host links
    local curFile=
    for curFile in "${hostFiles[@]}" ; do
	if [[ -L "$curFile" && ! -e "$curFile" ]] ; then
	    try rm -f "$curFile" "Unable to remove dead link to $curFile."
	fi
    done
    
    # link to hosts from both directories
    local curHostDir=
    for curHostDir in "${hostDirs[@]}" ; do

	if [[ -d "$curHostDir" ]] ; then

	    # get a list of all hosts in this directory
	    try '!1' pushd "$curHostDir" "Unable to navigate to ${curHostDir}"
	    hostFiles=( * )
	    try '!1' popd "Unable to navigate away from ${curHostDir}"

	    # link to any hosts that are not already in our directory
	    # or are links to a different file -- this way if a given
	    # host is in both the Chrome & Chromium directories, whichever
	    # we hit second will win
	    for curFile in "${hostFiles[@]}" ; do
		if [[ ( ! -e "$curFile" ) || \
			  ( -L "$curFile" && \
				! "$curFile" -ef "${curHostDir}/$curFile" ) ]] ; then
		    try ln -sf "${curHostDir}/$curFile" "$curFile" \
			"Unable to link to native messaging host ${curFile}."
		    
		    # abort on error
		    [[ "$ok" ]] || break
		fi
	    done
	    
	    # abort on error
	    [[ "$ok" ]] || break
	fi
    done
    
    # silently return to original directory
    try '!1' popd "Unable to navigate away from '$myHostDir'."
    
    # restore nullglob
    shoptrestore shoptState
    
    # return success or failure
    [[ "$ok" ]] && return 0 || return 1
}


# CHECKENGINE -- check if the app engine is in a good state, active or not
function checkengine {  # ( ON|OFF )
    # return codes:
    #   0 = engine is in expected state and in good condition
    #   1 = engine is in opposite state but in good condition
    #   2 = engine is not in good condition

    # arguments
    local expectedState="$1" ; shift
    
    # myEngineAppPath

    local curState= ; local inactivePath=
    if [[ -d "$myEnginePayloadPath" && ! -d "$myEnginePlaceholderPath" ]] ; then

	# engine is inactive
	debuglog "Engine is inactive."
	curState=OFF
	inactivePath="$myEnginePayloadPath"
	
    elif [[ -d "$myEnginePlaceholderPath" && ! -d "$myEnginePayloadPath" ]] ; then

	# engine is active
	debuglog "Engine is active."
	curState=ON
	inactivePath="$myEnginePlaceholderPath"
	
    else

	# engine is not in either state
	debuglog "Engine is in an unknown state."
	return 2
    fi

    # engine is in a known state, so make sure both app bundles are complete
    if [[ -x "$inactivePath/MacOS/$SSBEngineType" && \
	      -f "$inactivePath/Info.plist" && \
	      -x "$myEngineAppPath/Contents/MacOS/$SSBEngineType" && \
	      -f "$myEngineAppPath/Contents/Info.plist" ]] ; then
		
	# return code depending if we match our expected state
	[[ "$curState" = "$expectedState" ]] && return 0 || return 1
	
    else

	# either or both app states are damaged
	debuglog 'Engine is damaged.'
	return 2
    fi
    
} ; export -f checkengine


# SETENGINESTATE -- set the engine to the active or inactive state
function setenginestate {  # ( ON|OFF )
    
    # only operate if we're OK
    [[ "$ok" ]] || return 1

    # argument
    local newState="$1" ; shift
    
    # assume we're in the opposite state we're setting to
    local oldInactivePath= ; local newInactivePath=
    local oldInactiveError= ; local newInactiveError=
    if [[ "$newState" = ON ]] ; then
	oldInactivePath="$myEnginePayloadPath"
	oldInactiveError="payload"
	newInactivePath="$myEnginePlaceholderPath"
	newInactiveError="placeholder"
    else
	oldInactivePath="$myEnginePlaceholderPath"
	oldInactiveError="placeholder"
	newInactivePath="$myEnginePayloadPath"
	newInactiveError="payload"
    fi

    # engine app contents
    local myEngineAppContents="$myEngineAppPath/Contents"
    
    # move the old contents out
    if [[ -d "$newInactivePath" ]] ; then
	ok= ; errmsg="${newInactivePath##*/} already deactivated."
    fi
    try /bin/mv "$myEngineAppContents" "$newInactivePath" \
	"Unable to deactivate $newInactiveError."

    # move the new contents in
    if [[ -d "$myEngineAppContents" ]] ; then
	ok= ; errmsg="Unable to empty engine app."
    fi
    try /bin/mv "$oldInactivePath" "$myEngineAppContents" \
	"Unable to activate $oldInactiveError."
    
    # abort here on failure
    [[ "$ok" ]] || return 1
    
    # sometimes it takes a moment for the move to register
    if [[ ! -x "$myEngineAppContents/MacOS/$SSBEngineType" ]] ; then
	ok= ; errmsg="Engine $oldInactiveError executable not found."
	local attempt=
	for attempt in 0 1 2 3 4 5 6 7 8 9 ; do
	    if [[ -x "$myEngineAppContents/MacOS/$SSBEngineType" ]] ; then
		ok=1 ; errmsg=
		break
	    fi
	    errlog "Waiting for engine $oldInactiveError executable to appear..."
	    sleep .5
	done
	[[ "$ok" ]] || return 1
    fi
    
    [[ "$debug" ]] && ( de= ; [[ "$newState" != ON ]] && de=de ; errlog "Engine ${de}activated." )
    
} ; export -f setenginestate


# CREATEENGINE -- create Epichrome engine (payload & placeholder)
function createengine {

    # only run if we're OK
    [[ "$ok" ]] || return 1

    
    # CLEAR OUT ANY OLD ENGINE
    
    if [[ -d "$SSBEnginePath" ]] ; then
	try /bin/rm -rf "$SSBEnginePath" 'Unable to clear old engine.'
    fi
    
    
    # CREATE NEW ENGINE
    
    try /bin/mkdir -p "$SSBEnginePath" 'Unable to create new engine.'
    [[ "$ok" ]] || return 1
    
    if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	
	# GOOGLE CHROME PAYLOAD
	
	# make sure we have a source for the payload
	if [[ ! -d "$SSBGoogleChromePath" ]] ; then
	    
	    # we should already have this, so as a last ditch, ask the user to locate it
	    local myGoogleChromePath=
	    try 'myGoogleChromePath=' osascript -e \
		'return POSIX path of (choose application with title "Locate Google Chrome" with prompt "Please locate Google Chrome" as alias)' 'Locate Google Chrome dialog failed.'
	    myGoogleChromePath="${myGoogleChromePath%/}"
	    
	    if [[ ! "$ok" ]] ; then
		
		# we've failed to find Chrome
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find Google Chrome.$errmsg"
		return 1
	    fi
	    
	    # user selected a path, so check it
	    getgooglechromeinfo "$myGoogleChromePath"
	    
	    if [[ ! "$SSBGoogleChromePath" ]] ; then
		ok= ; errmsg="Selected app is not a valid instance of Google Chrome."
		return 1
	    fi
	    
	    # warn if we're not using the selected app
	    if [[ "$SSBGoogleChromePath" != "$myGoogleChromePath" ]] ; then
		alert "Selected app is not a valid instance of Google Chrome. Using '$SSBGoogleChromePath' instead." \
		      'Warning' '|caution'
	    fi
	fi
	
	# make sure Google Chrome is on the same volume as the engine
	if ! issamedevice "$SSBGoogleChromePath" "$SSBEnginePath" ; then
	    ok= ; errmsg="Google Chrome is not on the same volume as this app's data directory."
	    return 1
	fi
	
	# create Payload directory
	try /bin/mkdir -p "$myEnginePayloadPath/Resources" \
	    'Unable to create Google Chrome app engine payload.'
	
	# turn on extended glob for copying
	local shoptState=
	shoptset shoptState extglob
	
	# copy all of Google Chrome except Framework and Resources
	# (note that hard linking executblle causes confusion between apps & real Chrome)
	local allExcept='!(Frameworks|Resources)'
	try /bin/cp -PR "$SSBGoogleChromePath/Contents/"$allExcept "$myEnginePayloadPath" \
	    'Unable to copy Google Chrome app engine payload.'
	
	# copy Resources, except icons
	allExcept='!(*.icns)'
	try /bin/cp -PR "$SSBGoogleChromePath/Contents/Resources/"$allExcept "$myEnginePayloadPath/Resources" \
	    'Unable to copy Google Chrome app engine resources to payload.'
	
	# restore extended glob
	shoptrestore shoptState
	
	# hard link to Google Chrome Frameworks
	linktree "$SSBGoogleChromePath/Contents" "$myEnginePayloadPath" \
		 'Google Chrome app engine' 'payload' 'Frameworks'
	
	# filter localization files
	filterlproj "$myEnginePayloadPath/Resources" 'Google Chrome app engine'
	
	# link to this app's icons
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
	    "$myEnginePayloadPath/Resources/$googleChromeAppIconPath" \
	    "Unable to copy app icon to Google Chrome app engine."
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
	    "$myEnginePayloadPath/Resources/$googleChromeDocIconPath" \
	    "Unable to copy document icon file to Google Chrome app engine."


	# GOOGLE CHROME PLACEHOLDER
	
	# clear out any old active app
	if [[ -d "$myEngineAppPath" ]] ; then
	    try /bin/rm -rf "$myEngineAppPath" \
		'Unable to clear old Google Chrome app engine placeholder.'
	    [[ "$ok" ]] || return 1
	fi
	
	# create active placeholder app bundle
	try /bin/mkdir -p "$myEngineAppPath/Contents/MacOS" \
	    'Unable to create Google Chrome app engine placeholder.'
	
	# filter Info.plist from payload
	filterplist "$myEnginePayloadPath/Info.plist" \
		    "$myEngineAppPath/Contents/Info.plist" \
		    "Google Chrome app engine placeholder Info.plist" \
		    'Add :LSUIElement bool true' \
		    "Set :CFBundleShortVersionString $SSBVersion" \
		    'Delete :CFBundleDocumentTypes' \
		    'Delete :CFBundleURLTypes'

	# path to placeholder resources in the app
	local myAppPlaceholderPath="$SSBAppPath/Contents/$appEnginePath"
	
	# copy in placeholder executable
	try /bin/cp "$myAppPlaceholderPath/PlaceholderExec" \
	    "$myEngineAppPath/Contents/MacOS/$googleChromeExecutable" \
	    'Unable to copy Google Chrome app engine placeholder executable.'
	
	# copy Resources directory from payload
	try /bin/cp -PR "$myEnginePayloadPath/Resources" "$myEngineAppPath/Contents" \
	    'Unable to copy resources from Google Chrome app engine payload to placeholder.'
	
	# copy in scripts
	try /bin/cp -PR "$myAppPlaceholderPath/Scripts" \
	    "$myEngineAppPath/Contents/Resources" \
	    'Unable to copy scripts to Google Chrome app engine placeholder.'

    else
	
	# CHROMIUM PAYLOAD

	# make sure we have the current version of Epichrome
	if [[ ! -d "$epiCurrentPath" ]] ; then
	    ok=
	    errmsg="Unable to find this app's version of Epichrome ($SSBVersion)."
	    if vcmp "$epiLatestVersion" '>' "$SSBVersion" ; then
		errmsg+=" The app can't be run until it's reinstalled or the app is updated."
	    else
		errmsg+=" It must be reinstalled before the app can run."
	    fi
	    return 1
	fi
	
	# make sure Epichrome is on the same volume as the engine
	if ! issamedevice "$epiCurrentPath" "$SSBEnginePath" ; then
	    ok= ; errmsg="Epichrome is not on the same volume as this app's data directory."
	    return 1
	fi
	
	# copy main payload from app
	try /bin/cp -PR "$SSBAppPath/Contents/$appEnginePayloadPath" \
	    "$myEnginePayloadPath" \
	    'Unable to copy app engine payload.'
	
	# copy icons to payload  $$$ MOVED FROM UPDATE
	safecopy "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
		 "$myEnginePayloadPath/Resources/$CFBundleIconFile" \
		 "engine app icon"
	safecopy "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
		 "$myEnginePayloadPath/Resources/$CFBundleTypeIconFile" \
		 "engine document icon"
	
	# hard link large payload items from Epichrome
	linktree "$epiCurrentPath/Contents/Resources/Runtime/Engine/Link" \
		 "$myEnginePayloadPath" 'app engine' 'payload'


	# CHROMIUM PLACEHOLDER
	
	# clear out any old active app
	if [[ -d "$myEngineAppPath" ]] ; then
	    try /bin/rm -rf "$myEngineAppPath" \
		'Unable to clear old app engine placeholder.'
	    [[ "$ok" ]] || return 1
	fi
	
	# create active placeholder app bundle
	try /bin/mkdir -p "$myEngineAppPath" \
	    'Unable to create app engine placeholder.'
	
	# copy in app placeholder
	try /bin/cp -PR "$SSBAppPath/Contents/$appEnginePlaceholderPath" \
	    "$myEngineAppPath/Contents" \
	    'Unable to populate app engine placeholder.'

	# copy Resources directory from payload  $$$$ MOVED FROM UPDATE
	try /bin/cp -PR "$myEnginePayloadPath/Resources" "$myEngineAppPath/Contents" \
	    'Unable to copy resources from app engine payload to placeholder.'
	
	# copy in core script
	try /bin/mkdir -p "$myEngineAppPath/Contents/Resources/Scripts" \
	    'Unable to create app engine placeholder scripts.'
	try /bin/cp "$SSBAppPath/Contents/Resources/Scripts/core.sh" \
	    "$myEngineAppPath/Contents/Resources/Scripts" \
	    'Unable to copy core to placeholder.'
    fi
    
    # return code
    [[ "$ok" ]] && return 0 || return 1
}


# GETENGINEINFO: get the PID and canonical path of the running engine
myEnginePID= ; myEngineCanonicalPath= ; export myEnginePID myEngineCanonicalPath
function getengineinfo { # path

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # assume no PID
    myEnginePID=
    
    # args (canonicalize path)
    local path="$(canonicalize "$1")" ; shift
    if [[ ! -d "$path" ]] ; then
	errmsg="Unable to get canonical engine path for '$1'."
	return 1
    fi
    
    # get ASN associated with the engine's bundle path
    local asn=
    try 'asn=' /usr/bin/lsappinfo find "bundlepath=$path" \
	'Error while attempting to find running engine.'
    
    # search for PID
    if [[ "$ok" ]] ; then
	
	local info=
	
	# get PID for the ASN (we use try for the debugging output)
	try 'info=' /usr/bin/lsappinfo info -only pid "$asn" ''
	ok=1 ; errmsg=
	
	# if this ASN matches our bundle, grab the PID
	re='^"pid" *= *([0-9]+)$'
	if [[ "$info" =~ $re ]] ; then
	    myEnginePID="${BASH_REMATCH[1]}"
	    myEngineCanonicalPath="$path"
	fi
    fi
    
    # return result
    if [[ "$myEnginePID" ]] ; then
	ok=1 ; errmsg=
	debuglog "Found running engine '$myEngineCanonicalPath' with PID $myEnginePID."
	return 0
    elif [[ "$ok" ]] ; then
	debuglog "No running engine found."
	return 0
    else
	# errors in this function are nonfatal; just return the error message
	errlog "$errmsg"
	ok=1
	return 1
    fi
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # ( myConfigFile force
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local myConfigFile="$1" ; shift
    local force="$1"        ; shift
    
    # determine if we need to write the config file

    # we're being told to write no matter what
    local doWrite="$force"
    
    # not being forced, so compare all config variables for changes
    if [[ ! "$doWrite" ]] ; then
	local varname=
	local configname=
	for varname in "${appConfigVars[@]}" ; do
	    configname="config${varname}"
	    
	    isarray "$varname"
	    local varisarray="$?"
	    
	    # if variables are not the same type
	    isarray "$configname"
	    if [[ "$varisarray" != "$?" ]] ; then
		doWrite=1
		break
	    fi
	    
	    if [[ "$varisarray" = 0 ]] ; then
		
		# variables are arrays, so compare part by part
		
		# check for the same length
		local varlength="$(eval "echo \${#$varname[@]}")"
		if [[ "$varlength" \
			  -ne "$(eval "echo \${#$configname[@]}")" ]] ; then
		    doWrite=1
		    break
		fi
		
		# compare each element in both arrays
		local i=0
		while [[ "$i" -lt "$varlength" ]] ; do
		    if [[ "$(eval "echo \${$varname[$i]}")" \
			      != "$(eval "echo \${$configname[$i]}")" ]] ; then
			doWrite=1
			break
		    fi
		    i=$(($i + 1))
		done
		
		# if we had a mismatch, break out of the outer loop
		[[ "$doWrite" ]] && break
	    else
		
		# variables are scalar, simple compare
		if [[ "$(eval "echo \${$varname}")" \
			  != "$(eval "echo \${$configname}")" ]] ; then
		    doWrite=1
		    break
		fi
	    fi
	done
    fi
    
    # if we need to, write out the file
    if [[ "$doWrite" ]] ; then
	
	# write out the config file
	writevars "$myConfigFile" "${appConfigVars[@]}"
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1

}


# LAUNCHHELPER -- launch Epichrome Helper app
epiHelperMode= ; epiHelperParentPID=
export epiHelperMode epiHelperParentPID
function launchhelper { # ( mode )

    # only run if OK
    [[ "$ok" ]] || return 1
    
    # argument
    local mode="$1" ; shift
    
    # set state for helper
    epiHelperMode="Start$mode"
    epiHelperParentPID="$$"
    
    # launch helper (args are just for identification in jobs listings)
    try /usr/bin/open "$SSBAppPath/Contents/$appHelperPath" --args "$mode" \
	'Unable to launch Epichrome helper app.'

    # return code
    [[ "$ok" ]] && return 0 || return 1
}
