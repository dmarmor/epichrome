#!/bin/sh
#
#  build.sh: Create an Epichrome application
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

# FLAG A CLEAN EXIT

doCleanExit=


# CLEANUP -- clean up any half-made app
function cleanup {
    
    # report premature termination
    if [[ ! "$doCleanExit" ]] ; then
	echo "$myLogID: Unexpected termination." >> "$myLogFile"
	echo 'Unexpected termination.' 1>&2
    fi
    
    # clean up any temp app bundle we've been working on
    if [[ -d "$appTmp" ]] ; then

	# try to remove temp app bundle
	if [[ "$(type -t rmtemp)" = function ]] ; then
	    rmtemp "$appTmp" 'temporary app bundle'
	else
	    if ! /bin/rm -rf "$appTmp" 2> /dev/null ; then
		echo "$myLogID: Unable to remove temporary app bundle." >> "$myLogFile"
		echo 'Unable to remove temporary app bundle.' 1>&2
	    fi
	fi
    fi
}


# MYABORT -- exit cleanly on error
function myabort { # [myErrMsg code]
    
    # get error message
    local myErrMsg="$1" ; [[ "$myErrMsg" ]] || myErrMsg="$errmsg"
    
    # send only passed error message to stderr (goes back to main.applescript)
    echo "$myErrMsg" 1>&2

    doCleanExit=1
    
    abortsilent "$@"
}


# HANDLE EXIT SIGNAL

trap cleanup EXIT


# GET PATH TO MY PARENT EPICHROME RESOURCES

myResourcesPath="${BASH_SOURCE[0]%/Scripts/build.sh}"


# LOAD SCRIPTS

source "$myResourcesPath/Runtime/Contents/Resources/Scripts/core.sh" PRESERVELOG || exit 1
myLogID="$myLogID|${BASH_SOURCE[0]##*/}"
[[ "$ok" ]] || myabort

safesource "$myResourcesPath/Scripts/update.sh" || myabort


# COMMAND LINE ARGUMENTS - ALL ARE REQUIRED IN THIS EXACT ORDER

# path where the app should be created
myAppPath="$1"
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
SSBEngineType="$1"
shift
if [[ "${SSBEngineType%|*}" = internal ]] ; then
    SSBEngineSourceInfo=( "${epiEngineSource[@]}" )  # $$$ FIX THIS TO CHOOSE RIGHT SOURCEINFO
    #readonly SSBEngineType SSBEngineSourceInfo
fi

# the rest is the command line maybe --app + URLs
SSBCommandLine=("${@}")


# CREATE THE APP BUNDLE IN A TEMPORARY LOCATION

# create the app directory in a temporary location
appTmp=$(tempname "$myAppPath")
cmdtext=$(/bin/mkdir -p "$appTmp" 2>&1)
if [[ "$?" != 0 ]] ; then
    # if we don't have permission, let the app know to try for admin privileges
    errRe='Permission denied$'
    [[ "$cmdtext" =~ $errRe ]] && myabort 'PERMISSION' 2

    # regular error
    myabort 'Unable to create temporary app bundle.' 1
fi

# set ownership of app bundle to this user (only necessary if running as admin)
try /usr/sbin/chown -R "$USER" "$appTmp" 'Unable to set ownership of app bundle.'
[[ "$ok" ]] || myabort


# PREPARE CUSTOM ICON IF WE'RE USING ONE

if [[ "$iconSource" ]] ; then
    
    # get name for temporary icon directory
    customIconDir="$appTmp/Contents/Resources"
    try /bin/mkdir -p "$customIconDir" 'Unable to create app Resources directory.'
    [[ "$ok" ]] || myabort
    
    # find makeicon.sh
    makeIconScript="$myResourcesPath/Scripts/makeicon.sh"
    [[ -e "$makeIconScript" ]] || myabort "Unable to locate icon creation script."
    [[ -x "$makeIconScript" ]] || myabort "Unable to run icon creation script."
    
    # build command-line
    docArgs=(-c "$myResourcesPath/docbg.png" \
		256 286 512 "$iconSource" "$customIconDir/$CFBundleTypeIconFile")
    
    # run script to convert image into an ICNS
    makeIconErr=
    try 'makeIconErr&=' "$makeIconScript" -f -o "$customIconDir/$CFBundleIconFile" "${docArgs[@]}" ''
    
    # handle errors
    if [[ ! "$ok" ]] ; then
	errmsg="${makeIconErr#*Error: }"
	errmsg="${errmsg%.*}"
	[[ "$errmsg" ]] && errmsg=" ($errmsg)"
	myabort "Unable to create icon${errmsg}."
    fi
fi


# POPULATE THE ACTUAL APP AND MOVE TO ITS PERMANENT HOME

# populate the app bundle
updateapp "$appTmp"
[[ "$ok" ]] || myabort

# move new app to permanent location (overwriting any old app)
permanent "$appTmp" "$myAppPath" "app bundle"
[[ "$ok" ]] || myabort

doCleanExit=1
exit 0
