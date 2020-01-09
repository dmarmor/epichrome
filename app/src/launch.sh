#!/bin/sh
#
#  launch.sh: utility functions for building and launching an Epichrome engine
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
    
    # use spotlight to search the system for Epichrome instances
    local instances=()
    try 'instances=(n)' /usr/bin/mdfind \
	"kMDItemCFBundleIdentifier == '${appIDRoot}.Epichrome'" \
	'error'
    if [[ ! "$ok" ]] ; then
	# ignore mdfind errors
	ok=1
	errmsg=
    fi
    
    # if spotlight fails (or is off) try hard-coded locations
    if [[ ! "${instances[*]}" ]] ; then
	instances=( ~/'Applications/Epichrome.app' \
		      '/Applications/Epichrome.app' )
    fi
    
    # check instances of Epichrome to find the current and latest
    local curInstance= ; local curVersion=
    for curInstance in "${instances[@]}" ; do
	if [[ -d "$curInstance" ]] ; then
	    
	    # get this instance's version
	    curVersionScript="$curInstance/Contents/Resources/Scripts/version.sh"
	    curVersion="$( safesource "$curInstance/Contents/Resources/Scripts/version.sh" && try echo "$epiVersion" '' )"
	    if [[ ( "$?" != 0 ) || ( ! "$curVersion" ) ]] ; then
		curVersion=0.0.0
	    fi
	    
	    if vcmp "$curVersion" '>' 0.0.0 ; then
		
		debuglog "Found Epichrome $curVersion at '$curInstance'."
		
		# see if this is newer than the current latest Epichrome
		if ( [[ ! "$epiLatestPath" ]] || \
			 vcmp "$epiLatestVersion" '<' "$curVersion" ) ; then
		    epiLatestPath="$curInstance"
		    epiLatestVersion="$curVersion"
		fi
		
		# if we haven't already found an instance of the current version, check that
		if [[ ! "$epiCurrentPath" ]] && vcmp "$curVersion" '==' "$SSBVersion" ; then
		    epiCurrentPath="$curInstance"
		fi
		
	    else
		
		# failed to get version, so assume this isn't really a version of Epichrome
		debuglog "Epichrome at '$curInstance' is not valid."
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
    
    # return 
    [[ "$ok" ]] && return 0 || return 1
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
    latestVersion="$(/usr/bin/curl 'https://api.github.com/repos/dmarmor/epichrome/releases/latest' 2> /dev/null)"
    
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
    
    # get info on latest Epichrome version
    [[ "$epiLatestPath" && "$epiLatestVersion" ]] || getepichromeinfo
    if [[ ! "$ok" ]] ; then
	ok=1
	errmsg="Unable to get info on installed Epichrome versions. ($errmsg)"
	return 1
    elif [[ ! "$epiLatestVersion" ]] ; then

	# no Epichrome found on the system, so we're done
	return 0
    fi
    
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

	# update dialog info if the new version is beta
	if visbeta "$epiLatestVersion" ; then
	    updateMsg="$updateMsg

IMPORTANT NOTE: This is a BETA release, and may be unstable. Updating cannot be undone! Please back up both this app and your data directory ($myDataPath) before updating."
	    updateBtnUpdate="-$updateBtnUpdate"
	    updateBtnLater="+$updateBtnLater"
	else
	    updateBtnUpdate="+$updateBtnUpdate"
	    updateBtnLater="-$updateBtnLater"
	fi

	# display update dialog
	dialog doUpdate \
	       "$updateMsg" \
	       "Update" \
	       "|caution" \
	       "$updateBtnUpdate" \
	       "$updateBtnLater" \
	       "Don't Ask Again For This Version"
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
		safesource "${epiLatestPath}/Contents/Resources/Scripts/update.sh" "update script $epiLatestVersion"
		
		# use new runtime to update the SSB (and relaunch)
		updateapp "$SSBAppPath"
		
		# $$$$ MOVE THIS BACK INTO UPDATEAPP???
		if [[ "$ok" ]] ; then
		    
		    # SUCCESS -- relaunch & exit
		    relaunch "$SSBAppPath"
		    exit 0  # not necessary, but for clarity
		    
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
	
	# if we haven't set a version to check against, use the latest version
	[[ "$SSBUpdateCheckVersion" ]] || SSBUpdateCheckVersion="$epiLatestVersion"

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


