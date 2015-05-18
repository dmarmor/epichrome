#!/bin/sh
#
#  make-chrome-ssb.sh: Create a Chrome SSB application
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
#
# Based on the chrome-ssb.sh engine at https://github.com/lhl/chrome-ssb-osx
#
# Tested on Mac OS X 10.10.2 with Chrome version 41.0.2272.89 (64-bit)
# 

# initialize appTmp
appTmp=


# ABORT: exit cleanly on error

function abort {
    [ -d "$appTmp" ] && rm -rf "$appTmp" 2>&1 > /dev/null
    
    [ "$1" ] && echo "$1" 1>&2
    exit "$2"
}


# BOOTSTRAP RUNTIME SCRIPT

# determine location of runtime script
myPath=$(cd "$(dirname "$0")/../../.."; pwd)
[ $? != 0 ] && abort "Unable to determine MakeChromeSSB path." 1
[[ "$myPath" =~ \.[aA][aP][aP]$ ]] || abort "Unexpected MakeChromeSSB path." 1
myRuntimeScript="${myPath}/Contents/Runtime/Resources/Scripts/runtime.sh"

# load main runtime functions
source "$myRuntimeScript" > /dev/null 2>&1
[ $? != 0 ] && abort "Error loading runtime script." 1

# get important MCSSB info
mcssbinfo "$myPath"
[ $? != 0 ] && abort "$cmdtext" 1


# COMMAND LINE ARGUMENTS - ALL ARE REQUIRED

# path where the app should be created
appPath="$1"
shift

# long name (for the dock)
CFBundleDisplayName="$1"
shift

# short app name (for the menu bar)
CFBundleName="$1"
shift

# icon file
iconSource="$1"
shift

# register as browser ("Yes" or "No")
SSBRegisterBrowser="$1"
[ "$SSBRegisterBrowser" != "Yes" ] && SSBRegisterBrowser="No"
shift

# the rest is the command line maybe --app + URLs
SSBCommandLine=("${@}")


# CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

# create the app directory in a temporary location
appTmp=$(tempname "$appPath")
cmdtext=$(/bin/mkdir -p "$appTmp" 2>&1)
[ $? != 0 ] && abort "Unable to create app bundle." 1

# GET INFO NECESSARY TO RUN THE UPDATE

# get application bundle paths
apppaths "$appTmp"
[ $? != 0 ] && abort "$cmdtext" 1

# get info about Google Chrome
chromeinfo
[ $? != 0 ] && abort "$cmdtext" 1


# PREPARE CUSTOM ICON IF WE'RE USING ONE

customIconTmp=

if [ "$iconSource" ] ; then    
    [ -e "$mcssbMakeIconScript" ] || abort "Unable to locate makeicon.sh." 1
    
    customIconTmp=$(tempname "${appTmp}/${customIconName}" ".icns")
    
    cmdtext=$("$mcssbMakeIconScript" -f "$iconSource" "$customIconTmp" 2>&1)
    result="$?"
    if [ "$result" = 3 ] ; then
	# file was already an ICNS, so copy it in
	cmdtext=$(/bin/cp -p "$iconSource" "$customIconTmp" 2>&1)
	[ $? != 0 ] && abort "Unable to copy icon file into app." 1
    elif [ "$result" != 0 ] ; then
	# failed
	cmdtext="${cmdtext#Error: }"
	cmdtext="${cmdtext%.}"
	abort "Unable to create icon (${cmdtext})." 1
    fi
fi


# CALL UPDATE FUNCTION TO POPULATE THE APP BUNDLE

"${mcssbUpdateScript}"






# MOVE NEW APP TO PERMANENT LOCATION (OVERWRITING ANY OLD APP)

permanent "$appTmp" "$appPath" "app bundle"
[ $? != 0 ] && abort "$cmdtext" 1

exit 0
