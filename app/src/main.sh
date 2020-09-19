#!/bin/bash
#
#  main.sh: Run an Epichrome app
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


# CORE APP INFO

# filled in by Makefile
SSBVersion='EPIVERSION'

# filled in by updateapp
SSBIdentifier=APPID
CFBundleDisplayName=APPDISPLAYNAME
CFBundleName=APPBUNDLENAME
SSBRegisterBrowser=APPREGISTERBROWSER
SSBCustomIcon=APPCUSTOMICON
SSBEngineType=APPENGINETYPE
APPENGINESOURCE
SSBUpdateAction=APPUPDATEACTION
SSBCommandLine=APPCOMMANDLINE
SSBEdited=APPEDITED


# CORE APP VARIABLES

myAppPath="${BASH_SOURCE[0]%/Contents/Resources/Scripts/main.sh}"
myEnginePID=


# PARSE COMMAND-LINE ARGUMENTS

argsURIs=()
argsOptions=()
while [[ "$#" -gt 0 ]] ; do
    case "$1" in
        --epichrome-id=*)
            # ignore
            ;;
        
        --epichrome-debug)
            debug=1
            ;;
            
        [hH][tT][tT][pP]'://'*|[hH][tT][tT][pP][sS]'://'*|[fF][tT][pP]'://'*|[fF][iI][lL][eE]'://'*)
            # this should be sent to the open command
            argsURIs+=( "$1" )
            ;;
        
        *)
            # pass any other options along to the engine
            argsOptions+=( "$1" )
    esac
    
    # get next arg
    shift
done


# LOAD CORE SCRIPT

myLogID=   # reset log ID
source "$myAppPath/Contents/Resources/Scripts/core.sh" 'coreDoInit=1' || exit 1
[[ "$ok" ]] || abort

# ensure we have a data directory
[[ -d "$myDataPath" ]] || abort 'Unable to create data directory.'


# DON'T TRAP SIGINT

trap '' INT


# --- FUNCTION DEFINITIONS ---

# CLEANUP -- clean up from any failed update & deactivate any active engine
function cleanup {
    
    # clean up from any aborted update  $$$ MOVE THIS INTO PROGRESS APP?
    #[[ "$(type -t updatecleanup)" = 'function' ]] && updatecleanup
    
    if [[ "$myEnginePID" ]] ; then
        
        # if engine is still running, kill it now        
        if kill -0 "$myEnginePID" 2> /dev/null ; then
            errlog FATAL 'Terminated while engine still running! Killing engine.'
            kill "$myEnginePID"
        fi
        
        # deactivate engine
        ok=1 ; errmsg=
        setenginestate OFF
        [[ "$ok" ]] && debuglog "Engine deactivation complete."
        
        # the launch failed, so delete the failed engine
        if [[ "$myEnginePID" = 'LAUNCHFAILED' ]] ; then
            deletepayload
        fi
        
        # attempt to alert the user if the app was not left in a runnable state
        # $$$$ PROBABLY FALL BACK TO TRYING TO REPLACE APP WITH BACKUP?
        [[ "$ok" ]] || alert "FATAL ERROR attempting to deactive app engine: $errmsg"$'\n\nThis app has most likely been damaged and will not run again. Please restore from backup.' 'Error' '|stop'
    fi    
}


# --- MAIN BODY ---

# initialize log file
initlogfile


# LOAD LAUNCH FUNCTIONS

safesource "$myAppPath/Contents/Resources/Scripts/launch.sh"
[[ "$ok" ]] || abort


# READ CURRENT APP SETTINGS

# add extra config vars for external engine
[[ "${SSBEngineType%%|*}" != internal ]] && appConfigVars+=( SSBEngineSourceInfo )

# read config file (if any)
if [[ -f "$myConfigFile" ]] ; then
    
    # if we're running an internal engine, don't let config.sh override SSBEngineSourceInfo
    tempEngInfo=
    [[ "${SSBEngineSourceInfo[*]}" ]] && tempEngInfo=( "${SSBEngineSourceInfo[@]}" )
    
    # read config file
    readconfig "$myConfigFile"
    [[ "$ok" ]] || abort
    
    # restore SSBEngineSourceInfo if needed
    if [[ "${tempEngInfo[*]}" ]] ; then
        debuglog 'Overriding SSBEngineSourceInfo from config.sh with built-in value.'
        SSBEngineSourceInfo=( "${tempEngInfo[@]}" )
    fi
    