# CHECKSAMEDEVICE -- check that two paths are on the same device
function checksamedevice { # ( path1 path2 )
    
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
function linktree { # ( sourceDir destDir sourceErrID destErrID files ... )

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local sourceDir="$1"   ; shift
    local destDir="$1"     ; shift
    local sourceErrID="$1" ; shift
    local destErrID="$1"   ; shift
    local files=( "$@" )   ; [[ "${files[*]}" ]] || files=( * )
    
    # pushd to source directory
    try '!12' pushd "$sourceDir" "Unable to enter $sourceErrID"
    [[ "$ok" ]] || return 1
    
    # loop through files creating hard links
    for curFile in "${files[@]}" ; do	
	try /bin/pax -rwlpp "$curFile" "$destDir" \
	    "Unable to link $sourceErrID $curFile to $destErrID."
    done
    
    # popd back from source directory
    try '!12' popd "Unable to exit $sourceErrID."
}


# LPROJESCAPE: escape a string for insertion in an InfoPlist.strings file
function lprojescape { # string
    s="${1/\\/\\\\\\\\}"  # escape backslashes for both sed & .strings file
    s="${s//\//\\/}"  # escape forward slashes for sed only
    echo "${s//\"/\\\\\"}"  # escape double quotes for both sed & .strings file
}


# FILTERLPROJ: destructively filter all InfoPlist.strings files in a set of .lproj directories
function filterlproj {  # ( basePath errID usageKey

    [[ "$ok" ]] || return 1
    
    # turn on nullglob
    local shoptState=
    shoptset shoptState nullglob
    
    # path to folder containing .lproj folders
    local basePath="$1" ; shift

    # name to search for in usage description strings
    local usageKey="$1" ; shift
    
    # info about this filtering for error messages
    local errID="$1" ; shift
    
    # escape bundle name strings
    local displayName="$(lprojescape "$CFBundleDisplayName")"
    local bundleName="$(lprojescape "$CFBundleName")"

    # create sed command
    local sedCommand='s/^(CFBundleName *= *").*("; *)$/\1'"$bundleName"'\2/' -e 's/^(CFBundleDisplayName *= *").*("; *)$/\1'"$displayName"'\2/'

    # if we have a usage key, add command for searching usage descriptions
    [[ "$usageKey" ]] && sedCommand="$sedCommand; "'s/^((NS[A-Za-z]+UsageDescription) *= *".*)'"$usageKey"'(.*"; *)$/\1'"$displayName"'\3/'
    
    # filter InfoPlist.strings files
    local curLproj=
    for curLproj in "$basePath/"*.lproj ; do
	
	# get paths for current in & out files
	local curStringsIn="$curLproj/InfoPlist.strings"
	local curStringsOutTmp="$(tempname "$curStringsIn")"
	
	if [[ -f "$curStringsIn" ]] ; then
	    # filter current localization
	    try "$curStringsOutTmp<" /usr/bin/sed -E "$sedCommand" "$curStringsIn" \
		"Unable to filter $errID localization strings."
	    
	    # move file to permanent home
	    permanent "$curStringsOutTmp" "$curStringsIn" "$errID localization strings"

	    # on any error, abort
	    if [[ ! "$ok" ]] ; then
		# remove temp output file on error
		rmtemp "$curStringsOutTmp" "$errID localization strings"
		break
	    fi
	fi
    done
    
    # restore nullglob
    shoptrestore shoptState
    
    # return success or failure
    [[ "$ok" ]] && return 0 || return 1
}


# GETGOOGLECHROMEINFO: find Google Chrome on the system & get info on it
#                      sets the following variables:
#                         SSBGoogleChromePath, SSBGoogleChromeVersion
#                         googleChromeAppIconPath, googleChromeDocIconPath
function getgooglechromeinfo {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # set up list of search locations/methods
    local searchList=()
    [[ "$SSBGoogleChromePath" ]] && searchList+=( "$SSBGoogleChromePath" )
    searchList+=( "$HOME/Applications/Google Chrome.app" \
		      '/Applications/Google Chrome.app' \
		      SPOTLIGHT FAIL )
    
    # try various methods to find & validate Chrome
    for curPath in "${searchList[@]}" ; do
	
	# assume failure
	SSBGoogleChromePath=
	SSBGoogleChromeVersion=
	googleChromeAppIconPath=
	googleChromeDocIconPath=
	
	if [[ "$curPath" = FAIL ]] ; then

	    # failure
	    break
	    
	elif [[ "$curPath" = SPOTLIGHT ]] ; then
		
	    # search spotlight
	    try 'SSBGoogleChromePath=()' /usr/bin/mdfind "kMDItemCFBundleIdentifier == '$googleChromeID'" ''
	    if [[ ! "$ok" ]] ; then
		SSBGoogleChromePath=
		ok=1 ; errmsg=
	    fi
	    
	    # use the first instance
	    SSBGoogleChromePath="${SSBGoogleChromePath[0]}"
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
	    '$SSBGoogleChromePath/Contents/Info.plist' ''
	if [[ ! "$ok" ]] ; then
	    ok=1 ; errmsg=
	    continue
	fi

	# check bundle ID
	[[ "${infoPlist[0]}" = "$googleChromeID" ]] || continue
	
	# make sure the executable is in place
	local curExecPath="$SSBGoogleChromePath/Contents/MacOS/${infoPlist[1]}"
	[[ -f "$chromeExecPath" && -x "$chromeExecPath" ]] || continue
	
	# if we got here, we have a complete copy of Chrome, so break out
	break
	    
    done
    
    # set globals
    SSBGoogleChromeVersion="${infoPlist[2]}"
    googleChromeAppIconPath="${infoPlist[3]}"
    googleChromeDocIconPath="${infoPlist[3]}"

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

	debuglog "Forced data directory update. Installing external extensions."

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
	
	local hostScriptPath="$hostSourcePath/epichromeruntimehost.py"
	
	local hostManifest="org.epichrome.runtime.json"
	local hostManifestOld="org.epichrome.helper.json"
	local hostManifestDestPath="$myProfilePath/NativeMessagingHosts"
	
	# create the install directory if necessary
	if [[ ! -d "$hostManifestDestPath" ]] ; then
	    try /bin/mkdir -p "$hostManifestDestPath" \
		'Unable to create NativeMessagingHosts folder.'
	fi
	
	# paths to destination for host manifests with new and old IDs
	local hostManifestDest="$hostManifestDestPath/$hostManifest"
	local hostManifestOldDest="$hostManifestDestPath/$hostManifestOld"
	
	# stream-edit the new manifest into place  $$$ THIS WILL NEED TO HAVE ARGS
	if [[ "$force" || ! -e "$hostManifestDest" ]] ; then
	    filterscript "$hostSourcePath/$hostManifest" "$hostManifestDest" \
			 'native messaging host manifest' \
			 APPHOSTPATH "$hostScriptPath"
	fi
	
	# duplicate the new manifest with the old ID
	if [[ "$force" || ! -e "$hostManifestOldDest" ]] ; then
	    try /bin/rm -f "$hostManifestOldDest" \
		'Unable to remove old native messaging host manifest.'
	    try /bin/cp "$hostManifestDest" "$hostManifestOldDest" \
		'Unable to copy native messaging host manifest.'
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
    local nullglobOff=
    if shopt -q nullglob ; then
	nullglobOff=1
	shopt -s nullglob
    fi
	
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
    try '!12' pushd "$myHostDir" "Unable to navigate to '$myHostDir'."
    
    # get list of host files currently installed
    hostFiles=( * )
    
    # remove dead host links
    for curFile in "${hostFiles[@]}" ; do
	if [[ -L "$curFile" && ! -e "$curFile" ]] ; then
	    try rm -f "$curFile" "Unable to remove dead link to $curFile."
	fi
    done
    
    # link to hosts from both directories
    for curHostDir in "${hostDirs[@]}" ; do

	if [[ -d "$curHostDir" ]] ; then

	    # get a list of all hosts in this directory
	    try '!12' pushd "$curHostDir" "Unable to navigate to ${curHostDir}"
	    hostFiles=( * )
	    try '!12' popd "Unable to navigate away from ${curHostDir}"

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
    try '!12' popd "Unable to navigate away from '$myHostDir'."
    
    # restore nullglob
    [[ "$nullglobOff" ]] && shopt -u nullglob
    
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
	curState=OFF
	inactivePath="$myEnginePayloadPath"
	
    elif [[ -d "$myEnginePlaceholderPath" && ! -d "$myEnginePayloadPath" ]] ; then

	# engine is active
	curState=ON
	inactivePath="$myEnginePlaceholderPath"
	
    else

	# engine is not in either state
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
	return 2
    fi
    
} ; export -f setenginestate


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
	newInactivePath="$myEnginePlaceholderPath"
    else
	oldInactivePath="$myEnginePlaceholderPath"
	newInactivePath="$myEnginePayloadPath"
    fi

    # engine app contents
    local myEngineAppContents="$myEngineAppPath/Contents"
    
    # move the old contents out
    if [[ -d "$newInactivePath" ]] ; then
	ok= ; errmsg="${newInactivePath##*/} already deactivated."
    fi
    try /bin/mv "$myEngineAppContents" "$newInactivePath" \
	'Unable to deactivate $newInactiveError.'

    # move the new contents in
    if [[ -d "$myEngineAppContents" ]] ; then
	ok= ; errmsg="Unable to empty engine app."
    fi
    try /bin/mv "$oldInactivePath" "$myEngineAppContents" \
	'Unable to activate $oldInactiveError.'
    
} ; export -f setenginestate


