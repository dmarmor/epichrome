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

# deactivate any installed library
if [[ -e "$platypusShare" ]] ; then
    /bin/mv -f "$platypusShare" "$platypusShareOff" || abort 'Unable to deactivate installed Platypus library.'
fi

# link to our library
if ! /bin/ln -s "$platypusLib" "$platypusShare" ; then
    # failed -- attempt to reactivate installed libary
    errmsg=
    if [[ -e "$platypusShareOff" ]] ; then
        /bin/mv -f "$platypusShareOff" "$platypusShare" || errmsg=' Also unable to reactivate installed library.'
    fi
    abort "Unable to activate Epichrome Platypus library.$errmsg"
fi

# run our platypus
errmsg=
"$platypusExec" "$@" || errmsg='Platypus returned an error!'

# remove link to our library
if ! /bin/rm -f "$platypusShare" ; then
    [[ "$errmsg" ]] && errmsg+=' Also unable' || errmsg='Unable'
    abort "$errmsg to remove link to Epichrome Platypus library."
fi

# reactivate installed library
if [[ -e "$platypusShareOff" ]] ; then
    if ! /bin/mv -f "$platypusShareOff" "$platypusShare" ; then
        [[ "$errmsg" ]] && errmsg+=' Also unable' || errmsg='Unable'
        abort "$errmsg to reactivate installed Platypus library."
    fi
fi

# handle platypus error
[[ "$errmsg" ]] && abort $errmsg

# if we got here, all went smoothly
exit 0
