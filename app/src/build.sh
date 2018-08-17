#!/bin/sh
#
#  build.sh: Create an Epichrome application
#  Copyright (C) 2018  David Marmor
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


# ABORT -- exit cleanly on error

function abort {
    [[ -d "$appTmp" ]] && rmtemp "$appTmp" 'temporary app bundle'
    
    [[ "$1" ]] && echo "$1" 1>&2
    
    local result="$2" ; [ "$result" ] || result=1
    exit "$result"
}


# HANDLE KILL SIGNALS

trap "abort 'Unexpected termination.' 2" SIGHUP SIGINT SIGTERM


# BOOTSTRAP RUNTIME SCRIPT

# determine location of runtime script
myPath=$(cd "$(dirname "$0")/../../.."; pwd)
[ $? != 0 ] && abort 'Unable to determine Epichrome path.' 1
[[ "$myPath" =~ \.[aA][pP][pP]$ ]] || abort "Unexpected Epichrome path: $myPath." 1

# load main runtime functions
source "${myPath}/Contents/Resources/Runtime/Resources/Scripts/runtime.sh"
[[ "$?" != 0 ]] && abort 'Unable to load runtime script.' 1

# get important MCSSB info
mcssbinfo "$myPath"


# COMMAND LINE ARGUMENTS - ALL ARE REQUIRED

# path where the app should be created
appPath="$1"
shift

# long name (for the dock, and name for Chrome engine)
CFBundleDisplayName="$1"
shift

# short app name for the menu bar (and app identifier)
CFBundleName="$1"
shift

# icon file
iconSource="$1"
shift
if [ "$iconSource" ] ; then
    SSBCustomIcon="Yes"
else
    SSBCustomIcon="No"
fi

# register as browser ("Yes" or "No")
SSBRegisterBrowser="$1"
[ "$SSBRegisterBrowser" != "Yes" ] && SSBRegisterBrowser="No"
shift

# profile path may eventually come here as a command-line argument

# the rest is the command line maybe --app + URLs
SSBCommandLine=("${@}")

# determine path to Chrome engine
updatechromeenginepath "$appPath"


# CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

# create the app directory in a temporary location
appTmp=$(tempname "$appPath")
cmdtext=$(/bin/mkdir -p "$appTmp" 2>&1)
if [[ "$?" != 0 ]] ; then
    # if we don't have permission, let the app know to try for admin privileges
    errre='Permission denied$'
    [[ "$cmdtext" =~ $errre ]] && abort 'PERMISSION' 2
    
    # regular error
    abort 'Unable to create temporary app bundle.' 1
fi

# set ownership of app bundle to this user (only necessary if running as admin)
try /usr/sbin/chown -R "$USER" "$appTmp" 'Unable to set ownership of app bundle.'

#abort "The user is $USER" 1

# GET INFO NECESSARY TO RUN THE UPDATE

# get info about Google Chrome
chromeinfo


# PREPARE CUSTOM ICON IF WE'RE USING ONE

customIconDir=

if [[ "$iconSource" ]] ; then
    
    # get name for temporary icon directory
    customIconDir=$(tempname "${appTmp}/icons")
    try /bin/mkdir -p "$customIconDir" 'Unable to create temporary icon directory.'
    [[ "$?" != 0 ]] && abort "$errmsg" 1
    
    # convert image into an ICNS
    mcssbmakeicons "$iconSource" "$customIconDir" both
    
    # handle results
    if [[ ! "$ok" ]] ; then
	[[ "$errmsg" ]] && errmsg=" ($errmsg)"
	abort "Unable to create icon${errmsg}." 1
    fi
fi


# POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

# populate the Contents directory
updatessb "$appTmp" "$customIconDir" '' newApp

if [[ "$ok" ]] ; then
    # delete any temporary custom icon directory (fail silently, as any error here is non-fatal)
    [[ -e "$customIconDir" ]] && /bin/rm -rf "$customIconDir" > /dev/null 2>&1
    
    # move new app to permanent location (overwriting any old app)
    permanent "$appTmp" "$appPath" "app bundle"
fi

[[ "$ok" ]] || abort "$errmsg" 1

exit 0
