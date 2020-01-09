#!/bin/sh
#
#  core.sh: core utility functions for Epichrome creator & apps
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

# NOTE: the "try" function and many other functions in this system clear
#       the "ok" global variable on error, set a message in "errmsg",
#       and return 0 on success, non-zero on error


# VERSION

coreVersion='EPIVERSION'


# BUILD FLAGS

[[ "$debug" ]]       || debug=
[[ "$logPreserve" ]] || logPreserve=
export debug logPreserve


# CONSTANTS

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="document.icns"
export CFBundleIconFile CFBundleTypeIconFile

# bundle IDs
appIDBase="org.epichrome.app"
appEngineIDBase="org.epichrome.eng"
googleChromeID='com.google.Chrome'
export appIDBase appEngineIDBase googleChromeID

# app internal paths
appHelperPath='Resources/EpichromeHelper.app'
appEnginePath='Resources/Engine'
appEnginePayloadPath="$appEnginePath/Payload"
appEnginePlaceholderPath="$appEnginePath/Placeholder"


# SET UP CORE INFO

# path to stderr temp file
stderrTempFile="${myDataPath}/stderr.txt" ; export stderrTempFile

# variables to suppress logging to stderr or file
[[ "$logNoStderr" ]] || logNoStderr=  # set this in calling script to prevent logging to stderr
[[ "$logNoFile"   ]] || logNoFile=    # set this in calling script to prevent logging to file
export logNoStderr logNoFile


# FUNCTION DEFINITIONS


# JOIN_ARRAY -- join a bash array into a string with an arbitrary delimiter
function join_array { # (DELIMITER)
    local delim=$1; shift
    
    printf "$1"
    shift
    printf "%s" "${@/#/$delim}"
} ; export -f join_array


# LOGGING -- log to stderr & a log file
function errlog_raw {

    # if we're logging to stderr, do it
    [[ "$logNoStderr" ]] || echo "$@" 1>&2
    
    # if we're logging to file & either the file exists & is writeable, or
    # the file doesn't exist and its parent directory is writeable, do it
    if [[ ( ! "$logNoFile" ) && \
	      ( ( ( -f "$myLogFile" ) && ( -w "$myLogFile" ) ) || \
		    ( ( ! -e "$myLogFile" ) && ( -w "${myLogFile%/*}" ) ) ) ]] ; then
	echo "$@" >> "$myLogFile"
    fi
}
function errlog {

    # prefix format: LogID script(line)/function(line)/...:
    # LogID convention: AppName[PID]|Subname[PID]
    
    local trace=()
    local src=( "$myLogApp" )
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
function debuglog_raw {
    [[ "$debug" ]] && errlog_raw "$@"
}
function debuglog {
    [[ "$debug" ]] && errlog "$@"
}
export -f errlog_raw errlog debuglog_raw debuglog


# INITLOG: initialize logging
function initlog {

    if  [[ ( ! "$logPreserve" ) && ( -f "$myLogFile" ) ]] ; then
	# we're not saving logs & the logfile exists, so clear it, ignoring failure
	/bin/cat /dev/null > "$myLogFile"
    else
	# make sure the log file & its path exist
	/bin/mkdir -p "${myLogFile%/*}"
	/usr/bin/touch "$myLogFile"
    fi
    
    # check if we can write to stderr or if we need to disable it
    ( /bin/mkdir -p "${stderrTempFile%/*}" && /usr/bin/touch "$stderrTempFile" ) > /dev/null 2>&1
    if [[ $? != 0 ]] ; then
	errlog "Unable to direct stderr to '$stderrTempFile' -- stderr output will not be logged."
	stderrTempFile='/dev/null'
    fi
    
    # return code based on whether we have a writable log file
    [[ -w "$myLogFile" ]] && return 0 || return 1

} ; export -f initlog


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
	local doAppend=
	local ifscode=
	local storeStderr=
	local dropStdout= ; local dropStderr=
	
	# figure out which type of storage to do
	if [[ "$target" =~ (\+?)=$ ]]; then
	    # storing in a variable as a string
	    target="${target::${#target}-${#BASH_REMATCH[0]}}"
	    type=scalar
	    [[ "${BASH_REMATCH[1]}" ]] && doAppend=1
	    shift
	elif [[ "$target" =~ (\+?)=\(([^\)]?)\)$ ]] ; then
	    # array
	    target="${target::${#target}-${#BASH_REMATCH[0]}}"
	    type=array
	    [[ "${BASH_REMATCH[1]}" ]] && doAppend=1
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
	if [[ ( "$type" = scalar ) || ( "$type" = array ) ]] ; then

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
	    
	    if [[ "$type" = scalar ]] ; then
		
		# scalar
		
		# if we're not appending, start with an empty target
		[[ "$doAppend" ]] || eval "$target="
		
		# append the output to the target
		eval "$target=\"\${$target}\${temp}\""
	    else
		
		# array
		
		# if we're not appending, start with an empty target
		[[ "$doAppend" ]] || eval "$target=()"
		
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
} ; export ok errmsg ; export -f try


