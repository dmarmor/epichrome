#!/bin/sh
#
#  core.sh: core utility functions for Epichrome creator & apps
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

# NOTE: the "try" function and many other functions in this system clear
#       the "ok" global variable on error, set a message in "errmsg",
#       and return 0 on success, non-zero on error


# VERSION

coreVersion='EPIVERSION'


# BUILD FLAGS

[[ "$debug" ]]       || debug=EPIDEBUG
[[ "$logPreserve" ]] || logPreserve=EPILOGPRESERVE
export debug logPreserve


# CONSTANTS   $$$$ [[ "$X" ]] || X=  TEMPORARY TO FIX BETA 6 BUG

# icon names
[[ "$CFBundleIconFile" ]] || CFBundleIconFile="app.icns"
[[ "$CFBundleTypeIconFile" ]] || CFBundleTypeIconFile="document.icns"
#readonly CFBundleIconFile CFBundleTypeIconFile
export CFBundleIconFile CFBundleTypeIconFile

# bundle IDs
[[ "$appIDRoot" ]] || appIDRoot='org.epichrome'
[[ "$appIDBase" ]] || appIDBase="$appIDRoot.app"
[[ "$appEngineIDBase" ]] || appEngineIDBase="$appIDRoot.eng"
#readonly appIDRoot appIDBase appEngineIDBase
export appIDRoot appIDBase appEngineIDBase

# app internal paths
[[ "$appHelperPath" ]] || appHelperPath='Resources/EpichromeHelper.app'
[[ "$appEnginePath" ]] || appEnginePath='Resources/Engine'
[[ "$appEnginePayloadPath" ]] || appEnginePayloadPath="$appEnginePath/Payload"
[[ "$appEnginePlaceholderPath" ]] || appEnginePlaceholderPath="$appEnginePath/Placeholder"
[[ "$appNMHFile" ]] || appNMHFile='epichromeruntimehost.py'
#readonly appHelperPath appEnginePath appEnginePayloadPath appEnginePlaceholderPath appNMHFile

# data paths
userSupportPath="${HOME}/Library/Application Support"
epiDataPath="$userSupportPath/Epichrome"
appDataPathBase="$epiDataPath/Apps"
#readonly userSupportPath epiDataPath appDataPath
export userSupportPath epiDataPath appDataPath

# indices for SSBEngineSourceInfo
iID=0
iExecutable=1
iName=2
iDisplayName=3
iVersion=4
iAppIconFile=5
iDocIconFile=6
iPath=7
#readonly iID iExecutable iName iDisplayName iVersion iPath iAppIconPath iDocIconPath
export iID iExecutable iName iDisplayName iVersion iPath iAppIconPath iDocIconPath

# internal Epichrome engines
#epiEngineSource=( org.chromium.Chromium Chromium Chromium Chromium )
epiEngineSource=( com.brave.Browser 'Brave Browser' Brave 'Brave Browser' )
#readonly epiEngineSource


# CORE CONFIG VARIABLES

# variables used in config.sh
appConfigVars=( SSBAppPath \
		    SSBLastRunVersion \
		    SSBLastRunEngineType \
		    SSBUpdateVersion \
		    SSBUpdateCheckDate \
		    SSBUpdateCheckVersion \
		    SSBEnginePath \
		    SSBEngineAppName \
		    SSBExtensionInstallError )
export appConfigVars "${appConfigVars[@]}"


# SET UP CORE INFO

if [[ "$SSBIdentifier" ]] ; then

    # we're running from an app

    # set up this app's data path
    [[ "$myDataPath" ]] || myDataPath="$appDataPathBase/$SSBIdentifier"
    
    # logging
    [[ "$myLogID" ]] || myLogID="$SSBIdentifier"
    [[ "$myLogFile" ]] || myLogFile="$myDataPath/epichrome_app_log.txt"
    
    # path to important data directories and paths
    myConfigFile="$myDataPath/config.sh"
    myProfilePath="$myDataPath/UserData"
    
    # export all to helper
    export myDataPath myLogID myLogFile myConfigFile myProfilePath
else

    # we're running from Epichrome.app
    
    # set up Epichrome's data path
    [[ "$myDataPath" ]] || myDataPath="$epiDataPath"
    
    # logging
    [[ "$myLogID" ]] || myLogID='Epichrome'
    [[ "$myLogFile" ]] || myLogFile="$myDataPath/epichrome_log.txt"
        
    # export all to helper
    export myDataPath myLogID myLogFile
fi

