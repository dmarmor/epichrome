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