# TRYONERR -- like TRY above, but it only runs if there's already been an error
function tryonerr {
    
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
} ; export -f tryonerr


# SAFESOURCE -- safely source a script
function safesource { # SCRIPT [FILEINFO [ARGS ...]]
    
    # only run if no error
    if [[ "$ok" ]]; then
	
	# get command-line args
	local script="$1" ; shift
	local fileinfo="$1" ; shift
	
	# get file info string & make try error string
	if [[ ! "$fileinfo" ]] ; then
	    
	    # autocreate file info
	    if [[ "$script" =~ /([^/]+)$ ]] ; then
		fileinfo="${BASH_REMATCH[1]}"
	    else
		fileinfo='empty path'
	    fi
	fi
	
	# check that the source file exists & is readable
	local myErrPrefix="Error loading $fileinfo: "
	local myErr=
	[[ ! -e "$script" ]] && myErr="${myErrPrefix}Nothing found at '$script'."
	[[ ( ! "$myErr" ) && ( ! -f "$script" ) ]] && myErr="${myErrPrefix}'$script' is not a file."
	[[ ( ! "$myErr" ) && ( ! -r "$script" ) ]] && myErr="${myErrPrefix}'$script' is not readable."
	
	if [[ "$myErr" ]] ; then
	    ok=
	    errmsg="$myErr"
	else
	    
	    # try to source the file
	    try source "$script" "$@" "Unable to load $fileinfo."
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
    
} ; export -f safesource


# CLEANEXIT -- call any defined cleanup function and exit
function cleanexit { # [code]
    
    local myCode="$1" ; shift ; [[ "$myCode" ]] || myCode=0
    
    # call cleanup with exit code
    if [[ "$( type -t cleanup )" = function ]] ; then
	cleanup "$myCode"
    fi
    
    # exit
    exit "$myCode"
} ; export -f cleanexit


# ABORT -- display an error alert and abort
function abort { # ( [myErrMsg myCode] )

    # arguments
    local myErrMsg="$1" ; shift ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    local myCode="$1"   ; shift ; [[ "$myCode"   ]] || myCode=1
    
    # log error message
    local myAbortLog="Aborting: $myErrMsg"
    errlog "$myAbortLog"
    
    # show dialog & offer to open log
    if [[ "$( type -t dialog )" = function ]] ; then
	local choice=
	dialog choice "$myErrMsg" "Unable to Run" '|stop' '+Quit' '-View Log'
	if [[ "$choice" = 'View Log' ]] ; then
	    
	    # clear OK state so try works & ignore result
	    ok=1 ; errmsg=
	    try /usr/bin/osascript -e '
tell application "Finder" to reveal ((POSIX file "'"$myLogFile"'") as alias)
tell application "Finder" to activate' 'Error attempting to view log file.'
	fi
    fi
    
    # quit with error code
    cleanexit "$myCode"
    
}


# ABORTSILENT -- log an error message and abort with no dialog
function abortsilent { # ( [myErrMsg myCode] )
    unset dialog
    abort "$@"
}

export -f abort abortsilent


# SHOPTSET -- set shell options that can then be restored with shoptrestore
function shoptset { # ( saveVar options ... )

    # arguments
    local saveVar="$1" ; shift

    # initialize saveVar
    eval "$saveVar=()"

    local opt=
    for opt in "$@" ; do
	if ! shopt -q "$opt" ; then
	    eval "$saveVar+=( \"\$opt\" )"
	    shopt -s "$opt"
	fi
    done

    return 0
}


# SHOPTRESTORE -- restore shell options set with shoptset
function shoptrestore { # ( saveVar )

    # get list of options to turn back off
    local restoreList=
    eval "restoreList=( \"\${$1[@]}\" )"

    # restore options
    if [[ "${restoreList[*]}" ]] ; then
	local opt=
	for opt in "${restoreList[@]}" ; do
	    shopt -u "$opt"
	done
    fi

    return 0
}


