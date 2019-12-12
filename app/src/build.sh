#!/bin/sh
#
#  build.sh: Create an Epichrome application
#  Copyright (C) 2020  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
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


# BUILD FLAGS (CAN BE OVERRIDDEN BY RUNTIME.SH)

debug=
logPreserve=


# ABORT -- exit cleanly on error
function abort { # [myErrMsg code]

    # clean up any temp app bundle we've been working on
    [[ -d "$appTmp" ]] && rmtemp "$appTmp" 'temporary app bundle'
    
    # arguments
    local myErrMsg="$1" ; shift ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    local myCode="$1"   ; shift ; [[ "$myCode"   ]] || myCode=1
    
    # log error message
    local myAbortLog="Aborting: $myErrMsg"
    if [[ "$( type -t errlog )" = function ]] ; then
	errlog "$myAbortLog"
    else
	# send abort message to log
	[[ -w "$logPath" ]] && echo "$myAbortLog" >> "$logPath"

    fi
    
    # send only passed error message to stderr (goes back to main.applescript)
    echo "$myErrMsg" 1>&2
    
    exit "$myCode"
}


# HANDLE KILL SIGNALS

trap "abort 'Unexpected termination.' 2" SIGHUP SIGINT SIGTERM


# BOOTSTRAP UPDATE SCRIPT

# set logging parameters so all stderr output goes to log only
logNoStderr=1

source "${0%/*}/update.sh"
[[ "$?" != 0 ]] && abort 'Unable to load update script.'
[[ "$ok" ]] || abort


# COMMAND LINE ARGUMENTS - ALL ARE REQUIRED IN THIS EXACT ORDER

# path where the app should be created
appPath="$1"
shift

# long name (for the dock)
CFBundleDisplayName="$1"
shift

# short app name for the menu bar (and app identifier)
CFBundleName="$1"
shift

# icon file
iconSource="$1"
shift
if [[ "$iconSource" ]] ; then
    SSBCustomIcon="Yes"
else
    SSBCustomIcon="No"
fi

# register as browser ("Yes" or "No")
SSBRegisterBrowser="$1"
[[ "$SSBRegisterBrowser" != "Yes" ]] && SSBRegisterBrowser="No"
shift

# specify app engine
if [[ "$1" = "No" ]] ; then
    SSBEngineType="Google Chrome"
else
    SSBEngineType="Chromium"
fi
shift

# profile path may eventually come here as a command-line argument

# the rest is the command line maybe --app + URLs
SSBCommandLine=("${@}")


# GET INFO ON THIS INSTANCE OF EPICHROME


# CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

# create the app directory in a temporary location
appTmp=$(tempname "$appPath")
cmdtext=$(/bin/mkdir -p "$appTmp" 2>&1)
if [[ "$?" != 0 ]] ; then
    # if we don't have permission, let the app know to try for admin privileges
    errRe='Permission denied$'
    [[ "$cmdtext" =~ $errRe ]] && abort 'PERMISSION' 2

    # regular error
    abort 'Unable to create temporary app bundle.' 1
fi

# set ownership of app bundle to this user (only necessary if running as admin)
try /usr/sbin/chown -R "$USER" "$appTmp" 'Unable to set ownership of app bundle.'


# GET INFO NECESSARY TO RUN THE UPDATE

if [[ "$SSBEngineType" = "Google Chrome" ]] ; then
    # get info about Google Chrome
    googlechromeinfo
fi


# PREPARE CUSTOM ICON IF WE'RE USING ONE

customIconDir=

if [[ "$iconSource" ]] ; then

    # get name for temporary icon directory
    customIconDir=$(tempname "${appTmp}/icons")
    try /bin/mkdir -p "$customIconDir" 'Unable to create temporary icon directory.'
    [[ "$ok" ]] || abort "$errmsg"
    
    # convert image into an ICNS
    makeappicons "$myPath" "$iconSource" "$customIconDir" both
    
    # handle results
    if [[ ! "$ok" ]] ; then
	[[ "$errmsg" ]] && errmsg=" ($errmsg)"
	abort "Unable to create icon${errmsg}."
    fi
fi


# POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

# mark this as the first ever run
SSBFirstRun=1

# populate the app bundle
updateapp "$appTmp" "$customIconDir"

[[ "$ok" ]] || abort "$errmsg"

# delete any temporary custom icon directory (fail silently, as any error here is non-fatal)
[[ -e "$customIconDir" ]] && /bin/rm -rf "$customIconDir" > /dev/null 2>&1

# move new app to permanent location (overwriting any old app)
permanent "$appTmp" "$appPath" "app bundle"

[[ "$ok" ]] || abort "$errmsg"

exit 0
