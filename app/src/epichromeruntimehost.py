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
import inspect

# BUILD FLAGS

debug = EPIDEBUG                   # filled in by Makefile


# info specific to this host
appVersion     = 'EPIVERSION'      # filled in by Makefile
appID          = 'APPID'           # filled in by updateapp
appDisplayName = 'APPDISPLAYNAME'  # filled in by updateapp
appBundleName  = 'APPBUNDLENAME'   # filled in by updateapp

# log file
appLogPath     = os.path.join(os.environ['HOME'],
                                  'Library/Application Support/Epichrome/Apps',
                                  appID)


# special mode for communicating version to parent app
if (len(sys.argv) > 1) and (sys.argv[1] == '-v'):
    print appVersion
    exit(0)


# ERRLOG: log to stderr and log file
def errlog(msg):

    # get stack frame info
    myStack = inspect.stack()
    
    # if we were called from debuglog, trim the stack
    if myStack[1][3] == 'debuglog':
        myStack = myStack[1:]

    # reverse the stack for easier message-building
    myStack.reverse()
        
    # build log string
    myMsg = (
        '{app}|{filename}({fileline}){frame}: {msg}\n'.format( app=appBundleName,
                                                         filename=os.path.basename(myStack[0][1]),
                                                         fileline=myStack[0][2],
                                                         frame=(' [{}]'.format('/'.join(
                                                             ['{}({})'.format(n[3], n[2])
                                                                  for n in myStack[1:-1]]))
                                                                    if len(myStack[1:-1]) else ''),
                                                         msg=msg ) )

    # attempt to log to stderr & log file, but fail silently
    try:
        sys.stderr.write(myMsg)
        sys.stderr.flush()
    except:
        pass

    try:
        with open(appLogPath, 'a') as f:
            f.write(myMsg)
    except:
        pass


#DEBUGLOG: log debugging message if debugging enabled
def debuglog(msg):
    if debug:
        errlog(msg)


# SEND_MESSAGE -- send a message to a Chrome extension
def send_message(message):

    try:
        # send the message's size
        sys.stdout.write(struct.pack('I', len(message)))
    
        # send the message itself
        sys.stdout.write(message)
        sys.stdout.flush()
    except:
        # $$$$ HANDLE EXCEPTION PROPERLY
        errlog('Error sending message')
    
    # log message
    debuglog('sent message to app: {}'.format(message))


# SEND_RESULT -- send a result message
def send_result(result, url):
    send_message('{"result": "%s", "url": "%s" }' % (result, url))


# RECEIVE_MESSAGE -- receive and unpack a message
def receive_message():
    
    try:
        # read the message length (first 4 bytes)
        text_length_bytes = sys.stdin.read(4)

        # read returned nothing -- the pipe is closed
        if len(text_length_bytes) == 0:
            return False
    
        # unpack message length as 4-byte integer
        text_length = struct.unpack('i', text_length_bytes)[0]
    
        # read and parse the text into a JSON object
        json_text = sys.stdin.read(text_length)

        result = json.loads(json_text.decode('utf-8'))
    except:
        # $$$$$$ HANDLE EXCEPTIONS PROPERLY WITH LOG
        errlog('Error receiving message')

    # log received message
    debuglog('received message from app: {}'.format(json_text))

    return result


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
            
    except: # $$$$$ subprocess.CalledProcessError + plistlib err
        errlog('Error getting list of browsers.')


debuglog("native message host running")

    
# MAIN LOOP -- just keep on receiving messages until stdin closes
while True:
    message = receive_message()

    if not message:
        break

    if 'version' in message:
        send_message(('{ "version": "%s", '+
                     '"ssbID": "%s", '+
                     '"ssbName": "%s", '+
                     '"ssbShortName": "%s" }') % (appVersion, appID, appDisplayName, appBundleName))
    
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
