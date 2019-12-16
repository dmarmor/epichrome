#
#  Makefile: Build rules for the project.
#
#  Copyright (C) 2020  David Marmor
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

HOSTID:=org.epichrome.runtime
HOSTID_OLD:=org.epichrome.helper

EXTENSION_ID:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
EXTENSION_ID_BETA:=cknkfdhlojihpopgbmoknioompcojicj
EXTENSION_ID_INPLACE:=nhlnhgkagbiplaohhpmnhekngkckccfh

HOSTMANIFEST_SED_COMMON:="chrome-extension:\/\/$(EXTENSION_ID)\/",\\\n        "chrome-extension:\/\/$(EXTENSION_ID_BETA)\/"
HOSTMANIFEST_SED:=-e $$'s/EPIRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON)/'
HOSTMANIFEST_SED_INTERNAL:=-e $$'s/EPIRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON),\\\n        "chrome-extension:\/\/$(EXTENSION_ID_INPLACE)\/"/'

NMH_SED:=-e 's/EPIVERSION/$(VERSION)/'
NMH_SED_BETA:=$(NMH_SED) -e 's/debug = False/debug = True  \# DEBUG ON/'

EXEC_SED_BETA:=-e 's/^\#debug=$$/debug=1  \# DEBUG ON/'

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
APP_CLNP:=$(APP_RNTM_RSRC)/EpichromeCleanup.app
APP_CLNP_CTNT:=$(APP_CLNP)/Contents
INSTALL_PATH:=/Applications/Epichrome.app

.PHONY: build internal install clean clean-all

.PRECIOUS: runtime icons/app$(BETA).icns icons/document$(BETA).icns icons/epichrome$(BETA).icns welcome/img/icon128$(BETA).png

.DELETE_ON_ERROR: $(APP_ENGN) Engine runtime.app fake.icns fake.sh

internal: HOSTMANIFEST_SED:=$(HOSTMANIFEST_SED_INTERNAL)

internal: BETA:=_beta

#internal: EXEC_SED_BETA:=$(EXEC_SED_BETA) -e 's/^\#logPreserve=$$/logPreserve=1        \# PRESERVE LOG FILES ACROSS RUNS/'

internal: $(APP)

package: $(APP)

$(APP): $(APP_SCPT)/main.scpt \
	$(APP_CTNT)/MacOS/applet \
	$(APP_CTNT)/PkgInfo \
	$(APP_RSRC)/applet.rsrc \
	$(APP_SCPT)/version.sh \
	$(APP_CTNT)/Info.plist \
	$(APP_RSRC)/applet.icns \
	$(APP_RSRC)/docbg.png \
	$(APP_SCPT)/build.sh \
	$(APP_SCPT)/pathinfo.sh \
	$(APP_SCPT)/updatecheck.sh \
	$(APP_SCPT)/update.sh \
	$(APP_SCPT)/makeicon.sh \
	$(APP_RNTM)/Info.plist.in \
	$(APP_RNTM_RSRC)/script \
	$(APP_RNTM_RSRC)/app.icns \
	$(APP_RNTM_RSRC)/document.icns \
	$(APP_RNTM_SCPT)/runtime.sh \
	$(APP_RNTM_SCPT)/getversion.py \
	$(APP_RNTM_NMHT)/$(HOSTID).json \
	$(APP_RNTM_NMHT)/$(HOSTID_OLD).json \
	$(APP_RNTM_NMHT)/epichromeruntimehost.py \
	$(APP_RNTM_NMEX)/$(EXTENSION_ID).json \
	$(APP_RNTM_FRUN)/welcome.html \
	$(APP_RNTM_FRUN)/welcome.css \
	$(APP_RNTM_FRUN)/img/icon128.png \
	$(APP_RNTM_FRUN)/img/m1s1.png \
	$(APP_RNTM_FRUN)/img/m1s2.png \
	$(APP_RNTM_FRUN)/img/m2s1.png \
	$(APP_RNTM_FRUN)/img/m2s2.png \
	$(APP_RNTM_FRUN)/img/m3s1.png \
	$(APP_CLNP) \
	| $(APP_ENGN)

