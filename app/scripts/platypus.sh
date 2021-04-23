#!/bin/bash
#
#  platypus.sh: invoke platypus from the module in Epichrome
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


function abort {
    echo "$@" 1>&2
    exit 1
}


# status variables
statusOurShareLinked=

# set SIGEXIT handler
function handleexitsignal {
    
    # remove link to our library
    if [[ "$statusOurShareLinked" ]] ; then
        /bin/rm -f "$platypusShare" || echo 'Unable to remove link to Epichrome Platypus library.' 1>&2
    fi
    
    # attempt to reactivate any turned-off installed share library
    if [[ -e "$platypusShareOff" ]] ; then
        /bin/mv -f "$platypusShareOff" "$platypusShare" || echo 'Unable to reactivate installed Platypus library.' 1>&2
    fi
}
trap handleexitsignal EXIT


# path to installed platypus library
platypusShare='/usr/local/share/platypus'
platypusShareOff="$platypusShare.INSTALLED"

# get absolute paths
myPath="${BASH_SOURCE[0]%/*}"
if [[ "$myPath" = "${BASH_SOURCE[0]}" ]] ; then
    myPath="$(pwd)"
elif [[ "$myPath" ]] ; then
    myPath="$(cd "$myPath" ; pwd)"
fi
platypusPath="$myPath/../build/platypus"

# paths to our items
platypusExec="$platypusPath/platypus"
platypusLib="$platypusPath/library"

# make sure our platypus is properly installed
[[ -x "$platypusExec" && -d "$platypusLib" ]] || abort 'Epichrome Platypus not yet built.'

# make sure the installed library isn't already deactivated
[[ -e "$platypusShareOff" ]] && abort 'Unable to run! Installed Platypus library is already deactivated.'

# deactivate any installed share library
if [[ -e "$platypusShare" ]] ; then
    /bin/mv -f "$platypusShare" "$platypusShareOff" || abort 'Unable to deactivate installed Platypus library.'
    statusInstalledShareOff=1
fi

# link to our library
/bin/ln -s "$platypusLib" "$platypusShare" || abort 'Unable to activate Epichrome Platypus library.'
statusOurShareLinked=1

# run our platypus
"$platypusExec" "$@" || abort 'Platypus returned an error!'

# if we got here, all went smoothly
exit 0
