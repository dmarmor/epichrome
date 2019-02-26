#!/usr/bin/python
#
#  update.py: parse a JSON file for the latest Epichrome release on GitHub
#  Copyright (C) 2019  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
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



import urllib, json, sys, re

err = None

# any errors will be passed to our exception handler
try:

    # # get current version number
    # if len(sys.argv) < 2:
    #     raise Exception('Current version number not provided')
    # else:
    #     curversion = sys.argv[1]
    
    # read and parse JSON data
    try:
        url = urllib.urlopen("https://api.github.com/repos/dmarmor/epichrome/releases/latest")
    except IOError:
        raise Exception("Unable to connect to update URL (" + sys.exc_info()[1][0] + " - " + sys.exc_info()[1][1][1] + ")")
        
    try:
        obj = json.load(url)
    except: # ValueError, ???
        raise Exception("Unable to load version info (" + str(sys.exc_info()[1]) + ")")
    
    # check if JSON data has version tag
    if "message" in obj:
        raise Exception("Bad response (" + obj["message"] + ")")
    elif "tag_name" not in obj:
        raise Exception("Unable to parse response")
    
    # try to parse the version number
    m = re.search(r'((?:[0-9]+\.)+[0-9]+)', obj["tag_name"])
    if m is None:
        raise Exception('Unable to parse version number')
    latestversion = m.group(1)

    # $$$ compare version numbers
    
    
except Exception as err:
    # print error message and exit
    print "Error checking for Epichrome updates: %s." % err.args[0]
    exit(1)

# if we got here, it was successful
print latestversion
exit(0)