else
    debuglog "No configuration file found."
fi


# APP STATUS VARIABLES

myStatusNewApp=         # on new app, this is set
myStatusNewVersion=     # on update, this contains old version
myStatusEdited=         # on first run of an edited app, this is set
myStatusFixRuntime=     # set by updateprofiledir to a copy of Epichrome Helper settings if we need to preserve them
myStatusPayloadUserDir= # if payload directory is inside a per-user directory, this is set to that directory
myStatusEngineMoved=    # set if app engine needs to move
myStatusEngineChange=   # on engine change, this contains old engine info
myStatusReset=          # set if app settings appear to have been reset
myStatusWelcomeURL=     # set by setwelcomepage if welcome page should be shown
myStatusWelcomeTitle=   # title for URL bookmark


# DETERMINE IF THIS IS A NEW APP OR FIRST RUN ON A NEW VERSION

if [[ "$SSBVersion" != "$SSBLastRunVersion" ]] ; then
    
    if [[ "$SSBLastRunVersion" ]] ; then
        
        # updated app
        myStatusNewVersion="$SSBLastRunVersion"
        
    else
        
        # new app
        myStatusNewApp=1
        
    fi
    
    # update last run variables
    SSBLastRunVersion="$SSBVersion"
    #SSBUpdateVersion="$SSBVersion"
    
    # clear error states
    SSBLastErrorNMHInstall=
fi


# DETERMINE IF THIS IS FIRST RUN OF AN EDITED APP

if [[ "$SSBEdited" && \
        ( ( ! "$SSBLastRunEdited" ) || \
        ( "$SSBEdited" -gt "$SSBLastRunEdited" ) ) ]] ; then
    myStatusEdited=1
fi

# update last run variable
SSBLastRunEdited="$SSBEdited"


# DETERMINE IF WE'VE JUST CHANGED ENGINES

if [[ ( ! "$myStatusNewApp" ) && \
        ( "$SSBLastRunEngineType" && \
        ( "${SSBEngineType#*|}" != "${SSBLastRunEngineType#*|}" ) ) ]] ; then
    
    # mark engine change
    getbrowserinfo myStatusEngineChange "${SSBLastRunEngineType#*|}"
    myStatusEngineChange[0]="$SSBLastRunEngineType"
    
    # clear extension install error state
    SSBLastErrorNMHInstall=
fi

# update last-run engine
SSBLastRunEngineType="$SSBEngineType"


# DETERMINE IF SETTING HAVE BEEN RESET

[[ -e "$myFirstRunFile" && -e "$myPreferencesFile" ]] || \
    myStatusReset=1


# UPDATE APP PATH

SSBAppPath="$myAppPath"


# GET EPICHROME INFO

getepichromeinfo


# CHECK FOR NEW EPICHROME ON SYSTEM AND OFFER TO UPDATE

if [[ "$epiCurrentMissing" || ! ( "$myStatusNewApp" || "$myStatusNewVersion" || "$myStatusEngineChange" ) ]] ; then
    
    checkappupdate
    
    if [[ "$?" != 0 ]] ; then
        
        # abort on fatal error
        [[ "$ok" ]] || abort
        
        # display warning on non-fatal error
        alert "$errmsg Please try update again later." 'Unable to Update' '|caution'
        ok=1
        errmsg=
    fi
    
    # CHECK FOR NEW EPICHROME ON GITHUB AND OFFER TO DOWNLOAD
    
    if [[ ! "$SSBLastErrorGithubFatal" ]] ; then
        checkgithubupdate
    else
        errlog 'GitHub update check disabled due to fatal error on a previous attempt.'
    fi
fi


# UPDATE PAYLOAD PATH

# determine where our payloads should be
myPayloadPath=

