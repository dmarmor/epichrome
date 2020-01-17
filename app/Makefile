#
#  Makefile: Build rules for the Epichrome.
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


# BASIC INFO

APP:=Epichrome.app

NMH_ID:=org.epichrome.runtime

EXTN_ID_RELEASE:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
EXTN_ID_BETA:=cknkfdhlojihpopgbmoknioompcojicj
EXTN_ID_INTERNAL:=nhlnhgkagbiplaohhpmnhekngkckccfh

NOTARIZE_CREDENTIALS:=$(shell cat private/notarize_credentials.txt)

# VERSION INFO

VERSION:=$(shell source src/version.sh && echo "$$epiVersion")

VERSIONCODE:=$(shell 	if [[ "$(VERSION)" =~ ^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?$$ ]] ; then \
			  if [[ "$${BASH_REMATCH[4]}" ]] ; then \
			    vExtra=$${BASH_REMATCH[5]} ; \
			  else vExtra=999 ; fi ; \
			  printf '%d.%d.%d' $${BASH_REMATCH[1]} $${BASH_REMATCH[2]} \
				$$(( ($${BASH_REMATCH[3]} * 1000) + $$vExtra )) ; \
			else printf '%s' "FAIL" ; fi)
ifeq ($(VERSIONCODE),FAIL)
$(error Unable to parse version number in version.sh)
endif

BETA:=$(shell if [[ '$(VERSION)' =~ b ]] ; then echo _beta ; else echo '' ; fi)

CHROMIUM:=Chromium/Chromium.78.0.3904.97.sync.app.zip


# FILTERING INFO

ifeq ($(BETA),_beta)
DEBUG_SH:=1
DEBUG_PY:=True
else
DEBUG_SH:=
DEBUG_PY:=False
endif

LOGPRESERVE_SH:=

NMH_EXTN_IDS:="chrome-extension:\/\/$(EXTN_ID_RELEASE)\/",\'$$'\n''        "chrome-extension:\/\/$(EXTN_ID_BETA)\/"


# APP PATHS

APP_CT:=$(APP)/Contents
APP_RNTM:=$(APP_CT)/Resources/Runtime
APP_RNTM_HLPR:=$(APP_RNTM)/Contents/Resources/EpichromeHelper.app
APP_RNTM_HLPR_CT:=$(APP_RNTM_HLPR)/Contents

INSTALL_PATH:=/Applications/Epichrome.app


# META-TARGETS

.DELETE_ON_ERROR:

.PHONY: internal install clean clean-all

.PRECIOUS: \
	build/icons/app$(BETA).icns \
	build/icons/document$(BETA).icns \
	build/icons/epichrome$(BETA).icns \
	build/img/icon128$(BETA).png

INTERMEDIATES:=build/engine build/fake.icns build/fake.sh build/Chromium.app build/package build/requirements.plist build/epichrome-$(VERSION)-internal.pkg build/epichrome-$(VERSION)-dist.plist
.INTERMEDIATE: main runtime engine $(INTERMEDIATES)

# DEFAULT TARGET

internal: NMH_EXTN_IDS:=$(NMH_EXTN_IDS),\'$$'\n''        "chrome-extension:\/\/$(EXTN_ID_INTERNAL)\/"

internal: $(APP)

package: epichrome-$(VERSION).pkg

epichrome-$(VERSION).pkg: build/epichrome-$(VERSION)-internal.pkg build/epichrome-$(VERSION)-dist.plist
	@rm -f '$@'
	productbuild --distribution build/$(@:.pkg=)-dist.plist \
		--package-path build \
		--sign 'David Marmor' \
		'$@'

build/epichrome-$(VERSION)-internal.pkg: $(APP)
	@rm -f '$@'
	xattr -cr $(APP)
	mkdir -p build/package/Applications
	mv $(APP) build/package/Applications
	pkgbuild --analyze --root build/package $(@:.pkg=).plist
	pkgbuild --root build/package --component-plist $(@:.pkg=).plist $@
	rm -f $(@:.pkg=).plist
	mv build/package/Applications/$(APP) $(APP)

build/epichrome-$(VERSION)-dist.plist: build/epichrome-$(VERSION)-internal.pkg build/requirements.plist
	@rm -f '$@'
	productbuild --synthesize \
		--product build/requirements.plist \
		--package '$<' \
		'$@'
	sed -i '' 's/enable_anywhere="false"/enable_anywhere="true"/' '$@'

build/requirements.plist: src/package/requirements.plist
	@rm -f '$@'
	cp '$<' '$@'
	/usr/libexec/PlistBuddy -c 'Set :os:0 '"$$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' '$(APP)/Contents/Resources/Runtime/Engine/Filter/Info.plist')" build/requirements.plist

