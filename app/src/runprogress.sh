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
    try rm -f "$subappErrFile" 'Unable to remove progress bar message file.'
    [[ "$ok" ]] || return 1
    export subappErrFile
    
    # export basic app settings
    export SSBVersion SSBIdentifier CFBundleDisplayName CFBundleName \
            SSBRegisterBrowser SSBCustomIcon SSBEngineType \
            SSBUpdateAction SSBBackupData SSBSkipWelcome SSBEdited
    
    # run progress app in background and wait for it to quit (to suppress any signal termination messages)
    "$aProgressAppPath/EpichromeProgress.app/Contents/MacOS/EpichromeProgress" >& /dev/null &
    wait "$!" >& /dev/null
    
    # get result of subapp
    local iUpdateResult="$?"
    
    local myErrMsg=
    
    if [[ "$iUpdateResult" = 143 ]] ; then
        # TERM signal: CANCEL button (ignores any returned message)
        myErrMsg='CANCEL'
    else
        
        # retrieve any message from subapp
        
        # if error returned, expect a message
        if [[ "$iUpdateResult" != 0 ]] && \
                ! waitforcondition "progress bar message to appear" 2 .5 test -f "$subappErrFile" ; then
            myErrMsg='An unknown error occurred (no error message found).'
        fi
        if [[ -f "$subappErrFile" ]] ; then
            
            # read error message file
            local mySubappMsg=
            try 'mySubappMsg=' /bin/cat "$subappErrFile" 'Unable to read progress bar message.'
            
            if [[ "$ok" ]] ; then
                myErrMsg="$mySubappMsg"
            elif [[ "$iUpdateResult" != 0 ]] ; then
                # error reading message & subapp returned an error, so report that
                myErrMsg="An unknown error occurred (unable to read error message)."
            fi
            ok=1
        fi
    fi
    
    # remove any message file
    try /bin/rm -f "$subappErrFile" 'Unable to remove error message file.'
    ok=1
    
    # set errmsg
    errmsg="$myErrMsg"

    # return result
    if [[ "$iUpdateResult" = 0 ]] ; then
        return 0
    else
        ok=
        return "$iUpdateResult"
    fi
}