# TEMPNAME: internal version of mktemp
function tempname {
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    local result="${1}.${RANDOM}${2}"
    while [[ -e "$result" ]] ; do
	result="${result}.${RANDOM}${2}"
    done
    
    echo "$result"
} ; export -f tempname


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
	    permOld="$(tempname "$perm")"
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
		tryonerr /bin/mv "$permOld" "$perm" "Also unable to restore old $filetype."
	    fi
	    
	    # delete temp file
	    [[ ( ! "$saveTempOnError" ) && ( -e "$temp" ) ]] && rmtemp "$temp" "$filetype"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
} ; export -f permanent


# RMTEMP: remove a temporary file or directory (whether $ok or not)
function rmtemp {
    local temp="$1"
    local filetype="$2"	

    # delete the temp file
    if [ -e "$temp" ] ; then
	if [[ "$ok" ]] ; then
	    try /bin/rm -rf "$temp" "Unable to remove temporary $filetype."
	else
	    tryonerr /bin/rm -rf "$temp" "Also unable to remove temporary $filetype."
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
} ; export -f rmtemp


# SAFECOPY: safely copy a file or directory to a new location
function safecopy {
    
    if [[ "$ok" ]]; then
	
	# copy in custom icon
	local src="$1"      ; shift
	local dst="$1"      ; shift
	local filetype="$1" ; shift ; [[ "$filetype" ]] || filetype="${src##*/}"
	
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
} ; export -f safecopy


# $$$$ REMOVE THIS???
# SETOWNER: set the owner of a directory tree or file to the owner of the app
# function setowner {  # APPPATH THISPATH PATHINFO

#     if [[ "$ok" ]] ; then

# 	# get args
# 	local appPath="$1"
# 	local thisPath="$2"
# 	local pathInfo="$3"
# 	[[ "$pathInfo" ]] || pathInfo="path \"$2\""
	
# 	local appOwner=
# 	try 'appOwner=' /usr/bin/stat -f '%Su' "$appPath" 'Unable to get owner of app bundle.'
# 	try /usr/sbin/chown -R "$appOwner" "$thisPath" "Unable to set ownership of $pathInfo."
#     fi

#     [[ "$ok" ]] && return 0
#     return 1
# } ; export -f setowner


# DIRLIST: get (and possibly filter) a directory listing
function dirlist {  # DIRECTORY OUTPUT-VARIABLE FILEINFO FILTER

    if [[ "$ok" ]]; then

	local dir="$1"      ; shift
	local outvar="$1"   ; shift
	local fileinfo="$1" ; shift ; [[ "$fileinfo" ]] || fileinfo="$dir"
	local filter="$1"   ; shift
	
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
} ; export -f dirlist


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
    local icon="$1" ; shift
    
    # build icon code
    local icon_set=
    local icon_code=
    local myIcon="$SSBAppPath/Contents/Resources/app.icns"
    if [ "${icon::1}" = "|" ] ; then
	icon="${icon:1}"
	[[ ! "$icon" =~ ^stop|caution|note$ ]] && icon=caution
	if [[ -f "$myIcon" ]] ; then
	    icon_set="set myIcon to (POSIX file \"$myIcon\")"
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
} ; export -f dialog


# ALERT -- display a simple alert dialog box (whether ok or not)
function alert {  #  MESSAGE TITLE ICON (stop, caution, note)
    local result=
    
    # show the alert
    dialog '' "$1" "$2" "$3"
    return "$?"
} ; export -f alert


# FILTERFILE -- filter a file using token-text pairs   $$$$ WRITE THIS
function filterfile { # ( sourceFile destFile fileInfo token1 text1 [token2 text2] ... )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local sourceFile="$1" ; shift
    local destFile="$1"   ; shift
    local fileInfo="$1"   ; shift ; [[ "$fileInfo" ]] || fileInfo="${sourceFile##*/}"
    
    # build sed command
    local sedCommand=
    local arg=
    for arg in "$@" ; do

	if [[ ! "$curToken" ]] ; then

	    # starting a new token-text pair
	    sedCommand+="s/$arg/"
	else

	    # finishing a token-text pair
	    sedCommand+="$arg/g; "
	fi
    done

    # filter file
    local destFileTmp=$(tempname "$destFile")
    try "$destFileTmp<" /usr/bin/sed "$sedCommand" "$sourceFile" "Unable to filter $fileInfo."
    
    # move script to permanent home
    # on error, remove temporary file
    if [[ "$ok" ]] ; then
	permanent "$destFileTmp" "$destFile" "$fileInfo"
    else
	rmtemp "$destFileTmp" "$fileInfo"
    fi
}


