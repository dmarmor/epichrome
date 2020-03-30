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
#readonly appEnginePathBase

# external engine browser info
appExtEngineBrowsers=( 'com.microsoft.edgemac' \
			   'com.vivaldi.Vivaldi' \
			   'com.operasoftware.Opera' \
			   'com.brave.Browser' \
			   'org.chromium.Chromium' \
			   'com.google.Chrome' )

appBrowserInfo_com_microsoft_edgemac=( 'com.microsoft.edgemac' \
					   '' 'Edge' 'Microsoft Edge' \
					   '' '' '' '' \
					   'Microsoft Edge' )
appBrowserInfo_com_vivaldi_Vivaldi=( 'com.vivaldi.Vivaldi' \
					   '' 'Vivaldi' 'Vivaldi' \
					   '' '' '' '' \
					   'Vivaldi' )
appBrowserInfo_com_operasoftware_Opera=( 'com.operasoftware.Opera' \
					   '' 'Opera' 'Opera' \
					   '' '' '' '' \
					   'com.operasoftware.Opera' )
appBrowserInfo_com_brave_Browser=( 'com.brave.Browser' \
					   '' 'Brave' 'Brave Browser' \
					   '' '' '' '' \
					   'BraveSoftware/Brave-Browser' \
					   'Chromium Master Preferences' )
appBrowserInfo_org_chromium_Chromium=( 'org.chromium.Chromium' \
					   '' 'Chromium' 'Chromium' \
					   '' '' '' '' \
					   'Chromium' )
appBrowserInfo_com_google_Chrome=( 'com.google.Chrome' \
					   '' 'Chrome' 'Google Chrome' \
					   '' '' '' '' \
					   'Google/Chrome' \
					   'Google Chrome Master Preferences' )

# native messaging host manifests
nmhDirName=NativeMessagingHosts
nmhManifestNewID="org.epichrome.runtime"
nmhManifestOldID="org.epichrome.helper"
nmhManifestNewFile="$nmhManifestNewID.json"
nmhManifestOldFile="$nmhManifestOldID.json"
#readonly nmhDirName nmhManifestNewID nmhManifestNewFile nmhManifestOldID nmhManifestOldFile

# first-run files
myFirstRunFile="$myProfilePath/First Run"
myPreferencesFile="$myProfilePath/Default/Preferences"


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
		vnums[$i]=$(( ${vnums[$i]} + 999 ))
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


