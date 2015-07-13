#!/bin/sh
#
#  build.sh: Create an Epichrome application
#
#  Copyright (C) 2015 David Marmor
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

# long name (for the dock)
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


# CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

# create the app directory in a temporary location
appTmp=$(tempname "$appPath")
try /bin/mkdir -p "$appTmp" 'Unable to create temporary app bundle.'


# GET INFO NECESSARY TO RUN THE UPDATE

# get info about Google Chrome
chromeinfo


# PREPARE CUSTOM ICON IF WE'RE USING ONE

customIconTmp=

if [ "$iconSource" ] ; then    
    # find makeicon.sh
    makeIconScript="${mcssbPath}/Contents/Resources/Scripts/makeicon.sh"
    [ -e "$makeIconScript" ] || abort "Unable to locate makeicon.sh." 1
    
    # get temporary name for icon file
    customIconTmp=$(tempname "${appTmp}/${customIconName}" ".icns")
    
    # convert image into an ICNS
    try 'makeiconerr=' "$makeIconScript" -f "$iconSource" "$customIconTmp" ''
    result="$?"
    
    # handle results
    if [[ "$result" = 3 ]] ; then
	# not really an error, so clear error state
	ok=1
	
	# file was already an ICNS, so copy it in
	try /bin/cp -p "$iconSource" "$customIconTmp" 'Unable to copy icon file into app.'
    elif [[ "$result" != 0 ]] ; then
	# really an error, set errmsg
	errmsg="${makeiconerr#Error: }"
	errmsg="${errmsg%.}"
	abort "Unable to create icon (${errmsg})." 1
    fi
fi


# POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

# populate the Contents directory
updatessb "$appTmp" "$customIconTmp"

if [[ "$ok" ]] ; then
    # delete any temporary custom icon (fail silently, as any error here is non-fatal)
    [[ -e "$customIconTmp" ]] && /bin/rm -f "$customIconTmp" > /dev/null 2>&1
    
    # move new app to permanent location (overwriting any old app)
    permanent "$appTmp" "$appPath" "app bundle"
fi

[[ "$ok" ]] || abort "$errmsg" 1

exit 0
