#!/bin/bash
#
#  subapp.sh: functions/data for running Epichrome sub-apps
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


# CONSTANTS

appDataErrmsgFile='errmsg.txt'


# RUNSUBAPP: run a sub-app & process result
#   runsubapp(aAppExec)
function runsubapp {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local aAppExec="$1" ; shift
    
    # set up errmsg file & export to subapp
    local myErrmsgFile="$myDataPath/$appDataErrmsgFile"
    export myErrmsgFile
    
    # run subapp in background and wait for it to quit (to suppress any signal termination messages)
    "$aAppExec" >& /dev/null &
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
            # CANCEL button
            errmsg='CANCEL'
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
        
        return 1
    fi
}
