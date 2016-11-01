#!/usr/bin/python
#
#  strings.py: alter InfoPlist.strings localization files with dock & menubar names
#  Copyright (C) 2016  David Marmor
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

import os
import sys
import codecs
import re

# make sure we have the right number of arguments
if len(sys.argv) < 3:
    print "Wrong number of arguments"
    exit(1)

# get dock and menubar names
dockname = sys.argv[1].decode('utf-8')
menuname = sys.argv[2].decode('utf-8')

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
    except UnicodeError:
        try:
            infile = codecs.open(stringsfile, "r", "utf-8")
            intext = infile.read()
            infile.close()
            outfile = codecs.open(stringsfile, "w", "utf-8")
        except:
            print sys.exc_info()[1]
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
        print sys.exc_info()[1]
        exit(3)

exit(0)