# path to stderr temp file
stderrTempFile="$myDataPath/stderr.txt" ; export stderrTempFile

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

    # prefix format: [PID]LogID(line)/function(line)/...:

    # make sure we have some logID
    local logID="$myLogID"
    [[ "$logID" ]] || logID='EpichromeCore'
    
    # build function trace
    local trace=()
    local i=1
    local curfunc=
    while [[ "$i" -lt "${#FUNCNAME[@]}" ]] ; do
	curfunc="${FUNCNAME[$i]}"
	if [[ ( "$curfunc" = source ) || ( "$curfunc" = main ) ]] ; then
	    # trace=( "${BASH_SOURCE[$i]##*/}(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )  # $$$$
	    trace=( "$logID(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
	    break
	elif [[ ( "$curfunc" = errlog ) || ( "$curfunc" = debuglog ) ]] ; then
	    : # skip these functions
	else
	    trace=( "$curfunc(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
	fi
	i=$(( $i + 1 ))
    done
    
    # build prefix  $$$$ DELETE?
    # local prefix="$(join_array '/' "${trace[@]}")"
    # if [[ "$myLogID" && "$prefix" ]] ; then
    # 	prefix="$myLogID|$prefix: "
    # elif [[ "$myLogID" ]] ; then
    # 	prefix="$myLogID: "
    # elif [[ "$prefix" ]] ; then
    # 	prefix="EpichromeCore[$$]|$prefix: "
    # fi
    
    errlog_raw "[$$]$(join_array '/' "${trace[@]}"): $@"
}
function debuglog_raw {
    [[ "$debug" ]] && errlog_raw "$@"
}
function debuglog {
    [[ "$debug" ]] && errlog "$@"
}
export -f errlog_raw errlog debuglog_raw debuglog


# INITLOG: initialize logging
function initlog {  # ( [overrideLogPreserve] )

    # possibly override logPreserve
    local myLogPreserve="$logPreserve"
    [[ "$1" ]] && myLogPreserve=1
    
    # assume success
    local result=0
    
    # initialize log file
    if  [[ ( ! "$myLogPreserve" ) && ( -f "$myLogFile" ) ]] ; then
	
	# we're not preserving logs across runs, so clear the log file, ignoring failure
	/bin/cat /dev/null > "$myLogFile"
    else
	
	# ensure log file exists
	/bin/mkdir -p "${myLogFile%/*}"
	/usr/bin/touch "$myLogFile"
    fi
    
    # check if we have a writable log file
    if [[ ! -w "$myLogFile" ]] ; then
	errlog "Unable to write to log file -- logging will be to stderr only."
	logNoFile=1
	result=1
    fi
    
    # check if we can write to stderr or if we need to disable it
    ( /bin/mkdir -p "${stderrTempFile%/*}" && /usr/bin/touch "$stderrTempFile" ) > /dev/null 2>&1
    if [[ $? != 0 ]] ; then
	errlog "Unable to direct stderr to '$stderrTempFile' -- stderr output will not be logged."
	stderrTempFile='/dev/null'
	result=1
    fi

    # announce initialization
    debuglog "Core $coreVersion initialized."
    
    # return code
    return "$result"
    
} ; export -f initlog


# TRY: try to run a command, as long as no errors have already been thrown
#
#      usage:
#        try [(!|-)(1|2|12)] [target] cmd args ...  'Error message.'
#
#        if no drop command or target, stdout and stderr are logged together
#
#        (!|-)(1|2|12): either don't log or suppress stdout, stderr, or both
#            (will be overridden by targets that need them)
#            - = don't log
#            ! = suppress
#
#        'varname=':                 store stdout in scalar var
#        'varname+=':                append stdout to scalar var
#        'varname=([tn]|anything)':  store stdout in array var
#        'varname+=([tn]|anything)': append stdout to array var
#            for array targets: t=tab-delimited, n=newline-delimited
#        'filename.txt<':            store stdout in file (overwrite)
#        'filename.txt<<':           append stdout to file
#
#        for all targets, add & to the end to also capture stderr
#
# get first line of a variable: "${x%%$'\n'*}"
#
ok=1
errmsg=
function try {
    
    # only run if no prior error
    if [[ "$ok" ]]; then

	# see what output we're storing & how
	local target="$1"
	local type=
	local doAppend=
	local ifscode=
	local storeStderr=
	local dropStdout= ; local dropStderr=

	# see if we're to drop stdout and/or stderr
	if [[ "$target" =~ ^(\!|-)(1|2|12|21)$ ]] ; then
	    
	    # this is a drop command, so next arg might be target
	    shift
	    target="$1"

	    # don't log or suppress
	    local dropAction=suppress
	    [[ "${BASH_REMATCH[1]}" = '-' ]] && dropAction=ignore
	    
	    # select streams
	    case "${BASH_REMATCH[2]}" in
		1)
		    dropStdout="$dropAction"
		    ;;
		2)
		    dropStderr="$dropAction"
		    ;;
		12|21)
		    dropStdout="$dropAction"
		    dropStderr="$dropAction"
		    ;;
	    esac
	fi
	
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
		elif [[ "$dropStderr" = ignore ]] ; then
		    temp="$( "${args[@]}" )"
		else
		    temp="$( "${args[@]}" 2> /dev/null )"
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
		elif [[ "$dropStderr" = ignore ]] ; then
		    "${args[@]}" >> "$target"
		else
		    "${args[@]}" >> "$target" 2> /dev/null		    
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
		elif [[ "$dropStderr" = ignore ]] ; then
		    "${args[@]}" > "$target"
		else
		    "${args[@]}" > "$target" 2> /dev/null		    
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
		
		if [[ "$dropStderr" = ignore ]] ; then
		    # log stdout & ignore stderr
		    "${args[@]}" > "$stderrTempFile"
		else
		    # log stdout & suppress stderr
		    "${args[@]}" > "$stderrTempFile" 2> /dev/null
		fi
		
	    elif [[ ! "$dropStderr" ]] ; then
		
		if [[ "$dropStdout" = ignore ]] ; then
		    # log stderr & ignore stdout
		    "${args[@]}" 2> "$stderrTempFile"
		else
		    # log stderr & suppress stdout
		    "${args[@]}" > /dev/null 2> "$stderrTempFile"
		fi
		
	    else

		# ignoring or suppressing both (always the same)
		if [[ "$dropStdout" = ignore ]] ; then
		    # ignore both stdout & stderr
		    "${args[@]}"
		else
		    # suppress both stdout & stderr
		    "${args[@]}" > /dev/null 2>&1
		fi
		
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
	    [[ ( ! ( "$dropStdout" && "$dropStderr" ) ) && ! "$myStderr" ]] && \
		errlog "${args[0]} returned code $result with no stderr output."
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
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
	
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
	try source "$script" "$@" ''
	if [[ ! "$ok" ]] ; then
	    [[ "$errmsg" ]] && errmsg=" ($errmsg)"
	    errmsg="Unable to load $fileinfo.$errmsg"
	fi
    fi

    # return code
    [[ "$ok" ]] && return 0 || return 1
    
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
function abort { # ( [myErrMsg [myCode]] )

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

    # only run if we're OK
    [[ "$ok" ]] || return 1
	
    # copy in custom icon
    local src="$1"      ; shift
    local dst="$1"      ; shift
    local filetype="$1" ; shift ; [[ "$filetype" ]] || filetype="${src##*/}"

    if [[ ! -e "$dst" ]] ; then
	
	# get dirname for destination
	local dstDir=
	try 'dstDir=' dirname "$dst" "Unable to get destination directory listing for $filetype."
	
	# make sure destination directory exists
	try /bin/mkdir -p "$dstDir" "Unable to create the destination directory for $filetype."

	# copy file or directory directly
	try /bin/cp -PR "$src" "$dst" "Unable to copy $filetype."
	
    else
	
	# copy to temporary location
	local dstTmp="$(tempname "$dst")"
	try /bin/cp -PR "$src" "$dstTmp" "Unable to copy $filetype."
	
	if [[ "$ok" ]] ; then
	    # move file to permanent home
	    permanent "$dstTmp" "$dst" "$filetype"
	else
	    # remove any temp file
	    rmtemp "$dstTmp" "$filetype"
	fi
    fi
    
    # return code
    [[ "$ok" ]] && return 0 || return 1
    
} ; export -f safecopy


