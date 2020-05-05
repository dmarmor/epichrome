#!/usr/bin/python2.7
# -*- coding: utf-8 -*-
#
#  epichromeruntimehost.py: native messaging host for Epichrome Runtime
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

import struct
import sys
import json
import webbrowser
import subprocess
import os
import re
import platform
import inspect

# BUILD FLAGS

debug = True                   # filled in by Makefile


# CORE APP INFO

epiVersion     = "EPIVERSION"      # filled in by Makefile
appID          = "APPID"           # filled in by updateapp
appName        = "APPBUNDLENAME"   # filled in by updateapp
appDisplayName = "APPDISPLAYNAME"  # filled in by updateapp


# IMPORTANT APP INFO

appLogFile = None


# FUNCTION DEFINITIONS

# SETLOGPATH: set path to this app's log file
def setlogpath():

    global appLogFile
    global appLogID

    # set log ID
    appLogID = appID
    
    # get data path
    dataPath = os.path.join(os.environ['HOME'],
                                'Library/Application Support/Epichrome/Apps',
                                appID)
    
    # set temporary log path
    if appLogFile == None:
        appLogFile = os.path.join(dataPath, 'Logs', 'epichrome_app_log.txt')
    
    # read lock
    lockInfo = None
    try:
        with open(os.path.join(dataPath, 'lock'), 'r') as f:
            lockInfo = f.read()
    except Exception as e:
        errlog("Unable to read app lock ({})".format(e))

    # try to find log path in lock file
    if lockInfo:
        m = re.search("lockLogFile='([^\n]*)'[ \t]*\n", lockInfo)
        if m:
            appLogFile = m.group(1)
        else:
            # assume an older app version with old-style logging
            appLogFile = os.path.join(dataPath, 'epichrome_app_log.txt')


# ERRLOG: log to stderr and log file
def errlog(msg, msgType='*'):

    global appLogFile

    # get stack frame info
    myStack = inspect.stack()

    # if we were called from debuglog, trim the stack
    if myStack[1][3] == 'debuglog':
        myStack = myStack[1:]

    # reverse the stack for easier message-building
    myStack.reverse()

    # build log string
    myMsg = (
        '{mtype}[{pid}]{app}|{filename}({fileline}){frame}: {msg}\n'.format( mtype=msgType,
                                                         pid=os.getpid(),
                                                         app=appLogID,
                                                         filename=os.path.basename(myStack[0][1]),
                                                         fileline=myStack[0][2],
                                                         frame=('/{}'.format('/'.join(
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

    if appLogFile != None:
        try:
            with open(appLogFile, 'a') as f:
                f.write(myMsg)
        except:
            myMsg = "Error writing to log file '{}'. Logging will only be to stderr.".format(appLogFile)
            appLogFile = None
            errlog(myMsg)
            

#DEBUGLOG: log debugging message if debugging enabled
def debuglog(msg):
    if debug:
        errlog(msg, ' ')


# SEND_MESSAGE -- send a message to a Chrome extension
def send_message(message):

    try:
        # encode message into json
        msg_json = json.dumps(message)
        
        # send the message's size
        sys.stdout.write(struct.pack('I', len(msg_json)))

        # send the message itself
        sys.stdout.write(msg_json)
        sys.stdout.flush()
        
        # log message
        debuglog('sent message to app: {}'.format(msg_json))
    except Exception as e:
        errlog('Error sending message ({})'.format(e))


# SEND_RESULT -- send a result message
def send_result(result, url):
    send_message({ "result": result, "url": url })


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
        
    except Exception as e:
        errlog('Error receiving message ({})'.format(e))

    # log received message
    debuglog('received message from app: {}'.format(json_text))

    return result


# === MAIN BODY ===


# MAKE SURE WE HAVE APP INFO

if appID:

    # we're running from this app's bundle
    
    # set path to this app's log file
    setlogpath()

    # in this case, app version is the same is Epichrome version
    appVersion = epiVersion

    # determine parent app path from this script's path
    appPath = os.path.realpath(os.path.join(os.path.dirname(__file__), '../../..'))

else:

    # we're running from Epichrome.app
    
    # temporarily log to the main Epichrome log
    appLogID = '<UnknownEpichromeApp>'
    appLogFile = os.path.join(os.environ['HOME'],
                                  'Library/Application Support/Epichrome/Logs',
                                  'epichrome_log_nativemessaginghost.txt')
    
    # get parent process ID & use that to get engine path
    try:
        enginepath = subprocess.check_output(['/bin/ps', '-o', 'comm',
                                                  '-p', str(os.getppid())]).split('\n')[1]
    except Exception as e:

        errlog("Unable to get path of parent engine ({})".format(e), '!')
        exit(1)
        
    # read engine manifest
    try:
        with open(os.path.join(os.path.dirname(enginepath), '../../../info.json')) as fp:
            json_info = json.load(fp)

    except Exception as e:      
        errlog("Error reading info.json ({})".format(e), '!')
        exit(1)
    
    try:
        # set app info from manifest
        appVersion     = json_info['version'].encode('utf-8')
        appID          = json_info['appID'].encode('utf-8')
        appName        = json_info['appName'].encode('utf-8')
        appDisplayName = json_info['appDisplayName'].encode('utf-8')
        appPath        = json_info['appPath'].encode('utf-8')
    except Exception as e:
        
        errlog("Engine info.json missing expected key: {}".format(e), '!')
        exit(1)
    
    # set permanent log path
    setlogpath()

    debuglog("App info set: ID={} version={} name='{}' displayName='{}' path='{}'".format(appID,
                                                                                              appVersion,
                                                                                              appName,
                                                                                              appDisplayName,
                                                                                              appPath))


# SPECIAL MODE FOR COMMUNICATING VERSION TO PARENT APP

if (len(sys.argv) > 1) and (sys.argv[1] == '-v'):
    print appVersion
    exit(0)


debuglog("Native messaging host running.")


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

    except Exception as e:
        errlog("Error getting list of browsers ({})".format(e))


# MAIN LOOP -- just keep on receiving messages until stdin closes
while True:
    message = receive_message()

    if not message:
        break

    if 'version' in message:
        
        send_message({ 'version' : appVersion,
                           'ssbID' : appID,
                           'ssbName' : appDisplayName,
                           'ssbShortName': appName })

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
