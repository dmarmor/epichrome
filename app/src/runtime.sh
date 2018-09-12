#!/bin/sh
#
#  runtime.sh: runtime utility functions for Epichrome creator & apps
#  Copyright (C) 2018  David Marmor
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


# NOTE: the "try" function and many other functions in this system clear
#       the "ok" global variable on error, set a message in "errmsg",
#       and return 0 on success, non-zero on error


# CONSTANTS

# app executable name
CFBundleExecutable="Epichrome"

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="document.icns"

# important paths -- relative to app Contents directory
appInfoPlist="Info.plist"
appPayload="Resources/Payload"
appEngine="Resources/ChromeEngine"
appConfigScript="Resources/Scripts/config.sh"
appStringsScript="Resources/Scripts/strings.py"
appGetVersionScript="Resources/Scripts/getversion.py"

# profile base
appProfileBase="Library/Application Support/Epichrome/Apps"


# TRY: try to run a command, as long as no errors have already been thrown
#
#      usage:
#        try 'varname=' cmd arg arg arg 'Error message.'
#        try 'filename.txt<' cmd arg arg arg 'Error message.'
#        try 'filename.txt&<' cmd arg arg arg 'Error message.'
#        try 'filename.txt<<' cmd arg arg arg 'Error message.'
#        try 'filename.txt&<<' cmd arg arg arg 'Error message.'
#        try cmd arg arg arg 'Error message.'
#
# get first line of a variable: "${x%%$'\n'*}"
#
ok=1
errmsg=
function try {
    # only run if no prior error
    if [[ "$ok" ]]; then
	
	# see if we're storing output
	local target="$1"
	local type="${target:${#target}-1}"
	local ignorestderr=1
	if [[ "$type" = "=" ]]; then
	    # storing in a variable
	    target="${target%=}"
	    type=var
	    shift
	elif [[ "$type" = "<" ]]; then
	    # storing in a file
	    target="${target%<}"
	    type=file
	    if [[ "${target:${#target}-1}" = '<' ]] ; then
		# append to file
		target="${target%<}"
		type=append
	    fi
	    shift
	else
	    # not storing
	    target=
	    type=
	fi

	# determine handling of stderr
	if [[ "$type" && ( "${target:${#target}-1}" = '&' ) ]] ; then
	    # keep stderr
	    target="${target%&}"
	    ignorestderr=
	fi
	
	# get command-line args
	local args=("$@")
	
	# last arg is error message
	local last=$((${#args[@]} - 1))
	local myerrmsg="${args[$last]}"
	unset args[$last]
	
	# run the command
	local result=
	if [[ "$type" = var ]] ; then
	    # store stdout in named variable
	    local temp=
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    temp="$("${args[@]}")"
		else
		    temp="$("${args[@]}" 2> /dev/null)"
		fi
		result="$?"
	    else
		temp="$("${args[@]}" 2>&1)"
		result="$?"
	    fi
	    
	    # escape special characters
	    eval "${target}=$(printf '%q' "$temp")"
	    
	elif [[ "$type" = append ]] ; then
	    # append stdout to a file
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    "${args[@]}" >> "$target"
		    result="$?"
		else
		    "${args[@]}" >> "$target" 2> /dev/null
		    result="$?"
		fi
	    else
		"${args[@]}" >> "$target" 2>&1
		result="$?"
	    fi
	elif [[ "$type" = file ]] ; then
	    # store stdout in a file
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    "${args[@]}" > "$target"
		    result="$?"
		else
		    "${args[@]}" > "$target" 2> /dev/null
		    result="$?"
		fi
	    else
		"${args[@]}" > "$target" 2>&1
		result="$?"
	    fi
	else
	    # throw stdout away (unless in debug mode)
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    "${args[@]}"
		    result="$?"
		else
		    "${args[@]}" > /dev/null 2>&1
		    result="$?"
		fi
	    fi
	fi
	
	# check result
	if [[ "$result" != 0 ]]; then
	    [[ "$myerrmsg" ]] && errmsg="$myerrmsg"
	    ok=
	    return "$result"
	fi
    fi
    
    return 0
}


# ONERR -- like TRY above, but it only runs if there's already been an error
function onerr {
    
    # try a command, but only if there's already been an error
    
    if [[ ! "$ok" ]] ; then
	
	# save old error message
	local olderrmsg="$errmsg"
	
	# run the command
	ok=1
	errmsg=
	try "$@"
	local result="$?"
	ok=
	
	# add new error message
	if [[ "$errmsg" ]] ; then
	    errmsg="$olderrmsg $errmsg"
	else
	    errmsg="$olderrmsg"
	fi
	
	return "$result"
    fi

    return 0
}


# ISARRAY -- echo "true" and return 0 if a named variable is an array
function isarray {
    if [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ -a ]] ; then
	echo true
	return 0
    else
	return 1
    fi
}


# SAFESOURCE -- safely source a script
function safesource {
    
    # only run if no error
    if [[ "$ok" ]]; then
	
	local fileinfo=
	
	# get file info string
	if [ "$2" ] ; then
	    fileinfo="$2"
	else	
	    [[ "$fileinfo" =~ /([^/]+)$ ]] && fileinfo="${BASH_REMATCH[1]}"
	fi

	# try to source the file
	if [ -e "$1" ] ; then
	    try source "$1" "Unable to load $fileinfo."
	else
	    errmsg="Unable to find $fileinfo."
	    ok=
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# TEMPNAME: internal version of mktemp
function tempname {
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    local result="${1}.${RANDOM}${2}"
    while [[ -e "$result" ]] ; do
	result="${result}.${RANDOM}${2}"
    done
    
    echo "$result"
}


# PERMANENT: move temporary file or directory to permanent location safely
function permanent {

    if [[ "$ok" ]]; then
	
	local temp="$1"
	local perm="$2"
	local filetype="$3"
	local saveTempOnError="$4"  # optional argument
	
	local permOld=
	
	# MOVE OLD FILE OUT OF THE WAY, MOVE TEMP FILE TO PERMANENT NAME, DELETE OLD FILE
	
	# move the permanent file to a holding location for later removal
	if [[ -e "$perm" ]] ; then
	    permOld=$(tempname "$perm")
	    try /bin/mv "$perm" "$permOld" "Unable to move old $filetype."
	    [[ "$ok" ]] || permOld=
	fi
	
	# move the temp file or directory to its permanent name
	try /bin/mv -f "$temp" "$perm" "Unable to move new $filetype into place."
	
	# remove the old permanent file or folder if there is one
	if [[ "$ok" ]] ; then
	    temp=
	    if [ -e "$permOld" ]; then
		try /bin/rm -rf "$permOld" "Unable to remove old $filetype."
	    fi
	fi
	
	# IF WE FAILED, CLEAN UP
	
	if [[ ! "$ok" ]] ; then
	    
	    # move old permanent file back
	    if [[ "$permOld" ]] ; then
		onerr /bin/mv "$permOld" "$perm" "Also unable to restore old $filetype."
	    fi
	    
	    # delete temp file
	    [[ ( ! "$saveTempOnError" ) && ( -e "$temp" ) ]] && rmtemp "$temp" "$filetype"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# SAFECOPY: safely copy a file or directory to a new location
function safecopy {
    
    if [[ "$ok" ]]; then
	
	# copy in custom icon
	local src="$1"
	local dst="$2"
	local filetype="$3"
	
	# get dirname for destination
	local dstDir=
	try 'dstDir=' dirname "$dst" "Unable to get destination directory listing for $filetype."
	
	# make sure destination directory exists
	try /bin/mkdir -p "$dstDir" "Unable to create the destination directory for $filetype."
	
	# copy to temporary location
	local dstTmp="$(tempname "$dst")"
	try /bin/cp -a "$src" "$dstTmp" "Unable to copy $filetype."
	
	# move file to permanent home
	permanent "$dstTmp" "$dst" "$filetype"
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# RMTEMP: remove a temporary file or directory (whether $ok or not)
function rmtemp {
    local temp="$1"
    local filetype="$2"	

    # delete the temp file
    if [ -e "$temp" ] ; then
	if [[ "$ok" ]] ; then
	    try /bin/rm -rf "$temp" "Unable to remove temporary $filetype."
	else
	    onerr /bin/rm -rf "$temp" "Also unable to remove temporary $filetype."
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# SETOWNER: set the owner of a directory tree or file to the owner of the app
function setowner {  # APPPATH THISPATH PATHINFO

    if [[ "$ok" ]] ; then

	# get args
	local appPath="$1"
	local thisPath="$2"
	local pathInfo="$3"
	[[ "$pathInfo" ]] || pathInfo="path \"$2\""
	
	local appOwner=
	try 'appOwner=' /usr/bin/stat -f '%Su' "$appPath" 'Unable to get owner of app bundle.'
	try /usr/sbin/chown -R "$appOwner" "$thisPath" "Unable to set ownership of $pathInfo."
    fi

    [[ "$ok" ]] && return 0
    return 1
}


# DIRLIST: get (and possibly filter) a directory listing
function dirlist {  # DIRECTORY OUTPUT-VARIABLE FILEINFO FILTER

    if [[ "$ok" ]]; then

	local dir="$1"
	local outvar="$2"
	local fileinfo="$3"
	local filter="$4"
	
	local files=
	files="$(unset CLICOLOR ; /bin/ls "$dir" 2>&1)"
	if [[ "$?" != 0 ]] ; then
	    errmsg="Unable to retrieve $fileinfo list."
	    ok=
	    return 1
	fi
	
	local filteredfiles=()
	local f=
	while read f ; do
	    if [[ ! "$filter" || ! ( "$f" =~ $filter ) ]] ; then
		# escape \ to \\
		
		# escape " to \" and <space> to \<space> and add to array
		filteredfiles=("${filteredfiles[@]}" "$(printf '%q' "$f")")
	    fi
	done <<< "$files"

	# copy array to output variable
	eval "${outvar}=(${filteredfiles[@]})"
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# LINKTREE: hard or symbolic link to a directory or file
function linktree { # $1 = SOFT/HARD
    #                 $2 = sourcedir (absolute)
    #                 $3 = destdir (absolute)
    #                 $4 = try error identifier $@ = <files>

    # read arguments
    local linktype="$1"
    local sourcedir="$2"  # could absolutize: echo "$(cd "$foo" 2> /dev/null && pwd)"
    local destdir="$3"
    local tryid="$4"
    shift 4
    
    # if hard linking, pushd to source directory
    [[ "$linktype" != SOFT ]] && try pushd "$sourcedir" \
				     "$tryid link error: Unable to move to $sourcedir."

    # loop through entries creating either symbolic or hard links
    for entry in "$@" ; do
	if [[ "$linktype" = SOFT ]] ; then
	    # symbolic link
	    try /bin/ln -s "$sourcedir/$entry" "$destdir" \
	    	"$tryid link error: Unable to create symlink to $entry."
	else
	    # hard link
	    try /bin/pax -rwlpp "$entry" "$destdir" \
		"$tryid link error: Unable to create link to $entry."
	fi
    done
    
    # if hard linking, popd back from source directory
    [[ "$linktype" != SOFT ]] && \
	try popd \
	    "$tryid link error: Unable to move back from $sourcedir."
}


# WRITEVARS: write out a set of arbitrary bash variables to a file
function writevars {  # $1 = destination file
    #                   $@ = list of vars
    
    if [[ "$ok" ]] ; then

	# destination file
	local dest="$1"
	shift

	# local variables
	local var=
	local value=
	local arr=()
	local i
	
	# temporary file
	local tmpDest="$(tempname "$dest")"

	# basename
	local destBase="${dest##*/}"
	# start temp vars file
	local myDate=
	try 'myDate=' /bin/date ''
	if [[ ! "$ok" ]] ; then ok=1 ; myDate= ; fi
	try "${tmpDest}<" echo "# ${destBase} -- autogenerated $myDate" \
	    "Unable to create ${destBase}."
	try "${tmpDest}<<" echo "" "Unable to write to ${destBase}."
	
	if [[ "$ok" ]] ; then
	    
	    # go through each variable
	    for var in "$@" ; do
		
		if [[ "$(isarray "$var")" ]]; then
		    
		    # variable holds an array, so start the array
		    value="("
		    
		    # pull out the array value
		    eval "arr=(\"\${$var[@]}\")"
		    
		    # go through each value and build the array
		    for elem in "${arr[@]}" ; do
			
			# escape \ to \\
			elem="${elem//\\/\\\\}"
			
			# add array value, escaping specials
			value="${value} $(printf "%q" "$elem")"

		    done
		    
		    # close the array
		    value="${value} )"
		else
		    
		    # scalar value, so pull out the value
		    eval "value=\"\${$var}\""
		    
		    # escape \ to \\
		    value="${value//\\/\\\\}"
		    
		    # escape spaces and quotes
		    value=$(printf '%q' "$value")

		fi
		
		try "${tmpDest}<<" echo "${var}=${value}" "Unable to write to ${destBase}."
		[[ "$ok" ]] || break
	    done
	fi
	
	# move the temp file to its permanent place
	permanent "$tmpDest" "$dest" "${destBase}"
	
	# on error, remove temp vars file
	[[ "$ok" ]] || rmtemp "$tmpDest" "${destBase}"
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# NEWVERSION (V1 V2) -- if V1 < V2, return (and echo) 1, else return 0
function newversion {
    local re='^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)'
    if [[ "$1" =~ $re ]] ; then
	old=("${BASH_REMATCH[@]:1}")
    else
	old=( 0 0 0 '' )
    fi
    if [[ "$2" =~ $re ]] ; then
	new=("${BASH_REMATCH[@]:1}")
    else
	new=( 0 0 0 '' )
    fi

    local i= ; local idx=( 0 1 2 )
    for i in "${idx[@]}" ; do
	if [[ "${old[$i]}" -lt "${new[$i]}" ]] ; then
	    echo "1"
	    return 1
	fi
	[[ "${old[$i]}" -gt "${new[$i]}" ]] && return 0
    done

    # if any trailing text is updated, that counts too (so 2.1.18b > 2.1.18)
    if [[ "${old[3]}" < "${new[3]}" ]] ; then
	echo "1"
	return 1
    fi
    
    # if we got here, the versions are equal
    return 0
}


# RELAUNCH -- relaunch this app after a delay
function relaunch { # APP-PATH DELAY-SECONDS
    [[ "$2" ]] && sleep "$2"
    open "$1"
}


# MCSSBINFO: get absolute path and version info for Epichrome
function mcssbinfo { # (optional)MCSSB-PATH
    
    if [[ "$ok" ]]; then
	
	# default value
	mcssbVersion="$SSBVersion"
	mcssbPath=
	
	# find Epichrome
	
	if [[ "$1" ]] ; then
	    # we've been told where it is
	    mcssbPath="$1"
	else
	    # otherwise use spotlight to find it
	    if [[ ! -d "$mcssbPath" ]] ; then
		
		mcssbPath=
		
		# try app ID first
		mcssbPath=$(mdfind \
				"kMDItemCFBundleIdentifier == 'org.epichrome.Epichrome'" \
				2> /dev/null)
		mcssbPath="${mcssbPath%%$'\n'*}"
		
		# new app ID failed, try old app ID
		if [[ ! -d "$mcssbPath" ]]; then
		    mcssbPath=$(mdfind \
				    "kMDItemCFBundleIdentifier == 'com.dmarmor.MakeChromeSSB'" \
				    2> /dev/null)
		    mcssbPath="${mcssbPath%%$'\n'*}"
		fi
		
		# old app ID failed too, maybe Spotlight is off, try last-ditch
		if [[ ! -d "$mcssbPath" ]]; then
		    mcssbPath=~/'Applications/Epichrome.app'
		fi
		if [[ ! -d "$mcssbPath" ]]; then
		    mcssbPath='/Applications/Epichrome.app'
		fi
	    fi
	fi
	
	# not found
	if [[ ! -d "$mcssbPath" ]] ; then
	    mcssbPath=
	    errmsg="Unable to find Epichrome."
	    ok=
	    return 1
	fi
	
	# get current value for mcssbVersion
	try source "${mcssbPath}/Contents/Resources/Scripts/version.sh" \
	    'Unable to load Epichrome version.'
	
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# CHROMEINFO: find absolute paths to and info on relevant Google Chrome items
#             sets the following variables:
#                chromePath, chromeContents
#                chromeVersion, chromeMajorVersion
#                chromeInfoPlist
#                chromeExecName, chromeExec
function chromeinfo {  # $1 == FALLBACKLEVEL
    
    if [[ "$ok" ]]; then
	
	# Chrome identifier
	local CFBundleIdentifier='com.google.Chrome'

	# holder for Info.plist file
	local infoplist=

	# save fallback level
	local fallback="$1"

	# determines if we need to check Chrome's ID
	local checkid=
	
	if [[ ! "$fallback" ]] ; then

	    # this is our first try finding Chrome -- use the config value,
	    # if any, or default location
	    chromePath="$SSBChromePath"

	    # next option is try the default install locations
	    fallback=DEFAULT1
	    
	elif [[ "$fallback" = DEFAULT1 ]] ; then

	    # try the first default install locations	    
	    chromePath="$HOME/Applications/Google Chrome.app"
	    
	    # we need to check the app's ID
	    checkid=1
	    
	    # if this fails, next stop is Spotlight search
	    fallback=DEFAULT2
	    
	elif [[ "$fallback" = DEFAULT2 ]] ; then
	    
	    # try the first default install locations	    
	    chromePath='/Applications/Google Chrome.app'
	    
	    # we need to check the app's ID
	    checkid=1
	    
	    # if this fails, next stop is Spotlight search
	    fallback=SPOTLIGHT
	    
	elif [[ "$fallback" = SPOTLIGHT ]] ; then
	    
	    # try using Spotlight to find Chrome
	    chromePath=$(mdfind "kMDItemCFBundleIdentifier == '$CFBundleIdentifier'" 2> /dev/null)
	    
	    # find first instance
	    chromePath="${chromePath%%$'\n'*}"
	    
	    # if this fails, the final stop is manual selection
	    fallback=MANUAL

	else # "$fallback" = MANUAL
	    
	    # last-ditch - ask the user to locate it
	    try 'chromePath=' osascript -e \
		'return POSIX path of (choose application with title "Locate Chrome" with prompt "Please locate Google Chrome" as alias)' ''
	    chromePath="${chromePath%/}"
	    
	    if [[ ! "$ok" || ! -d "$chromePath" ]] ; then
		
		# NOW it's an error -- we've failed to find Chrome
		chromePath=
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find Chrome application.$errmsg"
		ok=
		return 1
	    fi

	    # we need to check the ID
	    checkid=1
	    
	    # don't change the fallback -- we'll just keep doing this
	fi
	
	# create path to Info.plist
	chromeInfoPlist="${chromePath}/Contents/Info.plist"
	
	# check that Info.plist exists
	local fail=
	if [[ ! -e "$chromeInfoPlist" ]] ; then
	    fail=1
	else
	    
	    # parse Info.plist
	    
	    # read in Info.plist
	    infoplist=$(/bin/cat "${chromePath}/Contents/Info.plist" 2> /dev/null)
	    if [[ $? != 0 ]] ; then
		errmsg="Unable to read Chrome Info.plist. $fallback $chromePath"
		ok=
		chromePath=
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

	    # get executable name
	    re='<key>CFBundleExecutable</key>[
 	]*<string>([^<]*)</string>'
	    if [[ "$infoplist" =~ $re ]] ; then
		chromeExecName="${BASH_REMATCH[1]}"
	    fi
	    	    
	    # check app ID if necessary
	    if [[ "$checkid" ]] ; then
		
		re='<key>CFBundleIdentifier</key>[
 	]*<string>([^<]*)</string>'
		
		# check the app bundle's identifier against Chrome's
		if [[ "$infoplist" =~ $re ]] ; then
		    # wrong identifier, so we need to try again
		    [[ "${BASH_REMATCH[1]}" != "$CFBundleIdentifier" ]] && fail=1
		else
		    # error -- failed to find the identifier
		    errmsg="Unable to find Chrome identifier."
		    ok=
		    chromePath=
		    return 1
		fi
	    fi
	fi
	
	# if any of this parsing failed, fall back to another method of finding Chrome
	if [[ "$fail" ]] ; then
	    chromeinfo "$fallback"
	    return $?
	fi
	
	# create path to Chrome executable
	chromeExec="${chromePath}/Contents/MacOS/$chromeExecName"
	
	# make sure the executable is in place and is not a directory
	if [[ ! ( -x "$chromeExec" ) || ( -d "$chromeExec" ) ]] ; then
	    
	    # this error is fatal
	    errmsg='Unable to find Chrome executable.'
	    
	    # set error variables and quit
	    ok=
	    chromePath=
	    chromeExec=
	    chromeInfoPlist=
	    return 1
	fi
	
	# if we got here, we have a complete copy of Chrome, so get the version
	
	# try to get it via Spotlight
	local re='^kMDItemVersion = "(.*)"$'
	try 'chromeVersion=' mdls -name kMDItemVersion "$chromePath" ''
	if [[ "$ok" && ( "$chromeVersion" =~ $re ) ]] ; then
	    chromeVersion="${BASH_REMATCH[1]}"
	else
	    # Spotlight failed -- use version from Info.plist
	    ok=1
	    errmsg=
	    chromeVersion="$infoplistChromeVersion"
	fi
	
	# check for error
	if [[ ! "$ok" || ! "$chromeVersion" ]] ; then
	    chromePath=
	    chromeVersion=
	    errmsg='Unable to retrieve Chrome version.'
	    ok=
	    return 1
	fi
	
	# set up variables depending which version of Chrome we're running
	
	local chromeMajorVersion="${chromeVersion%%.*}"
	if [[ ( "$chromeMajorVersion" =~ ^[1-9][0-9]*$ ) && \
	    ( "$chromeMajorVersion" -lt 69 ) ]] ; then
	    chromeVersionPre69=1
	    # pre-69 we name the engine to avoid clashes with the real Chrome
	    engineExec="ChromeEngine"
	else
	    # from 69 on it MUST have the same name to avoid security problems
	    chromeVersionPre69=
	    engineExec="$chromeExecName"
	fi
    fi
    
    if [[ "$ok" ]] ; then
	# set up dependant variables
	chromeContents="$chromePath/Contents"
	return 0
    else
	return 1
    fi
}


# CREATEPAYLOAD: create persistent Chrome engine payload
function createpayload { # $1 = Contents path

    local payloadPath="$1/$appPayload"
    
    # set link style based on Chrome version
    local linkStyle=SOFT
    [[ "$chromeVersionPre69" ]] || linkStyle=HARD
    
    # clear out old payload & recreate
    try /bin/rm -rf "$payloadPath" 'Unable to clear old payload.'
    try /bin/mkdir -p "$payloadPath/Resources" \
	'Unable to create Chrome engine Resources directory.'
    
    # link to this app's icons
    if [[ "$ok" ]] ; then
	try /bin/ln -s "../../../../$CFBundleIconFile" \
	    "$payloadPath/Resources/$chromeBundleIconFile" \
	    "Unable to link Chrome engine to application icon file. '../../../../$CFBundleIconFile'"
	try /bin/ln -s "../../../../$CFBundleTypeIconFile" \
	    "$payloadPath/Resources/$chromeBundleTypeIconFile" \
	    "Unable to link Chrome engine to document icon file."
    fi
    
    # filter Chrome .lproj directories to modify InfoPlist.strings files
    if [[ "$ok" ]] ; then
	
	# copy all .lproj directories from Chrome
	try /bin/cp -a "$chromeContents/Resources/"*.lproj "$payloadPath/Resources" \
	    'Unable to copy localizations to Chrome engine.'
	
	# run python script to filter the InfoPlist.strings files for the
	# .lproj directories
	local pyerr=
	try 'pyerr&=' \
	    "$1/$appStringsScript" "$CFBundleDisplayName" "$CFBundleName" \
	    "$payloadPath/Resources/"*.lproj \
	    'Error filtering InfoPlist.strings'
	[[ "$ok" ]] || errmsg="$errmsg ($pyerr)"
    fi
}


# MCSSBMAKEICONS: wrapper for makeicon.sh
function mcssbmakeicons {  # INPUT OUTPUT-DIR app|doc|both
    if [[ "$ok" ]] ; then

	# find makeicon.sh
	local makeIconScript="${mcssbPath}/Contents/Resources/Scripts/makeicon.sh"
	[[ -e "$makeIconScript" ]] || abort "Unable to locate makeicon.sh." 1
	
	# build command-line
	local args=
	local docargs=(-c "$mcssbPath/Contents/Resources/docbg.png" 256 286 512 "$1" "$2/$CFBundleTypeIconFile")
	case "$3" in
	    app)
		args=(-f "$1" "$2/$CFBundleIconFile")
		;;
	    doc)
		args=(-f "${docargs[@]}")
		;;
	    both)
		args=(-f -o "$2/$CFBundleIconFile" "${docargs[@]}")
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


# FILTERCHROMEINFOPLIST: write out new Info.plist file
function filterchromeinfoplist {  # PY-CONTENTS-DIR DEST-CONTENTS-DIR FILTER-KEYS...
    
    if [[ "$ok" ]]; then

	# arguments
	local pyContentsDir="$1"   # Contents directory to use as root for Info.plist-filtering Python script
	shift
	local destContentsDir="$1" # Contents directory to use as root for destination Info.plist
	shift
	local filterkeys=("$@")    # keys to filter

	# makes sure we have the Chrome info we need
	[[ "$chromeInfoPlist" ]] || chromeinfo
	[[ "$ok" ]] || return 1
	
	# ensure Chrome's Info.plist file is where we think it is
	if [[ ! -f "$chromeInfoPlist" ]] ; then
	    errmsg="Unable to find Chrome Info.plist file."
	    ok=
	    return 1
	fi
	
	# full path to Info.plist file
	local fullInfoPlist="$destContentsDir/$appInfoPlist"
	
	# create name for temp Info.plist file
	local tmpInfoPlist="$(tempname "$fullInfoPlist")"
	
	# run python script to filter Info.plist
	local pyerr=
	try 'pyerr&=' "$pyContentsDir/Resources/Scripts/infoplist.py" \
	    "$chromeInfoPlist" \
	    "$tmpInfoPlist" \
	    "${filterkeys[@]}" 'Error filtering Info.plist file.'
	if [[ ! "$ok" ]] ; then
	    errmsg="$errmsg ($pyerr)"
	    
	    # delete the temp file
	    rmtemp "$tmpInfoPlist" "Info.plist"
	    return 1
	else
	    # move temp file to permanent location
	    permanent "$tmpInfoPlist" "$fullInfoPlist" "Info.plist"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # $1 = destination app bundle Contents directory
    
    if [[ "$ok" ]] ; then

	local configScript="$1/$appConfigScript"
	# write out the config file
	writevars "$configScript" \
		  CFBundleDisplayName \
		  CFBundleName \
		  CFBundleIdentifier \
		  SSBVersion \
		  SSBUpdateCheckDate \
		  SSBUpdateCheckVersion \
		  SSBProfilePath \
		  SSBChromePath \
		  SSBChromeVersion \
		  SSBChromeEngine \
		  SSBRegisterBrowser \
		  SSBCustomIcon \
		  SSBFirstRun \
		  SSBFirstRunSinceVersion \
		  SSBHostInstallError \
		  SSBCommandLine
	
	# set ownership of config file
	setowner "$1/.." "$configScript" "config file"
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# CHECKMCSSBVERSION: function that checks for a new version of Epichrome on github
function checkmcssbversion { # CONTENTS-PATH (optional)NOMINAL-VERSION

    # URL for the latest Epichrome release
    local updateURL='https://github.com/dmarmor/epichrome/releases/latest'
    
    # call Python script to check github for the latest version
    local latestVersion="$( "$1/$appGetVersionScript" 2> /dev/null )"
    if [[ "$?" != 0 ]] ; then
	ok=
	errmsg="$latestVersion"
    fi
    
    # set current version to compare against
    local curVersion="$mcssbVersion"
    [[ "$2" ]] && curVersion="$2"
    
    # compare versions
    if [[ "$ok" && "$(newversion "$curVersion" "$latestVersion")" ]] ; then
	# output new available version number & download URL
	echo "$latestVersion"
	echo "$updateURL"
    fi
    
    # return value tells us know if we had any errors
    if [[ "$ok" ]]; then
	return 0
    else
	return 1
    fi
}


# UPDATESSB: function that actually populates an app bundle with the SSB
function updatessb {
    
    if [[ "$ok" ]] ; then
	
	# command-line arguments
	local appPath="$1"        # path to the app bundle
	local customIconDir="$2"  # path to custom icon directory
	local chromeOnly="$3"     # if non-empty, we're ONLY updating Chrome stuff
	local newApp="$4"         # if non-empty, we're creating a new app
	
	# initially set this to permanent Contents directory
	local contentsTmp="$appPath/Contents"

	# make sure we've got Chrome info
	[[ "$chromePath" && "$chromeVersion" ]] || chromeinfo
	
	# FULL UPDATE OPERATION
	
	if [[ ! "$chromeOnly" ]] ; then
	    
	    # we need an actual temporary Contents directory
	    local contentsTmp="$(tempname "$appPath/Contents")"
	    
	    # copy in the boilerplate for the app
	    try /bin/cp -a "$mcssbPath/Contents/Resources/Runtime" "$contentsTmp" 'Unable to populate app bundle.'
	    [[ "$ok" ]] || return 1
	    
	    # place custom icon, if any
	    
	    # check if we are copying from an old version of a custom icon
	    local remakeDocIcon=
	    if [[ ( ! "$customIconDir" ) && ( "$SSBCustomIcon" = "Yes" ) ]] ; then
		customIconDir="$appPath/Contents/Resources"
		
		# starting in 2.1.14 we can customize the document icon too
		if [[ $(newversion "$SSBVersion" "2.1.14") ]] ; then
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
		mcssbmakeicons "$customIconDir/$CFBundleIconFile" "${contentsTmp}/Resources" doc
		if [[ ! "$ok" ]] ; then
		    errmsg="Unable to update doc icon ($errmsg)."
		fi
		
	    elif [[ -e "$customIconDir/$CFBundleTypeIconFile" ]] ; then
		# copy in existing custom doc icon
		safecopy "$customIconDir/$CFBundleTypeIconFile" "${contentsTmp}/Resources/$CFBundleTypeIconFile" "custom icon"
	    fi
	    
	    if [[ "$ok" ]] ; then
		
		# create a bundle identifier if necessary
		local idbase="org.epichrome.app."
		local idre="^${idbase//./\\.}"
		
		# make a new identifier if: either we're making a new SSB, or
		# updating an old enough version that there's either no
		# CFBundleIdentifier or an old format one
		
		if [[ ! "$CFBundleIdentifier" || ! ( "$CFBundleIdentifier" =~ $idre ) ]] ; then

		    # create a bundle identifier
		    local maxbidlength=$((30 - ${#idbase}))       # identifier must be 30 characters or less
		    local bid="${CFBundleName//[^-a-zA-Z0-9_]/}"  # remove all undesirable characters
		    [ ! "$bid" ] && bid="generic"                 # if trimmed away to nothing, use a default name
		    bid="${bid::$maxbidlength}"
		    local bidbase="${bid::$(($maxbidlength - 3))}"
		    bidbase="${#bidbase}"                         # length of the ID's base if using uniquifying numbers
		    CFBundleIdentifier="${idbase}$bid"            # set initial identifier
		    
		    # if this identifier already exists on the system, create a unique one
		    local idfound=0
		    local randext="000"

		    # determine if Spotlight is enabled for the root volume
		    local spotlight=$(mdutil -s / 2> /dev/null)
		    if [[ "$spotlight" =~ 'Indexing enabled' ]] ; then
			spotlight=1
		    else
			spotlight=
		    fi
		    
		    while [[ 1 ]] ; do

			if [[ "$spotlight" ]] ; then
			    try 'idfound=' mdfind "kMDItemCFBundleIdentifier == '$CFBundleIdentifier'" \
				'Unable to search system for bundle identifier.'
			    
			    # exit loop on error, or on not finding this ID
			    [[ "$ok" && "$idfound" ]] || break
			fi
			
			# try to create a new unique ID
			randext=$(((${RANDOM} * 100 / 3279) + 1000))  # 1000-1999
			bid="${bid::$bidbase}${randext:1:3}"
			CFBundleIdentifier="${idbase}$bid"
			
			# if we don't have spotlight we'll just use the first randomly-generated ID
			[[ ! "$spotlight" ]] && break
			
		    done
		    
		    # if we got out of the loop, we have a unique-ish ID (or we got an error)
		fi
	    fi

	    if [[ "$ok" ]] ; then
		
		# set profile path
		local appProfilePath="${appProfileBase}/${CFBundleIdentifier##*.}"
		
		# get the old profile path, if any
		local oldProfilePath=
		if [[ "$SSBProfilePath" ]] ; then
		    if [[ "$(isarray SSBProfilePath)" ]] ; then
			oldProfilePath="${SSBProfilePath[0]}"
		    fi
		elif [[ ! "$newApp" ]] ; then
		    # this is the old-style profile path, from before it got saved
		    oldProfilePath="Library/Application Support/Chrome SSB/${CFBundleDisplayName}"
		fi
		
		# if old path exists and is different, save it in an array for migration on first run
		if [[ "$oldProfilePath" && ( "$oldProfilePath" != "$appProfilePath" ) ]] ; then
		    SSBProfilePath=("$appProfilePath" "$oldProfilePath")
		else
		    SSBProfilePath="$appProfilePath"
		fi
		
		# set up first-run notification
		if [[ "$SSBVersion" ]] ; then
		    SSBFirstRunSinceVersion="$SSBVersion"
		else
		    SSBFirstRunSinceVersion="0.0.0"
		fi
		
		# update SSBVersion & SSBUpdateCheckVersion
		SSBVersion="$mcssbVersion"
		SSBUpdateCheckVersion="$mcssbVersion"
		
		# clear host install error state
		SSBHostInstallError=
	    fi
	else

	    # updating Chrome only; blow away Payload & engine for full relink
	    /bin/rm -rf "$contentsTmp/$appPayload" > /dev/null 2>&1
	    /bin/rm -rf "$contentsTmp/$appEngine" > /dev/null 2>&1
	    
	    if [[ ! "$SSBVersion" ]] ; then
		
		# this should never be reached, but just in case, we set SSBVersion
		SSBVersion="$mcssbVersion"
		SSBUpdateCheckVersion="$mcssbVersion"
	    fi
	fi
	
	# OPERATIONS FOR UPDATING CHROME
	
	# create list of keys to filter
	local filterkeys=(CFBundleDisplayName string "$CFBundleDisplayName" \
					      CFBundleExecutable string "$CFBundleExecutable" \
					      CFBundleIconFile string "$CFBundleIconFile" \
					      CFBundleIdentifier string "$CFBundleIdentifier" \
					      CFBundleName string "$CFBundleName" \
					      CFBundleShortVersionString string "$SSBVersion" \
					      CFBundleVersion string "$SSBVersion" \
					      CFBundleTypeIconFile string "$CFBundleTypeIconFile" \
					      CFBundleSignature string '????' \
					      BuildMachineOSBuild '' \
					      OSAScriptingDefinition '' \
					      LSHasLocalizedDisplayName '' \
					      UTExportedTypeDeclarations '' \
					      SCMRevision '' \
					      DTSDKBuild '' \
					      DTSDKName '' \
					      DTXcode '' \
					      DTXcodeBuild '' \
					      KSChannelID-32bit '' \
					      KSChannelID-32bit-full '' \
					      KSChannelID-full '' \
					      KSProductID '' \
					      KSUpdateURL '' \
					      KSVersion '' \
					      NSHighResolutionCapable true )
	
	# if we're not registering as a browser, delete these keys too
	if [[ "$SSBRegisterBrowser" != "Yes" ]] ; then
	    filterkeys+=( CFBundleURLTypes '' \
					   NSPrincipalClass '' \
					   NSUserActivityTypes '' )
	fi
	
	# write out Info.plist
	filterchromeinfoplist "$contentsTmp" "$contentsTmp" "${filterkeys[@]}"
	
	
	# WRITE OUT CONFIG FILE
	
	if [[ "$ok" ]] ; then
	    # set up output versions of Chrome variables
	    SSBChromePath="$chromePath"    
	    SSBChromeVersion="$chromeVersion"
	fi
	
	writeconfig "$contentsTmp"
	
	# set ownership of app bundle to this user (only necessary if running as admin)
	setowner "$appPath" "$contentsTmp" "app bundle Contents directory"
	
	
	# MOVE CONTENTS TO PERMANENT HOME
	if [[ ! "$chromeOnly" ]] ; then
	    if [[ "$ok" ]] ; then
		permanent "$contentsTmp" "$appPath/Contents" "app bundle Contents directory"
	    else
		# remove temp contents on error
		rmtemp "$contentsTmp" 'Contents folder'
	    fi
	fi
	

	# IF UPDATING (NOT CREATING A NEW APP), RELAUNCH AFTER A DELAY
	if [[ "$ok" && ! "$newApp" ]] ; then
	    relaunch "$appPath" 1 &
	    disown -ar
	    exit 0
	fi
    fi

    [[ "$ok" ]] && return 0
    return 1    
}