notarize: epichrome-$(VERSION).pkg
	@echo '*** This should only be done after thorough testing that the package is correct.' ; \
	read -p "Send to Apple for notarization? (y/n [n]) " -r ; \
	if [[ "$$REPLY" =~ ^[Yy]$$ ]] ; then \
		xcrun altool --notarize-app \
               --primary-bundle-id 'org.epichrome.Epichrome.$(VERSION)' \
               $(NOTARIZE_CREDENTIALS) \
               --file epichrome-$(VERSION).pkg > '$(<:.pkg=).notarize_request.txt' ; \
		result=$? ; cat 'build/$(<:.pkg=).notarize_request.txt' ; exit $result ; fi
# --asc-provider 'HDCPM67D76' \


# UTILITY TARGETS

clean:
	rm -rf $(APP) epichrome-$(VERSION).pkg
	rm -rf build/main* build/runtime* $(INTERMEDIATES) 'build/epichrome-$(VERSION).notarize_request.txt'

clean-all: clean
	rm -rf build
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;

install: $(APP)
	@if [[ -e "$(INSTALL_PATH)" ]] ; then \
		echo 'rm -rf "$(INSTALL_PATH)"' ; \
		rm -rf "$(INSTALL_PATH)" ; \
	fi
	cp -a $(APP) "$(INSTALL_PATH)"

notarize-check: build/epichrome-$(VERSION).notarize_request.txt
	xcrun altool --notarization-info "$$(sed -En 's/RequestUUID *= *([^ ]+) *$$/\1/p' '$<')" \
	$(NOTARIZE_CREDENTIALS)


# CODESIGNING

%.app: src/package/entitlements.plist
	codesign -vv --force --options runtime --entitlements src/package/entitlements.plist \
		-s 'David Marmor' $@
	codesign --verify --deep --strict --verbose=2 $@
	spctl --assess --type execute --verbose=4 $@
	touch $@


# *** MAIN APP ***

# MAIN APP DEPENDENCIES

$(APP):	$(APP_CT)/PkgInfo \
	$(APP_CT)/MacOS/applet \
	$(APP_CT)/Resources/applet.rsrc \
	$(APP_CT)/Resources/Scripts/main.scpt \
	\
	$(APP_CT)/Info.plist \
	\
	$(APP_CT)/Resources/applet.icns \
	$(APP_CT)/Resources/docbg.png \
	\
	$(APP_CT)/Resources/Scripts/build.sh \
	$(APP_CT)/Resources/Scripts/makeicon.sh \
	$(APP_CT)/Resources/Scripts/pathinfo.sh \
	$(APP_CT)/Resources/Scripts/updatecheck.sh \
	$(APP_CT)/Resources/Scripts/update.sh \
	$(APP_CT)/Resources/Scripts/version.sh \
	\
	$(APP_RNTM)/Filter/Info.plist \
	$(APP_RNTM)/Filter/AppExec \
	$(APP_RNTM)/Filter/epichromeruntimehost.py \
	\
	$(APP_RNTM)/Icons/app.icns \
	$(APP_RNTM)/Icons/document.icns \
	\
	$(APP_RNTM_HLPR) \
	\
	$(APP_RNTM)/Contents/Resources/Scripts/core.sh \
	$(APP_RNTM)/Contents/Resources/Scripts/filter.sh \
	$(APP_RNTM)/Contents/Resources/Scripts/launch.sh \
	\
	$(APP_RNTM)/Contents/Resources/External\ Extensions/$(EXTN_ID_RELEASE).json \
	\
	$(APP_RNTM)/Contents/Resources/NMH/$(NMH_ID).json \
	\
	$(APP_RNTM)/Contents/Resources/FirstRun/welcome.html \
	$(APP_RNTM)/Contents/Resources/FirstRun/welcome.css \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/icon128.png \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/m1s1.png \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/m1s2.png \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/m2s1.png \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/m2s2.png \
	$(APP_RNTM)/Contents/Resources/FirstRun/img/m3s1.png \
	\
	$(APP_RNTM)/Engine/Filter/PlaceholderExec \
	\
	$(APP_RNTM)/Resources/Scripts/runtime.sh \
	\
	$(APP_RNTM)/Contents/MacOS/Epichrome \
	$(APP_RNTM)/Contents/Resources/MainMenu.nib \
	$(APP_RNTM)/Contents/Resources/AppSettings.plist \
	\
	$(APP_RNTM)/Engine/Filter/Info.plist \
	$(APP_RNTM)/Engine/Payload \
	$(APP_RNTM)/Engine/Link/Frameworks


