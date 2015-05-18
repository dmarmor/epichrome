#/bin/sh
#
#  update.sh: update a Chrome SSB
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
# Inspired by the chrome-ssb.sh engine at https://github.com/lhl/chrome-ssb-osx
#


# $$$ HTIS IS FUCKED BECAUSE MY APPRESOURCESDIR DOESN'T POINT AT THE TEMP CONTENTS DIR....FIX APPPATHS???

contentsTmp=$(tempname "$appContentsDir")
resourcesTmp="${contentsTmp}/Resources"

# copy in the boilerplate for the app
cmdtext=$(/bin/cp -a "$myRuntimeDir" "$contentsTmp" 2>&1)
[ $? != 0 ] && abort "Unable to populate app bundle." 1

# place custom icon, if any
if [ -f "$customIconTmp" ] ; then
    # we're using a custom icon - update Info.plist info
    genericIcon="${resourcesTmp}/$CFBundleIconFile"
    CFBundleIconFile="customIconName"
    
    permanent "$customIconTmp" "${appResourcesDir}/${CFBundleIconFile}" "custom icon"
    [ $? != 0 ] && abort "$cmdtext" 1
    
    # remove generic icon
    cmdtext=$(/bin/rm -f "$genericIcon" 2>&1)
    [ $? != 0 ] && abort "Unable to remove default icon file." 1
fi




# LINK TO GOOGLE CHROME

linkchrome
[ $? != 0 ] && abort "$cmdtext" 1


# WRITE OUT NEW INFO.PLIST FILE

writeplist
[ $? != 0 ] && abort "$cmdtext" 1


# COPY CHROME RESOURCES DIRECTORY & MODIFY LOCALIZED STRINGS

#copychromeresources
#[ $? != 0 ] && abort "$cmdtext" 1


# $$$$ THIS SHOULD COME STRAIGHT FROM ABOVE
# COPY SCRIPTING.SDEF

copyscriptingsdef
[ $? != 0 ] && abort "$cmdtext" 1


# WRITE OUT CONFIG FILE

# set up output versions of config variables
SSBVersion="$mcssbVersion"
SSBChromePath="$chromePath"    
SSBChromeVersion="$chromeVersion"

writeconfig
[ $? != 0 ] && abort "$cmdtext" 1

# $$$$ PERMANENT CONTENTSDIR