# ISARRAY -- return 0 if a named variable is an array, or 1 otherwise
function isarray {
    if [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ -a ]] ; then
	return 0
    else
	return 1
    fi
} ; export -f isarray


# FORMATSCALAR -- utility funciton to format a scalar value for variable assignment or eval
function formatscalar { # ( value )

    local quote="\'"
    
    # escape single quotes & wrapping in single quotes
    echo "'${1//\'/'$quote'}'"
    
} ; export -f formatscalar


# FORMATARRAY -- utility function to format an array for variable assignment or eval
function formatarray { # ( [elem1 ...] )

    local quote="\'"
    
    # variable holds an array, so start the array
    local value="("
    
    # go through each value and build the array
    local elem=
    for elem in "$@" ; do
	
	# add array value, escaping single quotes & wrapping in single quotes
	value="${value} '${elem//\'/'$quote'}'"
	
    done
    
    # close the array
    value="${value} )"
        
    echo "$value"
} ; export -f formatarray


# WRITEVARS: write out a set of arbitrary bash variables to a file
function writevars {  # $1 = destination file
    #                   $@ = list of vars
    
    # only run if we're OK
    [[ "$ok" ]] || return 1

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
		
		# pull out the array value
		eval "arr=(\"\${$var[@]}\")"

		# format for printing
		value="$(formatarray "${arr[@]}")"
		
	    else
		
		# scalar value, so pull out the value
		eval "value=\"\${$var}\""
		
		# format for printing
		value="$(formatscalar "$value")"

	    fi

	    debuglog "Writing to ${destBase}: ${var}=${value}"
	    
	    try "${tmpDest}<<" echo "${var}=${value}" "Unable to write to ${destBase}."
	    [[ "$ok" ]] || break
	done
    fi
    
    if [[ "$ok" ]] ; then
	# move the temp file to its permanent place
	permanent "$tmpDest" "$dest" "${destBase}"
    
    else
	# on error, remove temp vars file
	rmtemp "$tmpDest" "${destBase}"
    fi
    
    [[ "$ok" ]] && return 0 || return 1
    
} ; export -f writevars


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

    # log the dialog
    local logmsg="${msg%%$'\n'*}"
    [[ "$logmsg" = "$msg" ]] && logmsg="with text '$msg'" || logmsg="starting '$logmsg'..."
    errlog "Showing dialog '$title' $logmsg"
    
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


# INITIALIZE LOGGING

initlog "$@"
