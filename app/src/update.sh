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
#  updateapp(updateAppPath)
function updateapp {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # argument -- send to EpichromeUpdate.app
    local updateAppPath="$1" ; shift
    
    # export app scalar variables
    export updateAppPath \
            SSBVersion SSBIdentifier CFBundleDisplayName CFBundleName \
            SSBRegisterBrowser SSBCustomIcon SSBEngineType \
            SSBUpdateAction SSBEdited
    
    # export app array variables
    exportarray SSBCommandLine myStatusEngineChange
    
    # export epichrome.sh variables
    if [[ "$coreContext" = 'epichrome' ]] ; then
        export epiAction epiIconSource
    fi
    
    # start update app
    local updateErr=
    try 'updateErr&=' \
            "${BASH_SOURCE[0]%/Contents/Resources/Scripts/update.sh}/Contents/Resources/EpichromeUpdate.app/Contents/MacOS/EpichromeUpdate" \
            ''
    
    if [[ "$ok" ]] ; then
        
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
            updaterelaunch &
            
            # exit
            cleanexit
        fi
        return 0
    else
        # $$$$ fix this
        errmsg="PENDING $updateErr"
        return 1
    fi
}


# UPDATERELAUNCH -- relaunch an updated app
function updaterelaunch {

    # only run if we're OK
    [[ "$ok" ]] || return 1
    
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
