#!/bin/sh
#
#  runtime.sh: runtime utility functions for Epichrome creator & apps
#  Copyright (C) 2019  David Marmor
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

# shell options
shopt -s nullglob


# NOTE: the "try" function and many other functions in this system clear
#       the "ok" global variable on error, set a message in "errmsg",
#       and return 0 on success, non-zero on error


# CONSTANTS

# app executable name
CFBundleExecutable="Epichrome"

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="document.icns"

# bundle IDs
appIDRoot="org.epichrome"
appIDBase="$appIDRoot.app"
appEngineIDBase="$appIDRoot.eng"

# Google Chrome ID
googleChromeID='com.google.Chrome'

# important paths -- relative to app Contents directory
appInfoPlist="Info.plist"
appEngine="Resources/Engine"
appPayload="$appEngine/Payload"
appConfigScript="Resources/Scripts/config.sh"
appGetVersionScript="Resources/Scripts/getversion.py"
appCleanup="Resources/EpichromeCleanup.app"

# profile base
appProfileBase="Library/Application Support/Epichrome"

# get name of innermost app for debug logs
debugLogApp="${BASH_SOURCE[0]##*.[aA][pP][pP]}"
debugLogApp="${BASH_SOURCE[0]%$debugLogApp}"
[[ "$debugLogApp" ]] || debugLogApp="${BASH_SOURCE[0]}"
debugLogApp="${debugLogApp##*/}"
debugLogApp="${debugLogApp%.[aA][pP][pP]}"

# set general debug log path (overridden by individual apps)
debugLogPath="$appProfileBase/debug_log.txt"


# JOIN_ARRAY: join a bash array into a string with an arbitrary delimiter
function join_array { # (DELIMITER)
    local delim=$1; shift
    
    echo -n "$1"
    shift
    printf "%s" "${@/#/$delim}"
}

