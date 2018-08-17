#!/usr/bin/python
#
#  infoplist.py: edit Chrome Info.plist for an SSB
#  Copyright (C) 2018  David Marmor
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

import sys
import re
import xml.etree.ElementTree as et
from itertools import izip_longest

# make sure we have the right number of arguments
if len(sys.argv) < 3:
    print "not enough arguments"
    exit(1)

# get Chrome Info.plist and temporary output Info.plist paths
infilename = sys.argv[1]
outfilename = sys.argv[2]

# zip the rest of the arguments into a dictionary: {<Info.plist-key>: [ <found>, <new-value> ]}
# where if <new-value> is False or '', it means delete the corresponding key
filterkeys = dict();
i = 3;
while i < len(sys.argv):
    key = sys.argv[i]
    i += 1
    if i < len(sys.argv): val = sys.argv[i]
    if val == 'string':
        i += 1
        if i < len(sys.argv):
            val = ( val, sys.argv[i] )
        else:
            print "string key requires a value"
            exit(1)
    elif not val:
        val = ()
    else:
        # a boolean key
        val = ( val, )
    i += 1

    # add the dictionary entry
    filterkeys[key] = [ False, val ]

#filterkeys = dict(izip_longest(*[iter(sys.argv[3:])] * 2, fillvalue=False))


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


# FILTER -- filter the Info.plist XML tree
def plist_filter(root):

    i = 0
    while i < len(root):
                
        if (root[i].tag == 'key') and (root[i].text in filterkeys):
            curkey = root[i].text
            curval = filterkeys[curkey]

            # mark this key as found
            curval[0] = True

            # now we're only interested in the new value
            curval = curval[1]
            
            # we're deleting this key
            if len(curval) == 0:
                root.remove(root[i])
                if (i < len(root)) and (root[i].tag != 'key'):
                    root.remove(root[i])

            # we're replacing this key's value
            else:
                
                # remove the next node (unless it's another key)
                i += 1
                if (i < len(root)) and (root[i].tag != 'key'):
                    oldtail = root[i].tail
                    root.remove(root[i])
                else:
                    oldtail = root[i-1].tail
                
                # add in a new node
                newval = et.Element(curval[0])
                if len(curval) > 1: newval.text = curval[1]
                newval.tail = oldtail
                root.insert(i, newval)
                i += 1
                
            # we might have to filter multiple copies of a key, so don't delete
            #del filterkeys[curkey]

        else:
            # not a key we're filtering, so recurse on it
            if len(root[i]) > 0: plist_filter(root[i])
            i += 1


# OUTPUT -- output the Info.plist XML tree
def output(root):
    
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


# filter the plist
plist_filter(infoplist)

# delete all found filterkeys
delkeys = []
for curkey in filterkeys:
    if filterkeys[curkey][0]:
        delkeys.append(curkey)
for curkey in delkeys:
    del filterkeys[curkey]

# add in any remaining filterkeys
if len(filterkeys) > 0:
    # make sure we go to the right node
    if infoplist.tag != 'plist':
        print 'root tag is not plist'
        exit(3)
    if (len(infoplist) < 1) or (infoplist[0].tag != 'dict'):
        print 'unexpected child tag'
        exit(3)

    # get the dict node to put the keys in
    ipdict = infoplist[0]

    # get tail text for formatting
    if len(ipdict) > 0:
        maintail = ipdict.text
        lasttail = ipdict[-1].tail
    else:
        maintail = '\n\t'
        lasttail = '\n'
    
    # create a list of new elements
    newelements = []
    for (key, [ignore, val]) in filterkeys.iteritems():
        if len(val) > 0:
            # add the key
            e = et.Element('key')
            e.text = key
            e.tail = maintail
            newelements.append(e)
            
            # add the value
            e = et.Element(val[0])
            if len(val) > 1: e.text = val[1]
            e.tail = maintail
            newelements.append(e)

    # add new elements to the tree
    if len(newelements) > 0:
        if len(ipdict) > 0: ipdict[-1].tail = maintail
        newelements[-1].tail = lasttail
        for e in newelements:
            ipdict.append(e)
    
# write out the plist file
try:
    outfile.write(prologue + output(infoplist) + '\n')
    outfile.close()
except:
    print sys.exc_info()[1][0]
    exit(2)

# success!
exit(0)
