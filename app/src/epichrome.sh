#!/bin/bash
#
#  epichrome.sh: interface script for Epichrome main.js
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


# GET PATH TO MY PARENT EPICHROME RESOURCES

myResourcesPath="${BASH_SOURCE[0]%/Scripts/epichrome.sh}"
myRuntimeScriptsPath="$myResourcesPath/Runtime/Contents/Resources/Scripts"


# LOAD UPDATE SCRIPT (THIS ALSO LOADS CORE AND LAUNCH)

source "$myRuntimeScriptsPath/core.sh" 'coreContext=epichrome' "epiLogPID=$PPID" "$@" || exit 1
[[ "$ok" ]] || abort


# LOADSCRIPT: load a given script
function loadscript {
    
    local iScript="$1" ; shift
    [[ "${iScript:0:1}" = '/' ]] || iScript="$myRuntimeScriptsPath/$iScript"
    
    if ! source "$iScript" ; then
        ok= ; errmsg="Unable to load ${iScript##*/}."
        errlog "$errmsg"
        abort
    fi
}


# DETERMINE REQUESTED ACTION

# abort if no action sent
[[ "$epiAction" ]] || abort "No action found."

if [[ "$epiAction" = 'init' ]] ; then
    
    # ACTION: INITIALIZE & CHECK GITHUB FOR UPDATES
    
    # initialize log file and report info back to Epichrome
    initlogfile
    
    # return JSON
    echo "{
   \"dataPath\": \"$(escapejson "$myDataPath")\",
   \"logFile\": \"$(escapejson "$myLogFile")\"
}"


elif [[ "$epiAction" = 'log' ]] ; then
    
    # ACTION: LOG
    
    if [[ "$epiLogMsg" ]] ; then
        if [[ "$epiLogType" = 'debug' ]] ; then
            debuglog "$epiLogMsg"
        elif [[ "$epiLogType" ]] ; then
            errlog "$epiLogType" "$epiLogMsg"
        else
            errlog "$epiLogMsg"
        fi
    fi
    
    
elif [[ "$epiAction" = 'githubupdate' ]] ; then
    
    # CHECK FOR UPDATE ON GITHUB
    
    # load launch.sh
    loadscript 'launch.sh'
    
    # get info on installed versions of Epichrome
    getepichromeinfo
    
    # check GitHub
    githubJson=
    checkgithubupdate githubJson
    
    # if we got any result, return JSON
    if [[ "$githubJson" ]] ; then
        echo $githubJson
    fi
    
    
elif [[ "$epiAction" = 'githubresult' ]] ; then
    
    # ACTION: WRITE BACK GITHUB-CHECK RESULT
    
    # load launch.sh
    loadscript 'launch.sh'
    
    # assume success from the update dialog
    nextCheck=
    
    # write back to the info file
    fatalErr=
    if ! checkgithubinfowrite "$epiCheckDate" "$epiNextVersion" "$epiGithubDialogErr" ; then
        fatalErr="$errmsg"
        errmsg=
    fi
    
    # handle any passed errors (or any we got writing the info file)
    if [[ "$epiGithubDialogErr" || "$fatalErr" ]] ; then
        ok= ; errmsg="$epiGithubDialogErr"
        checkgithubhandleerr "$epiGithubLastError" "$fatalErr" result
        echo "$result"
    fi
    
    
