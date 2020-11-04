#!/bin/bash
#
#  mode_extcache.sh: mode script for creating a new extension cache
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


# PROGRESS BAR SETUP

# step calibration
stepStart=0

progressAction='Searching for installed extensions...'
progressTotal=10000


# --- MAIN BODY ---

# import search paths
importarray iSearchPaths

# start progress bar
progress 'stepStart'

# run in cache-only mode (no result var)
getextensioninfo '' "${iSearchPaths[@]}"

progress 'end'