# start with Epichrome.app location
if [[ -d "$epiCurrentPath" ]] ; then
    
    # apps must be on the same volume as their engine
    if ! issamedevice "$SSBAppPath" "$epiCurrentPath" ; then
        abort 'Apps must reside on the same physical volume as the version of Epichrome they are based on.'
    fi
    
    myPayloadPath="$epiCurrentPath"
    
    # get directory path
    myPayloadPath="${myPayloadPath%/*}/$epiPayloadPathBase"
    
    # determine if path is in our user path
    if [[ "$myPayloadPath" = "$HOME"* ]] ; then
        # path is user-level, so just add our app ID
        myPayloadPath+="/$SSBIdentifier"
    else
        # path is root-level, so add our user ID & app ID
        myStatusPayloadUserDir="$myPayloadPath/$USER"
        myPayloadPath="$myStatusPayloadUserDir/$SSBIdentifier"
    fi
    
    # if updating from old version, switch out config variable
    [[ "$SSBEnginePath" && ( ! "$SSBPayloadPath" ) ]] && SSBPayloadPath="$SSBEnginePath"
    
    # check if payload path matches what it should be
    if [[ "$SSBPayloadPath" != "$myPayloadPath" ]] ; then
                
        if [[ "$SSBPayloadPath" ]] ; then

            # payload path is out of date, so we'll recreate it
            debuglog "Payload path '$SSBPayloadPath' is out of date. Moving to new location."
            
            if [[ ( ! -d "$myPayloadPath" ) && -d "$SSBPayloadPath" ]] && \
                    issamedevice "$epiCurrentPath" "$SSBPayloadPath" ; then
                try /bin/mv "$SSBPayloadPath" "$myPayloadPath" \
                        'Unable to move payload path to new location.'
                ok=1 ; errmsg=
            fi
            
            # engine still at old location -- delete
            if [[ -d "$SSBPayloadPath" ]] ; then
                
                deletepayload
                
                # set status variable
                myStatusEngineMoved="$SSBPayloadPath"
            fi
        else
            # no payload path yet
            debuglog "No payload path found. Creating new payload path."
        fi
        
        # set new payload path
        SSBPayloadPath="$myPayloadPath"
    fi
else
    # no current Epichrome! -- leave as is but make sure on same device as app
    if [[ ! -d "$SSBPayloadPath" ]] ; then
        abort "No engine payload path exists and this app's version of Epichrome can't be found."
    elif ! issamedevice "$SSBAppPath" "$SSBPayloadPath" ; then
        abort 'App is not on the same physical volume as its engine payload.'
    fi
fi

# set up payload subsidiary paths
myPayloadEnginePath="$SSBPayloadPath/$epiPayloadEngineDir"
myPayloadLauncherPath="$SSBPayloadPath/$epiPayloadLauncherDir"


# IF USING EXTERNAL ENGINE, GET INFO

if [[ "${SSBEngineType%%|*}" != internal ]] ; then
    
    # try the path we've been using first
    [[ "${SSBEngineSourceInfo[$iPath]}" ]] && getextenginesrcinfo "${SSBEngineSourceInfo[$iPath]}"
    
    # if that fails, search the system for external engine
    [[ "${SSBEngineSourceInfo[$iPath]}" ]] || getextenginesrcinfo
fi


# PREPARE DATA DIRECTORY

# update the data directory
if ! updatedatadir ; then
    [[ "$ok" ]] && alert "$errmsg" 'Warning' '|caution'
fi
[[ "$ok" ]] || abort

# set any welcome page
setwelcomepage

# update the profile directory
if ! updateprofiledir ; then
    [[ "$ok" ]] && alert "$errmsg" 'Warning' '|caution'
fi
[[ "$ok" ]] || abort

# install/update native messaging host manifests (including ours), reporting non-fatal errors
installnmhs ; installNMHError="$?"
if [[ "$ok" ]] ; then
    # success, so clear last error
    SSBLastErrorNMHInstall=
else
    if [[ "$SSBLastErrorNMHInstall" != "$errmsg" ]] ; then
        
        if [[ "$installNMHError" = 2 ]] ; then
            # unable to install NMH manifests for Epichrome extension
            installNMHError="Unable to install Epichrome extension native messaging host. ($errmsg)"$'\n\n'"The Epichrome extension will not work, but other extensions (such as 1Password) should work properly."
        else
            # unable to link to NMH directory -- no NMHs will work
            installNMHError="Unable to install native messaging hosts for this app. ($errmsg)"$'\n\n'"The Epichrome extension will not work, and other extensions (such as 1Password) may not either."
        fi
            
        # show warning alert for error installing native messaging host
        alert "$installNMHError"$'\n\n'"This error will only be reported once. All errors can be found in the app log." 'Warning' '|caution'
        
        # set new error state
        SSBLastErrorNMHInstall="$errmsg"
    fi
    
    # clear error state
    ok=1 ; errmsg=