elif [[ "$epiAction" = 'read' ]] ; then
    
    # ACTION: READ EXISTING APP
    
    # main app settings locations
    myOldConfigPath="$epiAppPath/Contents/Resources/Scripts/config.sh"
    myConfigPath="$epiAppPath/Contents/Resources/script"
    
    if [[ -f "$myConfigPath" ]] ; then
        
        # 2.3.0 AND LATER
        
        # read in app config
        myConfigScript=
        try 'myConfigScript=' /bin/cat "$myConfigPath" "Unable to read app data"
        [[ "$ok" ]] || abort
        
        # pull config from current flavor of app
        myConfigPart="${myConfigScript#*# CORE APP INFO}"
        myConfig="${myConfigPart%%# CORE APP VARIABLES*}"
        
        # if either delimiter string wasn't found, that's an error
        if [[ ( "$myConfigPart" = "$myConfigScript" ) || \
                ( "$myConfig" = "$myConfigPart" ) ]] ; then
            abort "Unexpected app configuration"
        fi
        
        # remove any trailing export statement
        # myConfig="${myConfig%%$'\n'export*}"
        
        # read in config variables
        try eval "$myConfig" "Unable to parse app configuration"
        [[ "$ok" ]] || abort
        
        # update engine type for beta versions 2.3.0b1-2.3.0b6
        if [[ "$SSBEngineType" = 'Chromium' ]] ; then
            ok= ; errmsg='Updating of Chromium-engine apps not yet implemented.'
            errlog "$errmsg"
            abort
            #SSBEngineType="internal|${appBrowserInfo_org_chromium_Chromium[0]}"
            # $$$ appBrowserInfo_com_brave_Browser ??
        elif [[ "$SSBEngineType" = 'Google Chrome' ]] ; then
            SSBEngineType="external|${appBrowserInfo_com_google_Chrome[0]}"
        fi
        
    elif [[ -e "$myOldConfigPath" ]] ; then
        
        # 2.1.0 - 2.2.4
        
        # load runtime.sh
        if ! source "$myResourcesPath/Runtime/Resources/Scripts/runtime.sh" ; then
            ok= ; errmsg="Unable to load runtime.sh."
            errlog "$errmsg"
            abort
        fi
        
        # read in app config
        safesource "$myOldConfigPath" 'app configuration'
        [[ "$ok" ]] || abort
        
        # make sure this is a recent enough app to be edited
        vcmp "$SSBVersion" '<' '2.1.0' && \
            abort 'Cannot edit apps older than version 2.1.0.'
        
        # update necessary variables (SSBIdentifier & SSBEngineType)
        updateoldcoreinfo_preload
        updateoldcoreinfo_postload
        [[ "$ok" ]] || abort
        
    else
        abort "This does not appear to be an Epichrome app"
    fi
    
    
    # SANITY-CHECK CORE APP INFO
    
    # basic info
    ynRe='^(Yes|No)$'
    updateRe='^(Auto|Never)$'
    if [[ ! ( "$SSBVersion" && "$SSBIdentifier" && \
            "$CFBundleDisplayName" && "$CFBundleName" && \
            ( ( ! "$SSBRegisterBrowser" ) || ( "$SSBRegisterBrowser" =~ $ynRe ) ) && \
            ( "$SSBCustomIcon" =~ $ynRe ) && \
            ( ( ! "$SSBUpdateAction" ) || ( "$SSBUpdateAction" =~ $updateRe ) ) ) ]] ; then
        abort "Basic app info is missing or corrupt"
    fi
    
    # make sure version isn't newer than ours
    vcmp "$SSBVersion" '>' "$coreVersion" && \
            abort "App version ($SSBVersion) is newer than Epichrome version."
    
    # fill in register browser if missing
    if [[ ! "$SSBRegisterBrowser" ]] ; then
        try '!12' /usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes' "$epiAppPath/Contents/Info.plist" ''
        if [[ "$ok" ]] ; then
            SSBRegisterBrowser=Yes
        else
            ok=1 ; errmsg=
            SSBRegisterBrowser=No
        fi
    fi
    
    # engine type
    engRe='^(in|ex)ternal\|'
    if [[ ! ( "$SSBEngineType" =~ $engRe ) ]] ; then
        abort "App engine type is missing or unreadable"
    fi
    
    # command line
    if ! isarray SSBCommandLine ; then
        abort "App URLs are missing or unreadable"
    fi
            
    
    # GET PATH TO ICON
    myAppIcon=
    try 'myAppIcon=' /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' \
            "$epiAppPath/Contents/Info.plist" \
            "Unable to find icon file in Info.plist"
    if [[ "$ok" ]] ; then
        myAppIcon="Contents/Resources/$myAppIcon"
        if [[ -e "$epiAppPath/$myAppIcon" ]] ; then
            myAppIcon="
   \"iconPath\": \"$(escapejson "$myAppIcon")\","
        else
            myAppIcon=
        fi
    else
        # fail silently, and we just won't use a custom icon in dialogs
        ok=1 ; errmsg=
        myAppIcon=
    fi
    
    
    # EXPORT INFO BACK TO MAIN.JS
    
    # adapt registerBrowser value
    if [[ "$SSBRegisterBrowser" = 'No' ]] ; then
        myRegisterBrowser='false'
    else
        myRegisterBrowser='true'
    fi
    
    # adapt icon value
    if [[ "$SSBCustomIcon" = 'Yes' ]] ; then
        myIcon='true'
    else
        myIcon='false'
    fi
    
    # adapt update action value
    if [[ "$SSBUpdateAction" = 'Auto' ]] ; then
        SSBUpdateAction='auto'
    elif [[ "$SSBUpdateAction" = 'Never' ]] ; then        
        SSBUpdateAction='never'
    else
        SSBUpdateAction='prompt'
    fi
    
    # export JSON
    echo "{$myAppIcon
   \"version\": \"$(escapejson "$SSBVersion")\",
   \"id\": \"$(escapejson "$SSBIdentifier")\",
   \"displayName\": \"$(escapejson "$CFBundleDisplayName")\",
   \"shortName\": \"$(escapejson "$CFBundleName")\",
   \"registerBrowser\": $myRegisterBrowser,
   \"icon\": $myIcon,
   \"engine\": {
      \"type\": \"$(escapejson "${SSBEngineType%%|*}")\",
      \"id\": \"$(escapejson "${SSBEngineType#*|}")\"
   },
   \"updateAction\": \"$(escapejson "$SSBUpdateAction")\",
   \"commandLine\": [
      "$(jsonarray $',\n      ' "${SSBCommandLine[@]}")"
   ]
}"


