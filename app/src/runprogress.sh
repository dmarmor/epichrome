#!/bin/bash
#
#  runprogress.sh: functions/data for running Epichrome sub-apps
#
#  Copyright (C) 2021  David Marmor
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


# RUNPROGRESS: run a progress sub-app & process result
#   runprogress(aProgressAppPath progressMode progressAction)
function runprogress {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local aProgressAppPath="$1" ; shift
    local progressMode="$1" ; shift
    local progressAction="$1" ; shift
    export progressMode progressAction
    
    # set up errmsg file & export to subapp
    local subappErrFile="$myDataPath/errmsg.txt"
    export subappErrFile
    
    # export basic app settings
    export SSBVersion SSBIdentifier CFBundleDisplayName CFBundleName \
            SSBRegisterBrowser SSBCustomIcon SSBEngineType \
            SSBUpdateAction SSBEdited
    
    # run progress app in background and wait for it to quit (to suppress any signal termination messages)
    "$aProgressAppPath/EpichromeProgress.app/Contents/MacOS/EpichromeProgress" >& /dev/null &
    wait "$!" >& /dev/null
    
    # get result of subapp
    local iUpdateResult="$?"
    
    if [[ "$iUpdateResult" = 0 ]] ; then
        return 0
    else
        # aborted or canceled
        ok=
        
        # try to retrieve error message from subapp
        if [[ "$iUpdateResult" = 143 ]] ; then
            # TERM signal: CANCEL button
            errmsg='CANCEL'
        else
            local myErrMsg=
            ok=1 ; errmsg=
            if waitforcondition "error message file to appear" 2 .5 \
                    test -f "$subappErrFile" ; then
                try 'myErrMsg=' /bin/cat "$subappErrFile" 'Unable to read error message file.'
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
            tryalways /bin/rm -f "$subappErrFile" 'Unable to remove error message file.'
        fi
        
        return "$iUpdateResult"
    fi
}
