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


# SAFESOURCE -- safely source a script (version 1.0)
function safesource {
    if [ "$2" ] ; then
	fileinfo="$2"
    else
	fileinfo="$1"
	[[ "$fileinfo" =~ /([^/]+)$ ]] && fileinfo="${BASH_REMATCH[1]}"
    fi
    
    if [ -e "$1" ] ; then
	source "$1" > /dev/null 2>&1
	if [ $? != 0 ] ; then
	    cmdtext="Unable to load $fileinfo."
	    return 1
	fi
    else
	cmdtext="Unable to find $fileinfo."
	return 1
    fi

    return 0
}


# ABORT -- exit cleanly on error

function abort {
    [ -d "$appTmp" ] && rm -rf "$appTmp" 2>&1 > /dev/null
    
    [ "$1" ] && echo "$1" 1>&2
    
    local result="$2" ; [ "$result" ] || result=1
    exit "$result"
}


# HANDLE KILL SIGNALS

trap "abort 'Unexpected termination.' 2" SIGHUP SIGINT SIGTERM


# BOOTSTRAP RUNTIME SCRIPT

# determine location of runtime script
myPath=$(cd "$(dirname "$0")/../../.."; pwd)
[ $? != 0 ] && abort "Unable to determine MakeChromeSSB path." 1
[[ "$myPath" =~ \.[aA][pP][pP]$ ]] || abort "Unexpected MakeChromeSSB path: $myPath." 1

# load main runtime functions
safesource "${myPath}/Contents/Resources/Runtime/Resources/Scripts/runtime.sh" "runtime script"
[ $? != 0 ] && abort "$cmdtext" 1

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
if [ "$iconSource" ] ; then
    SSBCustomIcon="Yes"
else
    SSBCustomIcon="No"
fi

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

# get info about Google Chrome
chromeinfo
[ $? != 0 ] && abort "$cmdtext" 1


# PREPARE CUSTOM ICON IF WE'RE USING ONE

customIconTmp=

if [ "$iconSource" ] ; then    
    # find makeicon.sh
    makeIconScript="${mcssbPath}/Contents/Resources/Scripts/makeicon.sh"
    [ -e "$makeIconScript" ] || abort "Unable to locate makeicon.sh." 1

    # get temporary name for icon file
    customIconTmp=$(tempname "${appTmp}/${customIconName}" ".icns")

    # convert image into an ICNS
    cmdtext=$("$makeIconScript" -f "$iconSource" "$customIconTmp" 2>&1)
    result="$?"

    # handle results
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


# POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

# populate the Contents directory
updatessb "$appTmp" "$customIconTmp"
[ $? != 0 ] && abort "$cmdtext" 1

# delete any temporary custom icon (fail silently, as it's no big deal if the temp file remains)
[ -e "$customIconTmp" ] && /bin/rm "$customIconTmp" > /dev/null 2>&1


# move new app to permanent location (overwriting any old app)
permanent "$appTmp" "$appPath" "app bundle"
[ $? != 0 ] && abort "$cmdtext" 1

exit 0
