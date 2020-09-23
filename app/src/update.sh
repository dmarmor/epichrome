#!/bin/bash
#
#  update.sh: functions for updating/or creating Epichrome apps
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


# FUNCTION DEFINITIONS

# UPDATEAPP: run Epichrome Update.app to populate an app bundle
#  updateapp(updateAppPath updateAppMessage)
function updateapp {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments -- send to EpichromeUpdate.app
    local updateAppPath="$1" ; shift
    local updateAppMessage="$1" ; shift
    [[ "$updateAppMessage" ]] || updateAppMessage="Updating \"${SSBAppPath##*/}\""
    
    # export app scalar variables
    export updateAppPath updateAppMessage \
            SSBVersion SSBIdentifier CFBundleDisplayName CFBundleName \
            SSBRegisterBrowser SSBCustomIcon SSBEngineType \
            SSBUpdateAction SSBEdited
            
    # export app array variables
    exportarray SSBCommandLine myStatusEngineChange
    
    # export epichrome.sh variables
    if [[ "$coreContext" = 'epichrome' ]] ; then
        export epiAction epiIconSource
    fi
    
    # set up errmsg file
    export myErrmsgFile="$myDataPath/"
    if [[ "$appDataErrmsgFile" ]] ; then
        myErrmsgFile+="$appDataErrmsgFile"
    else
        myErrmsgFile+='errmsg.txt'
    fi
    
    # get path to this script's enclosing Epichrome.app resources directory
    local myEpiResources="${BASH_SOURCE[0]%/Contents/Resources/Scripts/update.sh}/Contents/Resources"
    
    # run update app in background and wait for it to quit (to suppress any signal termination messages)
    "$myEpiResources/EpichromeUpdate.app/Contents/MacOS/EpichromeUpdate" >& /dev/null &
    wait "$!" >& /dev/null
    
    # get result of update app
    local iUpdateResult="$?"
    
    if [[ "$iUpdateResult" = 0 ]] ; then
        
        # running in an app -- update config & relaunch
        if [[ "$coreContext" = 'app' ]] ; then
            
            # write out config
            writeconfig "$myConfigFile" FORCE
            if [[ ! "$ok" ]] ; then
                tryalways /bin/rm -f "$myConfigFile" \
                        'Unable to delete old config file.'
                alert "Update succeeded, but unable to update settings. ($errmsg) The welcome page will not have accurate info about the update." \
                        'Warning' '|caution'
                ok=1 ; errmsg=
            fi
            
            # start relaunch job
            updaterelaunch "$myEpiResources/Runtime/Contents/Resources/Scripts" &
            
            # exit
            cleanexit
        fi
        return 0
    else
        # aborted or canceled
        ok=
        
        # try to retrieve error message from EpichromeUpdate.app
        if [[ "$iUpdateResult" = 143 ]] ; then
            
            # CANCEL button
            if [[ "$coreContext" != 'epichrome' ]] && vcmp "$SSBVersion" '<' '2.4.0b4[004]' ; then
                errmsg='Update canceled.'
            else
                errmsg='CANCEL'
            fi
            
        else
            local myErrMsg=
            ok=1 ; errmsg=
            if waitforcondition "error message file to appear" 2 .5 \
                    test -f "$myErrmsgFile" ; then
                try 'myErrMsg=' /bin/cat "$myErrmsgFile" 'Unable to read error message file.'
            else
                ok= ; errmsg='No error message found.'
                errlog "$errmsg"
            fi
            if [[ "$ok" ]] ; then
                errmsg="$myErrMsg"
                ok=
            else
                errmsg="An unknown error occurred. Unable to read error message file."
            fi
            tryalways /bin/rm -f "$myErrmsgFile" 'Unable to remove error message file.'
        fi
        
        unset myErrmsgFile
        
        return 1
    fi
}


# UPDATERELAUNCH -- relaunch an updated app
#   updaterelaunch(aEpiScripts)
function updaterelaunch {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local aEpiScripts="$1" ; shift
    
    # bootstrap updated core.sh & launch.sh
    if ! source "$aEpiScripts/core.sh" ; then
        ok= ; errmsg="Unable to load updated core."
        abort
    fi
    if [[ "$ok" ]] ; then
        if ! source "$aEpiScripts/launch.sh" ; then
            ok= ; errmsg="Unable to load updated launch.sh."
            abort
        fi
    fi
    
    # wait for parent to quit
    debuglog "Waiting for parent app (PID $$) to quit..."
    while kill -0 "$$" 2> /dev/null ; do
        pause 1
    done
    
    debuglog "Parent app has quit. Relaunching..."
    
    # relaunch
    launchapp "$SSBAppPath" REGISTER 'updated app' myRelaunchPID argsOptions  # $$$ REGISTER?
    
    # report result
    if [[ "$ok" ]] ; then
        debuglog "Parent app relaunched successfully. Quitting."
        return 0
    else
        alert "$errmsg You may have to launch it manually." 'Warning' '|caution'
        return 1
    fi
}
