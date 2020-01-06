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


# LINKTREE: hard link to a directory or file
function linktree { # $1 = sourcedir (absolute)
    #                 $2 = destdir (absolute)
    #                 $3 = try error identifier
    #                 $@ = <files>

    if [[ "$ok" ]]; then

	# read arguments
	local sourcedir="$1"  # could absolutize: echo "$(cd "$foo" 2> /dev/null && pwd)"
	local destdir="$2"
	local tryid="$3"
	shift 3

	# make sure both directories are on the same filesystem
	local sourceDevice=
	try 'sourceDevice=' /usr/bin/stat -f '%d' "$sourcedir" \
	    "Unable to get info on $sourcedir."
	local destDevice=
	try 'destDevice=' /usr/bin/stat -f '%d' "$destdir" \
	    "Unable to get info on $destdir."

	if [[ "$ok" ]] ; then
	    if [[ "$sourceDevice" != "$destDevice" ]]; then
		ok=
		errmsg="$entry must be on the same drive as this app."
	    fi
	fi

	if [[ "$ok" ]] ; then
	    # pushd to source directory
	    try '/dev/null&<' pushd "$sourcedir" \
		"$tryid link error: Unable to move to $sourcedir"

	    local files=
	    if [[ "$@" ]] ; then
		files=( "$@" )
	    else
		# no items specified, so link all non-dot items
		files=( * )
	    fi

	    # loop through entries creating hard links
	    for entry in "${files[@]}" ; do
		# hard link
		try /bin/pax -rwlpp "$entry" "$destdir" \
		    "$tryid link error: Unable to create link to $entry."
	    done

	    # popd back from source directory
	    try '/dev/null&<' popd \
		"$tryid link error: Unable to move back from $sourcedir."
	fi
    fi
}