# CREATEENGINEPAYLOAD: create app engine payload
function createenginepayload {
    
    [[ "$ok" ]] || return 1
        
    # clear out any old payload
    if [[ -d "$myEnginePayloadPath" ]] ; then
	try /bin/rm -rf "$myEnginePayloadPath" 'Unable to clear old engine payload.'
	[[ "$ok" ]] || return 1
    fi

    
    # CREATE NEW PAYLOAD
    
    if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	
	# GOOGLE CHROME PAYLOAD
	
	# make sure we have a source for the payload
	if [[ ! -d "$SSBGoogleChromePath" ]] ; then
	    
	    # we should already have this, so as a last ditch, ask the user to locate it
	    local myGoogleChromePath=
	    try 'myGoogleChromePath=' osascript -e \
		'return POSIX path of (choose application with title "Locate Google Chrome" with prompt "Please locate Google Chrome" as alias)' 'Error showing Locate Google Chrome dialog.'
	    myGoogleChromePath="${SSBGoogleChromePath%/}"
	    
	    if [[ ! "$ok" || ! -d "$myGoogleChromePath" ]] ; then
		
		# we've failed to find Chrome
		ok=
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find Google Chrome.$errmsg"
		return 1
	    fi
	    
	    # user selected a path, so check it
	    SSBGoogleChromePath="$myGoogleChromePath"
	    getgooglechromeinfo
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
	if ! checksamedevice "$SSBGoogleChromePath" "$myEnginePayloadPath" ; then
	    ok= ; errmsg="Google Chrome is not on the same volume as this app's data directory."
	    return 1
	fi
	
	# create Payload directory
	try /bin/mkdir -p "$myEnginePayloadPath/Resources" \
	    'Unable to create payload folder.'
	
	# turn on extended glob for copying
	local shoptState=
	shoptset shoptState extglob
	
	# copy all of Google Chrome except Framework and Resources
	# (note that hard linking executblle causes confusion between apps & real Chrome)
	try /bin/cp -a "$SSBGoogleChromePath/Contents/"!(Frameworks|Resources) "$myEnginePayloadPath" \
	    'Unable to copy Google Chrome app engine payload.'
	
	# copy Resources, except icons
	try /bin/cp -a "$SSBGoogleChromePath/Contents/Resources/"!(*.icns) "$myEnginePayloadPath/Resources" \
	    'Unable to copy Google Chrome app engine resources to payload.'
	
	# restore extended glob
	shoptrestore shoptState
	
	# hard link to Google Chrome Frameworks
	linktree "$SSBGoogleChromePath/Contents" "$myEnginePayloadPath" \
		 'Google Chrome app engine' 'payload' 'Frameworks'
	
	# filter localization files
	filterlproj "$curPayloadContentsPath/Resources" 'Google Chrome app engine'
	
	# link to this app's icons
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
	    "$myEnginePayloadPath/Resources/$googleChromeAppIconPath" \
	    "Unable to copy app icon to Google Chrome app engine."
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
	    "$myEnginePayloadPath/Resources/$googleChromeDocIconPath" \
	    "Unable to copy document icon file to Google Chrome app engine."
    else
	
	# CHROMIUM PAYLOAD

	# make sure we have the current version of Epichrome
	if [[ ! -d "$epiCurrentPath" ]] ; then
	    ok=
	    errmsg="Unable to find this app's version of Epichrome."
	    return 1
	fi
	
	# make sure Epichrome is on the same volume as the engine
	if ! checksamedevice "$epiCurrentPath" "$myEnginePayloadPath" ; then
	    ok= ; errmsg="Epichrome is not on the same volume as this app's data directory."
	    return 1
	fi

	# path to Epichrome engine
	local epiPayloadPath="$epiCurrentPath/Contents/$appEnginePayloadPath"
	
	# copy main payload from Epichrome
	try /bin/cp -a "$epiEnginePath/Main" "$myEnginePayloadPath" \
	    'Unable to copy app engine payload.'

	# hard link large payload items from Epichrome
	linktree "$epiEnginePath/Link" "$myEnginePayloadPath" 'app engine' 'payload'
	
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
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1
}