# WAITFORCONDITION -- wait for a given condition to become true, or timeout
function waitforcondition {  # ( msg waitTime increment command [args ...] )
    
    # arguments
    local msg="$1" ; shift
    local waitTime="$1" ; shift
    local increment="$1" ; shift

    # get rid of decimals
    local waitTimeInt="${waitTime#*.}" ; [[ "$waitTimeInt" = "$waitTime" ]] && waitTimeInt=
    local incrementInt="${increment#*.}" ; [[ "$incrementInt" = "$increment" ]] && incrementInt=
    local decDiff=$((${#incrementInt} - ${#waitTimeInt}))
    if [[ decDiff -gt 0 ]] ; then
	incrementInt="${increment%.*}$incrementInt"
	waitTimeInt=$(( ${waitTime%.*}$waitTimeInt * ( 10**$decDiff ) ))
    elif [[ decDiff -lt 0 ]] ; then
	waitTimeInt="${waitTime%.*}$waitTimeInt"
	incrementInt=$(( ${increment%.*}$incrementInt * ( 10**${decDiff#-} ) ))
    else
	incrementInt="${increment%.*}$incrementInt"
	waitTimeInt="${waitTime%.*}$waitTimeInt"	
    fi
    
    # wait for the condition to be true
    local curTime=0
    while [[ "$curTime" -lt "$waitTimeInt" ]] ; do
		
	# try the command
	"$@" && return 0
	
	# wait
	[[ "$curTime" = 0 ]] && errlog "Waiting for $msg..."
	sleep $increment
	
	# update time
	curTime=$(( $curTime + $incrementInt ))
    done

    # if we got here the condition never occurred
    return 1
}



# ENCODEURL -- encode a string for URL
function encodeurl {  # ( input [safe] )
    
    # arguments
    local input="$1" ; shift ; local input_err="$input"
    local safe="$1" ; shift
    
    # quote strings for python
    input="${input//\\/\\\\}"
    input="${input//\'/\'}"
    safe="${safe//\\/\\\\}"
    safe="${safe//\'/\'}"

    # use python urllib to urlencode string
    local encoded=
    try 'encoded=' /usr/local/bin/python2.7 \
	-c 'import urllib ; print urllib.quote('\'"$input"\'', '\'"$safe"\'')' \
	"Error URL-encoding string '$input_err'."

    if [[ ! "$ok" ]] ; then
	echo "$input_err"
	ok=1 ; errmsg=
	return 1
    else
	echo "$encoded"
	return 0
    fi
}


# UNESCAPEJSON: remove escapes from a JSON string
function unescapejson {  # ( str )
    local result="${1//\\\\/\\}"
    result="${result//\\\"/\"}"
    echo "$result"
}


# READJSONKEYS: pull keys out of a JSON string
function readjsonkeys {  # ( jsonVar key [key ...] )
    #  for each key found, sets the variable <jsonVar>_<key>

    # pull json string from first arg
    local jsonVar="$1" ; shift
    local json
    eval "json=\"\$$jsonVar\""

    # whitespace
    local ws=' 	
'
    local s="[$ws]*"
    
    # loop through each key
    local curKey curRe curMatch
    for curKey in "$@"; do

	# set regex for pulling out string key (groups 1-3, val is group 2)
	curRe="(\"$curKey\"$s:$s"
	curRe+='"(([^\"]|\\\\|\\")*)")'

	# set regex for pulling out dict key (groups 4-8, val is group 5)
	curRe+="|(\"$curKey\"$s:$s{$s"
	curRe+='(([^}"]*"([^\"]|\\\\|\\")*")*([^}"]*[^}"'"$ws])?)$s})"
	
	# try to match
	if [[ "$json" =~ $curRe ]] ; then
	    
	    if [[ "${BASH_REMATCH[2]}" ]] ; then

		# string key: fix escaped backslashes and double-quotes
		curMatch="$(unescapejson "${BASH_REMATCH[2]}")"
	    else

		# dict key
		curMatch="${BASH_REMATCH[5]}"
	    fi
	    
	    # set the variable
	    eval "${jsonVar}_${curKey}=$(formatscalar "$curMatch")"
	else

	    # clear the variable
	    eval "${jsonVar}_${curKey}="
	fi
    done
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
    
    # start with preferred install locations: the engine path & default user & global paths
    local preferred=()
    [[ -d "$SSBEnginePath" ]] && preferred+=( "${SSBEnginePath%/$appEnginePathBase/*}/Epichrome.app" )
    local globalDefaultEpichrome='/Applications/Epichrome/Epichrome.app'
    local userDefaultEpichrome="${HOME}$globalDefaultEpichrome"
    [[ "${preferred[0]}" != "$userDefaultEpichrome" ]] && preferred+=( "$userDefaultEpichrome" )
    [[ "${preferred[0]}" != "$globalDefaultEpichrome" ]] && preferred+=( "$globalDefaultEpichrome" )
    
    # use spotlight to search the system for all Epichrome instances
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
	    curVersion="$( safesource "$curInstance/Contents/Resources/Scripts/version.sh" && if [[ "$epiVersion" ]] ; then echo "$epiVersion" ; else echo "$mcssbVersion" ; fi )"
	    if [[ ( "$?" != 0 ) || ( ! "$curVersion" ) ]] ; then
		curVersion=0.0.0
	    fi
	    
	    if vcmp "$curVersion" '>=' "$SSBVersion" ; then
		
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
		
	    elif [[ "$debug" ]] ; then
		if vcmp "$curVersion" '>' 0.0.0 ; then
		    # failed to get version, so assume this isn't really a version of Epichrome
		    errlog "Ignoring '$curInstance' (old version $curVersion)."
		else
		    # failed to get version, so assume this isn't really a version of Epichrome
		    errlog "Ignoring '$curInstance' (unable to get version)."
		fi
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
	# the app uses an internal engine, don't allow the user to ignore this version
	if [[ "$epiCurrentPath" || ( "${SSBEngineType%%|*}" != internal ) ]] ; then
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
		    source "$SSBAppPath/Contents/Resources/Scripts/core.sh" PRESERVELOG || ok=
		    if [[ ! "$ok" ]] ; then

			# fatal error
			errmsg="Update failed and unable to reload current app. (Unable to load core script $SSBVersion)"
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
	try '-2' 'updateResult=(n)' checkgithubversion "$SSBUpdateCheckVersion" ''
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


# UPDATEDATADIR -- make sure an app's data directory is ready for the run
function updatedatadir {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    errmsg=
    
    # if we don't have a data path, abort (safety check before rm -rf)
    if ! checkpath "$myDataPath" "$appDataPathBase" ; then
	ok= ; errmsg='Data path is not properly set!'
	return 1
    fi

    
    # UPDATE DATA DIRECTORY FOR NEW VERSION
    
    if [[ "$myStatusNewVersion" ]] ; then
		
	# $$$ temporary -- GET RID OF THIS FOR RELEASE -- remove old-style engine directory
	if [[ -d "$myDataPath/Engine.noindex" ]] ; then

	    debuglog "Removing old engine directory."
	    
	    try /bin/rm -rf "$myDataPath/Engine.noindex" \
		'Unable to remove old engine directory'
	    if [[ ! "$ok" ]] ; then
		ok=1 ; errmsg=
	    fi
	fi

	# $$$ temporary -- GET RID OF THIS FOR RELEASE -- remove old-style engine directory
	if [[ -d "$myDataPath/UserData/External Extensions" ]] ; then
	    
	    debuglog "Removing old external extensions directory."
	    
	    # remove External Extensions and NativeMessagingHosts directories from profile
	    try /bin/rm -rf "$myDataPath/UserData/External Extensions" \
		'Unable to remove old external extensions folder.'
	    if [[ ! "$ok" ]] ; then
		ok=1 ; errmsg=
	    fi
	fi
    fi
    
    
    # UPDATE WELCOME PAGE
    
    if [[ "$myStatusNewApp" || "$myStatusNewVersion" || \
	      "${myStatusEngineChange[0]}" || "$myStatusReset" || \
	  ( ! -e "$myDataPath/Welcome/$appWelcomePage" ) ]] ; then
	
	debuglog 'Updating welcome page assets.'
	
	# copy welcome page into data directory
	safecopy "$SSBAppPath/Contents/$appWelcomePath" "$myDataPath/Welcome" \
		 "Unable to create welcome page. You will not see important information on the app's first run."
	if [[ "$ok" ]] ; then

	    # link to master directory of extension icons
	    try /bin/ln -s "../../../../$epiDataExtIconBase" "$myDataPath/Welcome/img/ext" \
		'Unable to link to extension icon directory.'
	fi

	# errors here are non-fatal
	ok=1
    fi
    
    # return code
    [[ "$errmsg" ]] && return 1 || return 0
}


# SETWELCOMEPAGE -- configure any welcome page to be shown on this run
#                   sets myStatusWelcomeURL
function setwelcomepage {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # basic welcome page URL
    local baseURL="file://$(encodeurl "$myDataPath/Welcome/$appWelcomePage" '/')?v=$SSBVersion&e=$(encodeurl "$SSBEngineType")"
    
    if [[ "$myStatusNewApp" ]] ; then
	
	# simplest case: new app
	debuglog "Creating new app welcome page."
	myStatusWelcomeURL="$baseURL"
	myStatusWelcomeTitle="App Created ($SSBVersion)"
	
    elif [[ "$myStatusNewVersion" ]] ; then
	
	# updated app
	debuglog "Creating app update welcome page."
	myStatusWelcomeURL="$baseURL&ov=$(encodeurl "$myStatusNewVersion")"
	myStatusWelcomeTitle="App Updated ($myStatusNewVersion -> $SSBVersion)"
	
    fi
    
    if [[ ! "$myStatusNewApp" ]] ; then
	
	if [[ "${myStatusEngineChange[0]}" ]] ; then
	    
	    # engine change
	    if [[ ! "$myStatusWelcomeURL" ]] ; then
		
		# this is the only trigger to show the page
		debuglog "Creating app engine change welcome page."
		myStatusWelcomeURL="$baseURL"
		myStatusWelcomeTitle="App Engine Changed (${myStatusEngineChange[$iName]} -> ${SSBEngineSourceInfo[$iName]})"
	    fi
	    
	    # set up arguments
	    myStatusWelcomeURL+="&oe=$(encodeurl "${myStatusEngineChange[0]}")"
	fi
	
	if [[ "$myStatusReset" ]] ; then
	    
	    # reset profile
	    if [[ ! "$myStatusWelcomeURL" ]] ; then
		debuglog "Creating app reset welcome page."
		myStatusWelcomeURL="$baseURL"
		myStatusWelcomeTitle="App Settings Reset"
	    fi
	    
	    # add reset argument
	    myStatusWelcomeURL+='&r=1'
	    
	fi
    fi
    
    # if we're already showing a page, check for extensions
    if [[ "$myStatusWelcomeURL" && \
	      ( ! -d "$myProfilePath/Default/Extensions" ) ]] ; then
	
	# no extensions, so give the option to install them
	debuglog 'App has no extensions, so offering browser extensions.'
	
	# collect data directories for all known browsers
	extDirs=()
	for browser in "${appExtEngineBrowsers[@]}" ; do
	    getbrowserinfo browserInfo "$browser"
	    if [[ "${browserInfo[$iLibraryPath]}" ]] ; then
		browserInfo="$userSupportPath/${browserInfo[$iLibraryPath]}"
		[[ -d "$browserInfo" ]] && extDirs+=( "$browserInfo" )
	    else
		debuglog "Unable to get info on browser ID $browser."
	    fi
	done
	
	# mine extensions from all browsers
	local extArgs=
	getextensioninfo extArgs "${extDirs[@]}"
	
	# if any extensions found, add them to the page
	[[ "$extArgs" ]] && myStatusWelcomeURL+="&xi=1&$extArgs"
    fi
    
    return 0
}


# UPDATEPROFILEDIR -- ensure the profile directory is ready for this run
function updateprofiledir {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # ensure we have a configured profile path
    if [[ ! "$myProfilePath" ]] ; then
	ok= ; errmsg='No profile path configured!'
	return 1
    fi

    # ensure profile directory exists
    if [[ ! -d "$myProfilePath" ]] ; then

	debuglog "Creating profile directory '$myProfilePath'."
	
	# ensure data & profile directories exists
	try /bin/mkdir -p "$myProfilePath" 'Unable to create app engine profile folder.'
	
	# if we couldn't create the directory, that's a fatal error
	[[ "$ok" ]] || return 1
    fi

    # check on runtime extension status

    # implicit argument to signal welcome page to offer a new install of the extension
    local runtimeExtArg=0

    # check if the runtime extension is still installed
    if [[ -d "$myProfilePath/Default/Extensions/EPIEXTIDRELEASE" ]] ; then

	# check if we're updating from pre-2.3.0b9
	if [[ "$myStatusNewVersion" ]] && \
	       vcmp "$myStatusNewVersion" '<' '2.3.0b9' ; then

	    debuglog "Saving Epichrome Helper settings."
	    
	    # preserve runtime extension settings
	    myStatusFixRuntime=( "$myProfilePath/Default/Local Extension Settings/EPIEXTIDRELEASE" \
				     "$myDataPath/EPIEXTIDRELEASE" )
	    safecopy "${myStatusFixRuntime[0]}" "${myStatusFixRuntime[1]}" \
		     'Unable to save Epichrome Helper settings.'
	    if [[ ! "$ok" ]] ; then
		ok=1 ; errmsg=
		myStatusFixRuntime=

		# tell welcome page we couldn't save settings
		runtimeExtArg=3
	    else
	    
		# tell welcome page to ask user to reinstall extension due to update
		runtimeExtArg=1
	    fi
	fi
    fi
    
    # error states
    local myErrDelete=
    local myErrAllExtensions=
    local myErrSomeExtensions=
    local myErrBookmarks=

    
    # CLEAN UP PROFILE DIRECTORY ON ENGINE CHANGE
    
    errmsg=
    
    # triple check the directory as we're using rm -rf  $$$$ USE STATUS VAR INSTEAD
    if [[ "${myStatusEngineChange[0]}" && \
	      "$appDataPathBase" && ( "${myProfilePath#$appDataPathBase}" != "$myProfilePath" ) && \
	      "$HOME" && ( "${myProfilePath#$HOME}" != "$myProfilePath" ) ]] ; then
	
	debuglog "Switching engines from ${myStatusEngineChange[$iID]#*|} to ${SSBEngineType#*|}. Cleaning up profile directory."
	
	# turn on extended glob
	local shoptState=
	shoptset shoptState extglob
	
	# remove all of the UserData directory except Default
	local allExcept='!(Default)'
	try /bin/rm -rf "$myProfilePath/"$allExcept \
	    'Error deleting top-level files.'
	if [[ ! "$ok" ]] ; then
	    myErrDelete="$errmsg"
	    ok=1 ; errmsg=
	fi
	
	if [[ ( "${myStatusEngineChange[$iID]#*|}" = 'com.google.Chrome' ) || \
		  ( "${SSBEngineType#*|}" = 'com.google.Chrome' ) ]] ; then
	    
	    # SWITCHING BETWEEN GOOGLE CHROME AND CHROMIUM-BASED ENGINE
	    
	    debuglog "Clearing profile directory for engine switch between incompatible engines ${myStatusEngineChange[$iID]#*|} and ${SSBEngineType#*|}."
	    
	    # if there are any extensions, try to save them
	    local oldExtensionArgs=
	    getextensioninfo 'oldExtensionArgs'
	    if [[ "$?" = 1 ]] ; then
		local myErrAllExtensions=1
	    elif [[ "$?" = 2 ]] ; then
		local myErrSomeExtensions="$errmsg"
	    fi
	    
	    # add to welcome page
	    [[ "$oldExtensionArgs" ]] && myStatusWelcomeURL+="&$oldExtensionArgs"
	    
	    # delete everything from Default except:
	    #  Bookmarks, Favicons, History, Local Extension Settings
	    allExcept='!(Bookmarks|Favicons|History|Local?Extension?Settings)'
	    try /bin/rm -rf "$myProfilePath/Default/"$allExcept \
		'Error deleting browser profile files.'
	    if [[ ! "$ok" ]] ; then
		[[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
		ok=1 ; errmsg=
	    fi
	    
	    # add reset argument
	    myStatusWelcomeURL+='&r=1'

	    # update runtime extension argument if not already set for update warning
	    [[ "$runtimeExtArg" = 0 ]] || runtimeExtArg=2
	    
	else
	    
	    # CATCH-ALL FOR SWITCHING FROM ONE FLAVOR OF CHROMIUM TO ANOTHER
	    
	    debuglog "Clearing profile directory for engine switch between compatible engines ${myStatusEngineChange[$iID]#*|} and ${SSBEngineType#*|}."
	    
	    #    - delete Login Data & Login Data-Journal so passwords will work (will need to be reimported)
	    try /bin/rm -f "$myProfilePath/Default/Login Data"* \
		'Error deleting login data.'
	    if [[ ! "$ok" ]] ; then
		[[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
		ok=1 ; errmsg=
	    fi
	fi

	# $$$$ ADD MORE DETAIL AS I DO MORE TESTS, E.G. CHROMIUM->CHROME
	
	# restore extended glob
	shoptrestore shoptState
	
    fi
    
    
    # SET UP PROFILE DIRECTORY

    # if this is our first-run, get Preferences and First Run file in consistent state
    if [[ "$myStatusReset" ]] ; then

	# we're missing either First Run or Prefs file, so delete both
	try /bin/rm -f "$myFirstRunFile" "$myPreferencesFile" \
	    'Error deleting first-run files.'
	if [[ ! "$ok" ]] ; then
	    [[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
	    ok=1 ; errmsg=
	fi
    fi


    # WELCOME PAGE ACTIONS
    
    if [[ "$myStatusWelcomeURL" ]] ; then

	# LET WELCOME PAGE KNOW ABOUT RUNTIME EXTENSION

	[[ "$runtimeExtArg" != 0 ]] && \
	    myStatusWelcomeURL+="&rt=$runtimeExtArg"
	
	
	# INSTALL/UPDATE BOOKMARKS FILE

	local bookmarkResult=
	
	local myBookmarksFile="$myProfilePath/Default/Bookmarks"
	
	if [[ ! -e "$myBookmarksFile" ]] ; then

	    # no bookmarks found, create new file with welcome page
	    
	    debuglog 'Creating new app bookmarks.'
	    
            [[ -d "$myProfilePath/Default" ]] || \
		try /bin/mkdir -p "$myProfilePath/Default" \
		    'Unable to create browser profile directory.'
	    filterfile "$SSBAppPath/Contents/$appBookmarksPath" \
		       "$myBookmarksFile" \
		       'bookmarks file' \
		       APPWELCOMETITLE "$myStatusWelcomeTitle" \
		       APPWELCOMEURL "$myStatusWelcomeURL"
	    if [[ "$ok" ]] ; then

		# new bookmark folder
		bookmarkResult=2

	    else
		
		# non-serious error, fail silently
		myErrBookmarks=1
		ok=1 ; errmsg=
	    fi

	else

	    # bookmarks found, so try to add welcome page to our folder

	    debuglog 'Checking app bookmarks...'
	    
	    # read in bookmarks file
	    local bookmarksJson=
	    try 'bookmarksJson=' /bin/cat "$myBookmarksFile" \
		'Unable to read in app bookmarks.'

	    if [[ "$ok" ]] ; then

		# status variable
		local bookmarksChanged=
		
		# utility regex
		local s="[[:space:]]*"
		
		# regex to parse bookmarks JSON file for our folder
		local bookmarkRe='^((.*)"checksum"'"$s:$s"'"[^"]+"'"$s,$s)?(.*[^[:blank:]]([[:blank:]]*)"'"children"'"$s:$s"'\['"($s{.*})?)$s(]$s,[^]}]*"'"guid"'"$s:$s"'"e91c4703-ee91-c470-3ee9-1c4703ee91c4"[^]}]*"type"'"$s:$s"'"folder".*)$'
		
		if [[ "$bookmarksJson" =~ $bookmarkRe ]] ; then

		    debuglog "Adding welcome page bookmark to existing folder."
		    
		    bookmarksJson=
		    
		    # if there's a checksum, remove it
		    [[ "${BASH_REMATCH[1]}" ]] && bookmarksJson="${BASH_REMATCH[2]}"

		    # insert section before our bookmark
		    bookmarksJson+="${BASH_REMATCH[3]}"

		    # if there are other bookmarks in our folder, add a comma
		    [[ "${BASH_REMATCH[5]}" ]] && bookmarksJson+=','

		    # add our bookmark & the rest of the file
		    bookmarksJson+=" {
${BASH_REMATCH[4]}   \"name\": \"$myStatusWelcomeTitle\",
${BASH_REMATCH[4]}   \"type\": \"url\",
${BASH_REMATCH[4]}   \"url\": \"$myStatusWelcomeURL\"
${BASH_REMATCH[4]}} ${BASH_REMATCH[6]}"

		    bookmarksChanged=1

		    # bookmark added to existing folder
		    bookmarkResult=1

		elif ( [[ "$myStatusNewVersion" ]] && \
			   vcmp "$myStatusNewVersion" '<' '2.3.0b9' ) ; then
		    
		    # updating from before 2.3.0b9, so seed bookmark file with our folder
		    
		    debuglog "Adding folder for welcome pages to bookmarks."
		    
		    # new regex to insert our bookmarks folder into JSON file
		    local bookmarkRe='^((.*)"checksum"'"$s:$s"'"[^"]+"'"$s,$s)?"'(.*"bookmark_bar"'"$s:$s{"'([[:blank:]]*'$'\n'')?([[:blank:]]*)"children"'"$s:$s"'\[)'"$s"'(({?).*)$'
		    
		    if [[ "$bookmarksJson" =~ $bookmarkRe ]] ; then

			bookmarksJson=
			
			# if there's a checksum, remove it
			[[ "${BASH_REMATCH[1]}" ]] && bookmarksJson="${BASH_REMATCH[2]}"
			
			# insert section before our folder
			bookmarksJson+="${BASH_REMATCH[3]}"
			
			# add our bookmark
			bookmarksJson+=" {
${BASH_REMATCH[5]}   \"children\": [ {
${BASH_REMATCH[5]}      \"name\": \"$myStatusWelcomeTitle\",
${BASH_REMATCH[5]}      \"type\": \"url\",
${BASH_REMATCH[5]}      \"url\": \"$myStatusWelcomeURL\"
${BASH_REMATCH[5]}} ],
${BASH_REMATCH[5]}   \"guid\": \"e91c4703-ee91-c470-3ee9-1c4703ee91c4\",
${BASH_REMATCH[5]}   \"name\": \"$CFBundleName Info\",
${BASH_REMATCH[5]}   \"type\": \"folder\"
${BASH_REMATCH[5]}}"
			
			# if there are other items in the bookmark bar, add a comma
			[[ "${BASH_REMATCH[7]}" ]] && bookmarksJson+=','

			# add the rest of the file
			bookmarksJson+=" ${BASH_REMATCH[6]}"
			
			bookmarksChanged=1
			
			# new bookmark folder
			bookmarkResult=2
			
		    else
			errlog 'Unable to add welcome page folder to app bookmarks.'
			myErrBookmarks=1
		    fi
		else
		    errlog 'Welcome page folder not found in app bookmarks.'
		    myErrBookmarks=1
		fi
		
		# write bookmarks file back out
		if [[ "$bookmarksChanged" ]] ; then
		    try "${myBookmarksFile}<" echo "$bookmarksJson" \
			'Error writing out app bookmarks file.'
		    if [[ ! "$ok" ]] ; then
			bookmarkResult=
			myErrBookmarks="$errmsg"
			ok=1 ; errmsg=
		    fi
		fi

	    else
		
		# non-serious error, fail silently
		myErrBookmarks=1
		ok=1 ; errmsg=
	    fi
	fi

	# let the page know the result of this bookmarking
	[[ "$bookmarkResult" ]] && myStatusWelcomeURL+="&b=$bookmarkResult"
	
	# clear non-serious errors
	[[ "$myErrBookmarks" = 1 ]] && myErrBookmarks=
    fi
    
    
    # REPORT NON-FATAL ERRORS
    
    if [[ "$myErrDelete" ]] ; then
	errmsg="Unable to remove old profile files. ($myErrDelete) The app's settings may be corrupted and might need to be deleted."
    fi
    if [[ "$myErrBookmarks" ]] ; then
	if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
	errmsg+=" to write to the bookmarks file. The app's bookmarks may be lost."
    fi
    if [[ "$myErrAllExtensions" ]] ; then
	if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
	errmsg+=" to save extensions that will be uninstalled in the engine change. You will have to reinstall the app's extensions manually."
    elif [[ "$myErrSomeExtensions" ]] ; then
	if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
	errmsg="to save some of the extensions that will be uninstalled in the engine change. You will have to reinstall the following extensions manually: $myErrSomeExtensions"
    fi
    
    [[ "$errmsg" ]] && return 1 || return 0
}


# GETEXTENSIONINFO -- collect info on a set of extensions & format into URL variables
function getextensioninfo {  # ( resultVar [dir dir ...] )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local resultVar="$1" ; shift
    local result=
    
    local mySearchPaths=( "$@" )
    if [[ "${#mySearchPaths[@]}" = 0 ]] ; then
	mySearchPaths=( "$myProfilePath/Default" )
    fi
    
    # error states
    local myGlobalError=
    local myFailedExtensions=()
    local mySuccessfulExtensions=()
    
    # turn on nullglob & extglob
    local myShoptState=
    shoptset myShoptState nullglob extglob

    # find all requested extensions directories
    local myExtDirPaths=()
    local d sd
    for d in "${mySearchPaths[@]}" ; do
	if [[ -d "$d/Extensions" ]] ; then

	    # we're in an actual profile directory
	    myExtDirPaths+=( "$d/Extensions" )
	else

	    # we're in a root browser data directory
	    for sd in "$d"/* ; do
		if [[ ( -d "$sd" ) && ( -d "$sd/Extensions" ) ]] ; then
		    myExtDirPaths+=( "$sd/Extensions" )
		fi
	    done
	fi
    done
    
    # set backstop directory to return to
    try '!1' pushd . \
	'Unable to save working directory.'
    if [[ ! "$ok" ]] ; then
	ok=1 ; return 1
    fi
    
    # get extension IDs, excluding weird internal Chrome ones
    local allExcept="!(Temp|coobgpohoikkiipiblmjeljniedjpjpf|nmmhkkegccagdldgiimedpiccmgmieda|pkedcjkdefgpdelpbcmbmeomcjbeemfm)"
    
    # find all valid extensions in each path
    local myExtensions=
    local curExtensions=()
    local curExtDirPath=
    local curExt=
    for curExtDirPath in "${myExtDirPaths[@]}" ; do
	
	# move into this Extensions directory
	try cd "$curExtDirPath" \
	    "Unable to navigate to extensions directory '$curExtDirPath'."
	if [[ ! "$ok" ]] ; then
	    myGlobalError=1
	    ok=1
	    continue
	fi

	# grab all valid extension IDs
	curExtensions=( $allExcept )

	# append each one with its path
	for curExt in "${curExtensions[@]}" ; do

	    # only operate on valid extension IDs
	    if [[ "$curExt" =~ ^[a-z]{32}$ ]] ; then
		myExtensions+="${curExt}|$curExtDirPath"$'\n'
	    fi
	done
    done
    
    # move back out of extensions directory
    try '!1' popd 'Unable to restore working directory.'
    if [[ ! "$ok" ]] ; then
	myGlobalError=1 ; ok=1
    fi
    
    # sort extension IDs
    local oldIFS="$IFS" ; IFS=$'\n'
    curExtensions=( $(echo "$myExtensions" | \
			  try '-1' /usr/bin/sort 'Unable to sort extensions.' ) )
    if [[ "$?" != 0 ]] ; then
	ok=1 ; errmsg="Unable to create list of installed extensions."
	IFS="$oldIFS"
	return 1
    fi
    IFS="$oldIFS"

    # uniquify extension IDs
    local prevExtID=
    myExtensions=()
    for curExt in "${curExtensions[@]}" ; do
	
	if [[ "${curExt%%|*}" = 'EPIEXTIDRELEASE' ]] ; then

	    # don't include the Epichrome Runtime extension
	    prevExtId="${curExt%%|*}"
	    
	elif [[ "$prevExtID" != "${curExt%%|*}" ]] ; then

	    # first time seeing this ID, so add id
	    myExtensions+=( "$curExt" )
	    prevExtID="${curExt%%|*}"
	fi
    done
    
    # important paths
    local welcomeExtGenericIcon="$SSBAppPath/Contents/$appWelcomePath/img/ext_generic_icon.png"
    local epiExtIconPath="$epiDataPath/$epiDataExtIconBase"
    
    # ensure extension icons directory exists
    if [[ "${#myExtensions[@]}" != 0 ]] ; then
	
	try /bin/mkdir -p "$epiExtIconPath" \
	    'Unable to create extension icon directory.'
	if [[ ! "$ok" ]] ; then
	    ok=1
	    return 1
	fi
    fi

    
    # GET INFO ON ALL EXTENSIONS

    # status variables & constants
    local c
    local curExtID curExtPath curExtVersions curExtVersionPath
    local mani mani_icons mani_name mani_default_locale mani_app
    local curIconSrc biggestIcon
    local curLocale=
    local curExtLocalePath
    local curMessageID msg msg_message
    local iconRe='^([0-9]+):(.+)$'

    # loop through every extension
    for curExt in "${myExtensions[@]}" ; do
	
	debuglog "Adding extension ID $curExt to welcome page."

	# break out extension ID & path
	curExtID="${curExt%%|*}"
	curExtPath="${curExt#*|}/$curExtID"
	
	
	# PARSE EXTENSION'S MANIFEST
	
	# get extension version directories
	curExtVersions=( "$curExtPath"/* )
	if [[ ! "${curExtVersions[*]}" ]] ; then
	    errlog "Unable to get version for extension $curExtID."
	    myFailedExtensions+=( "$curExtID" )
	    continue
	fi
	
	# get latest version path
	curExtVersionPath=
	for c in "${curExtVersions[@]}" ; do
	    [[ "$c" > "$curExtVersionPath" ]] && curExtVersionPath="$c"
	done
	curExtPath="$curExtVersionPath"
	
	# read manifest
	try 'mani=' /bin/cat "$curExtPath/manifest.json" \
	    "Unable to read manifest for $curExt."
	if [[ ! "$ok" ]] ; then
	    myFailedExtensions+=( "$curExtID" )
	    ok=1 ; errmsg=
	    continue
	fi
	
	# pull out icon and name info
	readjsonkeys mani icons name default_locale app
	
	# for now, ignore apps
	[[ "$mani_app" ]] && continue
	
	
	# COPY BIGGEST ICON TO WELCOME PAGE (IF NOT FOUND)
	
	curExtIcon=( "$epiExtIconPath/$curExtID".* )
	if [[ -f "${curExtIcon[0]}" ]] ; then
	    
	    # there's already an icon for this ID, so use that
	    curExtIcon="${curExtIcon[0]##*/}"
	    
	    debuglog "Found cached icon $curExtIcon."
	    
	else
	    
	    # no icon found, so we have to copy it

	    debuglog "No icon cached for extension $curExtID. Attempting to copy from extension."
	    
	    curIconSrc=
	    biggestIcon=0
	    if [[ "$mani_icons" ]] ; then
		# remove all newlines
		mani_icons="${mani_icons//$'\n'/}"
		
		# munge entries into parsable lines
		oldIFS="$IFS" ; IFS=$'\n'
		mani_icons=( $(echo "$mani_icons" | \
				   /usr/bin/sed -E \
						's/[^"]*"([0-9]+)"[ 	]*:[ 	]*"(([^\"]|\\\\|\\")*)"[^"]*/\1:\2\'$'\n''/g' 2> /dev/null) )
		if [[ "$?" != 0 ]] ; then
		    errlog "Unable to parse icons for extension $curExtID."
		    myFailedExtensions+=( "$curExtID" )
		    continue
		fi
		IFS="$oldIFS"
		
		# find biggest icon
		for c in "${mani_icons[@]}" ; do
		    if [[ "$c" =~ $iconRe ]] ; then
			if [[ "${BASH_REMATCH[1]}" -gt "$biggestIcon" ]] ; then
			    biggestIcon="${BASH_REMATCH[1]}"
			    curIconSrc="$(unescapejson "${BASH_REMATCH[2]}")"
			fi
		    fi
		done
	    fi
	    
	    # get full path to icon (or generic, if none found)
	    if [[ ! "$curIconSrc" ]] ; then
		errlog "No icon found for extension $curExtID."
		curIconSrc="$welcomeExtGenericIcon"
	    else
		curIconSrc="$curExtPath/${curIconSrc#/}"
	    fi
	    
	    # create welcome-page icon name
	    curExtIcon="$curExtID.${curIconSrc##*.}"
	    
	    # copy icon to welcome page
	    try /bin/cp "$curIconSrc" "$epiExtIconPath/$curExtIcon" \
		"Unable to copy icon for extension $curExtID."
	    if [[ ! "$ok" ]] ; then
		myFailedExtensions+=( "$curExtID" )
		ok=1 ; errmsg=
		continue
	    fi
	fi
	
	
	# GET NAME
	
	if [[ "$mani_name" =~ ^__MSG_(.+)__$ ]] ; then
	    
	    # get message ID
	    curMessageID="${BASH_REMATCH[1]}"
	    
	    # set locale if not already set
	    if [[ ! "$curLocale" ]] ; then
		if [[ "$LC_ALL" ]] ; then
		    curLocale="$LC_ALL"
		elif [[ "$LC_MESSAGES" ]] ; then
		    curLocale="$LC_MESSAGES"
		elif [[ "$LANG" ]] ; then
		    curLocale="$LANG"
		else
		    curLocale='en_US'
		fi

		# cut off any cruft
		curLocale="${curLocale%%.*}"
	    fi

	    # try to find the appropriate directory
	    curExtLocalePath="$curExtPath/_locales"
	    if [[ -d "$curExtLocalePath/$curLocale" ]] ; then
		curExtLocalePath="$curExtLocalePath/$curLocale"
	    elif [[ -d "$curExtLocalePath/${curLocale%%_*}" ]] ; then
		curExtLocalePath="$curExtLocalePath/${curLocale%%_*}"
	    elif [[ "$mani_default_locale" && -d "$curExtLocalePath/$mani_default_locale" ]] ; then
		curExtLocalePath="$curExtLocalePath/$mani_default_locale"
	    else
		# failed to match, so pick any
		for c in "$curExtLocalePath"/* ; do
		    if [[ -d "$c" ]] ; then
			curExtLocalePath="$c"
			break
		    else
			curExtLocalePath=
		    fi
		done
	    fi
	    
	    # create local variable for message
	    local "msg_${curMessageID}="
	    
	    # read in locale messages file
	    msg="$curExtLocalePath/messages.json"
	    if [[ "$curExtLocalePath" && ( -f "$msg" ) ]] ; then
		try 'msg=' /bin/cat "$msg" \
		    "Unable to read locale ${curExtLocalePath##*/} messages for extension $curExtID. Using ID as name."
		if [[ "$ok" ]] ; then

		    # clear mani_name
		    mani_name=
		    
		    # try to pull out name message
		    readjsonkeys msg "$curMessageID"
		    eval "msg=\"\$msg_${curMessageID}\""
		    if [[ "$msg" ]] ; then
			readjsonkeys msg message
			mani_name="$msg_message"
		    fi

		    # check for error
		    [[ "$mani_name" ]] || \
			errlog "Unable to get locale ${curExtLocalePath##*/} name for extension $curExtID. Using ID as name."
		else
		    
		    # failed to read locale JSON file, so no name
		    mani_name=
		    ok=1 ; errmsg=
		fi
	    else
		mani_name=
		errlog "Unable to find locale ${curExtLocalePath##*/} messages for extension $curExtID. Using ID as name."
	    fi
	fi
	
	
	# SUCCESS! ADD EXTENSION OR APP TO WELCOME PAGE ARGS
	
	[[ "$result" ]] && result+='&'
	#[[ "$mani_app" ]] && result+='a=' || result+='x='
	result+="x=$(encodeurl "${curExtIcon},$mani_name")"
	
	# report success
	mySuccessfulExtensions+=( "$curExtID" )
    done	    
    
    # restore nullglob and extended glob
    shoptrestore myShoptState

    # write out result variable
    eval "${resultVar}=\"\$result\""
    
    # return error states
    if [[ "$myGlobalError" || \
	      ( "${myFailedExtensions[*]}" && ! "${mySuccessfulExtensions[*]}" ) ]] ; then

	return 1
    elif [[ "${myFailedExtensions[*]}" && "${mySuccessfulExtensions[*]}" ]] ; then

	# some succeeded, some failed, so report list of failures
	errmsg="${myFailedExtensions[*]}"
	errmsg="${errmsg// /, }"
	return 2
    else
	return 0
    fi
}


# CANONICALIZE -- canonicalize a path
function canonicalize { # ( path )
    local rp=
    local result=
    if [[ "$path" ]] ; then
	result=$(unset CDPATH && try '!12' cd "$1" '' && try 'rp=' pwd -P '' && echo "$rp")
    fi
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


# GETBROWSERINFO: try to return info on known browsers
function getbrowserinfo { # ( var [id] )

    # arguments
    local var="$1" ; shift
    local id="$1" ; shift
    
    [[ "$id" ]] || id="${SSBEngineType#*|}"

    if [[ "$id" ]] ; then
	eval "${var}=( \"\${appBrowserInfo_${id//./_}[@]}\" )"
    else
	eval "${var}="
    fi
}


# GETEXTENGINESRCINFO: find external engine source app on the system & get info on it
#                      if successful, it sets the SSBEngineSourceInfo variable
function getextenginesrcinfo { # ( [myExtEngineSrcPath] )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # argument
    local myExtEngineSrcPath="$1" ; shift
    
    # set up list of search locations/methods
    local searchList=()
    if [[ "$myExtEngineSrcPath" ]] ; then

	# if we were passed a specific path, only check that
	searchList=( "$myExtEngineSrcPath" FAIL )
    else
	# otherwise, search known locations & spotlight
	
	# try to get the display name of the engine app
	local engineDispName=
	getbrowserinfo 'engineDispName'
	engineDispName="${engineDispName[$iDisplayName]}"
	
	# if we know the name of the app, search in the usual places
	if [[ "$engineDispName" ]] ; then
	    searchList=( "$HOME/Applications/$engineDispName.app" \
			     "/Applications/$engineDispName.app" )
	else
	    engineDispName="${SSBEngineType#*|}"
	fi
	
	# always search with spotlight
	searchList+=( SPOTLIGHT FAIL )
    fi
    
    # assume failure
    SSBEngineSourceInfo=()
    
    # try various methods to find & validate external engine browser
    local myEngineSourcePath=
    for curPath in "${searchList[@]}" ; do
	
	if [[ "$curPath" = FAIL ]] ; then

	    # failure
	    debuglog 'External engine $engineDispName not found.'
	    break
	    
	elif [[ "$curPath" = SPOTLIGHT ]] ; then

	    debuglog "Searching Spotlight for instances of $engineDispName..."
	    
	    # search spotlight
	    try 'myEngineSourcePath=(n)' /usr/bin/mdfind \
		"kMDItemCFBundleIdentifier == '${SSBEngineType#*|}'" ''
	    if [[ "$ok" ]] ; then
		
		# use the first instance
		myEngineSourcePath="${myEngineSourcePath[0]}"
	    else
		debuglog "Spotlight found no instances of $engineDispName."
		myEngineSourcePath=
		ok=1 ; errmsg=
	    fi
	else

	    debuglog "Trying path '$curPath'..."
	    
	    # regular path, so check it
	    if [[ -d "$curPath" ]] ; then
		myEngineSourcePath="$curPath"
	    fi
	fi
	
	# if nothing found, try next
	[[ "$myEngineSourcePath" ]] || continue
	
	# validate any found path
	
	# check that Info.plist exists
	if [[ ! -e "$myEngineSourcePath/Contents/Info.plist" ]] ; then
	    debuglog "No app found at '$myEngineSourcePath'"
	    continue
	fi
	
	# parse Info.plist -- create list in same order as SSBEngineSourceInfo
	local infoPlist=()
	try 'infoPlist=(n)' /usr/libexec/PlistBuddy \
	    -c 'Print CFBundleIdentifier' \
	    -c 'Print CFBundleExecutable' \
	    -c 'Print CFBundleName' \
	    -c 'Print CFBundleDisplayName' \
	    -c 'Print CFBundleShortVersionString' \
	    -c 'Print CFBundleIconFile' \
	    -c 'Print CFBundleDocumentTypes:0:CFBundleTypeIconFile' \
	    "$myEngineSourcePath/Contents/Info.plist" ''
	if [[ ! "$ok" ]] ; then
	    ok=1 ; errmsg=
	    debuglog "Unable to parse Info.plist at '$myEngineSourcePath'"
	    continue
	fi
	
	# check bundle ID
	if [[ "${infoPlist[$iID]}" != "${SSBEngineType#*|}" ]] ; then
	    debuglog "Found ID ${infoPlist[$iID]} instead of ${SSBEngineType#*|} at '$myEngineSourcePath'"
	    continue
	fi
	
	# make sure the executable is in place
	local curExecPath="$myEngineSourcePath/Contents/MacOS/${infoPlist[$iExecutable]}"
	if [[ ! ( -f "$curExecPath" && -x "$curExecPath" ) ]] ; then
	    debuglog "No valid executable at '$myEngineSourcePath'"
	    continue
	fi
	
	# if we got here, we have a complete copy of the browser,
	# so set SSBEngineSourceInfo & break out
	SSBEngineSourceInfo=( "${infoPlist[@]}" )
	SSBEngineSourceInfo[$iPath]="$myEngineSourcePath"
	
	debuglog "External engine ${SSBEngineSourceInfo[$iDisplayName]} ${SSBEngineSourceInfo[$iVersion]} found at '${SSBEngineSourceInfo[$iPath]}'."
	
	break	
    done
}


# INSTALLNMH -- install native messaging host
function installnmh {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # paths to host manifests with new and old IDs
    local nmhManifestDestPath="$myProfilePath/$nmhDirName"    
    local nmhManifestNewDest="$nmhManifestDestPath/$nmhManifestNewFile"
    local nmhManifestOldDest="$nmhManifestDestPath/$nmhManifestOldFile"

    # determine which manifests to update
    local updateOldManifest=
    local updateNewManifest=
    if [[ "$myStatusNewApp" || "$myStatusNewVersion" || \
	      ( "$SSBAppPath" != "$configSSBAppPath" ) ]] ; then
	
	# this is the first run on a new version, or app has moved, so update both
	updateOldManifest=1
	updateNewManifest=1
    else
	
	# update any that are missing
	[[ ! -e "$nmhManifestOldDest" ]] && updateOldManifest=1
	[[ ! -e "$nmhManifestNewDest" ]] && updateNewManifest=1
    fi

    if [[ "$updateOldManifest" || "$updateNewManifest" ]] ; then
	
	# get source NMH script path
	local hostSourcePath="$SSBAppPath/Contents/Resources/NMH"
	local hostScriptPath="$hostSourcePath/$appNMHFile"
	
	# create the install directory if necessary
	if [[ ! -d "$nmhManifestDestPath" ]] ; then
	    try /bin/mkdir -p "$nmhManifestDestPath" \
		'Unable to create native messaging host folder.'
	fi
	
	# stream-edit the new manifest into place  $$$$ ESCAPE DOUBLE QUOTES IN PATH??
	if [[ "$updateNewManifest" ]] ; then
	    debuglog "Installing host manifest for $nmhManifestNewID."
	    filterfile "$hostSourcePath/$nmhManifestNewFile" "$nmhManifestNewDest" \
		       'native messaging host manifest' \
		       APPHOSTPATH "$hostScriptPath"
	fi
	
	# duplicate the new manifest with the old ID
	if [[ "$updateOldManifest" ]] ; then
	    debuglog "Installing host manifest for $nmhManifestOldID."
	    filterfile "$nmhManifestNewDest" "$nmhManifestOldDest" \
		       'old native messaging host manifest' \
		       "$nmhManifestNewID" "$nmhManifestOldID"
	fi
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1
}


# LINKEXTERNALNMHS -- link to native message hosts from compatible browsers
function linkexternalnmhs {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # paths to NMH directories for compatible browsers
    
    # get path to destination NMH manifest directory
    local myHostDir="$myProfilePath/$nmhDirName"

    # list of NMH directories to search
    local myNMHBrowsers=()
    
    # favor hosts from whichever browser our engine is using
    if [[ "${SSBEngineType%%|*}" != internal ]] ; then

	# see if the current engine is in the list
	local curBrowser= ; local i=0
	for curBrowser in "${appExtEngineBrowsers[@]}" ; do
	    if [[ "${SSBEngineType#*|}" = "$curBrowser" ]] ; then
		
		debuglog "Prioritizing ${SSBEngineType#*|} native messaging hosts."
		
		# engine found, so bump it to the end of the list (giving it top priority)
		myNMHBrowsers=( "${appExtEngineBrowsers[@]::$i}" \
				     "${appExtEngineBrowsers[@]:$(($i + 1))}" \
				     "$curBrowser" )
		break
	    fi
	    i=$(($i + 1))
	done
    fi
    
    # for internal engine, or if external engine not found, use vanilla list
    [[ "${myNMHBrowsers[*]}" ]] || myNMHBrowsers=( "${appExtEngineBrowsers[@]}" )
    
    # navigate to our host directory (report error)
    try '!1' pushd "$myHostDir" "Unable to navigate to '$myHostDir'."
    if [[ ! "$ok" ]] ; then
	ok=1 ; return 1
    fi
    
    # turn on nullglob
    local shoptState=
    shoptset shoptState nullglob
    
    # get list of host files currently installed
    hostFiles=( * )

    # collect errors
    local myError=
    
    # remove dead host links
    local curFile=
    for curFile in "${hostFiles[@]}" ; do
	if [[ -L "$curFile" && ! -e "$curFile" ]] ; then
	    try rm -f "$curFile" "Unable to remove dead link to $curFile."
	    if [[ ! "$ok" ]] ; then
		[[ "$myError" ]] && myError+=' '
		myError+="$errmsg"
		ok=1 ; errmsg=
		continue
	    fi
	fi
    done
    
    # link to hosts from both directories
    local curHost=
    local curHostDir=
    local curError=
    for curHost in "${myNMHBrowsers[@]}" ; do

	# get only the data directory
	getbrowserinfo 'curHostDir' "$curHost"
	if [[ ! "${curHostDir[$iLibraryPath]}" ]] ; then
	    curError="Unable to get data directory for browser $curHost."
	    errlog "$curError"
	    [[ "$myError" ]] && myError+=' '
	    myError+="$curError"
	    continue
	fi
	curHostDir="$userSupportPath/${curHostDir[$iLibraryPath]}/$nmhDirName"
	
	if [[ -d "$curHostDir" ]] ; then
	    
	    # get a list of all hosts in this directory
	    try '!1' pushd "$curHostDir" "Unable to navigate to ${curHostDir}"
	    if [[ ! "$ok" ]] ; then
		[[ "$myError" ]] && myError+=' '
		myError+="$errmsg"
		ok=1 ; errmsg=
		continue
	    fi
	    
	    hostFiles=( * )
	    
	    try '!1' popd "Unable to navigate away from ${curHostDir}"
	    if [[ ! "$ok" ]] ; then
		[[ "$myError" ]] && myError+=' '
		myError+="$errmsg"
		ok=1 ; errmsg=
		continue
	    fi
	    
	    # link to any hosts that are not already in our directory or are
	    # links to a different file -- this way if a given host is in
	    # multiple NMH directories, whichever we hit last wins
	    for curFile in "${hostFiles[@]}" ; do
		if [[ ( ! -e "$curFile" ) || \
			  ( -L "$curFile" && \
				! "$curFile" -ef "${curHostDir}/$curFile" ) ]] ; then

		    debuglog "Linking to native messaging host at ${curHostDir}/$curFile."

		    # symbolic link to current native messaging host
		    try ln -sf "${curHostDir}/$curFile" "$curFile" \
			"Unable to link to native messaging host ${curFile}."
		    if [[ ! "$ok" ]] ; then
			[[ "$myError" ]] && myError+=' '
			myError+="$errmsg"
			ok=1 ; errmsg=
			continue
		    fi
		fi
	    done
	fi
    done
    
    # silently return to original directory
    try '!1' popd "Unable to navigate away from '$myHostDir'."
    if [[ ! "$ok" ]] ; then
	[[ "$myError" ]] && myError+=' '
	myError+="$errmsg"
	ok=1 ; errmsg=
	continue
    fi
    
    # restore nullglob
    shoptrestore shoptState
    
    # return success or failure
    if [[ "$myError" ]] ; then
	errmsg="$myError"
	return 1
    else
	errmsg=
	return 0
    fi
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
    if [[ -x "$inactivePath/MacOS/${SSBEngineSourceInfo[$iExecutable]}" && \
	      -f "$inactivePath/Info.plist" && \
	      -x "$myEngineAppPath/Contents/MacOS/${SSBEngineSourceInfo[$iExecutable]}" && \
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
    if ! waitforcondition "engine $oldInactiveError executable to appear" 5 .5 \
	 test -x "$myEngineAppContents/MacOS/${SSBEngineSourceInfo[$iExecutable]}" ; then
	ok=
	errmsg="Engine $oldInactiveError executable not found."
	errlog "$errmsg"
	return 1
    fi
    
    [[ "$debug" ]] && ( de= ; [[ "$newState" != ON ]] && de=de ; errlog "Engine ${de}activated." )
    
} ; export -f setenginestate


# DELETEENGINE -- delete Epichrome engine
function deleteengine {

    # save OK state
    local oldOK="$ok"
    
    debuglog "Deleting engine at '$SSBEnginePath'"
    
    # $$$$ TEMP FOR KILLING THE UNKILLABLE BETA 6 ENGINE UGH
    tryalways /bin/chmod -R u+w "$SSBEnginePath" 'Warning -- Unable to fix permissions for old engine.'
    
    # delete engine
    tryalways /bin/rm -rf "$SSBEnginePath" 'Warning -- Unable to remove old engine.'

    # handle errors
    if [[ ! "$ok" ]] ; then
	ok="$oldOK"
	[[ "$ok" ]] && errmsg=
	return 1
    fi

    return 0
}


# CREATEENGINE -- create Epichrome engine (payload & placeholder)
function createengine {

    # only run if we're OK
    [[ "$ok" ]] || return 1

    
    # CLEAR OUT ANY OLD ENGINE
    
    if [[ -d "$SSBEnginePath" ]] ; then

	debuglog "Removing old engine at '$SSBEnginePath'"
	
	# $$$$ FIX PERMISSIONS FOR BETA 6 -- REMOVE FOR RELEASE
	try /bin/chmod -R u+w "$SSBEnginePath" 'Unable to fix permissions for old engine.'
	
	# remove old engine
	try /bin/rm -rf "$SSBEnginePath" 'Unable to clear old engine.'
    fi
    
    
    # CREATE NEW ENGINE
    
    try /bin/mkdir -p "$SSBEnginePath" 'Unable to create new engine.'
    [[ "$ok" ]] || return 1
    
    debuglog "Creating ${SSBEngineType%%|*} ${SSBEngineSourceInfo[$iName]} engine at '$SSBEnginePath'."
    
    if [[ "${SSBEngineType%%|*}" != internal ]] ; then
	
	# EXTERNAL ENGINE PAYLOAD
	
	# make sure we have a source for the payload
	if [[ ! -d "${SSBEngineSourceInfo[$iPath]}" ]] ; then
	    
	    # we should already have this, so as a last ditch, ask the user to locate it
	    local myExtEngineSourcePath=
	    local myExtEngineName=
	    getbrowserinfo 'myExtEngineName'
	    myExtEngineName="${myExtEngineName[$iDisplayName]}"
	    [[ "$myExtEngineName" ]] || myExtEngineName="${SSBEngineType#*|}"
	    
	    try 'myExtEngineSourcePath=' osascript -e \
		"return POSIX path of (choose application with title \"Locate $myExtEngineName\" with prompt \"Please locate $myExtEngineName\" as alias)" \
		"Locate engine app dialog failed."
	    myExtEngineSourcePath="${myExtEngineSourcePath%/}"
	    
	    if [[ ! "$ok" ]] ; then
		
		# we've failed to find the engine browser
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find $myExtEngineName.$errmsg"
		return 1
	    fi
	    
	    # user selected a path, so check it
	    getextenginesrcinfo "$myExtEngineSourcePath"
	    
	    if [[ ! "${SSBEngineSourceInfo[$iPath]}" ]] ; then
		ok= ; errmsg="Selected app is not a valid instance of $myExtEngineName."
		return 1
	    fi
	    
	    # # warn if we're not using the selected app  $$$ IRRELEVANT NOW
	    # if [[ "${SSBEngineSourceInfo[$iPath]}" != "$myExtEngineSourcePath" ]] ; then
	    # 	alert "Selected app is not a valid instance of Google Chrome. Using '$SSBExtEngineSrcPath' instead." \
	    # 	      'Warning' '|caution'
	    # fi
	fi
	
	# make sure external browser is on the same volume as the engine
	if ! issamedevice "${SSBEngineSourceInfo[$iPath]}" "$SSBEnginePath" ; then
	    ok= ; errmsg="${SSBEngineSourceInfo[$iDisplayName]} is not on the same volume as this app's data directory."
	    return 1
	fi
	
	# create Payload directory
	try /bin/mkdir -p "$myEnginePayloadPath/Resources" \
	    "Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
	
	# turn on extended glob for copying
	local shoptState=
	shoptset shoptState extglob
	
	# copy all of the external browser except Framework and Resources
	local allExcept='!(Frameworks|Resources)'
	try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/"$allExcept \
	    "$myEnginePayloadPath" \
	    "Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
	
	# copy Resources, except icons
	allExcept='!(*.icns)'
	try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/Resources/"$allExcept \
	    "$myEnginePayloadPath/Resources" \
	    "Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine resources to payload."
	
	# restore extended glob
	shoptrestore shoptState
	
	# hard link to external engine browser Frameworks
	linktree "${SSBEngineSourceInfo[$iPath]}/Contents" "$myEnginePayloadPath" \
		 "${SSBEngineSourceInfo[$iDisplayName]} app engine" 'payload' 'Frameworks'
	
	# filter localization files
	filterlproj "$myEnginePayloadPath/Resources" \
		    "${SSBEngineSourceInfo[$iDisplayName]} app engine"
	
	# link to this app's icons
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
	    "$myEnginePayloadPath/Resources/${SSBEngineSourceInfo[$iAppIconFile]}" \
	    "Unable to copy app icon to ${SSBEngineSourceInfo[$iDisplayName]} app engine."
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
	    "$myEnginePayloadPath/Resources/${SSBEngineSourceInfo[$iDocIconFile]}" \
	    "Unable to copy document icon file to ${SSBEngineSourceInfo[$iDisplayName]} app engine."


	# EXTERNAL ENGINE PLACEHOLDER
	
	# clear out any old active app
	if [[ -d "$myEngineAppPath" ]] ; then
	    try /bin/rm -rf "$myEngineAppPath" \
		"Unable to clear old ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder."
	    [[ "$ok" ]] || return 1
	fi
	
	# create active placeholder app bundle
	try /bin/mkdir -p "$myEngineAppPath/Contents/MacOS" \
	    "Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder."
	
	# filter Info.plist from payload
	filterplist "$myEnginePayloadPath/Info.plist" \
		    "$myEngineAppPath/Contents/Info.plist" \
		    "${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder Info.plist" \
		    'Add :LSUIElement bool true' \
		    'Delete :CFBundleDocumentTypes' \
		    'Delete :CFBundleURLTypes'
#		    "Set :CFBundleShortVersionString $SSBVersion" \   $$$$ BAD IDEA?
	
	# path to placeholder resources in the app
	local myAppPlaceholderPath="$SSBAppPath/Contents/$appEnginePath"
	
	# copy in placeholder executable
	try /bin/cp "$myAppPlaceholderPath/PlaceholderExec" \
	    "$myEngineAppPath/Contents/MacOS/${SSBEngineSourceInfo[$iExecutable]}" \
	    "Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder executable."
	
	# copy Resources directory from payload
	try /bin/cp -PR "$myEnginePayloadPath/Resources" "$myEngineAppPath/Contents" \
	    "Unable to copy resources from ${SSBEngineSourceInfo[$iDisplayName]} app engine payload to placeholder."
	
	# copy in scripts
	try /bin/cp -PR "$myAppPlaceholderPath/Scripts" \
	    "$myEngineAppPath/Contents/Resources" \
	    "Unable to copy scripts to ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder."
	
    else
	
	# INTERNAL ENGINE PAYLOAD
	
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
	
	# copy icons to payload
	safecopy "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
		 "$myEnginePayloadPath/Resources/$CFBundleIconFile" \
		 "engine app icon"
	safecopy "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
		 "$myEnginePayloadPath/Resources/$CFBundleTypeIconFile" \
		 "engine document icon"
	
	# hard link large payload items from Epichrome
	linktree "$epiCurrentPath/Contents/Resources/Runtime/Engine/Link" \
		 "$myEnginePayloadPath" 'app engine' 'payload'


	# INTERNAL ENGINE PLACEHOLDER
	
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

	# copy Resources directory from payload
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


# UPDATEENGINEMANIFEST: check the status of the engine info manifest and create/update as necessary
function updateenginemanifest {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # path to manifest
    local myEngineManifest="$SSBEnginePath/info.json"

    # if no manifest, or if main app has moved, create a new one
    if [[ ( ! -f "$myEngineManifest" ) || \
	      ( "$SSBAppPath" != "$configSSBAppPath" ) ]] ; then

	debuglog "Writing new engine manifest."
	
	try "$myEngineManifest<" echo \
'{
	"version": "'"$SSBVersion"'",
	"appID": "'"$SSBIdentifier"'",
	"appName": "'"$CFBundleName"'",
	"appDisplayName": "'"$CFBundleDisplayName"'",
	"appPath": "'"$SSBAppPath"'"
}' 'Unable to write engine manifest.'
    fi
    
    [[ "$ok" ]] && return 0 || return 1
}


# UPDATECENTRALNMH
function updatecentralnmh {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # relevant paths
    local centralNMHPath=
    getbrowserinfo 'centralNMHPath' 'com.google.Chrome'
    local centralNMHPath="$userSupportPath/${centralNMHPath[$iLibraryPath]}/$nmhDirName"
    local oldManifestPath="$centralNMHPath/$nmhManifestOldFile"
    local newManifestPath="$centralNMHPath/$nmhManifestNewFile"
    
    # Epichrome version and path to pull new manifest from
    local sourceVersion="$epiCurrentVersion"
    local sourcePath="$epiCurrentPath"
    if [[ ! "$sourceVersion" ]] ; then
	sourceVersion="$epiLatestVersion"
	sourcePath="$epiLatestPath"
    fi
    
    # assume no update
    local doUpdate=
    
    # if either is missing, update both
    if [[ ! ( ( -f "$oldManifestPath" ) && ( -f "$newManifestPath" ) ) ]] ; then
	doUpdate=1
	debuglog 'One or more manifests missing.'
    fi

    if [[ ! "$doUpdate" ]] ; then
	
	# regex for version and path
	local info_re='Host ([0-9.a-zA-Z]+)".*"path": *"([^"]+)"'
	
	# read in one of the manifests
	try 'curManifest=' /bin/cat "$newManifestPath" 'Unable to read central manifest.'
	[[ "$ok" ]] || return 1
	
	# check current manifest version & path
	if [[ "$curManifest" =~ $info_re ]] ; then

	    # bad path
	    if [[ ! -e "${BASH_REMATCH[2]}" ]] ; then
		doUpdate=1
		debuglog 'Central native messaging host has moved.'
	    else
		local curManifestVersion="${BASH_REMATCH[1]}"
	    fi
	else
	    
	    # unreadable manifest
	    doUpdate=1
	    debuglog 'Unable to parse central manifest.'
	fi
    fi

    # we're supposed to update but there's no Epichrome
    if [[ "$doUpdate" && ! "$sourceVersion" ]] ; then
	ok=
	errmsg='Epichrome not found.'
	return 1
    fi

    # manifests still look OK, so check if version is out of date
    if [[ ! "$doUpdate" ]] ; then
	if vcmp "$curManifestVersion" '<' "$SSBVersion" ; then
	    doUpdate=1
	    debuglog 'Central manifest version is out of date.'
	fi
    fi
    
    # if any of the above triggered an update, do it now
    if [[ "$doUpdate" ]] ; then

	debuglog 'Installing central native messaging host manifests.'
	
	# path to Epichrome NMH items
	local nmhScript="$sourcePath/Contents/Resources/Scripts/$appNMHFile"
	local sourceManifest="$sourcePath/Contents/Resources/Runtime/Contents/Resources/NMH/$nmhManifestNewFile"

	# make sure directory exists
	try /bin/mkdir -p "$centralNMHPath" \
	    'Unable to create central native messaging host directory.'
	
	# new ID
	filterfile "$sourceManifest" \
		   "$newManifestPath" \
		   "$nmhManifestNewFile" \
		   APPHOSTPATH "$nmhScript"
	
	# old ID
	filterfile "$sourceManifest" \
		   "$oldManifestPath" \
		   "$nmhManifestOldFile" \
		   APPHOSTPATH "$nmhScript" \
		   "$nmhManifestNewID" "$nmhManifestOldID"
    fi

    [[ "$ok" ]] && return 0 || return 1
}


# SETMASTERPREFS: if needed, install master prefs to central engine data directory
myMasterPrefsState=
function setmasterprefs {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # initialize state
    myMasterPrefsState=
    
    if [[ ! ( -e "$myFirstRunFile" || -e "$myPreferencesFile" ) ]] ; then

	# this looks like a first run, so set master prefs
	debuglog "Setting master prefs for new profile."
	
	# get path to master prefs file for this engine
	local myEngineBrowser=
	getbrowserinfo myEngineBrowser
	local myEngineMasterPrefsFile="$userSupportPath/${myEngineBrowser[$iLibraryPath]}/${myEngineBrowser[$iMasterPrefsFile]}"
	local mySavedMasterPrefsFile="$myDataPath/${myEngineBrowser[$iMasterPrefsFile]}"

	# backup browser's master prefs
	if [[ -e "$myEngineMasterPrefsFile" ]] ; then

	    debuglog "Backing up browser master prefs."
	    
	    try /bin/mv -f "$myEngineMasterPrefsFile" "$mySavedMasterPrefsFile" \
		'Unable to back up browser master prefs.'
	fi
	
	# install our master prefs
	try /bin/cp "$SSBAppPath/Contents/Resources/Profile/Prefs/prefs_${myEngineBrowser[$iID]//./_}.json" \
	    "$myEngineMasterPrefsFile" \
	    'Unable to install app master prefs.'
	
	if [[ "$ok" ]] ; then

	    # success! set state
	    myMasterPrefsState=( "$myEngineMasterPrefsFile" "$mySavedMasterPrefsFile" )
	    
	else
	    
	    # on error, restore any backup we just made
	    if [[ -e "$mySavedMasterPrefsFile" && ! -e "$myEngineMasterPrefsFile" ]] ; then
		tryalways /bin/mv -f "$mySavedMasterPrefsFile" "$myEngineMasterPrefsFile" \
			  'Unable to restore browser master prefs.'
	    fi

	    return 1
	fi
    else

	# return state for no master prefs installed
	return 2
    fi

    return 0
}


# CLEARMASTERPREFS: wait for master prefs to be read, then clear master prefs file
function clearmasterprefs {

    # only run if we have actually set the master prefs
    if [[ "$myMasterPrefsState" ]] ; then

	if ! waitforcondition 'app prefs to appear' 5 .5 \
	     test -e "$myPreferencesFile" ; then
	    ok=
	    errmsg="Timed out waiting for app prefs to appear."
	    errlog "$errmsg"
	fi
	
	if [[ -e "${myMasterPrefsState[1]}" ]] ; then
	    
	    # backup found, so restore browser master prefs
	    debuglog "Restoring browser master prefs."
	    
	    tryalways /bin/mv -f "${myMasterPrefsState[1]}" "${myMasterPrefsState[0]}" \
		      'Unable to restore browser master prefs.'
	    
	    # on any error, remove any remaining backup master prefs
	    [[ "$ok" ]] || tryalways /bin/rm -f "${myMasterPrefsState[1]}" \
				     'Unable to remove backup browser master prefs.'
	    
	else
	    # no backup, so just remove app master prefs
	    debuglog "Removing app master prefs."
	    
	    tryalways /bin/rm -f "${myMasterPrefsState[0]}" \
		      'Unable to remove app master prefs.'
	fi
		
	# clear state
	myMasterPrefsState=	
    fi

    # return error state
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
function writeconfig {  # ( myConfigFile force )
    
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
	
	[[ "$doWrite" ]] && debuglog "Configuration variables have changed."
    else
	debuglog "Forced update."
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
	'Got error launching Epichrome helper app.'

    if [[ ! "$ok" ]] ; then
	return 0
    else

	# check the process table for our helper
	function checkforhelper {
	    local pstable=
	    try 'pstable=' /bin/ps -x 'Unable to list active processes.'
	    if [[ ! "$ok" ]] ; then
		ok=1 ; errmsg=
		return 1
	    fi
	    if [[ "$pstable" == *"$SSBAppPath/Contents/$appHelperPath/Contents/MacOS"* ]] ; then
		return 0
	    else
		return 1
	    fi
	}
	
	# give our helper five seconds to launch
	if ! waitforcondition 'Epichrome helper to launch' 5 .5 checkforhelper ; then
	    ok=
	    errmsg="Epichrome helper app failed to launch."
	    errlog "$errmsg"
	fi
	unset -f checkforhelper
	
	# return code
	[[ "$ok" ]] && return 0 || return 1
    fi
}
