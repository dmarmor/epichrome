#!/bin/bash
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
# $$$$ export coreVersion


# BUILD FLAGS

[[ "$debug" ]]       || debug=EPIDEBUG
[[ "$logPreserve" ]] || logPreserve=EPILOGPRESERVE
[[ "$backupPreserve" ]] || backupPreserve=EPIBACKUPPRESERVE


# EXPORT CORE INFO TO SUBTASKS

export debug logPreserve backupPreserve coreContext myLogFile


# INITIALIZE CORE VARIABLES

# by default, do not run init code at end
coreDoInit=

# assume we're running in an app unless coreVersion isn't set
if [[ ! "$coreContext" ]] ; then
    [[ "$coreVersion" = 'EPI''VERSION' ]] && coreContext='shell' || coreContext='app'
fi


# SET COMMAND-LINE ENVIRONMENT

while [[ "$#" -gt 0 ]] ; do
    if [[ "$1" =~ ^([a-zA-Z][a-zA-Z0-9_]*)=(.*)$ ]] ; then
        
        # move past this argument
        shift
        
        foundArray=
        
        if [[ "${BASH_REMATCH[2]}" = '(' ]] ; then
            
            # this looks like the start of an array variable
            
            # save rest of args in temp variable
            tempArgs=( "$@" )
            
            # look for the end of the array variables
            for ((i=0 ; i < "${#tempArgs[@]}" ; i++)) ; do
                if [[ "${tempArgs[$i]}" = ')' ]] ; then
                    foundArray=1
                    break
                fi
            done
        fi
        
        # save array or scalar value
        if [[ "$foundArray" ]] ; then
            
            # save as an array
            eval "${BASH_REMATCH[1]}=( \"\${tempArgs[@]::\$i}\" )"
            
            # remove array elements from args
            for ((j=0 ; j <= $i ; j++)) ; do shift ; done
        else
            
            # save as a scalar variable
            eval "${BASH_REMATCH[1]}=\"\${BASH_REMATCH[2]}\""
        fi
        
        unset foundArray tempArgs
    else
        # assume any further args are not variables
        break
    fi
done

# set variable with remaining command-line  $$$ UNUSED
coreCommandLine=( "$@" )


# CONSTANTS

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="document.icns"
# $$$$ export CFBundleIconFile CFBundleTypeIconFile

# bundle IDs
appIDRoot='org.epichrome'
appIDBase="$appIDRoot.app"
# $$$$ export appIDRoot appIDBase

# monitor app info
epiMonitorAppName='EpichromeMonitor.app'
epiMonitorAppVersionFile="Resources/v${coreVersion}.dat"
# $$$$ export epiMonitorAppName epiMonitorAppVersionFile

# app internal paths
appMonitorPath="Resources/$epiMonitorAppName"
appEnginePath='Resources/Engine'
appNMHFileBase='epichromeruntimehost_'
appWelcomePath='Resources/Welcome'
appWelcomePage='welcome.html'
appMasterPrefsPath='Resources/Profile/prefs.json'
appBookmarksFile='Bookmarks'
appBookmarksPath="Resources/Profile/$appBookmarksFile"
# $$$$ export appMonitorPath appEnginePath \
        # appNMHFileBase \
        # appWelcomePath appWelcomePage \
        # appMasterPrefsPath \
        # appBookmarksFile appBookmarksPath

# payload paths
epiPayloadPathBase='Payload.noindex'
epiPayloadLauncherDir='Launcher'
epiPayloadEngineDir='Engine'
epiOldEngineBase='EpichromeEngines.noindex'
# $$$$ export epiPayloadPathBase epiPayloadLauncherDir epiPayloadEngineDir epiOldEngineBase

# data paths
userSupportPath="${HOME}/Library/Application Support"
epiDataPath="$userSupportPath/Epichrome"
epiGithubCheckFile="$epiDataPath/github.dat"
appDataPathBase="$epiDataPath/Apps"
appDataConfigFile='config.sh'
epiDataExtIconDir='ExtensionIcons'
appDataProfileDir='UserData'
epiDataLogDir='Logs'
epiDataLogDirEpichrome="$epiDataLogDir/Epichrome"
epiDataLogDirScan="$epiDataLogDir/Scan"
epiDataLogDirLogin="$epiDataLogDir/Login"
appDataLogFilePrefix='epichrome_app_log'
epiDataLogFilePrefix='epichrome_log'
epiDataLogFilePrefixScan='epichrome_scan_log'
epiDataLogFilePrefixLogin='epichrome_login_log'
appDataStderrFile='stderr.txt'
appDataStdoutFile='stdout.txt'
appDataPauseFifo='pause'
appDataBackupDir='Backups'
appDataFailsafeFile='backup.dat'
appDataWelcomeDir='Welcome'
# $$$$ export userSupportPath epiDataPath \
        # epiGithubCheckFile \
        # appDataPathBase \
        # appDataConfigFile \
        # epiDataExtIconDir appDataProfileDir \
        # epiDataLogDir epiDataLogDirEpichrome epiDataLogDirScan epiDataLogDirLogin \
        # appDataLogFilePrefix epiDataLogFilePrefix epiDataLogFilePrefixScan epiDataLogFilePrefixLogin \
        # appDataStderrFile appDataStdoutFile appDataPauseFifo appDataBackupDir appDataFailsafeFile \
        # appDataWelcomeDir

# indices for SSBEngineSourceInfo
iID=0
iExecutable=1
iName=2
iDisplayName=3
iVersion=4
iAppIconFile=5
iDocIconFile=6
iPath=7
iLibraryPath=8
iMasterPrefsFile=9
iNoNMHLink=10
iArgs=11
# $$$$ export iID iExecutable iName iDisplayName iVersion iAppIconPath iDocIconPath iPath \
       # iLibraryPath iMasterPrefsFile iNoNMHLink iArgs

