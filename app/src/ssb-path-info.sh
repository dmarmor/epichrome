#!/bin/sh
#
#  ssb-path-info.sh: Return information about a given SSB path
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


# ABORT: return an error message
function abort {
    [ "$1" ] && echo "$1"
    exit "$2"
}

mode="$1"
shift

# ssbDir: directory where SSB will be created
# ssbBase: basename of SSB (without extension)
# the argument should always be a fully-qualified path
ssbDir= ; ssbBase=
if [[ "$1" =~ ^/((([^/]+/+)*[^/]+)/+)?([^/]+)/*$ ]] ; then
    # directory and base
    ssbDir="/${BASH_REMATCH[2]}"
    ssbBase="${BASH_REMATCH[4]}"
fi

if [ "$mode" = "app" ] ; then
    # remove any .app extension
    if [[ "$ssbBase" =~ (^.*[^.])\.[aA][pP]{2}$ ]] ; then
	ssbBase="${BASH_REMATCH[1]}"
	ssbExtAdded="FALSE"
    else
	ssbExtAdded="TRUE"
    fi
    
    # make sure we have an app path!
    [ ! \( "$ssbDir" -a "$ssbBase" \) ] && abort "Unable to determine app path." 1
    
    # ssbShortName: default short name for the menubar
    ssbShortName="${ssbBase}"
    [ "${#ssbShortName}" -ge 16 ] && ssbShortName="${ssbShortName//[^a-zA-Z0-9]/}" # too long - remove all non-alphanumerics
    [ "${#ssbShortName}" -ge 16 ] && ssbShortName="${ssbShortName//[aeiou]/}" # still too long - remove all lowercase vowels
    [ ! "${ssbShortName}" ] && ssbShortName="Chrome SSB" # we removed everything!
    
    # truncate name if still too long
    [ "${#ssbShortName}" -ge 16 ] && ssbShortName="${ssbShortName::16}"
    
    # ssbName: add canonical .app extension to base name
    ssbName="${ssbBase}.app"
    
    # ssbPath: full path of SSB
    if [[ "$ssbDir" =~ /$ ]]; then
	ssbPath="${ssbDir}${ssbName}"
    else
	ssbPath="${ssbDir}/${ssbName}"
    fi
    
    # echo the five items on five lines
    echo "$ssbDir"
    echo "$ssbBase"
    echo "$ssbShortName"
    echo "$ssbName"
    echo "$ssbPath"
    echo "$ssbExtAdded"
else
    echo "$ssbDir"
    echo "$ssbBase"
fi

exit 0
