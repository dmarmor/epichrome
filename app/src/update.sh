#!/bin/bash
#
#  update.sh: functions for updating/or creating Epichrome apps
#
#  Copyright (C) 2022  David Marmor
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
    
    # arguments -- send to progress app
    local updateAppPath="$1" ; shift
    local aAction="$1" ; shift
    [[ "$aAction" ]] || aAction="Updating \"${SSBAppPath##*/}\""
    
    # get path to this script's enclosing Epichrome.app Resources directory
    local myEpiRuntimeResources="${BASH_SOURCE[0]%/Scripts/update.sh}/Runtime/Contents/Resources"
    
    # load subapp script
    safesource "$myEpiRuntimeResources/Scripts/runprogress.sh"
    [[ "$ok" ]] || return 1
    
    # export update-related scalar variables
    export updateAppPath
    
    # export app array variables
    exportarray SSBCommandLine myStatusEngineChange
    
    # export epichrome.sh variables
    if [[ "$coreContext" = 'epichrome' ]] ; then
        export epiAction epiIconSource epiIconCrop epiIconCompSize epiIconCompBG
        [[ "$epiOldIdentifier" ]] && export epiOldIdentifier
    fi
    
    # run update
    runprogress "$myEpiRuntimeResources" 'update' "$aAction"
    
    if [[ "$ok" ]] ; then
        
        # running in an app -- update config & relaunch
        if [[ "$coreContext" = 'app' ]] ; then
            
            # write out config
            writeconfig "$myConfigFile" FORCE
            if [[ ! "$ok" ]] ; then
                tryalways /bin/rm -f "$myConfigFile" \
                        'Unable to delete old config file.'
                alert "Update succeeded, but unable to update settings. ($(msg)) The welcome page will not have accurate info about the update." \
                        'Warning' '|caution'
                ok=1 ; errmsg=
            fi
            
            # start relaunch job
            updaterelaunch "$myEpiRuntimeResources/Scripts" < /dev/null &> /dev/null &
            
            # exit
            cleanexit
        fi
        
        return 0
    else
        # aborted or canceled
        
        # fallback cancel message for old versions
        if [[ "$errmsg" = 'CANCEL' ]] ; then
            if [[ "$coreContext" != 'epichrome' ]] && \
                vcmp "$SSBVersion" '<' '2.4.0b4[004]' ; then
                errmsg='Update canceled.'
            fi
        fi
        
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
        abortreport
    fi
    if [[ "$ok" ]] ; then
        if ! source "$aEpiScripts/launch.sh" ; then
            ok= ; errmsg="Unable to load updated launch.sh."
            abortreport
        fi
    fi
    
    # wait for parent to quit
    debuglog "Waiting for parent app (PID $$) to quit..."
    while kill -0 "$$" 2> /dev/null ; do
        pause 1
    done
    
    debuglog "Parent app has quit. Relaunching..."
    
    # relaunch
    local iArgs=( '--relaunch' )
    local iRelaunchPid
    launchapp "$SSBAppPath" REGISTER 'updated app' iArgs
    
    # report result
    if [[ "$ok" ]] ; then
        debuglog "Parent app relaunched successfully. Quitting."
        return 0
    else
        alert "$(msg) You may have to launch it manually." 'Warning' '|caution'
        return 1
    fi
}