# info on allowed Epichrome engine browsers
appBrowserInfo_com_microsoft_edgemac=( 'com.microsoft.edgemac' \
        '' 'Edge' 'Microsoft Edge' \
        '' '' '' '' \
        'Microsoft Edge' \
        '' )
appBrowserInfo_com_vivaldi_Vivaldi=( 'com.vivaldi.Vivaldi' \
        '' 'Vivaldi' 'Vivaldi' \
        '' '' '' '' \
        'Vivaldi' \
        '' )
appBrowserInfo_com_operasoftware_Opera=( 'com.operasoftware.Opera' \
        '' 'Opera' 'Opera' \
        '' '' '' '' \
        'com.operasoftware.Opera' \
        '' )
appBrowserInfo_com_brave_Browser=( 'com.brave.Browser' \
        'Brave Browser' 'Brave' 'Brave Browser' \
        '' '' '' '' \
        'BraveSoftware/Brave-Browser' \
        'Chromium Master Preferences' \
        'noNMHLink' )
appBrowserInfo_org_chromium_Chromium=( 'org.chromium.Chromium' \
        '' 'Chromium' 'Chromium' \
        '' '' '' '' \
        'Chromium' \
        '' )
appBrowserInfo_com_google_Chrome=( 'com.google.Chrome' \
        '' 'Chrome' 'Google Chrome' \
        '' '' '' '' \
        'Google/Chrome' \
        'Google Chrome Master Preferences' \
        '' \
        '--enable-features=PasswordImport' )

# $$$$ exportarray appBrowserInfo_com_microsoft_edgemac \
        # appBrowserInfo_com_vivaldi_Vivaldi \
        # appBrowserInfo_com_operasoftware_Opera \
        # appBrowserInfo_com_brave_Browser \
        # appBrowserInfo_org_chromium_Chromium \
        # appBrowserInfo_com_google_Chrome


# CORE CONFIG VARIABLES

# variables used in config.sh
appConfigVars=( SSBAppPath \
        SSBLastRunVersion \
        SSBLastRunEngineType \
        SSBLastRunEdited \
        SSBUpdateIgnoreVersions \
        SSBPayloadPath \
        SSBLastErrorGithubFatal \
        SSBLastErrorNMHInstall )
# $$$$ export "${appConfigVars[@]}"


# SET UP CORE INFO

# set up this script's path
myScriptPath="${BASH_SOURCE[0]%/core.sh}"

# if this core.sh is inside an Epichrome instance, set extra variables
if [[ "$myScriptPath" = *'/Contents/Resources/Runtime/Contents/Resources/Scripts' ]] ; then
    
    # Epichrome-only script path
    myScriptPathEpichrome="${myScriptPath%/Runtime/Contents/Resources/Scripts}/Scripts"
    
    # path to this Epichrome
    myEpichrome="${myScriptPathEpichrome%/Contents/Resources/Scripts}"
    
else
    myScriptPathEpichrome=
    myEpichrome=
fi
# $$$$ export myScriptPath myScriptPathEpichrome myEpichrome

if [[ "$coreContext" = 'app' ]] ; then
    
    # RUNNING IN AN APP
    
    # set up this app's data path
    [[ "$myDataPath" ]] || myDataPath="$appDataPathBase/$SSBIdentifier"
    
    # app backup directory
    [[ "$myBackupDir" ]] || myBackupDir="$myDataPath/$appDataBackupDir"
    
    # path to important data directories and paths
    myConfigFile="$myDataPath/$appDataConfigFile"
    myProfilePath="$myDataPath/$appDataProfileDir"
    
    # app log ID
    [[ "$myLogID" ]] || myLogID="$SSBIdentifier"
    
    # log file prefix
    [[ "$myLogFilePrefix" ]] || myLogFilePrefix="$appDataLogFilePrefix"
    
    # log file directory
    [[ "$myLogDir" ]] || myLogDir="$myDataPath/$epiDataLogDir"
    
    # export all to helper
    # $$$$ export myConfigFile myProfilePath

else
    
    # RUNNING IN EPICHROME.APP, EPICHROME SCAN/LOGIN.APP OR SHELL
    
    # use Epichrome's data path
    [[ "$myDataPath" ]] || myDataPath="$epiDataPath"
    
    # app backup directory
    if [[ ( ! "$myBackupDir" ) && "$SSBIdentifier" ]] ; then
        if [[ "$epiOldIdentifier" && -d "$appDataPathBase/$epiOldIdentifier" ]] ; then
            myBackupDir="$appDataPathBase/$epiOldIdentifier/$appDataBackupDir"
        else
            myBackupDir="$appDataPathBase/$SSBIdentifier/$appDataBackupDir"
        fi
    else
        myBackupDir="$myDataPath/$appDataBackupDir"
    fi
    
    if [[ "$coreContext" = 'epichrome' ]] ; then
        
        # set logging ID
        if [[ ! "$myLogID" ]] ; then
            myLogID='Epichrome'
            if [[ "$epiAction" && ( "$epiAction" != 'log' ) ]] ; then
                myLogID+="|$epiAction"
            fi
        fi
        
        # log file prefix
        [[ "$myLogFilePrefix" ]] || myLogFilePrefix="$epiDataLogFilePrefix"
        
        # log file directory
        [[ "$myLogDir" ]] || myLogDir="$myDataPath/$epiDataLogDirEpichrome"

        # file logging only (unless explicitly turned off)
        [[ "$logNoFile" ]] && logNoStderr= || logNoStderr=1
        
    elif [[ "$coreContext" = 'scan' ]] ; then
        
        # set logging ID
        [[ "$myLogID" ]] || myLogID='EpichromeScan'
        
        # log file prefix
        [[ "$myLogFilePrefix" ]] || myLogFilePrefix="$epiDataLogFilePrefixScan"
        
        # log file directory
        [[ "$myLogDir" ]] || myLogDir="$myDataPath/$epiDataLogDirScan"
        
    elif [[ "$coreContext" = 'login' ]] ; then
        
        # set logging ID
        [[ "$myLogID" ]] || myLogID='EpichromeLogin'
        
        # log file prefix
        [[ "$myLogFilePrefix" ]] || myLogFilePrefix="$epiDataLogFilePrefixLogin"
        
        # log file directory
        [[ "$myLogDir" ]] || myLogDir="$myDataPath/$epiDataLogDirLogin"
        
    else  # shell
        
        # running unfiltered outside the app
        
        # stderr logging only
        myLogID='Shell'
        logNoFile=1
    fi