elif [[ "$epiAction" = 'build' ]] ; then
    
    # ACTION: BUILD NEW APP
    
    # load update.sh
    if ! source "$myResourcesPath/Scripts/update.sh" ; then
        ok=
        errmsg="Unable to load update.sh."
        errlog "$errmsg"
        abort
    fi
    
    
    # CLEANUP -- clean up any half-made app
    function cleanup {
        
        # clean up any temp app bundle we've been working on
        if [[ -d "$appTmp" ]] ; then
            
            # try to remove temp app bundle
            if [[ "$(type -t rmtemp)" = function ]] ; then
                rmtemp "$appTmp" 'temporary app bundle'
            else
                if ! /bin/rm -rf "$appTmp" 2> /dev/null ; then
                    echo "$myLogID: Unable to remove temporary app bundle." >> "$myLogFile"
                    echo 'Unable to remove temporary app bundle.' 1>&2
                fi
            fi
        fi
    }
    
    
    # CREATE THE APP BUNDLE IN A TEMPORARY LOCATION
    
    debuglog "Starting build for '$epiAppPath'."
    
    # create the app directory in a temporary location
    appTmp="$(tempname "$epiAppPath")"
    try 'cmdtext&=' /bin/mkdir -p "$appTmp" 'Unable to create temporary app bundle.'
    [[ "$ok" ]] || abort
    
    
    # POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME
    
    # populate the app bundle
    updateapp "$appTmp"
    [[ "$ok" ]] || abort
    
    # move new app to permanent location (overwriting any old app)
    permanent "$appTmp" "$epiAppPath" "app bundle"
    [[ "$ok" ]] || abort
    
    
