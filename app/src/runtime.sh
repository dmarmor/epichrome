#!/bin/sh
#
#  runtime.sh: runtime utility functions for Epichrome creator & apps
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

# BUILD FLAGS

#debug=
#logPreserve=


# SHELL OPTIONS

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
appConfigScriptPath="Resources/Scripts/config.sh"
appCleanupPath="Resources/EpichromeCleanup.app"

# profile base
epiProfileBase="Library/Application Support/Epichrome"
epiProfilePath="$HOME/$epiProfileBase"
appProfileBase="$epiProfileBase/Apps"

# app profile paths -- relative to app profile directory
appProfileMainPath='_epichrome'
appProfileEnginePath="$appProfileMainPath/Engine"
appProfilePayloadPath="$appProfileMainPath/Engine/Payload"

# dialog icon path
appDialogIcon="${BASH_SOURCE[0]%/Scripts/*}/app.icns"

# logging info (can be overridden by individual apps)
[[ "$logApp" ]] || logApp="Epichrome"
[[ "$logPath" ]] || logPath="$epiProfilePath/epichrome_log.txt"
#logNoStderr=  # set this in calling script to prevent logging to stderr
#logNoFile=    # set this in calling script to prevent logging to file

stderrTempFile="$epiProfilePath/stderr.txt"


# JOIN_ARRAY: join a bash array into a string with an arbitrary delimiter
function join_array { # (DELIMITER)
    local delim=$1; shift
    
    printf "$1"
    shift
    printf "%s" "${@/#/$delim}"
}

