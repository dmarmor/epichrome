#!/bin/bash
#
#  progress.sh: utility functions for progress bar apps
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


# PROGRESS BAR APP SETTINGS

# set progress action message
[[ "$progressAction" ]] || progressAction='Working'
progressAction+='...'

# sanity-check progress bar total
[[ "$progressTotal" -gt 0 ]] || progressTotal=

# set up for running as a sub-app
if [[ "$subappErrFile" ]] ; then
    coreAbortParentSignal=ABRT
    coreShowAlertOnAbort=
    coreErrFile="$subappErrFile"
fi


# --- FUNCTION DEFINITIONS ---

# HANDLECANCEL: handle a cancel signal
progressCanceled=
function handlecancel {
    progressCanceled=1
    [[ "$coreAbortParentSignal" ]] && coreAbortParentSignal=TERM
    abort 'Operation canceled.'
}
trap handlecancel TERM


# PROGRESS: print a message for the progress bar
#  progress(aStepId [aStatusItem aStatusNum]...)
#    if aStepId starts with '!' then force this message to show
progressCumulative=0
progressPrevStatus=
progressPrevTime=0
progressCurDetail=
function progress {
    
    # arguments
    local iForce=
    local aStepId="$1" ; shift
    if [[ "${aStepId::1}" = '!' ]] ; then
        iForce=1
        aStepId="${aStepId/\!/}"
    fi

    # end step is only for calibration
    [[ "$aStepId" = 'end' ]] && return
    
    # get increment for this step
    local iStepIncrement=
    eval "iStepIncrement=\"\$$aStepId\""
    
    # handle (and clear) detail message
    local iDetail=
    if [[ "$progressCurDetail" ]] ; then
        iDetail="$progressCurDetail"$'\n'
        progressCurDetail=
    fi
    
    # build percentage (or count)
    local iPercent=
    if [[ "$iStepIncrement" && "$progressTotal" ]] ; then
        progressCumulative=$(( $progressCumulative + $iStepIncrement ))
        iPercent=" ($(($progressCumulative * 100 / $progressTotal))%)"
    elif [[ "$iStepIncrement" || "$progressTotal" ]] ; then
        iPercent=" (${iStepIncrement}${progressTotal})"
    fi
    
    # build status text
    local iStatus= iCurStatus=
    while [[ "$#" -gt 0 ]] ; do
        [[ "$1" ]] && iCurStatus="$1"
        shift
        if [[ "$iCurStatus" ]] ; then
            if [[ "$1" ]] ; then
                # if this status has zero entries, skip it
                if [[ "$1" -eq 0 ]] ; then
                    shift
                    continue
                fi
                
                iCurStatus+=": $1"
            fi
            
            # add to status message
            [[ "$iStatus" ]] && iStatus+=', '
            iStatus+="$iCurStatus"
        fi
        shift
    done
    [[ "$iStatus" ]] && iStatus=" - $iStatus"
    
    # update time
    local iCurTime=
    try 'iCurTime=' /usr/bin/perl -MTime::HiRes=time -e 'printf "%d\n", time * 100' ''
    ok=1 ; errmsg=
    iCurTime="${iCurTime/./}"
    
    # decide whether to show this message (if forced, if status changes, or every .15 sec)
    if [[ "$iForce" || ( "$iStatus" != "$progressPrevStatus" ) || \
            ( $(( $iCurTime - $progressPrevTime )) -ge 15 ) ]] ; then
        echo "$iDetail$progressAction$iPercent$iStatus"
        
        # update status for next run
        progressPrevTime="$iCurTime"
        progressPrevStatus="$iStatus"
    fi
}


# PROGRESS: CALIBRATE progress bar
#  progress(aStepId)
# --- UNCOMMENT BELOW TO CALIBRATE --- $$$$$
progressCalibrateEndTime=
progressLastId=
progressDoCalibrate=1
progressIdList=()
function progress {

    # arguments
    local aStepId="${1/\!/}" ; shift  # ignore force flag

    # only calibrate once per ID
    [[ "$aStepId" = "$progressLastId" ]] && return
    if [[ "$aStepId" != 'end' ]] ; then
        progressLastId="$aStepId"
        progressIdList+=( $aStepId )
    fi

    # update times
    local curTime=$(/usr/bin/perl -MTime::HiRes=time -e 'printf "%d\n", time * 10000')
    [[ "$progressCalibrateEndTime" ]] || progressCalibrateEndTime="$curTime"

    # calculate the increment
    if [[ "$aStepId" != 'end' ]] ; then
        # output code to set this step's increment
        local iStepCode="# $aStepId=$(($curTime - $progressCalibrateEndTime))"
        echo "$iStepCode"
        errlog_raw "$iStepCode"
    else
        # last step, so output expression to calculate total
        local iEndCode="# progressTotal=\$(( \$$(join_array ' + $' "${progressIdList[@]}" ) ))"
        echo "$iEndCode"
        errlog_raw "$iEndCode"
    fi

    # update end time
    progressCalibrateEndTime="$curTime"
}