# DEBUGLOG: log to stderr & a log file if debug is on
function debuglog {
    if [[ "$debug" ]] ; then
	local trace=()
	local src=( "$debugLogApp" )
	local i=1
	while [[ "$i" -lt "${#FUNCNAME[@]}" ]] ; do
	    if [[ "${FUNCNAME[$i]}" = source ]] ; then
	     	src+=( "${BASH_SOURCE[$i]##*/}(${BASH_LINENO[$(($i - 1))]})" )
		break
	    else
		trace=( "${FUNCNAME[$i]}(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
	    fi
	    i=$(( $i + 1 ))
	done

	local prefix="$(join_array '/' "${trace[@]}")"
	src="$(join_array '|' "${src[@]}")"
	[[ "$src" ]] && prefix="$src [$prefix]"
	
	debuglog_raw "$prefix:" "$@"
    fi
}
function debuglog_raw {
    if [[ "$debug" ]] ; then
	echo "$@" 1>&2
	[[ -f "$debugLogPath" ]] && echo "$@" >> "$debugLogPath"
    fi
}


# TRY: try to run a command, as long as no errors have already been thrown
#
#      usage:
#        try 'varname=' cmd args ... 'Error message.'        [scalar var]
#        try 'varname=()' cmd args ... 'Error message.'      [array var]
#        try 'varname+=()' cmd args ... 'Error message.'     [append array]
#        try 'filename.txt<' cmd args ... 'Error message.'   [overwrite file]
#        try 'filename.txt<<' cmd args ... 'Error message.'  [append file]
#            for any of the above put & before the specifier to
#            also capture stderr
#        try cmd args ... 'Error message.'
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
	local type=
	local ignorestderr=1

	# figure out which type of storage to do
	if [[ "${target:${#target}-1}" = '=' ]]; then
	    # storing in a variable as a string
	    target="${target::${#target}-1}"
	    type=scalar
	    shift
	elif [[ "${target:${#target}-4}" = '+=()' ]] ; then
	    # append to array
	    target="${target::${#target}-4}"
	    type=array_append
	    shift
	elif [[ "${target:${#target}-3}" = '=()' ]] ; then
	    # store as array
	    target="${target::${#target}-3}"
	    type=array
	    shift
	elif [[ "${target:${#target}-2}" = '<''<' ]]; then
	    # append to file
	    target="${target::${#target}-2}"
	    type=file_append
	    shift
	elif [[ "${target:${#target}-1}" = '<' ]] ; then
	    # append to file
	    target="${target::${#target}-1}"
	    type=file
	    shift
	else
	    # not storing
	    target=
	fi
	
	# determine handling of stderr
	if [[ "$type" && ( "${target:${#target}-1}" = '&' ) ]] ; then
	    # keep stderr
	    target="${target::${#target}-1}"
	    ignorestderr=
	fi
	
	# get command-line args
	local args=("$@")
	
	# last arg is error message
	local last=$((${#args[@]} - 1))
	local myerrmsg="${args[$last]}"
	unset "args[$last]"
	
	# run the command
	local result=
	local try_stderr=
	if [[ "$type" = scalar ]] ; then
	    
	    # store output as string in named variable
	    
	    local temp=
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    #temp="$("${args[@]}")"
		    #result="$?"
		    eval "$( "${args[@]}" \
		    	     2> >(try_stderr=$(cat); declare -p try_stderr) \
		    	     > >(temp=$(cat); declare -p temp); \
			     result=$?; declare -p result )"
		else
		    temp="$("${args[@]}" 2> /dev/null)"
		fi
		result="$?"
	    else
		temp="$("${args[@]}" 2>&1)"
		result="$?"
	    fi
	    
	    # assign to target variable with special characters escaped
	    eval "${target}=$(printf '%q' "$temp")"

	elif [[ "${type::5}" = array ]] ; then
	    
	    # output to array
	    
	    local temp=
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    #temp=( $( "${args[@]}" ) )
		    #result="$?"
		    eval "$( "${args[@]}" \
		            2> >(try_stderr=$(cat); declare -p try_stderr) \
		            > >(declare -a temp="( $(cat) )"; declare -p temp); \
		    	     result=$?; declare -p result )"
		else
		    temp=( $( "${args[@]}" 2> /dev/null ) )
		    result="$?"
		fi
	    else
		temp=( $( "${args[@]}" 2>&1 ) )
		result="$?"
	    fi
	    
	    # # assign to target variable with special characters escaped
	    [[ "$type" = array ]] && eval "${target}=()"
	    local t
	    for t in "${temp[@]}" ; do
	    	eval "${target}+=( $(printf '%q' "$t") )"
	    done
	    
	elif [[ "$type" = file_append ]] ; then
	    # append stdout to a file
	    if [[ "$ignorestderr" ]] ; then
		if [[ "$debug" ]] ; then
		    #"${args[@]}" >> "$target"
		    #result="$?"
		    eval "$( "${args[@]}" \
		    	     2> >(try_stderr=$(cat); declare -p try_stderr) \
		    	     >> "$target"; \
			     result=$?; declare -p result )"
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
		    #"${args[@]}" > "$target"
		    #result="$?"
		    eval "$( "${args[@]}" \
		    	     2> >(try_stderr=$(cat); declare -p try_stderr) \
		    	     > "$target"; \
			     result=$?; declare -p result )"
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
		    try_stderr="$( "${args[@]}" 2>&1 )"
		    result="$?"
		else
		    "${args[@]}" > /dev/null 2>&1
		    result="$?"
		fi
	    fi
	fi
	
	if [[ "$try_stderr" ]] ; then
	    debuglog "$try_stderr"
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


# DIALOG -- display a dialog and return the button pressed
function dialog {  # VAR MESSAGE TITLE ICON (if starts with | try app icon first) BUTTON1 BUTTON2 BUTTON3 (+ = default, - = cancel)

    if [[ "$ok" ]] ; then

	local var="$1" ; shift ; [[ "$var" ]] || var=var  # if not capturing, just save dialog text to this local
	local msg="${1//\"/\\\"}" ; shift
	local title="${1//\"/\\\"}" ; shift
	local title_code="$title" ; [[ "$title_code" ]] && title_code="with title \"$title_code\""
	
	# build icon code
	local icon="$1" ; shift
	local icon_set=
	local icon_code=
	if [ "${icon::1}" = "|" ] ; then
	    icon="${icon:1}"
	    [[ ! "$icon" =~ ^stop|caution|note$ ]] && icon=caution
	    icon_set="set myIcon to (POSIX file \"$myPath/Contents/Resources/$CFBundleIconFile\")
tell application \"Finder\"
    if (not exists myIcon) or ((the name extension of (myIcon as alias)) is not \"icns\") then
        set myIcon to $icon
    end if
end tell"
	else
	    [[ "$icon" =~ ^stop|caution|note$ ]] && icon_set="set myIcon to $icon"
	fi
	[[ "$icon_set" ]] && icon_code='with icon myIcon'
	
	# build button list
	local buttonlist=
	local button=
	local button_default=
	local button_cancel=
	local try_start=
	local try_end=
	local numbuttons=0
	
	for button in "$@" ; do
	    # increment button count
	    numbuttons=$((${numbuttons} + 1))
	    
	    # identify default and cancel buttons
	    if [[ "${button::1}" = "+" ]] ; then
		button="${button:1}"
		button_default="default button \"$button\""
	    elif [[ ( "${button::1}" = "-" ) || ( "$button" = "Cancel" ) ]] ; then
		button="${button#-}"
		button_cancel="cancel button \"$button\""
		try_start="try"
		try_end="on error number -128
    \"$button\"
end try"
	    fi
	    
	    # add to button list
	    buttonlist="$buttonlist, \"$button\""
	done
	
	# if no buttons specified, make one default OK button
	if [[ "$numbuttons" -eq 0 ]]; then
	    numbuttons=1
	    button='OK'
	    button_default="default button \"$button\""
	    buttonlist=", \"$button\""
	fi
	
	# close button list
	buttonlist="{ ${buttonlist:2} }"

	# run the dialog
	
	try "${var}=" osascript -e "$icon_set
$try_start
    button returned of (display dialog \"$msg\" $title_code $icon_code buttons $buttonlist $button_default $button_cancel)
$try_end" 'Unable to display dialog box!'

	# dialog failure -- if this is an alert, fallback to basic alert
	if [[ ! "$ok" && ("$numbuttons" = 1) ]] ; then
	    # dialog failed, try an alert
	    ok=1
	    
	    # display simple alert with fallback icon
	    [[ "$icon" ]] && icon="with icon $icon"
	    osascript -e "display alert \"$msg\" $icon buttons {\"OK\"} default button \"OK\" $title_code" > /dev/null 2>&1
	    
	    if [[ "$?" != 0 ]] ; then
		# alert failed too!
		echo "Unable to display alert with message: $msg" 1>&2
		ok=
	    fi
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# ALERT -- display a simple alert dialog box (whether ok or not)
function alert {  #  MESSAGE TITLE ICON (stop, caution, note)
    local result=
    
    # save ok state
    local oldok="$ok"
    local olderrmsg="$errmsg"
    ok=1
    errmsg=

    # show the alert
    dialog '' "$1" "$2" "$3"
    result="$?"
    
    # add new error message or restore old one
    if [[ "$olderrmsg" && "$errmsg" ]] ; then
	errmsg="$olderrmsg Also: ${errmsg}."
    elif [[ "$olderrmsg" ]] ; then
	errmsg="$olderrmsg"
    fi
    
    # if ok was off or we turned it off, turn it off
    [[ "$oldok" ]] || ok="$oldok"
    
    return "$result"
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
    
    # special handling for trailing text: if V1 has trailing text & V2 doesn't,
    # V1 was pre-release & V2 is release; otherwise, if both have trailing text,
    # just compare it
    if [[ ( "${old[3]}" && ! "${new[3]}" ) || \
	      ( "${old[3]}" && "${new[3]}" && ( "${old[3]}" < "${new[3]}" ) ) ]] ; then
	echo "1"
	return 1
    fi 
    
    # if we got here, the V1 >= V2
    return 0
}


# FILTERPLIST: write out a new plist file by filtering an input file with PlistBuddy
function filterplist {  # SRC-FILE DEST-FILE TRY-ERROR-ID PLISTBUDDY-COMMANDS
    
    if [[ "$ok" ]]; then
	
	# source & dest files
	local srcFile="$1"
	local destFile="$2"

	# ID of this plist file for messaging
	local tryErrorID="$3"
	
	# command list, appended with save & exit commands
	local plistbuddyCommands="$4
Save
Exit"	

	
	# create name for temp destination file
	local destFileTmp="$(tempname "$destFile")"

	echo "copying $srcFile to $destFileTmp" 1>&2
	echo 1>&2
	
	# copy source file to temp
	try cp "$srcFile" "$destFileTmp" "Unable to create temporary $tryErrorID."
	
	if [[ "$ok" ]] ; then
	    
	    # use PlistBuddy to filter temp plist
	    if [[ "$debug" ]] ; then
		echo "$plistbuddyCommands" | /usr/libexec/PlistBuddy "$destFileTmp" 1>&2
	    else
		echo "$plistbuddyCommands" | /usr/libexec/PlistBuddy "$destFileTmp" > /dev/null 2>&1
	    fi
	    
	    if [[ "$?" = 0 ]] ; then
		# move temp file to permanent location
		permanent "$destFileTmp" "$destFile" "$tryErrorID"
	    else
		ok=
		errmsg="Error filtering $tryErrorID."
		
		# delete the temp file
		rmtemp "$destFileTmp" "$tryErrorID"
	    fi
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# LPROJESCAPE: escape a string for insertion in an InfoPlist.strings file
function lprojescape { # string
    s="${1/\\/\\\\\\\\}"  # escape backslashes for both sed & .strings file
    s="${s//\//\\/}"  # escape forward slashes for sed only
    echo "${s//\"/\\\\\"}"  # escape double quotes for both sed & .strings file
}


# FILTERLPROJ: destructively filter all InfoPlist.strings files in a set of .lproj directories
function filterlproj {  # BASE-PATH SEARCH-NAME MESSAGE-INFO

    if [[ "$ok" ]] ; then
	
	# path to folder containing .lproj folders
	local basePath="$1" ; shift

	# name to search for in access strings
	local searchString="$1" ; shift

	# info about this filtering for error messages
	local messageInfo="$1" ; shift
	
	# escape bundle name strings
	local displayName="$(lprojescape "$CFBundleDisplayName")"
	local bundleName="$(lprojescape "$CFBundleName")"

	# filter InfoPlist.strings files
	local curLproj=
	for curLproj in "$basePath/"*.lproj ; do
	    
	    # get paths for current in & out files
	    local curStringsIn="$curLproj/InfoPlist.strings"
	    local curStringsOutTmp="$(tempname "${curStringsIn}")"

	    if [[ -f "$curStringsIn" ]] ; then
		# filter current localization
		try "$curStringsOutTmp<" /usr/bin/sed -E \
		    -e 's/^((NS[A-Za-z]+UsageDescription) *= *".*)'"$searchString"'(.*"; *)$/\1'"$displayName"'\3/' \
		    -e 's/^(CFBundleName *= *").*("; *)$/\1'"$bundleName"'\2/' -e 's/^(CFBundleDisplayName *= *").*("; *)$/\1'"$displayName"'\2/' \
		    "$curStringsIn" \
		    "Unable to filter $messageInfo localization strings."

		# move file to permanent home
		permanent "$curStringsOutTmp" "$curStringsIn" "$messageInfo localization strings"

		# on any error, abort
		if [[ ! "$ok" ]] ; then
		    # remove temp output file on error
		    rmtemp "$curStringsOutTmp" "$messageInfo localization strings"
		    break
		fi
	    fi
	done
    fi
}


# EPICHROMEINFO: get absolute path and version info for Epichrome
function epichromeinfo { # (optional)EPICHROME-PATH
    #                         sets the following globals:
    #                             epiPath, epiVersion,
    #                             epiContents,
    #                             epiEngine, epiEngineRuntime, epiPayload
    
    if [[ "$ok" ]]; then
	
	# default value
	epiVersion="$SSBVersion"
	epiPath=
		
	# if a path is specified, only use that path
	if [[ "$1" ]] ; then
	    epiPath=( "$1" )
	else
	    
	    # use spotlight to find Epichrome instances
	    try 'epiPath=' /usr/bin/mdfind \
			    "kMDItemCFBundleIdentifier == '${appIDRoot}.Epichrome'" \
			    'error'
	    if [[ "$ok" ]] ; then
		# get paths to all Epichrome.app instances found
		
		# break up result into array
		local oldifs=$IFS
		IFS=$'\n'
		epiPath=($epiPath)
		IFS="$oldifs"
	    else
		# ignore mdfind errors
		ok=1
		errmsg=
	    fi
	    
	    # if spotlight fails (or is off) try hard-coded locations
	    if [[ ! "$epiPath" ]] ; then
		epiPath+=( ~/'Applications/Epichrome.app' \
			       '/Applications/Epichrome.app' )
	    fi
	fi

	# find all instances of Epichrome on the system
	local curPath=
	local latestPath=
	local latestVersion=0.0.0
	for curPath in "${epiPath[@]}" ; do
	    if [[ -d "$curPath" ]] ; then
		debuglog "found Epichrome instance at '$curPath'"
		
		# get current value for epiVersion
		try source "${curPath}/Contents/Resources/Scripts/version.sh" ''
		if [[ "$ok" ]] ; then
		    if [[ $(newversion "$latestVersion" "$epiVersion") ]] ; then
			latestPath="$curPath"
			latestVersion="$epiVersion"
		    fi
		else
		    ok=1 ; errmsg=
		fi
	    fi
	done
	
	if [[ "$latestPath" ]] ; then
	    # use the latest version
	    epiPath="$latestPath"
	    epiVersion="$latestVersion"
	    debuglog "latest Epichrome instance found: version $epiVersion at '$epiPath'"
	else
	    # not found
	    epiPath=
	    epiVersion="0.0.0"
	    
	    errmsg="Unable to find Epichrome."
	    ok=
	    return 1
	fi
    fi

    # set useful globals
    epiContents="$epiPath/Contents"
    epiEngine="$epiContents/Resources/Engine"
    epiEngineRuntime="$epiContents/Resources/Engine/Runtime"
    epiPayload="$epiContents/Resources/Engine/Payload"
    
    [[ "$ok" ]] && return 0
    return 1
}


# GOOGLECHROMEINFO: find absolute paths to and info on relevant Google Chrome items
#                   sets the following variables:
#                      SSBGoogleChromePath, SSBGoogleChromeVersion, SSBGoogleChromeExec, googleChromeContents
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
	# set up dependant variables
	googleChromeContents="$SSBGoogleChromePath/Contents"
	return 0
    else
	return 1
    fi
}


# CREATEENGINEPAYLOAD: create persistent engine payload
function createenginepayload { # $1 = Contents path
    
    local enginePath="$1/$appEngine"
    local payloadContents="$1/$appPayload/Contents"

    # clear out old engine
    if [[ -d "$enginePath" ]] ; then
	try /bin/rm -rf "$enginePath"/* "$enginePath"/.[^.]* 'Unable to clear old engine.'
    fi
    
    # create persistent payload
    if [[ "$ok" ]] ; then
	
	if [[ "$SSBEngineType" != "Google Chrome" ]] ; then

	    # CHROMIUM PAYLOAD

	    # create engine directory
	    try /bin/mkdir -p "$enginePath" \
		'Unable to create app engine directory.'

	    # copy payload items from Epichrome
	    try /bin/cp -a "$epiPayload" "$enginePath" \
		'Unable to copy items to app engine payload.'
	    
	    # filter Info.plist with app info
	    filterplist "$payloadContents/Info.plist.in" \
			"$payloadContents/Info.plist.off" \
			"app engine Info.plist" \
			"
set :CFBundleDisplayName $CFBundleDisplayName
set :CFBundleName $CFBundleName
set :CFBundleIdentifier ${appEngineIDBase}.$SSBIdentifier
Delete :CFBundleDocumentTypes
Delete :CFBundleURLTypes"

	    if [[ "$ok" ]] ; then
		try /bin/rm -f "$payloadContents/Info.plist.in" \
		    'Unable to remove app engine Info.plist template.'
	    fi
	    
	    # filter localization strings
	    filterlproj "$payloadContents/Resources" Chromium 'app engine'
	    
	else

	    # GOOGLE CHROME PAYLOAD
	    
	    try /bin/mkdir -p "$payloadContents/Resources" \
		'Unable to create Google Chrome app engine Resources directory.'
	    
	    # copy engine executable (linking causes confusion between apps & real Chrome)
	    try /bin/cp -a "$googleChromeContents/MacOS" "$payloadContents" \
		'Unable to copy Google Chrome executable to app engine payload.'

	    # copy .lproj directories
	    try /bin/cp -a "$googleChromeContents/Resources/"*.lproj "$payloadContents/Resources" \
		'Unable to copy Google Chrome localizations to app engine payload.'
	    
	    # filter localization files
	    filterlproj "$payloadContents/Resources" Chrome 'Google Chrome app engine'
	fi	
	
	# link to this app's icons
	if [[ "$ok" ]] ; then
	    try /bin/ln -s "../../../../$CFBundleIconFile" \
		"$payloadContents/Resources/$chromeBundleIconFile" \
		"Unable to link app engine to application icon file. '../../../../$CFBundleIconFile'"
	    try /bin/ln -s "../../../../$CFBundleTypeIconFile" \
		"$payloadContents/Resources/$chromeBundleTypeIconFile" \
		"Unable to link app engine to document icon file."
	fi
    fi
}


# MAKEAPPICONS: wrapper for makeicon.sh
function makeappicons {  # INPUT OUTPUT-DIR app|doc|both
    if [[ "$ok" ]] ; then

	# find makeicon.sh
	local makeIconScript="$epiContents/Resources/Scripts/makeicon.sh"
	[[ -e "$makeIconScript" ]] || abort "Unable to locate makeicon.sh." 1
	
	# build command-line
	local args=
	local docargs=(-c "$epiContents/Resources/docbg.png" 256 286 512 "$1" "$2/$CFBundleTypeIconFile")
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


# CONFIGVARS: list of variables in config.sh
appConfigVarsCommon=( SSBIdentifier \
			  SSBCommandLine \
			  CFBundleDisplayName \
			  CFBundleName \
			  SSBVersion \
			  SSBUpdateCheckDate \
			  SSBUpdateCheckVersion \
			  SSBEngineType \
			  SSBEngineAppName \
			  SSBEngineAppPath \
			  SSBProfilePath \
			  SSBCustomIcon \
			  SSBFirstRun \
			  SSBFirstRunSinceVersion \
			  SSBHostInstallError )
appConfigVarsGoogleChrome=( SSBGoogleChromePath \
				SSBGoogleChromeVersion \
				SSBGoogleChromeExec )


# READCONFIG: read in config.sh file & save config versions to track changes
function readconfig {
    
    safesource "$myContents/$appConfigScript" "config file"
    
    if [[ "$ok" && ! ( "$SSBIdentifier" && "$CFBundleDisplayName" && \
			   "$SSBVersion" && "$SSBProfilePath" ) ]] ; then
	ok=
	errmsg='Config file is corrupt.'
    fi

    if [[ "$ok" ]] ; then
	
	# create full list of config vars based on engine type
	local myConfigVars=( "${appConfigVarsCommon[@]}" )
	if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	    myConfigVars+=( "${appConfigVarsGoogleChrome[@]}" )
	fi
	
	# save all relevant config variables prefixed with "config"
	
	for varname in "${myConfigVars[@]}" ; do
	    
	    if [[ "$(isarray "$varname")" ]]; then
		# copy array value
		eval "config$varname=(\"\${$varname[@]}\")"
		[[ "$debug" ]] && eval "debuglog \"$varname=( \${config$varname[*]} )\""
	    else
		
		# copy scalar value
		eval "config$varname=\"\${$varname}\""
		[[ "$debug" ]] && eval "debuglog \"$varname=\$config$varname\""
	    fi
	done
    fi
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # DEST-CONTENTS-DIR FORCE
    
    local destContents="$1"
    local force="$2"
    
    if [[ "$ok" ]] ; then
	
	# create full list of config vars based on engine type
	local myConfigVars=( "${appConfigVarsCommon[@]}" )
	if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	    myConfigVars+=( "${appConfigVarsGoogleChrome[@]}" )
	fi
	
	# determine if we need to write the config file

	# we're being told to write no matter what
	local dowrite="$force"
	
	# not being forced, so compare all config variables for changes
	if [[ ! "$dowrite" ]] ; then
	    local varname=
	    local configname=
	    for varname in "${myConfigVars[@]}" ; do
		configname="config${varname}"
		
		local varisarray="$(isarray "$varname")"
		
		# if variables are not the same type
		if [[ "$varisarray" != "$(isarray "$configname")" ]] ; then
		    dowrite=1
		    break
		fi
		
		if [[ "$varisarray" ]] ; then
		    
		    # variables are arrays, so compare part by part
		    
		    # check for the same length
		    local varlength="$(eval "echo \${#$varname[@]}")"
		    if [[ "$varlength" \
			      -ne "$(eval "echo \${#$configname[@]}")" ]] ; then
			dowrite=1
			break
		    fi
		    
		    # compare each element in both arrays
		    local i=0
		    while [[ "$i" -lt "$varlength" ]] ; do
			if [[ "$(eval "echo \${$varname[$i]}")" \
				  != "$(eval "echo \${$configname[$i]}")" ]] ; then
			    dowrite=1
			    break
			fi
			i=$(($i + 1))
		    done
		    
		    # if we had a mismatch, break out of the outer loop
		    [[ "$dowrite" ]] && break
		else
		    
		    # variables are scalar, simple compare
		    if [[ "$(eval "echo \${$varname}")" \
			      != "$(eval "echo \${$configname}")" ]] ; then
			dowrite=1
			break
		    fi
		fi
	    done
	fi
	
	# if we need to, write out the file
	if [[ "$dowrite" ]] ; then
	    
	    local configScript="$destContents/$appConfigScript"
	    
	    # write out the config file
	    writevars "$configScript" "${myConfigVars[@]}"
	    
	    # set ownership of config file
	    setowner "$destContents/.." "$configScript" "config file"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# CHECKEPICHROMEVERSION: function that checks for a new version of Epichrome on github
function checkepichromeversion { # CONTENTS-PATH (optional)NOMINAL-VERSION

    # URL for the latest Epichrome release
    local updateURL='https://github.com/dmarmor/epichrome/releases/latest'
    
    # call Python script to check github for the latest version
    local latestVersion="$( "$1/$appGetVersionScript" 2> /dev/null )"
    if [[ "$?" != 0 ]] ; then
	ok=
	errmsg="$latestVersion"
    fi
    
    # set current version to compare against
    local curVersion="$epiVersion"
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


# UPDATEAPP: function that populates an app bundle
function updateapp {
    
    if [[ "$ok" ]] ; then
	
	# arguments
	local appPath="$1"        # path to the app bundle
	local customIconDir="$2"  # path to custom icon directory
	
	if [[ ! "$SSBEngineType" ]] ; then
	    
	    # No engine type in config, so we're updating from an old Google Chrome app

	    # Allow the user to choose which engine to use (Chromium is the default)
	    dialog useChromium \
		   "SOME TEXT ABOUT CHROMIUM ENGINE." \
		   "Choose App Engine" \
		   "|caution" \
		   "+Yes" \
		   "-No"
	    if [[ ! "$ok" ]] ; then
		alert "CHROMIUM ENGINE TEXT but the update dialog failed. Attempting to update with Chromium engine. If this is not what you want, you must abort the app now." 'Update' '|caution'
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

	if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	    # Google Chrome engine: make sure we've got Chrome info
	    [[ "$SSBGoogleChromePath" && "$SSBGoogleChromeVersion" ]] || googlechromeinfo
	fi


	# PERFORM UPDATE
	
	# put updated bundle in temporary Contents directory
	local contentsTmp="$(tempname "$appPath/Contents")"
	
	# copy in the boilerplate for the app
	try /bin/cp -a "$epiContents/Resources/Runtime" "$contentsTmp" 'Unable to populate app bundle.'
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
	    makeappicons "$customIconDir/$CFBundleIconFile" "${contentsTmp}/Resources" doc
	    if [[ ! "$ok" ]] ; then
		errmsg="Unable to update doc icon ($errmsg)."
	    fi
	    
	elif [[ -e "$customIconDir/$CFBundleTypeIconFile" ]] ; then
	    # copy in existing custom doc icon
	    safecopy "$customIconDir/$CFBundleTypeIconFile" "${contentsTmp}/Resources/$CFBundleTypeIconFile" "custom icon"
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
	    SSBVersion="$epiVersion"
	    SSBUpdateCheckVersion="$epiVersion"
	    
	    # clear host install error state
	    SSBHostInstallError=
	fi
	

	# FILTER BOILERPLATE INFO.PLIST WITH APP INFO

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

	# $$$ CLEAN THIS UP
	# if using Google Chrome engine, do not register as a background app
	# (to prevent losing custom icon)
# 	if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
# 	    filterCommands="$filterCommands
# Delete :LSUIElement"
# 	fi
	
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
	
	
	# MOVE CONTENTS TO PERMANENT HOME
	if [[ ! "$chromeOnly" ]] ; then
	    if [[ "$ok" ]] ; then
		permanent "$contentsTmp" "$appPath/Contents" "app bundle Contents directory"
	    else
		# remove temp contents on error
		rmtemp "$contentsTmp" 'Contents folder'
	    fi
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# $$$ REMOVE THIS IN FUTURE VERSIONS
function updatessb {
    updateapp "$@"
}
