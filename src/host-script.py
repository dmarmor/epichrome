#!/usr/bin/python

import struct
import sys
import json
import webbrowser
import os


# info specific to this host (filled in on install)
version = 'SSBVERSION'  # filled in by Makefile
ssbid   = 'SSBID'  # filled in by MakeChromeSSB


# special mode for communicating version to parent SSB
if (len(sys.argv) > 1) and (sys.argv[1] == '-v'):
    print version
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


# MAIN LOOP -- just keep on receiving messages until stdin closes
while 1:
    message = receive_message()

    if not message:
        break

    if 'url' in message:
        # open the url
        try:
            webbrowser.open(message['url'])
        except webbrowser.Error:
            send_result("error", message['url'])
        else:
            send_result("success", message['url'])
    
exit(0)