$(APP_CLNP): $(APP_CLNP_CTNT)/Info.plist \
	$(APP_CLNP_CTNT)/MacOS/EpichromeCleanup \
	$(APP_CLNP_CTNT)/Resources/Scripts/runtime.sh

$(APP) $(APP_CLNP):
	codesign --force --options runtime -s 'David Marmor' -vv $@
	codesign --verify --deep --strict --verbose=2 $@
	spctl --assess --type execute --verbose=4 $@
	touch $@

clean:
	rm -rf $(APP)
	rm -rf Engine
	rm -rf runtime

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	rm -rf icons
	rm -f welcome/img/icon128.png

install: $(APP)
	@if [[ -e "$(INSTALL_PATH)" ]] ; then \
		echo 'rm -rf "$(INSTALL_PATH)"' ; \
		rm -rf "$(INSTALL_PATH)" ; \
	fi
	cp -a $(APP) "$(INSTALL_PATH)"

$(APP_SCPT)/main.scpt $(APP_CTNT)/MacOS/applet $(APP_CTNT)/PkgInfo $(APP_RSRC)/applet.rsrc: src/main.applescript
	@if [[ -d Engine ]] ; then \
		echo "Temp Engine directory left over from previous run" ; false ; \
	fi
	@if [[ -d $(APP_ENGN) ]] ; then \
		echo 'mv -n $(APP_ENGN) Engine' ; \
		mv -n $(APP_ENGN) Engine ; \
	fi
	@rm -rf $(APP)
	chmod 444 $<
	osacompile -o $(APP) -x -d $<
	@touch $(APP_SCPT)/main.scpt $(APP_CTNT)/MacOS/applet $(APP_CTNT)/PkgInfo $(APP_RSRC)/applet.rsrc
	chmod 644 $<
	chmod 444 $(APP_SCPT)/main.scpt  # lock main.scpt so codesigning works
	@rm -f $(APP_CTNT)/Info.plist $(APP_RSRC)/applet.icns
	@if [[ -d Engine ]] ; then \
		echo 'mv -f Engine $(APP_ENGN)' ; \
		mv -f Engine $(APP_ENGN) ; \
	fi
	@touch $(APP)

$(APP_RNTM_SCPT)/runtime.sh: src/runtime.sh
	@mkdir -p $(dir $@)
	@if [[ "$(BETA)" ]] ; then \
	  echo "sed -E $(EXEC_SED_BETA) $< > $@" ; \
	  sed -E $(EXEC_SED_BETA) $< > $@ ; \
	else \
	  echo "cp $< $@" ; \
	  cp $< $@ ; \
	fi

$(APP_CTNT)/Info.plist: src/Info.plist src/version.sh
	@if [[ "$(VERSIONCODE)" = "VERSIONCODE_FAIL" ]] ; then echo "Bad version number in src/version.sh" ; false ; fi
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@

$(APP_RSRC)/applet.icns: icons/epichrome$(BETA).icns
	cp $< $@

$(APP_RSRC)/docbg.png: ../images/icons/docbg.png
	cp $< $@