# GOOGLECHROMEINFO: find absolute paths to and info on relevant Google Chrome items
#                   sets the following variables:
#                      SSBGoogleChromePath, SSBGoogleChromeVersion, SSBGoogleChromeExec
function googlechromeinfo {  # $1 == FALLBACKLEVEL
    
    if [[ "$ok" ]]; then
	
	# holder for Info.plist file
	local infoplist=

	# save fallback level
	local fallback="$1"

	# determines if we need to check Chrome's ID
	local checkid=
	
	if [[ ! "$fallback" ]] ; then

	    # this is our first try finding Chrome -- use the value already
	    # in SSBGoogleChromePath
	    
	    # next option is try the default install locations
	    fallback=DEFAULT1
	    
	elif [[ "$fallback" = DEFAULT1 ]] ; then

	    # try the first default install locations	    
	    SSBGoogleChromePath="$HOME/Applications/Google Chrome.app"
	    
	    # we need to check the app's ID
	    checkid=1
	    
	    # if this fails, next stop is Spotlight search
	    fallback=DEFAULT2
	    
	elif [[ "$fallback" = DEFAULT2 ]] ; then
	    
	    # try the first default install locations	    
	    SSBGoogleChromePath='/Applications/Google Chrome.app'
	    
	    # we need to check the app's ID
	    checkid=1
	    
	    # if this fails, next stop is Spotlight search
	    fallback=SPOTLIGHT
	    
	elif [[ "$fallback" = SPOTLIGHT ]] ; then
	    
	    # try using Spotlight to find Chrome
	    SSBGoogleChromePath=$(mdfind "kMDItemCFBundleIdentifier == '$googleChromeID'" 2> /dev/null)
	    
	    # find first instance
	    SSBGoogleChromePath="${SSBGoogleChromePath%%$'\n'*}"
	    
	    # if this fails, the final stop is manual selection
	    fallback=MANUAL

	else # "$fallback" = MANUAL
	    
	    # last-ditch - ask the user to locate it
	    try 'SSBGoogleChromePath=' osascript -e \
		'return POSIX path of (choose application with title "Locate Google Chrome" with prompt "Please locate Google Chrome" as alias)' ''
	    SSBGoogleChromePath="${SSBGoogleChromePath%/}"
	    
	    if [[ ! "$ok" || ! -d "$SSBGoogleChromePath" ]] ; then
		
		# NOW it's an error -- we've failed to find Chrome
		SSBGoogleChromePath=
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find Chrome application.$errmsg"
		ok=
		return 1
	    fi

	    # we need to check the ID
	    checkid=1
	    
	    # don't change the fallback -- we'll just keep doing this
	fi
		
	# check that Info.plist exists
	local fail=
	if [[ ! -e "${SSBGoogleChromePath}/Contents/Info.plist" ]] ; then
	    fail=1
	else
	    
	    # parse Info.plist
	    
	    # read in Info.plist
	    infoplist=$(/bin/cat "${SSBGoogleChromePath}/Contents/Info.plist" 2> /dev/null)
	    if [[ $? != 0 ]] ; then
		errmsg="Unable to read Chrome Info.plist. $fallback $SSBGoogleChromePath"
		ok=
		SSBGoogleChromePath=
		return 1
	    fi
	    
	    # get app icon file name
	    local re='<key>CFBundleIconFile</key>[
 	]*<string>([^<]*)</string>'
	    if [[ "$infoplist" =~ $re ]] ; then
		chromeBundleIconFile="${BASH_REMATCH[1]}"
	    else
		chromeBundleIconFile=
	    fi

	    # get document icon file name
	    local re='<key>CFBundleTypeIconFile</key>[
 	]*<string>([^<]*)</string>'
	    if [[ "$infoplist" =~ $re ]] ; then
		chromeBundleTypeIconFile="${BASH_REMATCH[1]}"
	    else
		chromeBundleTypeIconFile=
	    fi
	    
	    # get version
	    local infoplistChromeVersion=
	    re='<key>CFBundleShortVersionString</key>[
 	]*<string>([^<]*)</string>'
	    if [[ "$infoplist" =~ $re ]] ; then
		infoplistChromeVersion="${BASH_REMATCH[1]}"
	    fi

	    # get executable name & path
	    re='<key>CFBundleExecutable</key>[
 	]*<string>([^<]*)</string>'
	    if [[ "$infoplist" =~ $re ]] ; then
		SSBGoogleChromeExec="${BASH_REMATCH[1]}"
		local chromeExecPath="${SSBGoogleChromePath}/Contents/MacOS/$SSBGoogleChromeExec"
	    fi
	    	    
	    # check app ID if necessary
	    if [[ "$checkid" ]] ; then
		
		re='<key>CFBundleIdentifier</key>[
 	]*<string>([^<]*)</string>'
		
		# check the app bundle's identifier against Chrome's
		if [[ "$infoplist" =~ $re ]] ; then
		    # wrong identifier, so we need to try again
		    [[ "${BASH_REMATCH[1]}" != "$googleChromeID" ]] && fail=1
		else
		    # error -- failed to find the identifier
		    errmsg="Unable to find Chrome identifier."
		    ok=
		    SSBGoogleChromePath=
		    return 1
		fi
	    fi
	fi
	
	# if any of this parsing failed, fall back to another method of finding Chrome
	if [[ "$fail" ]] ; then
	    googlechromeinfo "$fallback"
	    return $?
	fi
	
	# make sure the executable is in place and is not a directory
	if [[ ( ! -x "$chromeExecPath" ) || ( -d "$chromeExecPath" ) ]] ; then
	    
	    # this error is fatal
	    errmsg='Unable to find Chrome executable.'
	    
	    # set error variables and quit
	    ok=
	    SSBGoogleChromePath=
	    return 1
	fi
	
	# if we got here, we have a complete copy of Chrome, so get the version
	
	# try to get it via Spotlight
	local re='^kMDItemVersion = "(.*)"$'
	try 'SSBGoogleChromeVersion=' mdls -name kMDItemVersion "$SSBGoogleChromePath" ''
	if [[ "$ok" && ( "$SSBGoogleChromeVersion" =~ $re ) ]] ; then
	    SSBGoogleChromeVersion="${BASH_REMATCH[1]}"
	else
	    # Spotlight failed -- use version from Info.plist
	    ok=1
	    errmsg=
	    SSBGoogleChromeVersion="$infoplistChromeVersion"
	fi
	
	# check for error
	if [[ ! "$ok" || ! "$SSBGoogleChromeVersion" ]] ; then
	    SSBGoogleChromePath=
	    SSBGoogleChromeVersion=
	    errmsg='Unable to retrieve Chrome version.'
	    ok=
	    return 1
	fi
    fi
    
    if [[ "$ok" ]] ; then
	return 0
    else
	return 1
    fi
} ; export -f googlechromeinfo


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

	# set up useful variables
	local extDir="External Extensions"
	
	# if we need to copy the extension install directory, do it now
	safecopy "$myAppPath/Contents/Resources/$extDir" "$myProfilePath/$extDir" \
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
    if [[ "$force" || ( "$SSBAppPath" != "$myAppPath" ) ]] ; then
	
	# set up NMH file paths
	local hostSourcePath="$myAppPath/Contents/Resources/NMH"
	
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
			 'native messaging host manifest'
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
    #   1 = error checking engine (and ok=, errmsg set)
    #   2 = engine is in opposite state but in good condition
    #   3 = engine is not in good condition

    return 3
} ; export -f setenginestate