fi

# add any requested add-on to log ID
[[ "$logIDExt" ]] && myLogID+="|$logIDExt"

# pausing without spawning sleep processes
[[ "$myPauseFifo" ]] || myPauseFifo="$myDataPath/$appDataPauseFifo"

# log file gets set up in initlogfile
[[ "$myLogFile" ]] || myLogFile=

# collector for any pre-initlogfile logging
[[ "$myLogTempVar" ]] || myLogTempVar=

# variables to suppress logging to stderr or file
[[ "$logNoStderr" ]] || logNoStderr=  # set this in calling script to prevent logging to stderr
[[ "$logNoFile"   ]] || logNoFile=    # set this in calling script to prevent logging to file

# path to stderr temp file
stderrTempFile="$myDataPath/$appDataStderrFile"
stdoutTempFile="$myDataPath/$appDataStdoutFile"

# log file info
if [[ ! "$myRunTimestamp" ]] ; then
    myRunTimestamp="_$(date '+%Y%m%d_%H%M%S' 2> /dev/null)"
    [[ "$?" = 0 ]] || myRunTimestamp=
fi

# export all
# $$$$ export myDataPath myBackupDir \
        # myPauseFifo \
        # myLogID myLogFile myLogFilePrefix myLogDir myLogTempVar logNoStderr logNoFile \
        # stderrTempFile stdoutTempFile \
        # myRunTimestamp


# FUNCTION DEFINITIONS


# LOGGING -- log to stderr & a log file
function errlog_raw {
    
    # if we're logging to stderr, do it
    [[ "$logNoStderr" ]] || echo "$@" 1>&2
    
    # logging to file
    if [[ ! "$logNoFile" ]] ; then
        
        # check if there's a log file specified
        if [[ "$myLogFile" ]] ; then
            
            # log to file if the file exists & is writeable,
            # or if it doesn't exist but parent directory is writeable
            if [[ ( ( ( -f "$myLogFile" ) && ( -w "$myLogFile" ) ) || \
                    ( ( ! -e "$myLogFile" ) && ( -w "${myLogFile%/*}" ) ) ) ]] ; then
                echo "$@" >> "$myLogFile"
            fi
        else
            
            # no log file specified yet, so collect logs in a variable
            myLogTempVar+="$*"$'\n'
        fi
    fi
}
# errlog([ERROR|DEBUG|FATAL|STDOUT|STDERR] msg...)
function errlog {
    
    # prefix format: *[PID]LogID(line)/function(line)/...:
    
    # arguments
    local logType="${1%%|*}"
    local logName="${1#*|}" ; [[ "$logName" = "$1" ]] && logName=
        
    # determine log type & final name element
    case "$logType" in
        DEBUG)
            logType=' '  # debug message
            shift
            ;;
        FATAL)
            logType='!'  # fatal error
            shift
            ;;
        ERROR)
            logType='*'  # error
            shift
            ;;
        STDOUT)
            logType='1'  # stdout log
            shift
            ;;
        STDERR)
            logType='2'  # stderr log
            shift
            ;;
        *)
            logType='*'  # error
            logName=
            ;;
    esac

    # make sure we have some logID
    local logID="$myLogID"
    [[ "$logID" ]] || logID='EpichromeCore'
    
    # build function trace
    local trace=() ; [[ "$logName" ]] && trace=( "{$logName}" )
    local i=1
    local curfunc=
    while [[ "$i" -lt "${#FUNCNAME[@]}" ]] ; do
        curfunc="${FUNCNAME[$i]}"
        if [[ ( "$curfunc" = source ) || ( "$curfunc" = main ) ]] ; then
            trace=( "$logID(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
            break
        elif [[ ( "$curfunc" = errlog ) || ( "$curfunc" = debuglog ) || \
                ( "$curfunc" = try ) || ( "$curfunc" = tryalways ) || \
                ( "$curfunc" = runalways ) ]] ; then
            : # skip these functions
        else
            trace=( "$curfunc(${BASH_LINENO[$(($i - 1))]})" "${trace[@]}" )
        fi
        i=$(( $i + 1 ))
    done
    
    # output prefix & message
    local logPID="$epiLogPID"
    [[ "$logPID" ]] || logPID="$$"
    errlog_raw "$logType[$logPID]$(join_array '/' "${trace[@]}"): $@"
}
function debuglog_raw {
    [[ "$debug" ]] && errlog_raw "$@"
}
function debuglog {
    [[ "$debug" ]] && errlog DEBUG "$@"
}
# $$$$ export -f errlog_raw errlog debuglog_raw debuglog