# MAIN APP CORE

$(APP_CT)/PkgInfo $(APP_CT)/MacOS/applet \
$(APP_CT)/Resources/applet.rsrc \
$(APP_CT)/Resources/Scripts/main.scpt: src/main.applescript src/version.sh main

main:
	@mkdir -p build
	@rm -rf build/main.app build/main
	sed -e 's/EPIVERSION/$(VERSION)/g; s/EPIDEBUG/$(DEBUG_SH)/g; s/EPILOGPRESERVE/$(LOGPRESERVE_SH)/g' \
		src/main.applescript > build/main.applescript
#	chmod 444 src/main.applescript
	osacompile -x -o build/main.app build/main.applescript
#	chmod 644 src/main.applescript
#	chmod 444 $(APP_SCPT)/main.scpt  # lock main.scpt so codesigning works
	@mv build/main.app build/main
	@rm -f build/main.applescript
	@cd build/main/Contents && rm -f Info.plist Resources/applet.icns
	@mkdir -p $(APP_CT)/MacOS $(APP_CT)/Resources/Scripts
	mv -f build/main/Contents/Resources/Scripts/main.scpt $(APP_CT)/Resources/Scripts/main.scpt
	@touch $(APP_CT)/Resources/Scripts/main.scpt
	mv -f build/main/Contents/PkgInfo $(APP_CT)/PkgInfo
	mv -f build/main/Contents/MacOS/applet $(APP_CT)/MacOS/applet
	mv -f build/main/Contents/Resources/applet.rsrc $(APP_CT)/Resources/applet.rsrc
	@touch $(APP_CT)/PkgInfo $(APP_CT)/MacOS/applet $(APP_CT)/Resources/applet.rsrc
	rmdir build/main/Contents/MacOS
	@cd build && if ! rmdir -p main/Contents/Resources/Scripts ; then \
		echo "*** Unexpected files found in main app (check build/main)." 1>&2 ; false ; fi
	@touch $(APP)


# MAIN APP BUNDLE ELEMENTS

$(APP_RNTM)/Contents/Resources/Scripts/core.sh: src/core.sh src/version.sh
	@mkdir -p $(APP_RNTM)/Contents/Resources/Scripts
	sed -e 's/EPIVERSION/$(VERSION)/g; s/EPIDEBUG/$(DEBUG_SH)/g; s/EPILOGPRESERVE/$(LOGPRESERVE_SH)/g' $< > $@

$(APP_CT)/Info.plist: src/Info.plist src/version.sh
	@mkdir -p $(APP_CT)
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/' -e 's/EPIVERSION/$(VERSION)/' $< > $@

$(APP_CT)/Resources/applet.icns: build/icons/epichrome$(BETA).icns
	@mkdir -p $(APP_CT)/Resources
	cp '$<' '$@'

$(APP_CT)/Resources/docbg.png: ../images/icons/docbg.png
	@mkdir -p $(APP_CT)/Resources
	cp '$<' '$@'