# FILTERPLIST: write out a new plist file by filtering an input file with PlistBuddy
function filterplist {  # ( srcFile destFile tryErrorID PlistBuddyCommands ... )

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local srcFile="$1"    ; shift
    local destFile="$1"   ; shift
    local tryErrorID="$1" ; shift # ID of this plist file for messaging
    
    # create command list
    local pbCommands=( )
    local curCmd=
    for curCmd in "$@" ; do
	pbCommands+=( -c "$curCmd" )
    done
    
    # create name for temp destination file
    local destFileTmp="$(tempname "$destFile")"
    
    # copy source file to temp
    try cp "$srcFile" "$destFileTmp" "Unable to create temporary $tryErrorID."
    
    [[ "$ok" ]] || return 1
    
    # use PlistBuddy to filter temp plist
    try /usr/libexec/PlistBuddy "${pbCommands[@]}" "$destFileTmp" \
	"Error filtering $tryErrorID."
    
    if [[ "$ok" ]] ; then
	
	# on success, move temp file to permanent location
	permanent "$destFileTmp" "$destFile" "$tryErrorID"
    else
	
	# on error, delete the temp file
	rmtemp "$destFileTmp" "$tryErrorID"
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1

} ; export -f filterplist


# ISARRAY -- return 0 if a named variable is an array, or 1 otherwise
function isarray {
    if [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ -a ]] ; then
	return 0
    else
	return 1
    fi
} ; export -f isarray


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
	try "${tmpDest}<<" echo '' "Unable to write to ${destBase}."
	
	if [[ "$ok" ]] ; then
	    
	    # go through each variable
	    for var in "$@" ; do

		if isarray "$var" ; then
		    
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
		
		echo "var=$var, value=$value"
		
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
} ; export -f writevars


# CONFIGVARS: list of variables in config.sh
appConfigVarsCommon=( SSBAppPath \
			  SSBUpdateVersion \
			  SSBUpdateCheckDate \
			  SSBUpdateCheckVersion \
			  SSBAppPath \
			  SSBDataPath \
			  SSBEngineAppName \
			  SSBCustomIcon \
			  SSBExtensionInstallError )
appConfigVarsGoogleChrome=( SSBGoogleChromePath \
				SSBGoogleChromeVersion )
export appConfigVarsCommon appConfigVarsGoogleChrome


# READCONFIG: read in config.sh file & save config versions to track changes
function readconfig { # ( myConfigFile )

    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local myConfigFile="$1" ; shift
    
    # read in config file
    safesource "$myConfigFile" 'configuration file'	
    [[ "$ok" ]] || return 1
    	
    # create full list of config vars based on engine type
    local myConfigVars=( "${appConfigVarsCommon[@]}" )
    if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	myConfigVars+=( "${appConfigVarsGoogleChrome[@]}" )
    fi

    # export config vars
    export "${myConfigVars[@]}"
    
    # save all relevant config variables prefixed with "config"
    for varname in "${myConfigVars[@]}" ; do
	
	if isarray "$varname" ; then

	    # array value
	    
	    eval "config$varname=(\"\${$varname[@]}\") ; export config$varname"
	    [[ "$debug" ]] && eval "errlog \"$varname=( \${config$varname[*]} )\""
	else
	    
	    # scalar value
	    
	    eval "config$varname=\"\${$varname}\" ; export config$varname"
	    [[ "$debug" ]] && eval "errlog \"$varname=\$config$varname\""
	fi	    
    done
    
} ; export -f readconfig


# WRITECONFIG: write out config.sh file
function writeconfig {  # ( myConfigFile force
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local myConfigFile="$1" ; shift
    local force="$1"        ; shift
    
    # create full list of config vars based on engine type
    local myConfigVars=( "${appConfigVarsCommon[@]}" )
    if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
	myConfigVars+=( "${appConfigVarsGoogleChrome[@]}" )
    fi
    
    # determine if we need to write the config file

    # we're being told to write no matter what
    local doWrite="$force"
    
    # not being forced, so compare all config variables for changes
    if [[ ! "$doWrite" ]] ; then
	local varname=
	local configname=
	for varname in "${myConfigVars[@]}" ; do
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
	writevars "$myConfigFile" "${myConfigVars[@]}"
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1

} ; export -f writeconfig


# do it $$$$
initlog