# INITLOGFILE: initialize log file
function initlogfile {

    # nothing to do if we're not logging to a file
    [[ "$logNoFile" ]] && return
    
    # create log file name if we haven't been passed one
    [[ "$myLogFile" ]] || myLogFile="$myLogDir/${myLogFilePrefix}${myRunTimestamp}.txt"
    
    # trim saved logs so we don't have too many (ignore errors)
    trimsaves "$myLogDir" "$logPreserve" '.txt' 'logs'
    ok=1 ; errmsg=
    
    # set up log file
    if  [[ ! -f "$myLogFile" ]] ; then
        
        # make sure we have a directory for the log file
        try /bin/mkdir -p "${myLogFile%/*}" \
                'Unable to create log directory.'        
    fi
    
    if [[ "$ok" ]] ; then
        
        # check if we have a writable log file
        if [[ "$myLogTempVar" ]] ; then
            
            # add collected logs to file
            try "${myLogFile}<<" printf "$myLogTempVar" \
                    'Unable to add collected logs to file.'
            myLogTempVar=
            
            # fail silently
            if [[ ! "$ok" ]] ; then
                ok=1 ; errmsg=
            fi
        fi
        
        return 0
    else
        
        # error -- turn off file logging
        logNoFile=1
        myLogTempVar=
        errlog "Unable to write to log file -- logging will be to stderr only."
        ok=1 ; errmsg=
        return 1
    fi
}
# $$$$ export -f initlogfile


# JOIN_ARRAY -- join a bash array into a string with an arbitrary delimiter
#   join_array(aDelimiter)
function join_array {
    
    local aDelimiter=$1; shift
    
    local result="$1"
    shift
    
    local item
    for item in "$@" ; do
        result+="$aDelimiter$item"
    done
    
    printf "$result"
}
# $$$$ export -f join_array


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
#        for all targets, add & before = or << to also capture stderr (e.g. varname&=)
#
# get first line of a variable: "${x%%$'\n'*}"
#
ok=1
errmsg=
# $$$$ export ok errmsg
function try {
    
    # only run if no prior error
    [[ "$ok" ]] || return 1
    
    # see what output we're storing & how
    local target="$1"
    local type=
    local doAppend=
    local ifscode=
    local storeStderr=
    local dropStdout= ; local dropStderr=
    local logStdout=1 ; local logStderr=1
    
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
                logStdout=
                ;;
            2)
                dropStderr="$dropAction"
                logStderr=
                ;;
            12|21)
                dropStdout="$dropAction"
                dropStderr="$dropAction"
                logStdout=
                logStderr=
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
    
    # determine storing/logging of stdout and stderr
    if [[ "$type" ]] ; then
        logStdout=
        if [[ "${target:${#target}-1}" = '&' ]] ; then
            # store stderr too
            target="${target::${#target}-1}"
            storeStderr=1
            logStderr=
        fi
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

        # not storing, so log both stdout & stderr unless we're dropping either or both
        if [[ ( ! "$dropStdout" ) && ( ! "$dropStderr" ) ]] ; then
            
            # log both stdout & stderr
            "${args[@]}" 1> "$stdoutTempFile" 2> "$stderrTempFile"
            
        elif [[ ! "$dropStdout" ]] ; then
            
            if [[ "$dropStderr" = ignore ]] ; then
                # log stdout & ignore stderr
                "${args[@]}" 1> "$stdoutTempFile"
            else
                # log stdout & suppress stderr
                "${args[@]}" 1> "$stdoutTempFile" 2> /dev/null
            fi
            
        elif [[ ! "$dropStderr" ]] ; then
            
            if [[ "$dropStdout" = ignore ]] ; then
                # log stderr & ignore stdout
                "${args[@]}" 2> "$stderrTempFile"
            else
                # log stderr & suppress stdout
                "${args[@]}" 1> /dev/null 2> "$stderrTempFile"
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
    if [[ "$logStdout" || "$logStderr" ]] ; then
        
        # set up logging state
        local myOutput=() IFS=$'\n' hasOutput= curOutputLine=
        
        # log any stdout output
        if [[ "$logStdout" ]] ; then
            myOutput=( $(/bin/cat "$stdoutTempFile" 2> /dev/null) )
            for curOutputLine in "${myOutput[@]}" ; do
                hasOutput=1
                errlog "STDOUT|${args[0]##*/}" "$curOutputLine"
            done
        fi
        
        # log any stderr output
        if [[ "$logStderr" ]] ; then
            myOutput=( $(/bin/cat "$stderrTempFile" 2> /dev/null) )
            for curOutputLine in "${myOutput[@]}" ; do
                hasOutput=1
                errlog "STDERR|${args[0]##*/}" "$curOutputLine"
            done
        fi
    fi
    
    # check result
    if [[ "$result" != 0 ]]; then
        
        # set error flag
        ok=
        
        # report if no error output
        [[ ( ! ( "$dropStdout" && "$dropStderr" ) ) && ! "$hasOutput" ]] && \
            errlog "ERROR|${args[0]##*/}" "Returned code $result with no logged output."
        if [[ "$myerrmsg" ]] ; then
            errmsg="$myerrmsg"
            errlog "$errmsg"
        fi
        return "$result"
    fi
    
    return 0
}
# $$$$ export -f try


# RUNALWAYS -- run a command even if there's already been an error
function runalways {
    
    # run a command whether we're OK or not
    
    # save old try state
    local oldok="$ok" ; ok=1
    local olderrmsg="$errmsg" ; errmsg=
    
    # run the command
    "$@"
    local result="$?"
    
    # restore OK state
    [[ ! "$oldok" ]] && ok=
    
    # combine error messages
    if [[ "$errmsg" && "$olderrmsg" ]] ; then
        errmsg="$olderrmsg Also: $errmsg"
    elif [[ "$olderrmsg" ]] ; then
        errmsg="$olderrmsg"
    fi
    
    return "$result"
}
# $$$$ export -f runalways


# TRYALWAYS -- try a command even if there's already been an error
function tryalways {
    runalways try "$@"
}
# $$$$ export -f tryalways


# SAFESOURCE -- safely source a script
#   safesource(script [fileinfo [args ...]])
function safesource {
    
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
    
}
# $$$$ export -f safesource


