#!/bin/bash
#
#  legaciy.sh: functions for updating old (pre-2.3) apps
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


# UPDATECOREINFO: update core info to conform to current variable naming
function updateoldcoreinfo {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # try to pull out SSBIdentifier from CFBundleIdentifier
    SSBIdentifier="${CFBundleIdentifier#org.epichrome.app.}"
    if [[ "$SSBIdentifier" = "$CFBundleIdentifier" ]] ; then
        ok= ; errmsg="Unable to determine app ID. This app may be too old to update."
        return 1
    fi
    
    # create engine type variable
    SSBEngineType="external|${appBrowserInfo_com_google_Chrome[0]}"
}


# UPDATEOLDDATADIR: update a 2.2.4 or earlier data directory to post-2.3.0
function updateolddatadir {  # ( [locDataPath locProfilePath] )
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local locDataPath="$1" ; shift ; [[ "$locDataPath" ]] || locDataPath="$myDataPath"
    local locProfilePath="$1" ; shift ; [[ "$locProfilePath" ]] || locProfilePath="$myProfilePath"
    
    if [[ ( -d "$locDataPath" ) && ! -d "$locProfilePath" ]] ; then
        
        # UPDATE OLD-STYLE PROFILE DIRECTORY
        
        debuglog 'Updating pre-2.3.0 data directory structure to current structure.'
        
        # remove old NativeMessagingHosts directory
        saferm 'Unable to remove old native messaging hosts directory.' \
                "$locDataPath/$nmhDirName"
        
        # create profile directory
        try /bin/mkdir -p "$locProfilePath" 'Unable to create profile directory.'
        
        # move to data directory
        try '!1' pushd "$locDataPath" 'Unable to move to data directory.'
        
        if [[ "$ok" ]] ; then
            
            # turn on extended glob
            local shoptState=
            shoptset shoptState extglob
            
            # find all except new log & profile directories
            local allExcept="!($appDataProfileDir|$epiDataLogDir|$appDataStdoutFile|$appDataStderrFile|$appDataPauseFifo|$appDataBackupDir|$appDataWelcomeDir)"
            
            # move everything into profile directory
            try /bin/mv $allExcept "$locProfilePath" \
                    'Unable to migrate to new profile directory.'
            
            # restore extended glob
            shoptrestore shoptState
            
            # leave data directory no matter what
            if [[ "$ok" ]] ; then
                
                # nonfatal if this doesn't work
                try '!1' popd 'Unable to restore working directory.'
                ok=1 ; errmsg=
            else
                
                # try to leave even on error
                tryalways '!1' popd 'Unable to restore working directory.'
            fi
        fi        
    fi
    
    [[ "$ok" ]] && return 0 || return 1
}