# LOGGING: log to stderr & a log file
function errlog {
	local trace=()
	local src=( "$logApp" )
	local i=1
	local curfunc=
	while [[ "$i" -lt "${#FUNCNAME[@]}" ]] ; do
	    curfunc="${FUNCNAME[$i]}"
	    if [[ ( "$curfunc" = source ) || ( "$curfunc" = main ) ]] ; then
	     	src+=( "${BASH_SOURCE[$i]##*/}(${BASH_LINENO[$(($i - 1))]})" )
		break
	    elif [[ ( "$curfunc" = errlog ) || ( "$curfunc" = debuglog ) ]] ; then
		: # skip these functions
	    else
		trace=( "$curfunc(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
	    fi
	    i=$(( $i + 1 ))
	done

	local prefix="$(join_array '/' "${trace[@]}")"
	src="$(join_array '|' "${src[@]}")"
	if [[ "$src" && "$prefix" ]] ; then
	    prefix="$src [$prefix]: "
	elif [[ "$src" ]] ; then
	    prefix="$src: "
	elif [[ "$prefix" ]] ; then
	    prefix="$prefix: "
	fi
	
	errlog_raw "$prefix$@"
 }
function errlog_raw {

    # if we're logging to stderr, do it
    [[ "$logNoStderr" ]] ||	echo "$@" 1>&2
    
    # if we're logging to file & either the file exists & is writeable, or
    # the file doesn't exist and its parent directory is writeable, do it
    if [[ ( ! "$logNoFile" ) && \
	      ( ( ( -f "$logPath" ) && ( -w "$logPath" ) ) || \
		    ( ( ! -e "$logPath" ) && ( -w "${logPath%/*}" ) ) ) ]] ; then
	echo "$@" >> "$logPath"
    fi
}
function debuglog {
    [[ "$debug" ]] && errlog "$@"
}
function debuglog_raw {
    [[ "$debug" ]] && errlog_raw "$@"
}

# INITLOG: initialize log file
function initlog {

    if  [[ ( ! "$logPreserve" ) && ( -f "$logPath" ) ]] ; then
	# we're not saving logs & the logfile exists, so clear it, ignoring failure
	/bin/cat /dev/null > "$logPath"
    else
	# make sure the log file & its path exist
	/bin/mkdir -p "${logPath%/*}"
	/usr/bin/touch "$logPath"
    fi

    # check if we can write to stderr or if we need to disable it
    ( /bin/mkdir -p "${stderrTempFile%/*}" && /usr/bin/touch "$stderrTempFile" ) > /dev/null 2>&1
    if [[ $? != 0 ]] ; then
	errlog "Unable to direct stderr to '$stderrTempFile' -- stderr output will not be logged."
	stderrTempFile='/dev/null'
    fi
}


# TRY: try to run a command, as long as no errors have already been thrown
#
#      usage:
#        try 'varname=' cmd args ... 'Error message.'        [scalar var]
#        try 'varname+=' cmd args ... 'Error message.'        [append scalar]
#        try 'varname=([tn]|anything)' cmd args ... 'Error message.'      [array var]
#        try 'varname+=([tn]|anything)' cmd args ... 'Error message.'     [append array]
#        try 'filename.txt<' cmd args ... 'Error message.'   [overwrite file]
#        try 'filename.txt<<' cmd args ... 'Error message.'  [append file]
#            for any of the above put & before the specifier to
#            also capture stderr
#        try cmd args ... 'Error message.'  [log stdout/stderr together]
#        try '![1|2|12]' cmd args ... 'Error message.' [don't log stdout/stderr or both]
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
	local ifscode=
	local storeStderr=
	local dropStdout= ; local dropStderr=
	
	# figure out which type of storage to do
	if [[ "$target" =~ (\+?)=$ ]]; then
	    # storing in a variable as a string
	    target="${target::${#target}-${#BASH_REMATCH[0]}}"
	    type=scalar
	    [[ "${BASH_REMATCH[1]}" ]] && type="${type}_append"
	    shift
	elif [[ "$target" =~ (\+?)=\(([^\)]?)\)$ ]] ; then
	    # array
	    target="${target::${#target}-${#BASH_REMATCH[0]}}"
	    type=array
	    [[ "${BASH_REMATCH[1]}" ]] && type="${type}_append"
	    ifscode="${BASH_REMATCH[2]}"
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
	elif [[ ( "${target::1}" = '!' ) && \
		    "${target:1:${#target}-1}" =~ ^(1|2|12|21)$ ]] ; then
	    	    
	    target=
	    shift
	    
	    # not storing, and dropping stdout or stderr or both
	    case "${BASH_REMATCH[0]}" in
		1)
		    dropStdout=1
		    ;;
		2)
		    dropStderr=1
		    ;;
		12|21)
		    dropStdout=1
		    dropStderr=1
		    ;;
	    esac
	else
	    # not storing, logging both stdout & stderr
	    target=
	fi

	# handle special ifscode values
	if [[ "$ifscode" = t ]] ; then
	    ifscode=$'\t\n'
	elif [[ "$ifscode" = n ]] ; then
	    ifscode=$'\n'
	elif [[ ! "$ifscode" ]] ; then
	    ifscode="$IFS"  # no IFS given, so use current value
	fi
	
	# determine handling of stderr
	if [[ "$type" && ( "${target:${#target}-1}" = '&' ) ]] ; then
	    # keep stderr
	    target="${target::${#target}-1}"
	    storeStderr=1
	fi
	
	# get command-line args
	local args=("$@")
	
	# last arg is error message
	local last=$((${#args[@]} - 1))
	local myerrmsg="${args[$last]}"
	unset "args[$last]"
	
	# run the command
	local result=
	if [[ ( "${type::6}" = scalar ) || ( "${type::5}" = array ) ]] ; then

	    # store output as string initially
	    
	    local temp=
	    if [[ ! "$storeStderr" ]] ; then
		if [[ ! "$dropStderr" ]] ; then
		    temp="$( "${args[@]}" 2> "$stderrTempFile" )"
		else
		    temp="$( "${args[@]}" )"
		fi
		result="$?"
	    else
		temp="$("${args[@]}" 2>&1)"
		result="$?"
	    fi

	    # put output into the correct type of variable
	    
	    # if we're not appending, start with an empty target
	    [[ "${type:${#type}-6:6}" = append ]] || eval "$target="
	    
	    if [[ "${type::6}" = scalar ]] ; then
		
		# scalar
		
		# append the output to the target
		eval "$target=\"\${$target}\${temp}\""
	    else
		
		# array

		# break up the output using our chosen delimiter (and newline, no way around that)
		local temparray=
		while IFS="$ifscode" read -ra temparray ; do
		      eval "$target+=( \"\${temparray[@]}\" )"
		done <<< "$temp"
	    fi
	    
	elif [[ "$type" = file_append ]] ; then
	    # append stdout to a file
	    if [[ ! "$storeStderr" ]] ; then
		if [[ ! "$dropStderr" ]] ; then
		    "${args[@]}" >> "$target" 2> "$stderrTempFile"
		else
		    "${args[@]}" >> "$target"
		fi
		result="$?"
	    else
		"${args[@]}" >> "$target" 2>&1
		result="$?"
	    fi
	elif [[ "$type" = file ]] ; then
	    # store stdout in a file
	    if [[ ! "$storeStderr" ]] ; then
		if [[ ! "$dropStderr" ]] ; then
		    "${args[@]}" > "$target" 2> "$stderrTempFile"
		else
		    "${args[@]}" > "$target"
		fi
		result="$?"
	    else
		"${args[@]}" > "$target" 2>&1
		result="$?"
	    fi
	else
	    # not storing, so put both stdout & stderr into stderr log
	    # unless we're dropping either or both
	    if [[ ( ! "$dropStdout" ) && ( ! "$dropStderr" ) ]] ; then
		
		# log both stdout & stderr
		"${args[@]}" > "$stderrTempFile" 2>&1
		
	    elif [[ ! "$dropStdout" ]] ; then
		
		# log stdout & drop stderr
		"${args[@]}" > "$stderrTempFile" 2> /dev/null
		
	    elif [[ ! "$dropStderr" ]] ; then

		# log stderr & drop stdout
		"${args[@]}" > /dev/null 2> "$stderrTempFile"

	    else

		# drop both stdout & stderr
		"${args[@]}" > /dev/null 2>&1
		
	    fi
	    result="$?"
	fi
	
	# log unstored output
	local myStderr=
	[[ ! ( "$dropStdout" && "$dropStderr" ) ]] && myStderr="$(/bin/cat "$stderrTempFile")"
	[[ "$myStderr" ]] && errlog "$myStderr"
	
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
function safesource { # SCRIPT [ARGS... FILEINFO]
    
    # only run if no error
    if [[ "$ok" ]]; then
	
	# get command-line args
	local args=( "$@" )
	local lastIndex=$(( ${#args[@]} - 1 ))
	
	# get file info string & make try error string
	local fileinfo=
	if [[ ( "$#" -lt 2 ) || ( ! "${args[$lastIndex]}" ) ]] ; then
	    
	    # no file info supplied, so autocreate it
	    if [[ "$1" =~ /([^/]+)$ ]] ; then
		fileinfo="${BASH_REMATCH[1]}"
	    else
		fileinfo='empty path'
	    fi
	    args+=( "$fileinfo" )
	else
	    fileinfo="${args[$lastIndex]}"
	fi
	
	# check that the source file exists & is readable
	local myErrPrefix="Error loading $fileinfo: "
	local myErr=
	local sourceFile="${args[0]}"
	[[ ! -e "$sourceFile" ]] && myErr="${myErrPrefix}Nothing found at '$sourceFile'."
	[[ ( ! "$myErr" ) && ( ! -f "$sourceFile" ) ]] && myErr="${myErrPrefix}'$sourceFile' is not a file."
	[[ ( ! "$myErr" ) && ( ! -r "$sourceFile" ) ]] && myErr="${myErrPrefix}'$sourceFile' is not readable."

	if [[ "$myErr" ]] ; then
	    ok=
	    errmsg="$myErr"
	else
	    
	    # try to source the file
	    args[$lastIndex]="Unable to load ${args[$(( ${#args[@]} - 1 ))]}."
	    try source "${args[@]}"
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

    # save ok state
    local oldok="$ok" ; local olderrmsg="$errmsg"
    ok=1 ; errmsg=

    # arguments
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
	if [[ -f "$appDialogIcon" ]] ; then
	    icon_set="set myIcon to (POSIX file \"$appDialogIcon\")"
	else
	    icon_set="set myIcon to $icon"
	fi
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
    
    try "${var}=" /usr/bin/osascript -e "$icon_set
$try_start
    button returned of (display dialog \"$msg\" $title_code $icon_code buttons $buttonlist $button_default $button_cancel)
$try_end" 'Unable to display dialog box!'

    # dialog failure -- if this is an alert, fallback to basic alert
    if [[ ! "$ok" && ("$numbuttons" = 1) ]] ; then
	# dialog failed, try an alert
	ok=1
	
	# display simple alert with fallback icon
	[[ "$icon" ]] && icon="with icon $icon"
	/usr/bin/osascript -e "display alert \"$msg\" $icon buttons {\"OK\"} default button \"OK\" $title_code" > /dev/null 2>&1
	
	if [[ "$?" != 0 ]] ; then
	    # alert failed too!
	    echo "Unable to display alert with message: $msg" 1>&2
	    ok=
	fi
    fi
    
    # add new error message or restore old one
    if [[ "$olderrmsg" && "$errmsg" ]] ; then
	errmsg="$olderrmsg Also: ${errmsg}."
    elif [[ "$olderrmsg" ]] ; then
	errmsg="$olderrmsg"
    fi
    
    # if ok was off or we turned it off, turn it off
    [[ "$oldok" ]] || ok="$oldok"

    [[ "$ok" ]] && return 0
    return 1
}


# ALERT -- display a simple alert dialog box (whether ok or not)
function alert {  #  MESSAGE TITLE ICON (stop, caution, note)
    local result=
    
    # show the alert
    dialog '' "$1" "$2" "$3"
    return "$?"
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


# VCMP -- if V1 OP V2 is true, return 0, else return 1
function vcmp { # ( version1 operator version2 )

    # arguments
    local v1="$1" ; shift ; [[ "$v1" ]] || v1=0.0.0
    local op="$1" ; shift ; [[ "$op" ]] || op='=='
    local v2="$1" ; shift ; [[ "$v2" ]] || v2=0.0.0
    
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
	    vnums[$1]=0
	fi
	
	i=$(( $i + 1 ))
    done

    # compare versions using the operator & return the result
    eval "[[ ${vnums[0]} $op ${vnums[1]} ]]"
}


# FILTERPLIST: write out a new plist file by filtering an input file with PlistBuddy
function filterplist {  # SRC-FILE DEST-FILE TRY-ERROR-ID PLISTBUDDY-COMMANDS
    
    if [[ "$ok" ]]; then
	
	# arguments
	local srcFile="$1"    ; shift
	local destFile="$1"   ; shift
	local tryErrorID="$1" ; shift # ID of this plist file for messaging
	
	# command list, appended with save & exit commands
	local plistbuddyCommands="$1
Save
Exit"	
	
	# create name for temp destination file
	local destFileTmp="$(tempname "$destFile")"
	
	# copy source file to temp
	try cp "$srcFile" "$destFileTmp" "Unable to create temporary $tryErrorID."
	
	if [[ "$ok" ]] ; then
	    
	    # use PlistBuddy to filter temp plist
	    local ignore=
	    echo "$plistbuddyCommands" | try '!1' /usr/libexec/PlistBuddy "$destFileTmp" \
					     "Error filtering $tryErrorID."
	    
	    if [[ "$ok" ]] ; then		
		# move temp file to permanent location
		permanent "$destFileTmp" "$destFile" "$tryErrorID"
	    else
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
e_version=0 ; e_path=1 ; e_contents=2 ; e_engineRuntime=3 ; e_enginePayload=4
function epichromeinfo { # (optional) RESULT-VAR EPICHROME-PATH
    #                         if RESULT-VAR & EPICHROME-PATH are set, populates ARRAY-VAR
    #                         otherwise, populates the following globals:
    #                             epiCompatible, epiLatest
    #                               each is an array with the following elements:
    #                                e_version, e_path, e_contents,
    #                                e_engineRuntime, e_enginePayload
    
    if [[ "$ok" ]]; then
	
	# arguments
	local resultVar="$1" ; shift
	local epiPath="$1" ; shift

	# get the instances of Epichrome we're interested in
	local instances=
	if [[ "$resultVar" && "$epiPath" ]] ; then
	    
	    # we're only getting info on one specific instance of Epichrome
	    instances=( "$epiPath" )
	    
	elif [[ "$resultVar" && ( ! "$epiPath" ) ]] ; then

	    ok= ; errmsg="Bad arguments to epichromeinfo."
	    return 1
	else
	    
	    # search the system for all instances
	    
	    # clear arguments
	    resultVar= ; epiPath=
	    
	    # default return values
	    epiCompatible= ; epiLatest=
	    
	    # use spotlight to find Epichrome instances
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
	fi

	# create maximum compatible version for Chromium engine
	# NOTE: I've arbitrarily decided that versions with the same middle number
	# are Chromium-engine compatible
	local versionCeiling=
	if [[ "$SSBEngineType" = 'Chromium' ]] ; then
	    local mcv_re='^[0-9]+\.[0-9]+\.'

	    if [[ "$SSBVersion" =~ $mcv_re ]] ; then
		versionCeiling="${BASH_REMATCH[0]}999"
	    else
		errlog 'Unexpected version number format. Unable to create maximum compatible version.'
		versionCeiling="$SSBVersion"
	    fi
	fi
	
	# check chosen instances of Epichrome to find the current and latest
	# or just populate our one variable
	local curInstance= ; local curVersion= ; curInfo=
	for curInstance in "${instances[@]}" ; do
	    if [[ -d "$curInstance" ]] ; then
		
		# get this instance's version
		try 'curVersion=' /usr/bin/sed -En -e 's/^epiVersion=(.*)$/\1/p' \
		    "$curInstance/Contents/Resources/Scripts/version.sh" ''

		if ( [[ "$ok" ]] && vcmp 0.0.0 '<' "$curVersion" ) ; then
		    
		    debuglog "found Epichrome $curVersion at '$curInstance'"
		    
		    # get all info for this version
		    curInfo=( "$curVersion" \
				  "$curInstance" \
				  "$curInstance/Contents" \
				  "$curInstance/Contents/Resources/Engine/Runtime" \
				  "$curInstance/Contents/Resources/Engine/Payload" )
		    
		    # see if this is newer than the current latest Epichrome
		    if [[ "$resultVar" ]] ; then
			eval "$resultVar=( \"\${curInfo[@]}\" )"
		    else
			if ( [[ ! "$epiLatest" ]] || \
				 vcmp "${epiLatest[$e_version]}" '<' "$curVersion" ) ; then
			    epiLatest=( "${curInfo[@]}" )
			fi
			
			if [[ "$SSBEngineType" = 'Chromium' ]] ; then
			    # if we haven't already found an instance of a compatible version,
			    # check that too
			    if [[ ! "$epiCompatible" ]] || \
				   ( vcmp "${epiCompatible[$e_version]}" '<' "$curVersion" && \
					 vcmp "$curVersion" '<=' "$versionCeiling" ) ; then
				epiCompatible=( "${curInfo[@]}" )
			    fi
			fi
		    fi
		    
		else
		    
		    # failed to get version, so assume this isn't really a version of Epichrome
		    debuglog "Epichrome not found at '$curInstance'"
		    
		    if [[ "$resultVar" ]] ; then
			ok= ; [[ "$errmsg" ]] && errmsg="$errmsg "
			errmsg="${errmsg}No Epichrome version found at provided path '$curInstance'."
		    else
			ok=1 ; errmsg=
		    fi
		fi
	    fi
	done
	
	# log versions found
	[[ "$epiCompatible" ]] && \
	    debuglog "engine-compatible Epichrome found: ${epiCompatible[$e_version]} at '${epiCompatible[$e_path]}'"
	[[ "${epiCompatible[$e_path]}" != "${epiLatest[$e_path]}" ]] && \
	    debuglog "latest Epichrome found: ${epiLatest[$e_version]} at '${epiLatest[$e_path]}'"
    fi
    
    [[ "$ok" ]] && return 0
    return 1
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
}


# CREATEENGINEPAYLOAD: create persistent engine payload
function createenginepayload { # ( curContents curProfilePath [epiPayloadPath] )

    if [[ "$ok" ]] ; then
	
	local curContents="$1"    ; shift
	local curProfilePath="$1" ; shift
	local epiPayloadPath="$1" ; shift  # only needed for Chromium engine
	
	local curEnginePath="$curProfilePath/$appProfileEnginePath"
	local curPayloadContentsPath="$curProfilePath/$appProfilePayloadPath/Contents"
	
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
		try /bin/cp -a "$googleChromeContents/MacOS" "$curPayloadContentsPath" \
		    'Unable to copy Google Chrome executable to app engine payload.'

		# copy .lproj directories
		try /bin/cp -a "$googleChromeContents/Resources/"*.lproj "$curPayloadContentsPath/Resources" \
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
    fi
}


# CONFIGVARS: list of variables in config.sh
appConfigVarsCommon=( SSBIdentifier \
			  SSBCommandLine \
			  CFBundleDisplayName \
			  CFBundleName \
			  SSBVersion \
			  SSBUpdateVersion \
			  SSBUpdateCheckDate \
			  SSBUpdateCheckVersion \
			  SSBEngineType \
			  SSBEngineVersion \
			  SSBEngineAppName \
			  SSBProfilePath \
			  SSBCustomIcon \
			  SSBFirstRun \
			  SSBFirstRunSinceVersion \
			  SSBHostInstallError )
appConfigVarsGoogleChrome=( SSBGoogleChromePath \
				SSBGoogleChromeExec )


# READCONFIG: read in config.sh file & save config versions to track changes
function readconfig {  # ( [myContents] )
    #                    if myContents not set, then log config instead of reading
    
    # arguments
    local myContents="$1" ; shift
    
    if [[ "$ok" ]] ; then
	
	if [[ "$myContents" ]] ; then
	    
	    # read in config file
	    safesource "$myContents/$appConfigScriptPath" 'config file'

	    # check for required values
	    if [[ "$ok" && ! ( "$SSBIdentifier" && "$CFBundleDisplayName" && \
				   "$SSBVersion" && "$SSBProfilePath" ) ]] ; then
		ok=
		errmsg='Config file is corrupt.'
	    fi
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

		    # array value
		    
		    if [[ "$myContents" ]] ; then
			eval "config$varname=(\"\${$varname[@]}\")"
		    else
			eval "debuglog \"$varname=( \${config$varname[*]} )\""
		    fi
		else
		    
		    # scalar value
		    
		    if [[ "$myContents" ]] ; then
			eval "config$varname=\"\${$varname}\""
		    else
			eval "debuglog \"$varname=\$config$varname\""
		    fi
		fi
	    done
	fi
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
	    
	    local configScript="$destContents/$appConfigScriptPath"
	    
	    # write out the config file
	    writevars "$configScript" "${myConfigVars[@]}"
	    
	    # set ownership of config file  $$$ GET RID?
	    setowner "$destContents/.." "$configScript" "config file"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# CHECKEPICHROMEVERSION: function that checks for a new version of Epichrome on github
function checkepichromeversion { # CONTENTS-PATH CURRENT-VERSION

    if [[ "$ok" ]] ; then
	
	# set current version to compare against
	local myContents="$1" ; shift
	local curVersion="$1" ; shift
	
	# URL for the latest Epichrome release
	local updateURL='https://github.com/dmarmor/epichrome/releases/latest'
	
	# call Python script to check github for the latest version
	local latestVersion="$( "$myContents/Resources/Scripts/getversion.py" 2> /dev/null )"
	if [[ "$?" != 0 ]] ; then
	    ok=
	    errmsg="$latestVersion"
	fi
	
	# compare versions
	if ( [[ "$ok" ]] && vcmp "$curVersion" '<' "$latestVersion" ) ; then
	    # output new available version number & download URL
	    echo "$latestVersion"
	    echo "$updateURL"
	fi
    fi
    
    # return value tells us if we had any errors
    if [[ "$ok" ]]; then
	return 0
    else
	return 1
    fi
}



# $$$ REMOVE THIS IN FUTURE VERSIONS
function updatessb { # curAppPath
    
    if [[ "$ok" ]] ; then

	# if we're here, we're updating from a pre-2.3.0 version, so set up
	# variables we need, then see if we need to redisplay the update dialog,
	# as the old dialog code has been failing in Mojave
	
	# arguments
	local curAppPath="$1"
	
	local doUpdate=Update
	
	# set up new-style logging
	logApp="$CFBundleName"
	logPath="$myProfilePath/$appProfileMainPath/epichrome_app_log.txt"
	stderrTempFile="$myProfilePath/$appProfileMainPath/stderr.txt"
	initlog
	
	# get our version of Epichrome
	local epiVersion="${epiRuntime[$e_version]}"
	if [[ ! "$epiVersion" ]] ; then
	    ok= ; errmsg="Unable to get Epichrome version for update."
	fi
	
	if [[ "$ok" ]] ; then
	    
	    # check if the old dialog code is failing
	    local asResult=
	    try 'asResult&=' /usr/bin/osascript -e \
		'tell application "Finder" to the name extension of ((POSIX file "'"${BASH_SOURCE[0]}"'") as alias)' \
		'FAILED'
	    
	    # for now, not parsing asResult, would rather risk a double dialog than none
	    if [[ ! "$ok" ]] ; then

		# assume nothing
		doUpdate=
		
		# reset command status
		ok=1
		errmsg=
		
		if [[ "$ok" ]] ; then

		    # show the update choice dialog
		    dialog doUpdate \
			   "A new version of the Epichrome runtime was found ($epiVersion). Would you like to update now?" \
			   "Update" \
			   "|caution" \
			   "+Update" \
			   "-Later" \
			   "Don't Ask Again For This Version"
		    
		    if [[ ! "$ok" ]] ; then
			alert "A new version of the Epichrome runtime was found ($epiVersion) but the update dialog failed. ($errmsg) Attempting to update now." 'Update' '|caution'
			doUpdate="Update"
			ok=1
			errmsg=
		    fi		
		fi
	    fi

	    debuglog "Got past dialog code: doUpdate=$doUpdate"
	    
	    if [[ "$ok" && ( "$doUpdate" = "Update" ) ]] ; then

		# load update script
		safesource "${epiRuntime[$e_contents]}/Resources/Scripts/update.sh" NORUNTIMELOAD 'update script'

		# run actual update
		[[ "$ok" ]] && updateapp "$@"
		
		# relaunch after a delay
		if [[ "$ok" ]] ; then
		    relaunch "$curAppPath" 1 &
		    disown -ar
		    exit 0
		fi
	    fi
	fi
    fi
    
    # handle a failed update or non-update

    if [[ ( ! "$ok" ) || ( "$doUpdate" != "Update" ) ]] ; then

	# if we chose not to ask again with this version, update config
	if [[ "$doUpdate" = "Don't Ask Again For This Version" ]] ; then
	    
	    # pretend we're already at the new version
	    SSBVersion="$epiVersion"
	    updateconfig=1
	fi
	
	# turn this option off again as it interferes with unset in old try function
	shopt -u nullglob
	
	# temporarily turn OK back on & reload old runtime
	local oldErrmsg="$errmsg" ; errmsg=
	local oldOK="$ok" ; ok=1
	safesource "$curAppPath/Contents/Resources/Scripts/runtime.sh" "runtime script $SSBVersion"
	[[ "$ok" ]] && ok="$oldOK"
	
	# update error message
	if [[ "$oldErrmsg" && "$errmsg" ]] ; then
	    errmsg="$oldErrmsg $errmsg"
	elif [[ "$oldErrmsg" ]] ; then
	    errmsg="$oldErrmsg"
	fi
    fi
    
    # return value
    [[ "$ok" ]] || return 1
    return 0
}


# GET INFO ON THIS SCRIPT'S VERSION OF EPICHROME

myApp="${BASH_SOURCE[0]%/Contents/Resources/Runtime/Resources/Scripts/runtime.sh}"
if [[ "$myApp" != "${BASH_SOURCE[0]}" ]] ; then
    
    # this runtime.sh script is in Epichrome itself, not an app

    if [[ "$myApp" != "${epiRuntime[$e_path]}" ]] ; then

	# epiRuntime not yet set, so populate it with info on this runtime
	# script's parent Epichrome instance
	
	if [[ "$myApp" = "${epiCompatible[$e_path]}" ]] ; then
	    myApp=( "${epiCompatible[@]}" )
	elif [[ "$myApp" = "${epiLatest[$e_path]}" ]] ; then
	    myApp=( "${epiLatest[@]}" )
	else
	    # temporarily turn off any logging to stderr
	    oldStderrTempFile="$stderrTempFile" ; oldLogNoStderr="$logNoStderr"
	    stderrTempFile=/dev/null ; logNoStderr=1
	    epichromeinfo epiRuntime "$myApp"
	    stderrTempFile="$oldStderrTempFile" ; logNoStderr="$oldLogNoStderr"
	fi
    fi
else
    
    # this runtime.sh  script is in an app, so unset epiRuntime
    epiRuntime=
fi
