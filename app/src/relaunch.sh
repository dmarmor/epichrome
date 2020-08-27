#!/bin/bash
#
#  relaunch.sh: Relaunch an Epichrome app
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


# WAIT UNTIL PARENT APP HAS QUIT, THEN RELAUNCH

# set log ID
myLogID="${myLogID%|*}|Relaunch"

# array variables from parent app
importarray argsURIs argsOptions

# wait for parent to quit
debuglog "Waiting for parent app (PID $PPID) to quit..."
while kill -0 "$PPID" 2> /dev/null ; do
    pause 1
done

debuglog "Parent app has quit. Relaunching..."

# relaunch
argsOptions+=( '--epichrome-new-log' )
launchapp "$SSBAppPath" REGISTER 'updated app' myRelaunchPID argsOptions  # $$$ REGISTER?

# report result
if [[ "$ok" ]] ; then
    debuglog "Parent app relaunched successfully. Quitting."
else
    alert "$errmsg You may have to launch it manually." 'Warning' '|caution'
fi

# exit
cleanexit