fi


# CREATE OR UPDATE ENGINE IF NECESSARY

# flag whether we need to (re)create the engine and/or activate it
doCreateEngine=

if [[ "$myStatusNewApp" ]] ; then
    
    # new app, so of course we need an engine
    doCreateEngine=1
    debuglog "Creating engine for new app."
    createEngineErrMsg="Unable to create engine for new app"
    
elif [[ "$myStatusNewVersion" ]] ; then
    
    # app was updated, so we need a new engine
    doCreateEngine=1
    debuglog "Updating engine for new Epichrome version $SSBVersion."
    createEngineErrMsg="Unable to update engine for new Epichrome version $SSBVersion"
    
elif [[ "$myStatusEdited" ]] ; then
    
    # this app was edited, so we need a new engine
    doCreateEngine=1
    debuglog "Updating engine for edited app."
    createEngineErrMsg="Unable to update engine for edited app"
    
elif [[ "${myStatusEngineChange[0]}" ]] ; then
    
    # the app engine was changed, so we need a new engine (probably never reached)
    doCreateEngine=1
    debuglog "Updating engine for new app engine type."
    createEngineErrMsg="Unable to update engine to new type"
    
elif [[ "$myStatusEngineMoved" ]] ; then
    
    # the app engine was changed, so we need a new engine (probably never reached)
    doCreateEngine=1
    debuglog "Recreating engine in new location '$SSBPayloadPath'."
    createEngineErrMsg="Unable to recreate engine in new location"
    
elif [[ ( "${SSBEngineType%%|*}" != internal ) && \
        "${SSBEngineSourceInfo[$iVersion]}" && \
        ( "${SSBEngineSourceInfo[$iVersion]}" != "${configSSBEngineSourceInfo[$iVersion]}" ) ]] ; then
    
    # new version of external engine
    doCreateEngine=1
    debuglog "Updating engine to ${SSBEngineSourceInfo[$iDisplayName]} version ${SSBEngineSourceInfo[$iVersion]}."
    createEngineErrMsg="Unable to update engine to ${SSBEngineSourceInfo[$iDisplayName]} version ${SSBEngineSourceInfo[$iVersion]}."

elif ! checkenginepayload ; then
    
    # engine damaged or missing
    doCreateEngine=1
    errlog "Replacing damaged or missing engine."
    createEngineErrMsg='Unable to replace damaged or missing engine'    
fi
[[ "$ok" ]] || abort

# create engine payload if necessary
if [[ "$doCreateEngine" ]] ; then
    
    # (re)create engine payload
    createenginepayload
    [[ "$ok" ]] || abort "$createEngineErrMsg: $errmsg"
fi


# PREPARE APP FOR LAUNCH

# build command line
myEngineArgs=( "--user-data-dir=$myProfilePath" \
        '--no-default-browser-check' \
        "${argsOptions[@]}" \
        "${SSBEngineSourceInfo[@]:$iArgs}" \
        "${SSBCommandLine[@]}" )

# temporarily install master prefs if needed
masterPrefsSet=
setmasterprefs
if [[ "$ok" ]] ; then
    masterPrefsSet=1
else
    alert "Unable to initialize app settings. ($errmsg) Some app settings may need to be adjusted." \
            'Warning' '|caution'
    ok=1 ; errmsg=
fi


# LAUNCH ENGINE

# activate engine
setenginestate ON
[[ "$ok" ]] || abort

# set illegal PID to trigger engine deactivation on exit
myEnginePID='LAUNCHFAILED'

# export app info to native messaging host
export SSBVersion SSBIdentifier CFBundleName CFBundleDisplayName \
        myLogID myLogFile SSBAppPath

# launch engine
launchapp "$SSBAppPath" REGISTER 'engine' myEnginePID myEngineArgs  # $$$ REGISTER?


# CHECK FOR A SUCCESSFUL LAUNCH

# start collecting post-launch errors
errPostLaunch=

if [[ ! "$ok" ]] ; then
    
    # launch failed
    [[ "$errmsg" ]] && errPostLaunch="$errmsg "
    errPostLaunch+="The app may not have launched properly. If it did, the engine will not be properly cleaned up upon quitting."
    myEnginePID='LAUNCHFAILED'