# SETENGINESTATE -- set the engine to the active or inactive state
function setenginestate {  # ( ON|OFF )
    
} ; export -f setenginestate


# CREATEENGINEPAYLOAD: create persistent engine payload
function createenginepayload { # ( curContents curDataPath [epiPayloadPath] )

    if [[ "$ok" ]] ; then
	
	# turn on nullglob
	local nullglobOff=
	if shopt -q nullglob ; then
	    nullglobOff=1
	    shopt -s nullglob
	fi
	
	local curContents="$1"    ; shift
	local curDataPath="$1" ; shift
	local epiPayloadPath="$1" ; shift  # only needed for Chromium engine
	
	local curEnginePath="$curDataPath/$appDataEngineBase"
	local curPayloadContentsPath="$curDataPath/$appDataPayloadBase/Contents"
	
	# clear out old engine
	if [[ -d "$curEnginePath" ]] ; then
	    try /bin/rm -rf "$curEnginePath"/* "$curEnginePath"/.[^.]* 'Unable to clear old engine.'
	fi
	
	# create persistent payload
	if [[ "$ok" ]] ; then
	    
	    if [[ "$SSBEngineType" != "Google Chrome" ]] ; then

		# CHROMIUM PAYLOAD

		# create engine directory
		try /bin/mkdir -p "$curEnginePath" \
		    'Unable to create app engine directory.'

		# copy payload items from Epichrome
		try /bin/cp -a "$epiPayloadPath" "$curEnginePath" \
		    'Unable to copy items to app engine payload.'
		
		# filter Info.plist with app info
		filterplist "$curPayloadContentsPath/Info.plist.in" \
			    "$curPayloadContentsPath/Info.plist.off" \
			    "app engine Info.plist" \
			    "
set :CFBundleDisplayName $CFBundleDisplayName
set :CFBundleName $CFBundleName
set :CFBundleIdentifier ${appEngineIDBase}.$SSBIdentifier
Delete :CFBundleDocumentTypes
Delete :CFBundleURLTypes"

		if [[ "$ok" ]] ; then
		    try /bin/rm -f "$curPayloadContentsPath/Info.plist.in" \
			'Unable to remove app engine Info.plist template.'
		fi
		
		# filter localization strings
		filterlproj "$curPayloadContentsPath/Resources" Chromium 'app engine'
		
	    else

		# GOOGLE CHROME PAYLOAD
		
		try /bin/mkdir -p "$curPayloadContentsPath/Resources" \
		    'Unable to create Google Chrome app engine Resources directory.'
		
		# copy engine executable (linking causes confusion between apps & real Chrome)
		try /bin/cp -a "$SSBGoogleChromePath/Contents/MacOS" "$curPayloadContentsPath" \
		    'Unable to copy Google Chrome executable to app engine payload.'

		# copy .lproj directories
		try /bin/cp -a "$SSBGoogleChromePath/Contents/Resources/"*.lproj "$curPayloadContentsPath/Resources" \
		    'Unable to copy Google Chrome localizations to app engine payload.'
		
		# filter localization files
		filterlproj "$curPayloadContentsPath/Resources" Chrome 'Google Chrome app engine'
	    fi	
	    
	    # link to this app's icons
	    if [[ "$ok" ]] ; then
		try /bin/cp "$curContents/Resources/$CFBundleIconFile" \
		    "$curPayloadContentsPath/Resources/$chromeBundleIconFile" \
		    "Unable to copy application icon file to app engine."
		try /bin/cp "$curContents/Resources/$CFBundleTypeIconFile" \
		    "$curPayloadContentsPath/Resources/$chromeBundleTypeIconFile" \
		    "Unable to copy document icon file to app engine."
	    fi
	fi
	
	# restore nullglob
	[[ "$nullglobOff" ]] && shopt -u nullglob
    fi


    # $$$$$ INTEGRATE THIS
    
# BUILD ENGINE OUT OF PAYLOAD

# rename Payload to engine app name  $$$$$ 
try /bin/mv "$myPayloadPath" "$myEngineAppPath" 'Unable to create app engine from payload.'

[[ "$ok" ]] || abort "$errmsg" 1

if [[ "$SSBEngineType" != "Google Chrome" ]] ; then

    # EPICHROME CHROMIUM ENGINE
    
    if [[ ! "$epiCompatible" ]] ; then
	abort "Unable to find a version of Epichrome compatible with this app's engine."
    fi
    # link to everything except Resources directory
    dirlist "${epiCompatible[e_engineRuntime]}" curdir 'Epichrome app engine' '^Resources$'
    linktree "${epiCompatible[e_engineRuntime]}" "$myEngineAppContents" \
	     'Epichrome app engine' "${curdir[@]}"

    # link to everything in Resources
    linktree "${epiCompatible[e_engineRuntime]}/Resources" "$myEngineAppContents/Resources" \
	     'Epichrome app engine Resources'

    try /bin/mv -f "$myEngineAppContents/Info.plist.off" \
	"$myEngineAppContents/Info.plist" \
	'Unable to activate payload Info.plist.'
else
    # GOOGLE CHROME ENGINE

    # link to everything except Resources & MacOS directories
    dirlist "$SSBGoogleChromePath/Contents" curdir \
	    'Google Chrome app engine' '^((Resources)|(MacOS))$'
    linktree "$SSBGoogleChromePath/Contents" "$myEngineAppContents" \
	     'Google Chrome app engine' "${curdir[@]}"

    # link to everything in Resources except .lproj & .icns
    dirlist "$SSBGoogleChromePath/Contents/Resources" curdir \
	    'Google Chrome app engine Resources' '\.((icns)|(lproj))$'
    linktree "$SSBGoogleChromePath/Contents/Resources" "$myEngineAppContents/Resources" \
	     'Google Chrome app engine Resources' \
	     "${curdir[@]}"
fi





    
} ; export -f createenginepayload


# CREATEENGINE -- create entire Epichrome engine (payload & placeholder)
function createengine {
}


# GETENGINEPID: get the PID of the running engine  $$$$ REWRITE TO USE PS INSTEAD??
myEnginePID= ; export myEnginePID
function getenginepid { # ENGINE-BUNDLE-ID ENGINE-BUNDLE-PATH

    # assume no PID
    myEnginePID=

    # args
    local id="$1"
    local path="$2"

    # get all ASNs associated with the engine's bundle ID
    local asns=
    try 'asns=()' /usr/bin/lsappinfo find "bundleid=$id" \
	'Error while attempting to find running engine.'

    # no engine found, just don't return a PID
    if [[ "$ok" && ( "${#asns[@]}" = 0 ) ]] ; then
	return 0
    fi

    # search for PID
    if [[ "$ok" ]] ; then

	local info=

	local a=
	for a in "${asns[@]}" ; do

	    # get info on an ASN (we use try for the debugging output)
	    try 'info=' /usr/bin/lsappinfo info "$a" ''
	    ok=1 ; errmsg=

	    # if this ASN matches our bundle, grab the PID
	    re='bundle path *= *"([^'$'\n'']+)".*pid *= *([0-9]+)'
	    if [[ ( "$info" =~ $re ) && ( "${BASH_REMATCH[1]}" = "$path" ) ]] ; then
		myEnginePID="${BASH_REMATCH[2]}"
		break
	    fi

	    # not found, so reset info
	    info=
	done
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
} ; export -f getenginepid
