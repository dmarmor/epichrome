#
#  Makefile: Build rules for the project.
#
#  Copyright (C) 2015  David Marmor
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


APP=chromessb.app/Contents
APP_RSRC=$(APP)/Resources
APP_SCPT=$(APP_RSRC)/Scripts


.PHONY: all install clean

all: $(APP_SCPT)/main.scpt $(APP)/Info.plist $(APP_RSRC)/applet.icns $(APP_SCPT)/chrome-ssb.sh $(APP_SCPT)/lastpath.sh

clean:
	rm -rf chromessb.app

clean-all: clean
	find . -name '*~' -o -name '.DS_Store' -exec rm {} \;

install: all
	cp -aR chromessb.app "/Applications/Chrome Apps/Make Chrome SSB.app"

$(APP_SCPT)/main.scpt: src/main.applescript
	osacompile -x -o "chromessb.app" src/main.applescript
	@rm $(APP)/Info.plist $(APP_RSRC)/applet.icns
	mkdir -p $(APP_RSRC)/Paths

$(APP)/Info.plist: src/Info.plist
	cp -a src/Info.plist $(APP)/

$(APP_RSRC)/applet.icns: icon/applet.icns
	cp -a icon/applet.icns $(APP_RSRC)/

$(APP_SCPT)/chrome-ssb.sh: src/chrome-ssb.sh
	cp -a src/chrome-ssb.sh $(APP_SCPT)/

$(APP_SCPT)/lastpath.sh: src/lastpath.sh
	cp -a src/lastpath.sh $(APP_SCPT)/
