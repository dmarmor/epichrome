#!/usr/bin/python
#
#  infoplist.py: edit Chrome Info.plist for an SSB
#
#  Copyright (C) 2015 David Marmor
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

import sys
import re
import xml.etree.ElementTree as et

try:
    infile = open('/Applications/Google Chrome.app/Contents/Info.plist', 'r')
    infoplist = infile.read()
    infile.close()
    #outfile = codecs.open(stringsfile, "w", "utf-16")
except:
    print sys.exc_info()[1][1]
    exit(2)

# get the XML tag and DOCTYPE for the file, or use reasonable defaults
m = re.match(r'^(<\?xml[^>]*encoding="([^"]*)"\?>\s*<!DOCTYPE[^>]*>\s*)', infoplist)
if m:
    prologue = m.group(1)
    encoding = m.group(2)
else:
    prologue = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
    encoding = 'UTF-8'

# read in the Info.plist file to an ElementTree
infoplist = et.fromstring(infoplist)

def output(root):
    # figure out what this element has
    result = '<' + root.tag
    for k, v in root.attrib.iteritems():
        result += ' ' + k + '="' + v + '"'
    if (len(root) == 0) and (not root.text):
        result += '/>'
    else:
        result += '>'
        if root.text: result += root.text
        for child in root: result += output(child)
        result += '</' + root.tag + '>'
    if root.tail: result += root.tail
    return result

# $$$ i am here - filter


print prologue + output(infoplist)

exit(0)


# make sure we have the right number of arguments
if len(sys.argv) < 3:
    print "Wrong number of arguments"
    exit(1)

# get dock and menubar names
dockname = sys.argv[1]
menuname = sys.argv[2]

# compile the regular expression
re_strings = re.compile(ur'((?:(CFBundleDisplayName)|(CFBundleName))\s*=\s*")[^"]*("\s*;)', flags=re.UNICODE)

# go through each directory & filter
for lprojdir in sys.argv[3:]:
    
    # read in the InfoPlist.strings file, then reopen for writing
    stringsfile = lprojdir + "/InfoPlist.strings"
    try:
        infile = codecs.open(stringsfile, "r", "utf-16")
        intext = infile.read()
        infile.close()
        outfile = codecs.open(stringsfile, "w", "utf-16")
    except:
        print sys.exc_info()[1][1]
        exit(2)
    
    # replace the dock and menubar names
    prevend = 0
    outtext = []
    for m in re_strings.finditer(intext):
        outtext.append(intext[prevend:m.start()])
        prevend = m.end()
        if m.group(2):  # CFBundleDisplayName
            curname = dockname
        else:  # CFBundleName
            curname = menuname
        outtext.append(m.group(1) + curname + m.group(4))
    outtext.append(intext[prevend:])
    
    # write out the output file
    try:
        outfile.write(''.join(outtext))
        outfile.close()
    except:
        print sys.exc_info()[1][1]
        exit(3)

exit(0)