# CLEANEXIT -- call any defined cleanup function and exit
#   cleanexit([myCode])
function cleanexit {
    
    local myCode="$1" ; shift ; [[ "$myCode" ]] || myCode=0
    
    # call cleanup with exit code
    if [[ "$( type -t cleanup )" = function ]] ; then
        cleanup "$myCode"
    fi
    
    # delete any pause fifo
    [[ -p "$myPauseFifo" ]] && tryalways /bin/rm -f "$myPauseFifo" \
            'Unable to delete pause FIFO.'
    
    # let EXIT signal handler know we're clean
    readyToExit=1
    
    # exit unless we got here from an exit signal
    [[ "$myCode" = 'SIGEXIT' ]] || exit "$myCode"
}
# $$$$ export -f cleanexit


# ABORT -- display an error alert and abort
#  abort([myErrMsg [myCode]])
function abort {
    
    # arguments
    local myErrMsg="$1" ; shift ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    local myCode="$1"   ; shift ; [[ "$myCode"   ]] || myCode=1
    
    # make sure we have a log file
    if [[ ( ! "$logNoFile" ) && ( ! "$myLogFile" ) ]] ; then
        initlogfile
    fi
    
    # log error message
    local myAbortLog="Aborting"
    [[ "$myErrMsg" ]] && myAbortLog+=": $myErrMsg" || myAbortLog+='.'
    errlog FATAL "$myAbortLog"
    
    if [[ ( "$coreContext" = 'epichrome' ) || ( "$epiSubApp" ) ]] ; then
        
        # log just the error message to stderr
        [[ "$myErrMsg" ]] && echo "$myErrMsg" 1>&2
        
    elif [[ "$coreContext" = 'app' ]] ; then
        
        # show dialog & offer to open log
        if [[ "$( type -t dialog )" = function ]] ; then
            local buttons=( '+Quit' )
            [[ "$logNoFile" ]] || buttons+=( '-View Log' )
            local choice=
            dialog choice "$myErrMsg" "Unable to Run" '|stop' "${buttons[@]}"
            if [[ "$choice" = 'View Log' ]] ; then
                
                # clear OK state so try works & ignore result
                ok=1 ; errmsg=
                try /usr/bin/osascript -e '
tell application "Finder" to reveal ((POSIX file "'"$myLogFile"'") as alias)
tell application "Finder" to activate' 'Error attempting to view log file.'
            fi
        fi
    fi
    
    # quit with error code
    cleanexit "$myCode"
}
# $$$$ export -f abort


# HANDLEEXITSIGNAL -- handle an exit signal, cleaning up if needed
readyToExit=
function handleexitsignal {
    if [[ ! "$readyToExit" ]] ; then
        local exitMsg='Unexpected termination.'
        errlog FATAL "$exitMsg"
        cleanexit 'SIGEXIT'
    fi
}
# $$$$ export -f handleexitsignal

# set SIGEXIT handler
trap handleexitsignal EXIT


# EPIVERSIONRE -- regex to match & parse any legal Epichrome version number
# 7 groups as follows: 0A.0B.0Cb0D[00E]
#  1: A, 2: B, 3: C, 4: b0D, 5: D, 6: [00E], 7: E
epiVersionRe='0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?(\[0*([0-9]+)])?'
# $$$$ export epiVersionRe


# VCMP -- if V1 OP V2 is true, return 0, else return 1
#   vcmp(version1 operator version2)
function vcmp {
    
    # arguments
    local v1="$1" ; shift
    local op="$1" ; shift ; [[ "$op" ]] || op='='
    local v2="$1" ; shift
    
    # munge version numbers into comparable integers
    local curv=
    local vmaj vmin vbug vbeta vbuild
    local vstr=()
    for curv in "$v1" "$v2" ; do
        if [[ "$curv" =~ ^$epiVersionRe$ ]] ; then
            
            # extract version number parts
            vmaj="${BASH_REMATCH[1]}"
            vmin="${BASH_REMATCH[2]}"
            vbug="${BASH_REMATCH[3]}"
            vbeta="${BASH_REMATCH[5]}" ; [[ "$vbeta" ]] || vbeta=1000
            vbuild="${BASH_REMATCH[7]}" ; [[ "$vbuild" ]] || vbuild=10000
        else
            
            # no version
            vmaj=0 ; vmin=0 ; vbug=0 ; vbeta=0 ; vbuild=0
        fi
        
        # build string
        vstr+=( "$(printf '%03d.%03d.%03d.%04d.%05d' "$vmaj" "$vmin" "$vbug" "$vbeta" "$vbuild")" )
    done
    
    # compare versions using the operator & return the result
    local opre='^[<>]=$'
    if [[ "$op" =~ $opre ]] ; then
        eval "[[ ( \"\${vstr[0]}\" ${op:0:1} \"\${vstr[1]}\" ) || ( \"\${vstr[0]}\" = \"\${vstr[1]}\" ) ]]"
    else
        eval "[[ \"\${vstr[0]}\" $op \"\${vstr[1]}\" ]]"
    fi
}
# $$$$ export -f vcmp


# PAUSE -- sleep for the specified number of seconds (without spawning /bin/sleep processes)
#   pause(seconds)
function pause {
    
    # create pause fifo if needed
    if [[ ! -p "$myPauseFifo" ]] ; then
        
        # try to create fifo, and on failure just sleep
        try /usr/bin/mkfifo "$myPauseFifo" 'Unable to create pause FIFO.'
        if [[ ! "$ok" ]] ; then
            ok=1 ; errmsg=
        fi
    fi
    
    if [[ -p "$myPauseFifo" ]] ; then
        
        # we have a fifo, so sleep using read
        read -t "$1" <>"$myPauseFifo"
        return 0
    else
        
        # no fifo, so spawn a process
        /bin/sleep "$1"
        return 1
    fi
}
# $$$$ export -f pause


