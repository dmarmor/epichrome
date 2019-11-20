#
#  Makefile: Build rules for the project.
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

# version info
VERSION:=$(shell source src/version.sh && echo "$$epiVersion")
VERSIONCODE:=$(shell if [[ "$(VERSION)" =~ ^([0-9]+\.[0-9]+\.[0-9]+)(b([0-9][0-9]))?$$ ]] ; then if [[ "$${BASH_REMATCH[2]}" ]] ; then printf '%s0%02d' "$${BASH_REMATCH[1]}" "$${BASH_REMATCH[3]}" ; else printf '%s100' "$${BASH_REMATCH[1]}" ; fi ; else printf '%s' "VERSIONCODE_FAIL" ; fi)
BETA:=$(shell if [[ '$(VERSION)' =~ b ]] ; then echo _beta ; else echo '' ; fi)
CHROMIUM:=Chromium/Chromium.78.0.3904.97.sync.app.zip

# build differently depending if version is beta
BUILD_TYPE:=$(patsubst build,build_release,build$(BETA))

APP:=Epichrome.app
RUNTIMEBG:=../runtime/src/background.js
#DEBUG_UPDATE_FREQ:=30
HOSTID:=$(shell sed -En 's/^.*chrome\.runtime\.connectNative[^a-zA-Z]+([a-zA-Z]([a-zA-Z0-9._-]*[a-zA-Z])?).*$$/\1/p' $(RUNTIMEBG))
HOSTID_OLD:=org.epichrome.helper
RUNTIMEID:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
RUNTIMEID_BETA:=cknkfdhlojihpopgbmoknioompcojicj
RUNTIMEID_INPLACE:=nhlnhgkagbiplaohhpmnhekngkckccfh

HOSTMANIFEST_SED_COMMON:="chrome-extension:\/\/$(RUNTIMEID)\/",\\\n        "chrome-extension:\/\/$(RUNTIMEID_BETA)\/"
HOSTMANIFEST_SED_RELEASE:=-e $$'s/EPIRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON)/'
HOSTMANIFEST_SED_BETA:=-e $$'s/EPIRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON),\\\n        "chrome-extension:\/\/$(RUNTIMEID_INPLACE)\/"/'

HOSTMANIFEST_SED:=$(HOSTMANIFEST_SED_RELEASE)

EXEC_SED:=-e 's/EPIHOSTID1/$(HOSTID)/' -e 's/EPIHOSTID2/$(HOSTID_OLD)/'
#EXEC_SED_BETA:=; s/--user-data-dir/--extensions-update-frequency=$(DEBUG_UPDATE_FREQ)\ --user-data-dir/

# app paths
APP_CTNT:=$(APP)/Contents
APP_RSRC:=$(APP_CTNT)/Resources
APP_SCPT:=$(APP_RSRC)/Scripts
APP_ENGN:=$(APP_RSRC)/Engine
APP_ENGN_PYLD:=$(APP_ENGN)/Payload
APP_ENGN_RNTM:=$(APP_ENGN)/Runtime
APP_RNTM:=$(APP_RSRC)/Runtime
APP_RNTM_MCOS:=$(APP_RNTM)/MacOS
APP_RNTM_RSRC:=$(APP_RNTM)/Resources
APP_RNTM_SCPT:=$(APP_RNTM_RSRC)/Scripts
APP_RNTM_NMHT:=$(APP_RNTM_RSRC)/NativeMessagingHosts
APP_RNTM_NMEX:=$(APP_RNTM_RSRC)/External\ Extensions
APP_RNTM_FRUN:=$(APP_RNTM_RSRC)/FirstRun
INSTALL_PATH:=/Applications/Epichrome.app

.PHONY: build build_release build_beta install clean clean-all

.PRECIOUS: icons/app$(BETA).icns icons/document$(BETA).icns icons/epichrome$(BETA).icns welcome/img/icon128.png

build: $(BUILD_TYPE)

build_beta: HOSTMANIFEST_SED:=$(HOSTMANIFEST_SED_BETA)

$(BUILD_TYPE): $(APP)

$(APP): $(APP_SCPT)/main.scpt \
	$(APP_SCPT)/version.sh \
	$(APP_CTNT)/Info.plist \
	$(APP_RSRC)/applet.icns \
	$(APP_RSRC)/docbg.png \
	$(APP_SCPT)/build.sh \
	$(APP_SCPT)/pathinfo.sh \
	$(APP_SCPT)/updatecheck.sh \
	$(APP_SCPT)/makeicon.sh \
	$(APP_RNTM)/Info.plist.in \
	$(APP_RNTM_MCOS)/Epichrome \
	$(APP_RNTM_SCPT)/runtime.sh \
	$(APP_RNTM_SCPT)/getversion.py \
	$(APP_RNTM_NMHT)/$(HOSTID).json \
	$(APP_RNTM_NMHT)/$(HOSTID_OLD).json \
	$(APP_RNTM_NMHT)/epichromeruntimehost.py \
	$(APP_RNTM_NMEX)/$(RUNTIMEID).json \
	$(APP_RNTM_FRUN)/welcome.html \
	$(APP_RNTM_FRUN)/welcome.css \
	$(APP_RNTM_FRUN)/img/icon128.png \
	$(APP_RNTM_FRUN)/img/m1s1.png \
	$(APP_RNTM_FRUN)/img/m1s2.png \
	$(APP_RNTM_FRUN)/img/m2s1.png \
	$(APP_RNTM_FRUN)/img/m2s2.png \
	$(APP_RNTM_FRUN)/img/m3s1.png \
	$(APP_RNTM_RSRC)/app.icns \
	$(APP_RNTM_RSRC)/document.icns \
	| $(APP_ENGN)

