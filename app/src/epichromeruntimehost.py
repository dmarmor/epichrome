#!/usr/bin/python
# -*- coding: utf-8 -*-
#
#  org.epichrome.runtime-host.py: native messaging host for Epichrome Runtime
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

import struct
import sys
import json
import webbrowser
import subprocess
import os
import platform

# BUILD FLAGS

debug = False


# info specific to this host (filled in on install)
appVersion     = 'EPIVERSION'      # filled in by Makefile
appBundleID    = 'APPBUNDLEID'     # filled in by Epichrome
appDisplayName = 'APPDISPLAYNAME'  # filled in by Epichrome
appBundleName  = 'APPBUNDLENAME'   # filled in by Epichrome
appLogPath     = 'APPLOGPATH'      # filled in by Epichrome

# special mode for communicating version to parent app
if (len(sys.argv) > 1) and (sys.argv[1] == '-v'):
    print appVersion
    exit(0)


# SEND_MESSAGE -- send a message to a Chrome extension
def send_message(message):
    
    # send the message's size
    sys.stdout.write(struct.pack('I', len(message)))
    
    # send the message itself
    sys.stdout.write(message)
    sys.stdout.flush()


# SEND_RESULT -- send a result message
def send_result(result, url):
    send_message('{"result": "%s", "url": "%s" }' % (result, url))


# RECEIVE_MESSAGE -- receive and unpack a message
def receive_message():
    
    # read the message length (first 4 bytes)
    text_length_bytes = sys.stdin.read(4)

    # read returned nothing -- the pipe is closed
    if len(text_length_bytes) == 0:
        return False
    
    # unpack message length as 4-byte integer
    text_length = struct.unpack('i', text_length_bytes)[0]
    
    # read and parse the text into a JSON object
    return json.loads(sys.stdin.read(text_length).decode('utf-8'))


# SPECIAL CASE -- if default browser is Chrome we need to specify that when opening links

# assume Chrome isn't default
defaultIsChrome = False

# get launch services plist
launchsvc = os.path.expanduser('~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist')

# if it exists, parse it
if os.path.isfile(launchsvc):

    import plistlib
    
    try:
        # parse LaunchServices plist
        plistData = plistlib.readPlistFromString(subprocess.check_output(['/usr/bin/plutil',
                                                                              '-convert',
                                                                              'xml1',
                                                                              '-o',
                                                                              '-', launchsvc]))

        # find handler for http scheme
        httpHandler = None
        for handler in plistData['LSHandlers']:
            if (handler.has_key('LSHandlerURLScheme') and
                (handler['LSHandlerURLScheme'] == 'http')):
                httpHandler = handler['LSHandlerRoleAll']
                break

        # if it's Chrome, set a flag
        if httpHandler.lower() == 'com.google.chrome':
            defaultIsChrome = True
            
    except: # subprocess.CalledProcessError + plistlib err
        pass

    
# MAIN LOOP -- just keep on receiving messages until stdin closes
while True:
    message = receive_message()

    if not message:
        break

    if 'version' in message:
        send_message(('{ "version": "%s", '+
                     '"ssbID": "%s", '+
                     '"ssbName": "%s", '+
                     '"ssbShortName": "%s" }') % (appVersion, appBundleID, appDisplayName, appBundleName))
    
    if 'url' in message:
        # open the url

        try:
            # work around identifier confusion between Epichrome apps and Chrome
            if defaultIsChrome:
                subprocess.check_call(['/usr/bin/open', '-b', httpHandler, message['url']])

            # work around macOS 10.12.5 python bug
            elif platform.mac_ver()[0] == '10.12.5':
                subprocess.check_call(["/usr/bin/open", message['url']])

            # use python webbrowser module
            else:
                webbrowser.open(message['url'])
                
        except:  # webbrowser.Error or subprocess.CalledProcessError
            send_result("error", message['url'])
        else:
            send_result("success", message['url'])
            
exit(0)