# WAITFORCONDITION -- wait for a given condition to become true, or timeout
#   waitforcondition(msg waitTime increment command [args ...])
#     returns 0 if condition is met in the timeout, or 1 if not
function waitforcondition {
    
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
        [[ "$curTime" = 0 ]] && debuglog "Waiting for $msg..."
        sleep $increment
        
        # update time
        curTime=$(( $curTime + $incrementInt ))
    done
    
    # if we got here the condition never occurred
    return 1
}
# $$$$ export -f waitforcondition


# SHOPTSET -- set shell options that can then be restored with shoptrestore
#   shoptset(saveVar options ...)
function shoptset {
    
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
# $$$$ export -f shoptset

# SHOPTRESTORE -- restore shell options set with shoptset
#   shoptrestore(saveVar)
function shoptrestore {
    
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
# $$$$ export -f shoptrestore


# ISSAMEDEVICE -- check that two paths are on the same device
#   issamedevice(paths[0] paths[1])
function issamedevice {
    
    # arguments
    local paths=()
    paths+=( "$1" ) ; shift
    paths+=( "$1" ) ; shift
    
    # find first existing part of each path
    local i= curPath= curParent=
    for ((i=0 ; i < "${#paths[@]}" ; i++)) ; do
        curPath="${paths[$i]}"
        
        # loop until we hit an existing directory
        while [[ ! -e "$curPath" ]] ; do
            curParent="${curPath%/*}"
            if [[ ! "$curParent" ]] ; then
                errlog "Couldn't find any part of '${paths[$i]}' that exists."
                return 1
            elif [[ "$curParent" = "$curPath" ]] ; then
                # we've reached the end of a relative path
                curPath="$PWD"
            else
                curPath="$curParent"
            fi
        done
        
        # if we got here, we should have a good path
        paths[$i]="$curPath"
    done
    
    # $$$ debuglog "Comparing devices for '${paths[0]}' and '${paths[1]}'."
    
    # get path devices
    local device1=
    local device2=
    try 'device1=' /usr/bin/stat -f '%d' "${paths[0]}" \
            "Unable to get device for path '${paths[0]}'."
    try 'device2=' /usr/bin/stat -f '%d' "${paths[1]}" \
            "Unable to get device for path '${paths[1]}'."
    
    # unable to get one or both devices
    if [[ ! "$ok" ]] ; then
        ok=1 ; errmsg=
        return 1
    fi
    
    # compare devices
    [[ "$device1" = "$device2" ]] && return 0 || return 1
}
# $$$$ export -f issamedevice


# SAFERM: rm -rf with safety checks for known paths
#  saferm(aErrMsg item [item...])
#    if myTry is set, use that instead of try
function saferm {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # argument
    local aErrMsg="$1" ; shift
    
    # check that all paths are in known places
    local curPath
    for curPath in "$@" ; do
        if [[ ( "$curPath" != "$epiDataPath"/* ) && \
                ( "$curPath" != */"$epiPayloadPathBase"/* ) && \
                ( "$curPath" != */"$epiOldEngineBase"/* ) ]] ; then
            ok= ; errmsg="Path '$curPath' is not in a known location."
            errlog "$errmsg"
            return 1
        fi
    done
    
    # all paths are OK, so run the rm
    local iTry=try
    [[ "$myTry" ]] && iTry="$myTry"
    "$iTry" /bin/rm -rf "$@" "$aErrMsg"
}
# $$$$ export -f saferm


# TEMPNAME: internal version of mktemp
#   tempname(root [ext])
function tempname {
    
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    local result="${1}.${RANDOM}${2}"
    while [[ -e "$result" ]] ; do
        result="${result}.${RANDOM}${2}"
    done
    
    echo "$result"
}
# $$$$ export -f tempname


# PERMANENT: move temporary file or directory to permanent location safely
#   permanent(temp perm filetype [saveTempOnError])
function permanent {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local temp="$1" ; shift
    local perm="$1" ; shift
    local filetype="$1" ; shift
    local saveTempOnError="$1" ; shift  # optional argument
    
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
        if [[ "$permOld" && ( -e "$permOld" ) ]]; then
            try /bin/rm -rf "$permOld" "Unable to remove old $filetype."
        fi
    fi
    
    # IF WE FAILED, CLEAN UP
    
    if [[ ! "$ok" ]] ; then
        
        # move old permanent file back
        if [[ "$permOld" ]] ; then
            tryalways /bin/mv "$permOld" "$perm" "Unable to restore old $filetype."
        fi
        
        # delete temp file
        [[ ( ! "$saveTempOnError" ) && ( -e "$temp" ) ]] && rmtemp "$temp" "$filetype"
    fi
    
    [[ "$ok" ]] && return 0 || return 1
}
# $$$$ export -f permanent


# RMTEMP: remove a temporary file or directory (whether $ok or not)
function rmtemp {
    local temp="$1"
    local filetype="$2"
    
    local result=0
    
    # delete the temp file
    if [[ -e "$temp" ]] ; then
        tryalways /bin/rm -rf "$temp" "Unable to remove temporary $filetype."
        result="$?"
    fi
    
    return "$result"
}
# $$$$ export -f rmtemp


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
        try 'dstDir=' dirname "$dst" "Unable to get destination directory for $filetype."
        
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
    
}
# $$$$ export -f safecopy


# TRIMSAVES -- trim a saved file directory to its maximum
#   trimsaves(saveDir maxFiles [ fileExt fileDesc trimVar ])
function trimsaves {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local saveDir="$1" ; shift
    local maxFiles="$1" ; shift
    local fileExt="$1" ; shift
    local fileDesc="$1" ; shift ; [[ "$fileDesc" ]] || fileDesc='files'
    local trimVar="$1" ; shift
    
    # get all files in directory
    local myShoptState=
    shoptset myShoptState nullglob
    local oldFiles=( "$saveDir"/*"$fileExt" )
    shoptrestore myShoptState
    
    # if we got any files, sort them oldest-to-newest
    if [[ "${#oldFiles[@]}" -gt 0 ]] ; then
        try '!2' 'oldFiles=(n)' /bin/ls -tUr "$saveDir"/*"$fileExt" ''
        ok=1 ; errmsg=
    fi
    
    # if more than the max number of files exist, delete the oldest ones
    if [[ "${#oldFiles[@]}" -gt "$maxFiles" ]] ; then
        
        # get list of files to trim
        local trimFiles=( "${oldFiles[@]::$((${#oldFiles[@]} - $maxFiles))}" )
        
        if [[ "$trimVar" ]] ; then
            
            # save list into trimVar
            eval "$trimVar=( \"\${trimFiles[@]}\" )"
        else
            # delete the files now
            try /bin/rm -f "${oldFiles[@]::$((${#oldFiles[@]} - $maxFiles))}" \
                    "Unable to remove old $fileDesc."
        fi
    fi
    
    # return code
    [[ "$ok" ]] && return 0 || return 1
}
# $$$$ export -f trimsaves


# ISARRAY -- return 0 if a named variable is an array, or 1 otherwise
function isarray {
    if [[ "$(declare -p "$1" 2> /dev/null)" =~ ^declare\ -a ]] ; then
        return 0
    else
        return 1
    fi
}
# $$$$ export -f isarray


# EPIWHITESPACE: utility variable holding whitespace for regexes
epiWhitespace=$' \t\n'
# $$$$ export epiWhitespace

# ESCAPE: backslash-escape \ & optional other characters
#  escape(str, [chars, var])
#    str -- string to escape
#    chars -- characters other than \ to escape
#    var -- if not empty, write to var instead of echo
function escape {
    
    # arguments
    local str="$1" ; shift
    local chars="$1" ; shift
    local var="$1" ; shift
    
    local iEscResult="${str//\\/\\\\}"
    
    # escape any other characters
    if [[ "$chars" ]] ; then
        local i
        for (( i=0 ; i < ${#chars} ; i++ )); do
            iEscResult="${iEscResult//${chars:i:1}/\\${chars:i:1}}"
        done
    fi
    
    if [[ "$var" ]] ; then
        eval "$var=\"\$iEscResult\""
    else
        echo "$iEscResult"
    fi
}
# $$$$ export -f escape


# UNESCAPE: remove escapes from a string
#  escape(str, [chars, var])
#    str -- string to escape
#    chars -- characters other than \ to escape
#    var -- if not empty, write to var instead of echo
function unescape {
    
    # arguments
    local str="$1" ; shift
    local chars="$1" ; shift
    local var="$1" ; shift
    
    local iUnescResult="${str//\\\\/\\}"
    
    # unescape any other characters
    if [[ "$chars" ]] ; then
        local i
        for (( i=0 ; i < ${#chars} ; i++ )); do
            iUnescResult="${iUnescResult//\\${chars:i:1}/${chars:i:1}}"
        done
    fi
    
    if [[ "$var" ]] ; then
        eval "$var=\"\$iUnescResult\""
    else
        echo "$iUnescResult"
    fi
}
# $$$$ export -f unescape


# ESCAPEJSON: escape \, ", \n & \t for a JSON string
#  escapejson(str, [var])
#    str -- string to escape
#    var -- if not empty, write to var instead of echo
function escapejson {
    
    # arguments
    local iEscJsonResult="$1"; shift
    local var="$1" ; shift
    
    # escape double-quotes
    escape "$iEscJsonResult" '"' iEscJsonResult
    
    # escape newlines and tabs
    iEscJsonResult="${iEscJsonResult//$'\n'/\\n}"
    iEscJsonResult="${iEscJsonResult//$'\t'/\\t}"
    
    if [[ "$var" ]] ; then
        eval "$var=\"\$iEscJsonResult\""
    else
        echo "$iEscJsonResult"
    fi
}
# $$$$ export -f escapejson


# UNESCAPEJSON: remove escapes from a JSON string
#  unescapejson(str, [var])
#    str -- string to unescape
#    var -- if not empty, write to var instead of echo
function unescapejson {
    
    # arguments
    local iUnescJsonResult="$1" ; shift
    local var="$1" ; shift
    
    # unescape newlines and tabs
    iUnescJsonResult="${iUnescJsonResult//\\r\\n/$'\n'}"
    iUnescJsonResult="${iUnescJsonResult//\\n/$'\n'}"
    iUnescJsonResult="${iUnescJsonResult//\\t/$'\t'}"
    
    # unescape double-quotes
    unescape "$iUnescJsonResult" '"' iUnescJsonResult
    
    # return result
    if [[ "$var" ]] ; then
        eval "$var=\"\$iUnescJsonResult\""
    else
        echo "$iUnescJsonResult"
    fi
}
# $$$$ export -f unescapejson


# JSONARRAY: convert an array to a JSON array
#  jsonarray(aJoinStr, [elems...])
function jsonarray {
    
    # arguments
    local aJoinStr="$1" ; shift
    
    local iResult=()
    local iCurElem
    for iCurElem in "$@" ; do
        iResult+=( "\"$(escapejson "$iCurElem")\"" )
    done
    
    # output joined array
    join_array "$aJoinStr" "${iResult[@]}"
}
# $$$$ export -f jsonarray


# FORMATSCALAR -- utility funciton to format a scalar value for variable assignment or eval
#   formatscalar(value [noQuotes])
function formatscalar {
    
    # arguments
    local value="$1" ; shift
    local noQuotes="$1" ; shift
    
    # utility escaped quote
    local eq="\'"
    
    # escape single quotes
    local result="${value//\'/'$eq'}"
    
    # wrap in single quotes unless requested not to
    [[ "$noQuotes" ]] && echo "$result" || echo "'$result'"
    
}
# $$$$ export -f formatscalar


# FORMATARRAY -- utility function to format an array for variable assignment or eval
#   formatarray([elem1 ...])
function formatarray {
    
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
}
# $$$$ export -f formatarray


# WRITEVARS: write out a set of arbitrary bash variables to a file
#   writevars(destfile vars ...)
function writevars {
    
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
    
}
# $$$$ export -f writevars


# ARRAY IMPORT/EXPORT

# EXPORTARRAY -- export array variables to a subshell
#   exportarray(var1 [var2 ...])
function exportarray {
	
	local curVar=
	for curVar in "$@" ; do
		eval "${curVar}_array=\"$curVar=\$(formatarray \"\${$curVar[@]}\")\" ; export ${curVar}_array"
	done
}
# $$$$ export -f exportarray


# IMPORTARRAY -- import array variables from a parent environment
#  importarray(var1 [var2 ...])
function importarray {
	local curVar=
	for curVar in "$@" ; do
		eval "eval \"\$${curVar}_array\""
	done    
}
# $$$$ export -f importarray


# DIALOG -- display a dialog and return the button pressed
#   dialog(var message title icon button1 button2 button3
#     (if icon starts with | try app icon first)
#     buttons: + = default, - = cancel
function dialog {
    
    # save ok state
    local oldok="$ok" ; local olderrmsg="$errmsg"
    ok=1 ; errmsg=
    
    # arguments
    local var="$1" ; shift ; [[ "$var" ]] || var=var  # if not capturing, just save dialog text to this local
    local msg="$1" ; shift
    local title="$1" ; shift
    local title_code="$title" ; [[ "$title_code" ]] && title_code="with title \"$(escapejson "$title_code")\""
    local icon="$1" ; shift
    
    # build icon code
    local icon_set=
    local icon_code=
    local myIcon="$SSBAppPath/Contents/Resources/app.icns"
    if [ "${icon::1}" = "|" ] ; then
        icon="${icon:1}"
        [[ ! "$icon" =~ ^stop|caution|note$ ]] && icon=caution
        if [[ -f "$myIcon" ]] ; then
            icon_set="set myIcon to (POSIX file \"$(escapejson "$myIcon")\")"
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
            button="\"$(escapejson "${button:1}")\""
            button_default="default button $button"
        elif [[ ( "${button::1}" = "-" ) || ( "$button" = "Cancel" ) ]] ; then
            button="\"$(escapejson "${button#-}")\""
            button_cancel="cancel button $button"
            try_start="try"
            try_end="on error number -128
            $button
            end try"
        else
            button="\"$(escapejson "$button")\""
        fi
        
        # add to button list
        buttonlist="$buttonlist, $button"
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
    if [[ "$debug" || ("$numbuttons" = 1) ]] ; then
        local logmsg="${msg%%$'\n'*}"
        [[ "$logmsg" = "$msg" ]] && logmsg="with text '$msg'" || logmsg="starting '$logmsg'..."
        if [[ ("$numbuttons" = 1) ]] ; then
            errlog "Showing alert '$title' $logmsg"
        else
            debuglog "Showing dialog '$title' $logmsg"
        fi
    fi
    
    # run the dialog
    try "${var}=" /usr/bin/osascript -e "$icon_set
    $try_start
    button returned of (display dialog \"$(escapejson "$msg")\" $title_code $icon_code buttons $buttonlist $button_default $button_cancel)
    $try_end" \
    "Unable to display dialog box with message \"$msg\""
    
    if [[ "$debug" && "$ok" && ("$numbuttons" != 1) ]] ; then
        errlog DEBUG "User clicked button '$(eval "echo "\$$var"")'"
        
    elif [[ ! "$ok" && ("$numbuttons" = 1) ]] ; then
        
        # dialog failed and this is an alert, so fallback to basic alert
        ok=1
        
        # display simple alert with fallback icon
        [[ "$icon" ]] && icon="with icon $icon"
        try /usr/bin/osascript -e \
                "display alert \"$(escapejson "$msg")\" $icon buttons {\"OK\"} default button \"OK\" $title_code" \
                "Unable to display fallback alert with message \"$msg\""
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
# $$$$ export -f dialog


# ALERT -- display a simple alert dialog box (whether ok or not)
#   alert(message title icon)
#     icon: stop|caution|note
function alert {
    local result=
    
    # show the alert
    dialog '' "$1" "$2" "$3"
    return "$?"
}
# $$$$ export -f alert


# INITIALIZE SCRIPT

if [[ "$coreDoInit" ]] ; then
    
    # make sure data directory exists
    try '-12' /bin/mkdir -p "$myDataPath" \
            'Unable to create data directory!'
    
    # check if the try function can save stderr output, or if we need to disable it
    if [[ "$ok" ]] ; then
        
        try '-12' /usr/bin/touch "$stdoutTempFile" \
                'Unable to create stdout collector file. Standard output will not be logged.'
        if [[ ! "$ok" ]] ; then
            stdoutTempFile='/dev/null'
            ok=1 ; stderr=
        fi
        try '-12' /usr/bin/touch "$stderrTempFile" \
                'Unable to create stderr collector file. Error output will not be logged.'
        if [[ ! "$ok" ]] ; then
            stderrTempFile='/dev/null'
            ok=1 ; stderr=
        fi
        
        # announce initialization
        if [[ "$coreContext" = 'app' ]] ; then
            runningIn="app $SSBIdentifier"
        elif [[ "$coreContext" = 'epichrome' ]] ; then
            runningIn='Epichrome.app'
        elif [[ "$coreContext" = 'scan' ]] ; then
            runningIn='Epichrome Scan.app'
        elif [[ "$coreContext" = 'login' ]] ; then
            runningIn='Epichrome Login.app'
        else
            runningIn='a shell'
        fi
        debuglog "Core $coreVersion initialized in $runningIn."
        unset runningIn
    fi
fi


# REPORT ANY ERRORS TO EPICHROME

if [[ ( "$coreContext" = 'epichrome' ) && ( ! "$ok" ) ]] ; then
    abort
fi