clean:
	rm -rf $(APP)
	rm -rf Engine

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	rm -rf icons
	rm -f welcome/img/icon128.png

install: $(APP)
	if [[ -e "$(INSTALL_PATH)" ]] ; then rm -rf "$(INSTALL_PATH)" ; fi
	cp -a $(APP) "$(INSTALL_PATH)"

$(APP_SCPT)/main.scpt: src/main.applescript
	@if [[ -d Engine ]] ; then echo "Temp Engine directory left over from previous run" ; false ; fi
	if [[ -d $(APP_ENGN) ]] ; then mv -n $(APP_ENGN) Engine ; fi
	@rm -rf $(APP)
	chmod 444 $<
	osacompile -o $(APP) -x -d $<
	chmod 644 $<
	chmod 444 $@  # lock main.scpt so codesigning works (no longer used)
	@rm -f $(APP_CTNT)/Info.plist $(APP_RSRC)/applet.icns
	mkdir -p $(APP_RNTM_SCPT)
	mkdir -p $(APP_RNTM_MCOS)
	mkdir -p $(APP_RNTM_NMHT)
	mkdir -p $(APP_RNTM_NMEX)
	mkdir -p $(APP_RNTM_FRUN)
	if [[ -d Engine ]] ; then mv -f Engine $(APP_ENGN) ; fi
	touch $(APP)

$(APP_CTNT)/Info.plist: src/Info.plist src/version.sh
	@if [[ "$(VERSIONCODE)" = "VERSIONCODE_FAIL" ]] ; then echo "Bad version number in src/version.sh" ; false ; fi
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@
	@touch $(APP) $(APP_CTNT)

$(APP_RSRC)/applet.icns: icons/epichrome$(BETA).icns
	cp -p $< $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC)

$(APP_RSRC)/docbg.png: ../images/icons/docbg.png
	cp -p $< $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC)

$(APP_SCPT)/version.sh: src/version.sh
	touch -c icons/*
	cp -p $< $(APP_SCPT)/
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_SCPT)

$(APP_SCPT)/%: src/%
	cp -p $< $(APP_SCPT)/
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_SCPT)

$(APP_RNTM)/Info.plist.in: src/Info.plist.runtime src/version.sh
	@if [[ "$(VERSIONCODE)" = "VERSIONCODE_FAIL" ]] ; then echo "Bad version number in src/version.sh" ; false ; fi
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@

.DELETE_ON_ERROR: $(APP_ENGN)

$(APP_ENGN): $(CHROMIUM)
	@rm -rf $(APP_ENGN)
	mkdir -p $(APP_ENGN)/Payload/Contents/Resources
	unzip -d $(APP_ENGN) $(CHROMIUM)
	mv $(APP_ENGN)/Chromium.app/Contents $(APP_ENGN)/Runtime
	rmdir $(APP_ENGN)/Chromium.app
	mv $(APP_ENGN)/Runtime/Info.plist $(APP_ENGN)/Payload/Contents/Info.plist.in
	mv $(APP_ENGN)/Runtime/MacOS $(APP_ENGN)/Payload/Contents
	mv $(APP_ENGN)/Runtime/Resources/*.lproj $(APP_ENGN)/Payload/Contents/Resources
	rm -f $(APP_ENGN)/Runtime/Resources/*.icns

$(APP_RNTM_MCOS)/Epichrome: src/epichrome $(RUNTIMEBG)
	sed -E $(EXEC_SED) $< > $@
	chmod 755 $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_MCOS)

$(APP_RNTM_RSRC)/%.icns: icons/%$(BETA).icns
	cp -p $< $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC)

$(APP_RNTM_SCPT)/%: src/%
	cp -p $< $(APP_RNTM_SCPT)/
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_SCPT)

$(APP_RNTM_NMHT)/$(HOSTID).json: src/epichromeruntimehost.json src/version.sh
	sed -E -e 's/EPIHOSTID/$(HOSTID)/' -e 's/EPIVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_NMHT)

# remove this after Epichrome Runtime 1.2.0 release
$(APP_RNTM_NMHT)/$(HOSTID_OLD).json: src/epichromeruntimehost.json src/version.sh
	sed -E -e 's/EPIHOSTID/$(HOSTID_OLD)/' -e 's/EPIVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_NMHT)

$(APP_RNTM_NMHT)/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh
	sed 's/EPIVERSION/$(VERSION)/' $< > $@
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_NMHT)

$(APP_RNTM_NMEX)/$(RUNTIMEID).json: src/install-extension.json
	cp -p $< "$@"
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_NMEX)

$(APP_RNTM_FRUN)/welcome.%: welcome/welcome.%
	cp -p $< $(APP_RNTM_FRUN)/
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_FRUN)

$(APP_RNTM_FRUN)/img/%.png: welcome/img/%.png
	mkdir -p $(APP_RNTM_FRUN)/img
	cp -p $< $(APP_RNTM_FRUN)/img
	@touch $(APP) $(APP_CTNT) $(APP_RSRC) $(APP_RNTM) $(APP_RNTM_RSRC) $(APP_RNTM_FRUN) $(APP_RNTM_FRUN)/img

welcome/img/icon128.png: ../images/icons/app$(BETA).psd
	@mkdir -p icons
	sips -s format png -z 128 128 $< --out $@

icons/%.icns: ../images/icons/%.psd
	@mkdir -p icons
	src/makeicon.sh -f $< $@