fi


# UNINSTALL MASTER PREFS (IF INSTALLED)

if [[ "$masterPrefsSet" ]] ; then
    
    clearmasterprefs
    
    # errors clearing master prefs are nonfatal
    if [[ ! "$ok" ]] ; then
        ok=1 ; errmsg=
    fi
fi


# UPDATE CONFIG FILE IF NECESSARY

writeconfig "$myConfigFile"
if [[ ! "$ok" ]] ; then
    if [[ "$errPostLaunch" ]] ; then
        errPostLaunch="$errmsg Also: $errPostLaunch"
    else
        errPostLaunch="$errmsg"
    fi
    ok=1 ; errmsg=
fi


# OPEN ANY URLS & SHOW WELCOME PAGE IF NEEDED

if [[ "$myEnginePID" && ( "$myStatusWelcomeURL" || "${argsURIs[*]}" ) ]] ; then
    
    # description & error message for URLs and/or welcome page
    urlDesc=
    
    # add description for URLs
    [[ "${argsURIs[*]}" ]] && urlDesc='URLs'
    
    # add welcome page to URL list and add to description
    if [[ "$myStatusWelcomeURL" ]] ; then
        
        [[ "$urlDesc" ]] && urlDesc+=' and '
        urlDesc+='welcome page'
        
        # if we're updating from pre-2.3.0b10, show extra popup alert
        if [[ "$myStatusNewApp" ]] || \
                ( [[ "$myStatusNewVersion" ]] && vcmp "$myStatusNewVersion" '<' '2.3.0b10' ) ; then
            myStatusWelcomeURL+='&m=1'
        fi
        
        # add welcome page to URIs
        argsURIs+=( "$myStatusWelcomeURL" )
        
        debuglog "Showing welcome page ($myStatusWelcomeURL)."
    fi
    
    # open the URLs and/or welcome page
    launchurls "$urlDesc" "${argsURIs[@]}"
    
    # save any error
    if [[ ! "$ok" ]] ; then
        [[ "$errPostLaunch" ]] && errPostLaunch+=' Also: '
        errPostLaunch+="Unable to open ${urlDesc} ($errmsg)"
        [[ "$myStatusWelcomeURL" ]] && errPostLaunch +=" You should be able to access the welcome page in the app's bookmarks. Please open it for important information about setting up the app."
        ok=1 ; errmsg=
    fi
fi


# SAVE LOST RUNTIME EXTENSION SETTINGS IF NEEDED

if [[ "${myStatusFixRuntime[0]}" ]] ; then
    
    # give the app 5 seconds to delete the runtime extension settings
    waitforcondition 'app to delete Epichrome Helper settings' \
            5 .5 test '!' -d "${myStatusFixRuntime[0]}"
    
    if [[ ! -d "${myStatusFixRuntime[0]}" ]] ; then
        
        debuglog "Restoring Epichrome Helper settings."
        
        # move copied settings back into place
        try /bin/mv "${myStatusFixRuntime[1]}" "${myStatusFixRuntime[0]}" \
                'Unable to restore Epichrome Helper settings.'
        if [[ ! "$ok" ]] ; then
            [[ "$errPostLaunch" ]] && errPostLaunch+=' Also: '
            errPostLaunch+="$errmsg After reinstalling Epichrome Helper, you will probably need to restore its settings from a backup or re-enter them."
            ok=1 ; errmsg=
        fi
    else
        debuglog "No need to restore Epichrome Helper settings."
        
        # silently remove unused backup
        saferm 'Unable to remove backup of Epichrome Helper settings.' \
                "${myStatusFixRuntime[1]}"
        ok=1 ; errmsg=
    fi
fi


# REPORT ANY POST-LAUNCH ERRORS

if [[ "$myEnginePID" = 'LAUNCHFAILED' ]] ; then
    abort "$errPostLaunch"
elif [[ "$errPostLaunch" ]] ; then
    alert "$errPostLaunch" 'Warning' '|caution'
fi


# MONITOR ENGINE FOR CLEANUP

# wait for app to exit
debuglog "Waiting for engine to quit..."
while kill -0 "$myEnginePID" 2> /dev/null ; do
    pause 1
done

# deactivate engine and quit
debuglog 'Engine has quit. Cleaning up...'

# exit cleanly
cleanexit
