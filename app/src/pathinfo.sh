#!/bin/bash
#
#  pathinfo.sh: Return information about a given Epichrome app path
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


# ABORT: return an error message
function abort {
    [ "$1" ] && echo "$1"
    exit "$2"
}

mode="$1"
shift

# appDir: directory where app will be created
# appBase: basename of app (without extension)
# the argument should always be a fully-qualified path
appDir= ; appBase=
if [[ "$1" =~ ^/((([^/]+/+)*[^/]+)/+)?([^/]+)/*$ ]] ; then
    # directory and base
    appDir="/${BASH_REMATCH[2]}"
    appBase="${BASH_REMATCH[4]}"
fi

if [ "$mode" = "app" ] ; then
    # remove any .app extension
    if [[ "$appBase" =~ (^.*[^.])\.[aA][pP]{2}$ ]] ; then
	appBase="${BASH_REMATCH[1]}"
	appExtAdded="FALSE"
    else
	appExtAdded="TRUE"
    fi
    
    # make sure we have an app path!
    [ ! \( "$appDir" -a "$appBase" \) ] && abort "Unable to determine app path." 1
    
    # appShortName: default short name for the menubar
    appShortName="${appBase}"
    [ "${#appShortName}" -ge 16 ] && appShortName="${appShortName//[^a-zA-Z0-9]/}" # too long - remove all non-alphanumerics
    [ "${#appShortName}" -ge 16 ] && appShortName="${appShortName//[aeiou]/}" # still too long - remove all lowercase vowels
    [ ! "${appShortName}" ] && appShortName="Epichrome App" # we removed everything!
    
    # truncate name if still too long
    [ "${#appShortName}" -ge 16 ] && appShortName="${appShortName::16}"
    
    # appName: add canonical .app extension to base name
    appName="${appBase}.app"
    
    # appPath: full path of app
    if [[ "$appDir" =~ /$ ]]; then
	appPath="${appDir}${appName}"
    else
	appPath="${appDir}/${appName}"
    fi
    
    # echo the five items on five lines
    echo "$appDir"
    echo "$appBase"
    echo "$appShortName"
    echo "$appName"
    echo "$appPath"
    echo "$appExtAdded"
else
    echo "$appDir"
    echo "$appBase"
fi

exit 0