# CREATEENGINE -- create entire Epichrome engine (payload & placeholder)
function createengine {

    [[ "$ok" ]] || return 1
    
    # create inactive payload
    createenginepayload
    
    # path to active engine app
    local myEngineApp="$myEnginePath/$SSBEngineAppName"
    
    # clear out any old active app
    if [[ -d "$myEngineApp" ]] ; then
	try /bin/rm -rf "$myEngineApp" 'Unable to clear old app engine placeholder.'
	[[ "$ok" ]] || return 1
    fi
    
    # create active placeholder
    safecopy "$SSBAppPath/Contents/$appEnginePlaceholderPath" \
	     "$myEngineApp/Contents" 'app engine placeholder'

    # if using Google Chrome engine, copy icons into placeholder
    if [[ "$SSBEngineType" = 'Google Chrome' ]] ; then
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
	    "$myEngineApp/Contents/Resources/$googleChromeAppIconPath" \
	    "Unable to copy app icon to Google Chrome app engine placeholder."
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
	    "$myEngineApp/Contents/Resources/$googleChromeDocIconPath" \
	    "Unable to copy document icon file to Google Chrome app engine placeholder."
    fi
    
    # filter Info.plist from payload
    filterplist "$myEnginePayloadPath/Info.plist" \
		"$myEngineApp/ContentsPayloadPath/Info.plist" \
		"app engine placeholder Info.plist" \
		'Add :LSUIElement bool true'
}


# GETENGINEPID: get the PID of the running engine   $$$$ DO THIS EXPORT IN EPICHROME??
myEnginePID= ; export myEnginePID
function getenginepid { # path

    # assume no PID
    myEnginePID=

    # args
    local path="$1" ; shift

    # get ASN associated with the engine's bundle path
    local asn=
    try 'asn=' /usr/bin/lsappinfo find "bundlepath=$path" \
	'Error while attempting to find running engine.'
    
    # no engine found, just don't return a PID
    [[ "$ok" && ! "$asn" ]] && return 0

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
	else
	    echo "got here and info='$info'"

	fi
    fi
    
    # return result
    if [[ "$myEnginePID" ]] ; then
	ok=1 ; errmsg=
	return 0
    elif [[ "$ok" ]] ; then
	return 0
    else
	# errors in this function are nonfatal; just return the error message
	ok=1
	return 1
    fi
}