$(APP_SCPT)/version.sh: src/version.sh
	touch -c icons/*
	cp $< $(APP_SCPT)/

$(APP_SCPT)/%: src/%
	cp $< $(APP_SCPT)/

$(APP_CLNP_CTNT)/Info.plist: src/cleanup/Info.plist src/version.sh
	@mkdir -p $(APP_CLNP_CTNT)
	@if [[ "$(VERSIONCODE)" = "VERSIONCODE_FAIL" ]] ; then \
	  echo "Bad version number in src/version.sh" ; false ; \
	fi
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@

$(APP_CLNP_CTNT)/MacOS/EpichromeCleanup: src/cleanup/EpichromeCleanup
	@mkdir -p $(APP_CLNP_CTNT)/MacOS
	cp $< $@

$(APP_CLNP_CTNT)/Resources/Scripts/runtime.sh: $(APP_RNTM_SCPT)/runtime.sh
	@mkdir -p $(APP_CLNP_CTNT)/Resources/Scripts
	cp $< $@

$(APP_RNTM): runtime
	rm -rf $@
	cp -R $< $@

runtime:
	rm -rf runtime
	echo > fake.icns
	echo > fake.sh
	platypus --name Epichrome --interface-type None --app-icon fake.icns --document-icon fake.icns --interpreter /bin/sh --app-version $(VERSION) --author 'David Marmor' --bundle-identifier org.epichrome.APPBUNDLEID --droppable --background --quit-after-execution  --uniform-type-identifiers 'com.compuserve.gif|public.html|public.jpeg|com.netscape.javascript-source|com.microsoft.word.mhtml|org.videolan.ogg-audio|org.videolan.ogg-audio|org.xiph.ogg-video|com.adobe.pdf|public.png|public.svg-image|public.plain-text|org.videolan.webm|public.webp|public.xhtml' --uri-schemes 'http|https|ftp|file' --optimize-nib fake.sh runtime.app
	rm fake.icns fake.sh
	mv runtime.app/Contents $@
	rm -rf runtime.app
	rm runtime/Info.plist runtime/Resources/*.icns runtime/Resources/script

$(APP_RNTM)/Info.plist.in: src/Info.plist.runtime src/version.sh $(APP_RNTM)
	@if [[ "$(VERSIONCODE)" = "VERSIONCODE_FAIL" ]] ; then \
	  echo "Bad version number in src/version.sh" ; false ; \
	fi
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@

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

$(APP_RNTM_RSRC)/script: src/epichrome $(APP_RNTM)
	cp $< $@

$(APP_RNTM_RSRC)/%.icns: icons/%$(BETA).icns $(APP_RNTM)
	cp $< $@

$(APP_RNTM_SCPT):
	mkdir -p $(APP_RNTM_SCPT)

$(APP_RNTM_SCPT)/%: src/% $(APP_RNTM) | $(APP_RNTM_SCPT)
	cp $< $(APP_RNTM_SCPT)/

$(APP_RNTM_NMHT):
	mkdir -p $(APP_RNTM_NMHT)

$(APP_RNTM_NMHT)/$(HOSTID).json: src/$(HOSTID).json src/version.sh $(APP_RNTM) | $(APP_RNTM_NMHT)
	sed -E -e 's/EPIVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@

# remove this after Epichrome Runtime 1.2.0 release
$(APP_RNTM_NMHT)/$(HOSTID_OLD).json: src/$(HOSTID).json src/version.sh $(APP_RNTM)
	sed -E -e 's/$(HOSTID)/$(HOSTID_OLD)/' -e 's/EPIVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@

$(APP_RNTM_NMHT)/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh $(APP_RNTM)
	@if [[ "$(BETA)" ]] ; then \
	  echo "sed $(NMH_SED_BETA) $< > $@" ; \
	  sed $(NMH_SED_BETA) $< > $@ ; \
	else \
	  echo "sed $(NMH_SED) $< > $@" ; \
	  sed $(NMH_SED) $< > $@ ; \
	fi

$(APP_RNTM_NMEX)/$(EXTENSION_ID).json: src/install-extension.json $(APP_RNTM)
	mkdir -p $(APP_RNTM_NMEX)
	cp $< "$@"

$(APP_RNTM_FRUN):
	mkdir -p $(APP_RNTM_FRUN)

$(APP_RNTM_FRUN)/welcome.%: welcome/welcome.% $(APP_RNTM) | $(APP_RNTM_FRUN)
	cp $< $(APP_RNTM_FRUN)/

$(APP_RNTM_FRUN)/img/icon128.png: welcome/img/icon128$(BETA).png $(APP_RNTM) | $(APP_RNTM_FRUN)
	mkdir -p $(APP_RNTM_FRUN)/img
	cp $< $@

$(APP_RNTM_FRUN)/img/%.png: welcome/img/%.png $(APP_RNTM) | $(APP_RNTM_FRUN)
	mkdir -p $(APP_RNTM_FRUN)/img
	cp $< $(APP_RNTM_FRUN)/img

welcome/img/icon128$(BETA).png: ../images/icons/app$(BETA).psd
	@mkdir -p icons
	sips -s format png -z 128 128 $< --out $@

icons/%.icns: ../images/icons/%.psd
	@mkdir -p icons
	src/makeicon.sh -f $< $@
