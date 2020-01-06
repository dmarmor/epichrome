#!/bin/sh
#
#  engine.sh: utility functions for working with Epichrome engines
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
#                      SSBEngineVersion, SSBGoogleChromePath, SSBGoogleChromeExec, googleChromeContents
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
	try 'SSBEngineVersion=' mdls -name kMDItemVersion "$SSBGoogleChromePath" ''
	if [[ "$ok" && ( "$SSBEngineVersion" =~ $re ) ]] ; then
	    SSBEngineVersion="${BASH_REMATCH[1]}"
	else
	    # Spotlight failed -- use version from Info.plist
	    ok=1
	    errmsg=
	    SSBEngineVersion="$infoplistChromeVersion"
	fi
	
	# check for error
	if [[ ! "$ok" || ! "$SSBEngineVersion" ]] ; then
	    SSBGoogleChromePath=
	    SSBEngineVersion=
	    errmsg='Unable to retrieve Chrome version.'
	    ok=
	    return 1
	fi
    fi
    
    if [[ "$ok" ]] ; then
	# set up dependant variables
	googleChromeContents="$SSBGoogleChromePath/Contents"
	return 0
    else
	return 1
    fi
} ; export -f googlechromeinfo


# POPULATEDATADIR -- make sure an app's data directory is populated
function populatedatadir { # ( [FORCE] )
    
    # SET UP PROFILE DIRECTORY
    
    if [[ "$ok" ]] ; then

	# collect all error messages
	local myErrMsg=
	
	# force an update?
	local force="$1" ; shift

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
    fi
    
    # if we couldn't create the directory, that's a fatal error
    [[ "$ok" ]] || return 1
    
    if [[ "$ok" ]] ; then
	
	# MOVE EXTENSION-INSTALLATION SCRIPT INTO PLACE
	
	# set up useful variables
	local extDir="External Extensions"
	local extSourcePath="$myAppPath/Contents/Resources/$extDir"
	local extDestPath="$myProfilePath/$extDir"

	# flag for deciding whether to copy the directory
	local doExtCopy=

	if [[ "$force" ]] ; then
	    doExtCopy=1
	else

	    # directory listings
	    local extSourceList=()
	    local extDestList=()
	    
	    # get a listing of the source directory
	    dirlist "$extSourcePath" extSourceList 'source directory'
	    
	    # compare to destination directory
	    if [[ "$ok" ]]; then
		
		# get a listing of the destination directory
		dirlist "$extDestPath" extDestList 'destination directory'
		
		if [[ "$ok" ]] ; then
		    
		    # compare source and destination directories
		    [[ "${extSourceList[*]}" != "${extDestList[*]}" ]] && doExtCopy=1
		    
		else

		    # destination listing failed, so stomp it
		    doExtCopy=1
		    ok=1 ; errmsg=
		fi
	    fi
	fi
	
	# if we need to copy the extension install directory, do it now
	if [[ "$ok" && "$doExtCopy" ]] ; then
	    safecopy "$extSourcePath" "$extDestPath" 'installation directory'
	fi
	
	# clear ok state, but keep error message
	myErrMsg="$errmsg"
	ok=1
	
	
	# INSTALL NATIVE MESSAGING HOST
	
	# set up NMH file paths
	local hostSourcePath="$myAppPath/Contents/Resources/NMH"
	local hostScript="epichromeruntimehost.py"
	local hostScriptSourceFile="$hostSourcePath/$hostScript"
	local hostScriptDestFile="$myDataDir/$hostScript"
	local hostManifest=( "org.epichrome.runtime.json" "org.epichrome.helper.json" )
	local hostManifestDestPath="$myProfilePath/NativeMessagingHosts"
	#local hostManifestInstalled=( "$hostInstallPath/${hostManifest[0]}" "$hostInstallPath/${hostManifest[1]}" )
	
	# install NMH script
	if [[ "$force" || ( ! -x "$hostScriptDestFile" ) ]] ; then
	    
	    # filter the host script into place & make it executable
	    filterscript "$hostScriptSourceFile" "$hostScriptDestFile" 'native messaging host script'
	    try /bin/chmod 755 "$hostScriptDestFile" 'Unable to make native messaging host executable.'
	fi

	# install NMH manifest
	if [[ "$ok" ]] ; then

	    local curManifestSourceFile=
	    for curManifest in "${hostManifest[@]}" ; do
		
		curManifestSourceFile="$hostManifestDestPath/$curManifest"
		if [[ "$force" || ! -e "curManifestSourceFile" ]] ; then
		    
		    # create the install directory
		    try /bin/mkdir -p "$hostManifestDestPath" \
			'Unable to create NativeMessagingHosts folder.'
		    
		    # stream-edit the current manifest
		    filterscript "$curManifestSourceFile" "$hostManifestDestPath/$curManifest" \
				 'native messaging host manifest'
		    
	    done
	fi
    fi

    # handle error messaging and result code
    if [[ "$ok" ]] ; then
	
	# success!
	return 0
    else
	
	# pass along error messages but clear error state
	if [[ "$myErrMsg" ]] ; then
	    errmsg="$myErrMsg Also: $errmsg"
	else
	    errmsg="$errmsg"
	fi
	
	ok=1
	
	return 1
    fi
}


# GETENGINEPID: get the PID of the running engine  $$$$ REWRITE TO USE PS INSTEAD??
enginePID=
function getenginepid { # ENGINE-BUNDLE-ID ENGINE-BUNDLE-PATH

    # assume no PID
    enginePID=

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
		enginePID="${BASH_REMATCH[2]}"
		break
	    fi

	    # not found, so reset info
	    info=
	done
    fi

    # return result
    if [[ "$enginePID" ]] ; then
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
