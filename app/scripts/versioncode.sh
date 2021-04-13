#!/bin/bash
#
#  versioncode.sh: create a numeric version code from an Epichrome version
#
#  Copyright (C) 2021  David Marmor
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


# <maj><02-min><03-bug>.<03-beta|100>.<build|10000>

if ! source src/core.sh 2> /dev/null ; then
    echo '*** Unable to load src/core.sh' 1>&2
    exit 1
fi
logNoStderr=1

# VCODE -- echo numeric code for given version (current if none given)
#   vcode([aVersion aBuildNum])
function vcode {
    
    # argument
    local aVersion="$1" ; shift ; [[ "$aVersion" ]] || aVersion="$coreVersion"
    local aBuildNum="$1" ; shift
    
    if [[ "$aVersion" =~ ^$epiVersionRe$ ]] ; then
        local iBeta="${BASH_REMATCH[5]}" ; [[ "$iBeta" ]] || iBeta='100'
        if [[ ! "$aBuildNum" ]] ; then
            aBuildNum="${BASH_REMATCH[7]}" ; [[ "$aBuildNum" ]] || aBuildNum='10000'
        fi
        printf '%d.%d.%d\n' \
                $(( (${BASH_REMATCH[1]} * 100000) + (${BASH_REMATCH[2]} * 1000) + ${BASH_REMATCH[3]} )) \
                $iBeta $aBuildNum
    else
        return 1
    fi
}

if ! vcode "$1" ; then
    echo "FAIL"
fi

cleanexit