elif [[ ("$epiAction" = 'edit') || ("$epiAction" = 'update') ]] ; then
    
    # ACTION: EDIT (AND POSSIBLY UPDATE) EXISTING APP
    
    # load update.sh
    if ! source "$myResourcesPath/Scripts/update.sh" ; then
        ok=
        errmsg="Unable to load update.sh."
        errlog "$errmsg"
        abort
    fi
    
    
    # CLEANUP -- clean up any half-finished edit
    function cleanup {
        
        # clean up from any aborted update
        [[ "$(type -t updatecleanup)" = 'function' ]] && updatecleanup
    }
    
    # save old version in case we're updating
    myOldVersion="$SSBVersion"
    
    # populate the app bundle
    updateapp "$epiAppPath"
    [[ "$ok" ]] || abort
    
    # capture post-update action warnings
    warnings=()
    
    # set up data directory path for post-update actions
    currentDataPath="$appDataPathBase/$SSBIdentifier"
    
    # MOVE DATA FOLDER IF ID CHANGED
    
    if [[ "$epiOldIdentifier" && \
            ( "$epiOldIdentifier" != "$SSBIdentifier" ) && \
            (  -e "$appDataPathBase/$epiOldIdentifier" ) ]] ; then
        
        # common warning prefix
        warnPrefix="Unable to migrate data directory to new ID $SSBIdentifier"
        
        if [[ -e "$currentDataPath" ]] ; then
            warnings+=( "$warnPrefix. A directory already exists for that ID. The app will use that directory." )
        else
            permanent "$appDataPathBase/$epiOldIdentifier" \
                    "$currentDataPath" "app bundle"
            if [[ ! "$ok" ]] ; then
                warnings+=( 'WARN' \
                        "$warnPrefix. ($errmsg) The app will create a new data directory on first run." )
                ok=1 ; errmsg=
            fi
        fi
    fi
    
    
    # MIGRATE DATA FOLDER TO NEW STRUCTURE IF NECESSARY
    
    if vcmp "$myOldVersion" '<=' '2.2.4' ; then
        
        # load runtime.sh
        if ! source "$myResourcesPath/Runtime/Resources/Scripts/runtime.sh" ; then
            ok= ; errmsg="Unable to load runtime.sh."
            errlog "$errmsg"
            abort
        fi
        
        # update data directory structure
        updateolddatadir "$currentDataPath" "$currentDataPath/$appDataProfileDir"
        
        if [[ ! "$ok" ]] ; then
            [[ "${warnings[*]}" ]] || warnings+=( 'WARN' )
            warnings+=( "Unable to update old data directory structure. ($errmsg) Your data for this app may be lost." )
            ok=1 ; errmsg=
        fi
    fi
    
    
    # MOVE TO NEW NAME IF DISPLAYNAME CHANGED
    
    if [[ "$epiNewAppPath" && \
            ( "$epiNewAppPath" != "$epiAppPath" ) ]] ; then
        
        # common warning prefix & postfix
        warnPrefix="Unable to rename app"
        warnPostfix="The app is intact under the old name of ${epiAppPath##*/}."
        
        if [[ -e "$epiNewPath" ]] ; then
            warnings+=( "$warnPrefix. ${epiNewPath##*/} already exists. $warnPostfix" )
        else
            permanent "$epiAppPath" "$epiNewAppPath" "app bundle"
            if [[ ! "$ok" ]] ; then
                [[ "${warnings[*]}" ]] || warnings+=( 'WARN' )
                warnings+=( "$warnPrefix. ($errmsg) $warnPostfix" )
                ok=1 ; errmsg=
            fi
        fi
    fi
    
    
    # WRITE OUT CONFIG IF NECESSARY
    
    # path to config file
    currentConfigFile="$currentDataPath/$appDataConfigFile"
    
    # if config file exists, read it in
    if [[ -f "$currentConfigFile" ]] ; then
        # read in config file, ignoring errors
        safesource "$currentConfigFile" 'configuration file'
        ok=1 ; errmsg
    fi
    
    # assume we don't need to write config
    doWriteConfig=
    
    # make sure key last-run variables are set up
    if [[ ! "$SSBLastRunVersion" ]] ; then
        SSBLastRunVersion="$myOldVersion"
        doWriteConfig=1
    fi
    if [[ ! "$SSBLastRunEngineType" ]] ; then
        SSBLastRunEngineType="$epiOldEngine"
        doWriteConfig=1
    fi
    
    # if we need to, write out config
    [[ -d "$currentDataPath" ]] || try /bin/mkdir -p "$currentDataPath" 'Unable to create data directory.'
    writeconfig "$currentConfigFile" FORCE
    
    if [[ ! "$ok" ]] ; then
        [[ "${warnings[*]}" ]] || warnings+=( 'WARN' )
        warnings+=( "Unable to update app configuration. ($errmsg) The welcome page may show inaccurate information." )
        ok=1 ; errmsg=
    fi
    
    
    # IF ANY WARNINGS FOUND, REPORT THEM
    
    [[ "${warnings[*]}" ]] && abort "$(join_array $'\n' "${warnings[@]}")"
    
else
    abort "Unable to perform action '$epiAction'."
fi

cleanexit
