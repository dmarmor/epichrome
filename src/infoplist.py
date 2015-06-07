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
from itertools import izip_longest

# make sure we have the right number of arguments
if len(sys.argv) < 2:
    print "Not enough arguments"
    exit(1)

# get Chrome Info.plist and temporary output Info.plist paths
infilename = sys.argv[1]
outfilename = sys.argv[2]

# zip the rest of the arguments into a dictionary: {<Info.plist-key>: <new-value>}
# where if <new-value> is False or '', it means delete the corresponding key
filterkeys = dict(izip_longest(*[iter(sys.argv[3:])] * 2, fillvalue=False))


# read in the Info.plist file
try:
    infile = open(infilename, 'r')
    infoplist = infile.read()
    infile.close()
except:
    print sys.exc_info()[1][1] + ' (Chrome Info.plist)'
    exit(2)

# open the output file for writing
try:
    outfile = open(outfilename, 'w')
except:
    print sys.exc_info()[1][1] + ' (temporary Info.plist)'
    exit(2)


# get the XML tag and DOCTYPE for the file, or use reasonable defaults
prologue = re.match(r'^<\?xml[^>]*encoding="([^"]*)"\?>\s*<!DOCTYPE[^>]*>\s*', infoplist)
if prologue:
    encoding = prologue.group(1)
    prologue = prologue.group(0)
else:
    encoding = 'UTF-8'
    prologue = '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'

    
# parse the Info.plist file to an ElementTree
infoplist = et.fromstring(infoplist)


# OUTPUT -- function that filters and outputs the Info.plist XML tree
def output(root):
    global state
    
    # we're one of the nodes after a key that we're filtering somehow
    if state:
        if root.tag == 'key':
            # we hit another key, so we're done
            state = False
        elif filterkeys[state]:
            # we're changing text (this should be a string node)
            if root.tag == 'string': root.text = filterkeys[state]
            # otherwise, it's an error, but we'll just silently fail for now
            state = False
        else:
            # we're delete everything in this key
            state = False
            return ''

    # determine if we're a key that should be filtered
    if (root.tag == 'key') and (root.text in filterkeys):
        state = root.text
        if not filterkeys[root.text]: return ''
    
    # print out this element
    result = '<' + root.tag
    for k, v in root.attrib.iteritems(): result += ' ' + k + '="' + v + '"'
    if (len(root) == 0) and (not root.text):
        result += '/>'
    else:
        result += '>'
        if root.text: result += root.text
        for child in root: result += output(child)
        result += '</' + root.tag + '>'
    if root.tail: result += root.tail

    return result


# run the output!
state = False
try:
    outfile.write(prologue + output(infoplist) + '\n')
    outfile.close()
except:
    print sys.exc_info()[1][1]
    exit(2)

# success!
exit(0)