$(APP_CT)/Resources/Scripts/version.sh: src/version.sh
	@mkdir -p $(APP_CT)/Resources/Scripts
	touch -c build/icons/*
	cp '$<' '$@'

$(APP_CT)/Resources/Scripts/%: src/%
	@mkdir -p $(APP_CT)/Resources/Scripts
	cp '$<' '$@'


# *** RUNTIME CORE ***

# RUNTIME CORE

$(APP_RNTM)/Contents/MacOS/Epichrome \
$(APP_RNTM)/Contents/Resources/MainMenu.nib \
$(APP_RNTM)/Contents/Resources/AppSettings.plist: runtime

runtime:
	@rm -rf build/runtime.app
	@echo > build/fake.icns
	@echo > build/fake.sh
	platypus --name Epichrome \
		 --interface-type None \
		 --app-icon build/fake.icns \
		 --document-icon build/fake.icns \
		 --interpreter /bin/sh \
		 --app-version $(VERSION) \
		 --author 'David Marmor' \
		 --bundle-identifier org.epichrome.APPBUNDLEID \
		 --droppable \
		 --background \
		 --quit-after-execution \
		 --uniform-type-identifiers 'com.compuserve.gif|public.html|public.jpeg|com.netscape.javascript-source|com.microsoft.word.mhtml|org.videolan.ogg-audio|org.videolan.ogg-audio|org.xiph.ogg-video|com.adobe.pdf|public.png|public.svg-image|public.plain-text|org.videolan.webm|public.webp|public.xhtml' \
		 --uri-schemes 'http|https|ftp|file' \
		 --optimize-nib \
		 build/fake.sh build/runtime.app
	mv build/runtime.app build/runtime
	@rm build/fake.icns build/fake.sh
	@cd build/runtime/Contents && rm -f Info.plist Resources/*.icns Resources/script
	@mkdir -p $(APP_RNTM)/Contents/MacOS $(APP_RNTM)/Contents/Resources
	mv -f build/runtime/Contents/MacOS/Epichrome $(APP_RNTM)/Contents/MacOS/Epichrome
	mv -f build/runtime/Contents/Resources/MainMenu.nib $(APP_RNTM)/Contents/Resources/MainMenu.nib
	mv -f build/runtime/Contents/Resources/AppSettings.plist $(APP_RNTM)/Contents/Resources/AppSettings.plist
	@rmdir build/runtime/Contents/MacOS
	@cd build && if ! rmdir -p runtime/Contents/Resources ; then \
		echo '*** Unexpected files found in Platypus runtime app (check build/runtime).' 1>&2 ; false ; fi

# $(APP_RNTM)/Contents/Resources/MainMenu.nib: build/runtime | $(APP_RNTM)/Contents/Resources/
# 	cp '$<' '$@'

# $(APP_RNTM)/Contents/Resources/AppSettings.plist: build/runtime | $(APP_RNTM)/Contents/Resources/
# 	cp '$<' '$@'

# build/runtime/MacOS/Epichrome \
# build/runtime/Resources/MainMenu.nib \
# build/runtime/Resources/AppSettings.plist: | build/
# 	rm -rf build/runtime build/runtime.app
# 	echo > build/fake.icns
# 	echo > build/fake.sh
# 	platypus --name Epichrome \
# 		 --interface-type None \
# 		 --app-icon build/fake.icns \
# 		 --document-icon build/fake.icns \
# 		 --interpreter /bin/sh \
# 		 --app-version $(VERSION) \
# 		 --author 'David Marmor' \
# 		 --bundle-identifier org.epichrome.APPBUNDLEID \
# 		 --droppable \
# 		 --background \
# 		 --quit-after-execution \
# 		 --uniform-type-identifiers 'com.compuserve.gif|public.html|public.jpeg|com.netscape.javascript-source|com.microsoft.word.mhtml|org.videolan.ogg-audio|org.videolan.ogg-audio|org.xiph.ogg-video|com.adobe.pdf|public.png|public.svg-image|public.plain-text|org.videolan.webm|public.webp|public.xhtml' \
# 		 --uri-schemes 'http|https|ftp|file' \
# 		 --optimize-nib \
# 		 build/fake.sh build/runtime.app
# 	rm build/fake.icns build/fake.sh
# 	mv build/runtime.app/Contents build/runtime
# 	rm -rf build/runtime.app
# 	rm build/runtime/Info.plist build/runtime/Resources/*.icns build/runtime/Resources/script


# RUNTIME FILTER ELEMENTS

$(APP_RNTM)/Filter/Info.plist: src/Info.plist.runtime src/version.sh
	@mkdir -p $(APP_RNTM)/Filter
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g' $< > $@

$(APP_RNTM)/Filter/AppExec: src/AppExec src/version.sh
	@mkdir -p $(APP_RNTM)/Filter
	sed -e 's/EPIVERSION/$(VERSION)/g' $< > $@

$(APP_RNTM)/Filter/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh
	@mkdir -p $(APP_RNTM)/Filter
	sed -e 's/EPIVERSION/$(VERSION)/g; s/EPIDEBUG/$(DEBUG_PY)/g' $< > $@


# RUNTIME ICONS

$(APP_RNTM)/Icons/%.icns: build/icons/%$(BETA).icns
	@mkdir -p $(APP_RNTM)/Icons
	cp '$<' '$@' 

build/icons/%.icns: ../images/icons/%.psd
	@mkdir -p build/icons
	src/makeicon.sh -f $< $@


# EPICHROME HELPER

$(APP_RNTM_HLPR): | $(APP_RNTM_HLPR_CT)/Info.plist \
	$(APP_RNTM_HLPR_CT)/MacOS/EpichromeHelper

$(APP_RNTM_HLPR_CT)/Info.plist: src/helper/Info.plist
	@mkdir -p $(APP_RNTM_HLPR_CT)
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g' $< > $@

$(APP_RNTM_HLPR_CT)/MacOS/EpichromeHelper: src/helper/EpichromeHelper
	@mkdir -p $(APP_RNTM_HLPR_CT)/MacOS
	cp '$<' '$@' 


# RUNTIME SCRIPTS

$(APP_RNTM)/Contents/Resources/Scripts/%.sh: src/%.sh
	@mkdir -p $(APP_RNTM)/Contents/Resources/Scripts
	cp '$<' '$@' 


# CHROME EXTENSION

$(APP_RNTM)/Contents/Resources/NMH/$(NMH_ID).json: src/$(NMH_ID).json src/version.sh
	@mkdir -p $(APP_RNTM)/Contents/Resources/NMH
	sed -E -e 's/EPIVERSION/$(VERSION)/g; s/EPIRUNTIMEIDS/$(NMH_EXTN_IDS)/' $< > $@

$(APP_RNTM)/Contents/Resources/External\ Extensions/$(EXTN_ID_RELEASE).json: src/install-extension.json
	@mkdir -p '$(APP_RNTM)/Contents/Resources/External Extensions'
	cp '$<' '$@'


# FIRST RUN HTML

$(APP_RNTM)/Contents/Resources/FirstRun/welcome.%: welcome/welcome.%
	@mkdir -p $(APP_RNTM)/Contents/Resources/FirstRun
	cp '$<' '$@' 

$(APP_RNTM)/Contents/Resources/FirstRun/img/icon128.png: build/img/icon128$(BETA).png
	@mkdir -p $(APP_RNTM)/Contents/Resources/FirstRun/img
	cp '$<' '$@' 

$(APP_RNTM)/Contents/Resources/FirstRun/img/%.png: welcome/img/%.png
	@mkdir -p $(APP_RNTM)/Contents/Resources/FirstRun/img
	cp '$<' '$@' 

build/img/icon128$(BETA).png: ../images/icons/app$(BETA).psd
	@mkdir -p build/img
	sips -s format png -z 128 128 $< --out $@


# *** ENGINE ***

# ENGINE FILTER ELEMENTS

$(APP_RNTM)/Engine/Filter/Info.plist $(APP_RNTM)/Engine/Payload $(APP_RNTM)/Engine/Link/Frameworks: \
		$(CHROMIUM) src/version.sh engine

engine:
	@rm -rf build/Chromium.app build/engine
	unzip -d build $(CHROMIUM)
	mv build/Chromium.app/Contents build/engine
	rmdir build/Chromium.app
	@if [[ "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' build/engine/Info.plist)" != 'app.icns' ]] ; then \
		echo '*** Chromium app icon name has changed.' 1>&2 ; false ; fi
	/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' \
				-c 'Delete :CFBundleDocumentTypes' \
				-c 'Delete :CFBundleURLTypes' \
				build/engine/Info.plist
	@mkdir -p $(APP_RNTM)/Engine/Filter
	mv -f build/engine/Info.plist $(APP_RNTM)/Engine/Filter/Info.plist
	rm -rf $(APP_RNTM)/Engine/Link $(APP_RNTM)/Engine/Payload
	mkdir -p $(APP_RNTM)/Engine/Link
	mv build/engine/Frameworks $(APP_RNTM)/Engine/Link/Frameworks
	@touch $(APP_RNTM)/Engine/Link/Frameworks
	rm -f build/engine/Resources/*.icns
	mv build/engine $(APP_RNTM)/Engine/Payload
	@touch $(APP_RNTM)/Engine/Payload

$(APP_RNTM)/Engine/Filter/PlaceholderExec: src/PlaceholderExec src/version.sh
	@mkdir -p $(APP_RNTM)/Engine/Filter
	sed 's/EPIVERSION/$(VERSION)/g' $< > $@


# *** LEGACY UPDATE CODE ***

$(APP_RNTM)/Resources/Scripts/runtime.sh: src/runtime.sh
	@mkdir -p $(APP_RNTM)/Resources/Scripts
	cp '$<' '$@'


# $(APP_ENGN): $(CHROMIUM)
# 	@rm -rf $(APP_ENGN)
# 	mkdir -p $(APP_ENGN)/Payload/Contents/Resources
# 	unzip -d $(APP_ENGN) $(CHROMIUM)
# 	mv $(APP_ENGN)/Chromium.app/Contents $(APP_ENGN)/Runtime
# 	rmdir $(APP_ENGN)/Chromium.app
# 	mv $(APP_ENGN)/Runtime/Info.plist $(APP_ENGN)/Payload/Contents/Info.plist.in
# 	mv $(APP_ENGN)/Runtime/MacOS $(APP_ENGN)/Payload/Contents
# 	mv $(APP_ENGN)/Runtime/Resources/*.lproj $(APP_ENGN)/Payload/Contents/Resources
# 	rm -f $(APP_ENGN)/Runtime/Resources/*.icns

