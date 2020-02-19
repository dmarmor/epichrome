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

APP:=Epichrome/Epichrome.app

NMH_ID:=org.epichrome.runtime

EXTN_ID_RELEASE:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
EXTN_ID_BETA:=cknkfdhlojihpopgbmoknioompcojicj
EXTN_ID_INTERNAL:=nhlnhgkagbiplaohhpmnhekngkckccfh

NOTARIZE_CREDENTIALS:=$(shell cat private/notarize_credentials.txt)

THISYEAR:=$(shell date '+%Y')

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

VERSIONTEXT:=$(shell 	if [[ "$(VERSION)" =~ ^([0-9]+\.[0-9]+\.[0-9]+)b([0-9]+)$$ ]] ; then \
			  printf '%s BETA %s' $${BASH_REMATCH[1]} $${BASH_REMATCH[2]} ; \
			else echo '$(VERSION)' ; fi)

MIN_OS:="$$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' '$(APP)/Contents/Resources/Runtime/Engine/Filter/Info.plist')"

BETA:=$(shell if [[ '$(VERSION)' =~ b ]] ; then echo _beta ; else echo '' ; fi)


# CHROMIUM ENGINE
# (Using Marmaduke build with Google APIs and Widevine from https://chromium.woolyss.com/)

CHROMIUM:=$(shell ls Engines/Chromium* 2> /dev/null | sort -r | head -n 1)
ifeq ($(CHROMIUM),)
$(error Unable to find Chromium archive)
endif
ifneq ($(suffix $(CHROMIUM)),.tgz)
ifneq ($(suffix $(CHROMIUM)),.zip)
$(error Unrecognized file in Engines directory: $(CHROMIUM))
endif
CHROMIUM:=$(CHROMIUM:.zip=.tgz)
endif
CHROMIUM_VERSION:=$(shell if [[ '$(CHROMIUM)' =~ [0-9][0-9.]*[0-9] ]] ; then \
				echo "$${BASH_REMATCH[0]}" ; else echo ERROR ; fi)
ifeq ($(CHROMIUM_VERSION),ERROR)
$(error Unable to retrieve Chromium version from $(CHROMIUM))
endif

# BRAVE ENGINE

BRAVE:=$(shell ls Engines/Brave* 2> /dev/null | sort -r | head -n 1)
ifeq ($(BRAVE),)
$(error Unable to find Brave archive)
endif
ifneq ($(suffix $(BRAVE)),.tgz)
ifneq ($(suffix $(BRAVE)),.dmg)
$(error Unrecognized file in Engines directory: $(BRAVE))
endif
BRAVE:=$(BRAVE:.dmg=.tgz)
endif
BRAVE_VERSION:=$(shell if [[ '$(BRAVE)' =~ [0-9][0-9.]*[0-9] ]] ; then \
				echo "$${BASH_REMATCH[0]}" ; else echo ERROR ; fi)
ifeq ($(BRAVE_VERSION),ERROR)
$(error Unable to retrieve Brave version from $(CHROMIUM))
endif


# NOTARIZE INFO

NOTARIZE_REQUEST_FILE:=$(shell ls epichrome-$(VERSION).notarize_request_*.txt 2> /dev/null | sort | tail -n 1)


# BETA CONDITIONAL INFO

ifeq ($(BETA),_beta)
DEBUG_SH:=1
DEBUG_PY:=True
PACKAGE_README:=build/resources/readme.rtf
else
DEBUG_SH:=
DEBUG_PY:=False
PACKAGE_README:=
endif

LOGPRESERVE_SH:=

NMH_EXTN_IDS:="chrome-extension:\/\/$(EXTN_ID_RELEASE)\/",'\\$$'\n''        "chrome-extension:\/\/$(EXTN_ID_BETA)\/"


# APP PATHS

APP_CT:=$(APP)/Contents
APP_RNTM:=$(APP_CT)/Resources/Runtime
APP_RNTM_HLPR:=$(APP_RNTM)/Contents/Resources/EpichromeHelper.app
APP_RNTM_HLPR_CT:=$(APP_RNTM_HLPR)/Contents


# META-TARGETS

.DELETE_ON_ERROR:

.PHONY: internal install clean clean-all

.PRECIOUS: $(PRECIOUS_INTERMEDIATES)

INTERMEDIATES:=\
	build/engine/Brave \
	build/engine/Chromium \
	build/fake.icns \
	build/fake.sh \
	build/Chromium.app \
	build/package \
	build/epichrome-$(VERSION)-main.plist \
	build/epichrome-$(VERSION)-dist.xml

PRECIOUS_INTERMEDIATES:=\
	build/icons/app$(BETA).icns \
	build/icons/document$(BETA).icns \
	build/icons/epichrome$(BETA).icns \
	build/img/icon128$(BETA).png \
	build/epichrome-$(VERSION)-main.pkg \
	build/resources/background.png \
	build/resources/license.rtf \
	build/resources/readme.rtf

.INTERMEDIATE: main engine runtime $(INTERMEDIATES) $(PRECIOUS_INTERMEDIATES)


# INTERNAL BUILD (DEFAULT TARGET)

internal: NMH_EXTN_IDS:=$(NMH_EXTN_IDS),'\\$$'\n''        "chrome-extension:\/\/$(EXTN_ID_INTERNAL)\/"

internal: $(APP)


# UTILITY TARGETS

clean:
	rm -rf Epichrome/* epichrome-*.pkg
	rm -rf build/main* build/runtime* $(INTERMEDIATES)
	@hdiutil detach build/brave 2> /dev/null || true

clean-package:
	rm -f epichrome-*.pkg
	rm -rf build/resources build/epichrome-*.pkg build/epichrome-*.xml build/main* build/runtime* $(INTERMEDIATES)

clean-all: clean
	rm -rf build
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	for psd in ../images/icons/*.psd ../images/package/*.psd ; do \
		echo rm -f "$${psd%.psd}.png" ; done

# $$$$ FIX THIS
install: $(APP)
	rm -rf '/Applications/$(APP)'
	mkdir -p '/Applications/Epichrome'
	cp -a '$(APP)' '/Applications/$(APP)'
	mkdir '/Applications/Epichrome/EpichromeEngines.noindex'
	chmod 1777 '/Applications/Epichrome/EpichromeEngines.noindex'
	touch '/Applications/Epichrome/EpichromeEngines.noindex/.preserve'

%.png: %.psd
	open -a "$$(cd ../images ; pwd)"/PNG.app '$<'
	@read -p "Hit Enter when Photoshop has finished converting $@: " -r


# PACKAGE BUILD
# (adapted from http://thegreyblog.blogspot.com/2014/06/os-x-creating-packages-from-command_2.html)

package: epichrome-$(VERSION).pkg

epichrome-$(VERSION).pkg: build/epichrome-$(VERSION)-main.pkg build/epichrome-$(VERSION)-dist.xml build/resources/background.png build/resources/welcome.rtf $(PACKAGE_README) build/resources/license.rtf
	@rm -f '$@'
	productbuild --distribution build/epichrome-$(VERSION)-dist.xml \
		--package-path build \
		--resources build/resources \
		--sign 'David Marmor' \
		'$@'

build/epichrome-$(VERSION)-main.pkg: $(APP)
	@rm -f '$@'
	xattr -cr $(APP)
	rm -rf build/package/Applications
	@mkdir -p build/package/Applications/Epichrome/EpichromeEngines.noindex
	chmod 1777 build/package/Applications/Epichrome/EpichromeEngines.noindex
	touch build/package/Applications/Epichrome/EpichromeEngines.noindex/.preserve
	mv $(APP) build/package/Applications/$(APP)
	pkgbuild --analyze --root build/package $(@:.pkg=).plist
	/usr/libexec/PlistBuddy -c 'Set 0:BundleIsRelocatable false' $(@:.pkg=).plist
	pkgbuild --root build/package --component-plist $(@:.pkg=).plist $@
	rm -f $(@:.pkg=).plist
	mv build/package/Applications/$(APP) $(APP)
	rm build/package/Applications/Epichrome/EpichromeEngines.noindex/.preserve
	@cd build ; rmdir -p package/Applications/Epichrome/EpichromeEngines.noindex

build/resources/background.png: ../images/package/background$(BETA).png
	@mkdir -p build/resources
	cp '$<' '$@'

build/resources/welcome.rtf: src/package/welcome.rtf src/version.sh
	@mkdir -p build/resources
	sed 's/EPIVERSION/$(VERSIONTEXT)/g' '$<' > '$@'

build/resources/license.rtf: src/package/license.rtf src/version.sh
	@mkdir -p build/resources
	sed 's/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

build/resources/readme.rtf: src/package/readme.rtf src/version.sh
	@mkdir -p build/resources
	sed 's/EPIVERSION/$(VERSIONTEXT)/g' '$<' > '$@'

build/epichrome-$(VERSION)-dist.xml: build/epichrome-$(VERSION)-main.pkg src/package/requirements.plist
	@rm -f '$@'
	productbuild --synthesize \
		--product src/package/requirements.plist \
		--package '$<' \
		'$@'
	sed -E -i '' 's/enable_anywhere="true"/enable_anywhere="false"/; '\
'		s/EPIMINOS/'$(MIN_OS)'/; '\
'		s/(<pkg-ref id="org.epichrome.Epichrome"\/>.*$$)/\1'\\$$'\n'\
'    <title>Epichrome $(VERSIONTEXT)<\/title>'\\$$'\n'\
'    <background file="background.png" mime-type="image\/png" alignment="bottomleft" scaling="proportional"\/>'\\$$'\n'\
'    <welcome file="welcome.rtf" mime-type="application\/rtf"\/>'\\$$'\n'\
'    <readme file="readme.rtf" mime-type="application\/rtf"\/>'\\$$'\n'\
'    <license file="license.rtf" mime-type="application\/rtf"\/>/' '$@'


# NOTARIZE PACKAGE

notarize: epichrome-$(VERSION).pkg
#	https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
#	sudo xcode-select -r
#	  # to find ProviderShortname for --asc-provider
#	xcrun altool --list-providers -u "dmarmor@gmail.com" -p "@keychain:AppleID altool notarize"
#	  # to store AppleID app password credential in keychain:
#	xcrun altool --store-password-in-keychain-item 'KEYCHAIN_ITEM' -u 'USERNAME' -p 'PASSWORD'
	@echo '*** This should only be done after thorough testing that the package is correct.' ; \
	read -p "Send $< to Apple for notarization? (y/n [n]) " -r ; \
	if [[ "$$REPLY" =~ ^[Yy]$$ ]] ; then \
		request_id='notarize-request.'"$$(date '+%Y%m%d-%H%M%S')" ; \
		xcrun altool --notarize-app \
               --primary-bundle-id 'org.epichrome.Epichrome.$(VERSION).'"$$request_id" \
               $(NOTARIZE_CREDENTIALS) \
               --file epichrome-$(VERSION).pkg > '$(<:.pkg=).'"$$request_id"'.txt' ; \
		result=$$? ; cat '$(<:.pkg=).'"$$request_id"'.txt' ; exit $$result ; fi

notarize-check:
	@request_file="$$(ls epichrome-$(VERSION).notarize*.txt 2> /dev/null | sort | tail -n 1)" ; \
	if [[ "$$request_file" ]] ; then \
		echo "Checking $$request_file..." ; \
		xcrun altool --notarization-info \
		"$$(sed -En 's/RequestUUID *= *([^ ]+) *$$/\1/p' "$$request_file")" \
		$(NOTARIZE_CREDENTIALS) > "$${request_file%.txt}.check.txt" ; \
		cat "$${request_file%.txt}.check.txt" ; \
		curl --silent --show-error \
			"$$(sed -En 's/^ *LogFileURL: *(.+)$$/\1/p' "$${request_file%.txt}.check.txt")" > \
			"$${request_file%.txt}.json" ; \
		echo 'Created check file & issues manifest.' ; \
	else echo 'No request file found.' ; fi

notarize-staple: epichrome-$(VERSION).pkg
	@echo '*** This should only be done after notarization has been accepted by Apple.' ; \
	read -p "Staple notarization for $<? (y/n [n]) " -r ; \
	if [[ "$$REPLY" =~ ^[Yy]$$ ]] ; then \
		xcrun stapler staple '$<' ; fi


# CODESIGNING

%.app: src/package/entitlements.plist
	xattr -cr '$@'
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
	$(APP_RNTM)/epichrome.dat \
	\
	$(APP_RNTM)/Contents/Resources/MainMenu.nib \
	$(APP_RNTM)/Contents/Resources/AppSettings.plist \
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
	$(APP_RNTM_HLPR) \
	\
	$(APP_RNTM)/Engine/Filter/PlaceholderExec \
	$(APP_RNTM)/Engine/Filter/Info.plist \
	$(APP_RNTM)/Engine/Payload \
	$(APP_RNTM)/Engine/Link/Frameworks \
	\
	$(APP_RNTM)/Resources/Scripts/runtime.sh

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
	sed -e 's/EPIVERSION/$(VERSION)/g; s/EPIDEBUG/$(DEBUG_SH)/g; s/EPILOGPRESERVE/$(LOGPRESERVE_SH)/g' '$<' > '$@'

$(APP_CT)/Info.plist: src/Info.plist src/version.sh
	@mkdir -p $(APP_CT)
	sed 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

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

$(APP_RNTM)/epichrome.dat \
$(APP_RNTM)/Contents/Resources/MainMenu.nib \
$(APP_RNTM)/Contents/Resources/AppSettings.plist: runtime

runtime:
	@rm -rf build/runtime.app build/runtime
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
#	alt:	--suffixes 'gif|html|htm|xhtml|js|jpg|jpeg|mhtml|mht|oga|ogg|ogv|png|svg|txt|text|webm|webp|pdf|'
	mv build/runtime.app/Contents build/runtime
	rmdir build/runtime.app
	@rm build/fake.icns build/fake.sh
	@cd build/runtime && rm -f Info.plist Resources/*.icns Resources/script
	@mkdir -p $(APP_RNTM)/Contents/Resources
	mv -f build/runtime/Resources/MainMenu.nib $(APP_RNTM)/Contents/Resources/MainMenu.nib
	mv -f build/runtime/Resources/AppSettings.plist $(APP_RNTM)/Contents/Resources/AppSettings.plist
	openssl AES-128-CBC -k data -in 'build/runtime/MacOS/Epichrome' -out '$(APP_RNTM)/epichrome.dat'
	@rm build/runtime/MacOS/Epichrome
	@rmdir build/runtime/MacOS
	@cd build && if ! rmdir -p runtime/Resources ; then \
		echo '*** Unexpected files found in Platypus runtime app (check build/runtime).' 1>&2 ; false ; fi


# RUNTIME FILTER ELEMENTS

$(APP_RNTM)/Filter/Info.plist: src/Info.plist.runtime src/version.sh
	@mkdir -p $(APP_RNTM)/Filter
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

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

build/icons/%.icns: ../images/icons/%.png
	@mkdir -p build/icons
	src/makeicon.sh -f $< $@


# EPICHROME HELPER

$(APP_RNTM_HLPR): | $(APP_RNTM_HLPR_CT)/Info.plist \
	$(APP_RNTM_HLPR_CT)/MacOS/EpichromeHelper

$(APP_RNTM_HLPR_CT)/Info.plist: src/helper/Info.plist
	@mkdir -p $(APP_RNTM_HLPR_CT)
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

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

build/img/icon128$(BETA).png: ../images/icons/app$(BETA).png
	@mkdir -p build/img
	sips -z 128 128 $< --out $@


# *** ENGINE ***

build/engine/%:
	@rm -rf build/engine/$*
	@mkdir -p build/engine
	tar xzvf '$<' --cd build/engine


# CODESIGNED CHROMIUM

build/engine/Chromium: $(CHROMIUM)

CHROMIUM_FRAMEWORK:=build/chromium/Contents/Frameworks/Chromium Framework.framework
# find Chromium.app -exec bash -c 'codesign --verify --deep --strict "{}" 2> /dev/null && codesign --verify --deep --strict --verbose=2 "{}"' ';'
$(CHROMIUM): $(CHROMIUM:.tgz=.zip)
	@mkdir -p build/chromium
	tar xzvf '$<' --cd build/chromium --strip-components 1
	codesign --remove-signature -vv build/chromium
	rm -rf build/chromium/Contents/_CodeSignature
	rm build/chromium/Contents/CodeResources
# codesign --remove-signature -vv \
# 	'$(CHROMIUM_FRAMEWORK)' \
# 	'$(CHROMIUM_FRAMEWORK)/Versions/Current/XPCServices/AlertNotificationService.xpc' \
# 	'$(CHROMIUM_FRAMEWORK)/Versions/Current/Helpers/'*
# rmdir '$(CHROMIUM_FRAMEWORK)/Versions/Current/_CodeSignature' \
# 	'$(CHROMIUM_FRAMEWORK)/Versions/Current/XPCServices/AlertNotificationService.xpc/Contents/_CodeSignature' \
# 	'$(CHROMIUM_FRAMEWORK)/Versions/Current/Helpers/'*.app/Contents/_CodeSignature
	src/signmatch.sh '/Applications/Google Chrome.app' build/chromium \
		'$(CHROMIUM_FRAMEWORK)/Versions/Current/Libraries/'*.dylib \
		'$(CHROMIUM_FRAMEWORK)/Versions/Current/Helpers/'* \
		'$(CHROMIUM_FRAMEWORK)/Versions/Current/XPCServices/AlertNotificationService.xpc' \
		'$(CHROMIUM_FRAMEWORK)'
#		'build/chromium'
	@rm -rf build/engine/Chromium
	@mkdir -p build/engine
	mv build/chromium/Contents build/engine/Chromium
	rmdir build/chromium
	tar czvf '$@' --cd build/engine Chromium
	@touch build/engine/Chromium


# BRAVE MINUS SPARKLE

build/engine/Brave: $(BRAVE)

BRAVE_FRAMEWORK:=build/brave/Contents/Frameworks/Brave Browser Framework.framework
$(BRAVE): $(BRAVE:.tgz=.dmg)
	@rm -rf build/brave
	hdiutil attach -nobrowse -mountpoint build/bravedmg '$<'
	cp -PRv 'build/bravedmg/Brave Browser.app' build/brave
	hdiutil detach build/bravedmg
	codesign --remove-signature -vv build/brave
	rmdir build/brave/Contents/_CodeSignature
	rm build/brave/Contents/CodeResources
	@if [[ ! -d '$(BRAVE_FRAMEWORK)/Versions/Current/Frameworks/Sparkle.framework' ]] ; then \
		echo '*** Unable to find Sparkle.framework' 1>&2 ; false ; fi
	rm -rf '$(BRAVE_FRAMEWORK)/Versions/Current/Frameworks/Sparkle.framework'
	xattr -cr build/brave
	src/signmatch.sh '' \
		'$(BRAVE_FRAMEWORK)/Versions/Current/Helpers/'* \
		'$(BRAVE_FRAMEWORK)/Versions/Current/Libraries/'*.dylib \
		'$(BRAVE_FRAMEWORK)/Versions/Current/XPCServices/AlertNotificationService.xpc' \
		'$(BRAVE_FRAMEWORK)'
#		'build/brave'
	@rm -rf build/engine/Brave
	mv build/brave/Contents build/engine/Brave
	rmdir build/brave
	tar czvf '$@' --cd build/engine Brave
	@touch build/engine/Brave


# ENGINE FILTER ELEMENTS

$(APP_RNTM)/Engine/Filter/Info.plist $(APP_RNTM)/Engine/Payload $(APP_RNTM)/Engine/Link/Frameworks: \
		$(CHROMIUM) src/version.sh engine

engine: build/engine/Brave
	@if [[ "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' build/engine/Brave/Info.plist)" != 'app.icns' ]] ; then \
		echo '*** Internal engine app icon name has changed.' 1>&2 ; false ; fi
	/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' \
				-c 'Delete :CFBundleDocumentTypes' \
				-c 'Delete :CFBundleURLTypes' \
				build/engine/Brave/Info.plist
	@mkdir -p $(APP_RNTM)/Engine/Filter
	mv -f build/engine/Brave/Info.plist $(APP_RNTM)/Engine/Filter/Info.plist
	rm -rf $(APP_RNTM)/Engine/Link $(APP_RNTM)/Engine/Payload
	mkdir -p $(APP_RNTM)/Engine/Link
	mv build/engine/Brave/Frameworks $(APP_RNTM)/Engine/Link/Frameworks
	@touch $(APP_RNTM)/Engine/Link/Frameworks
	rm -f build/engine/Brave/Resources/*.icns
	openssl AES-128-CBC -k data -in 'build/engine/Brave/MacOS/Brave Browser' -out '$(APP_RNTM)/Engine/exec.dat'
	rm 'build/engine/Brave/MacOS/Brave Browser'
	rmdir build/engine/Brave/MacOS
	mv build/engine/Brave $(APP_RNTM)/Engine/Payload
	@touch $(APP_RNTM)/Engine/Payload

$(APP_RNTM)/Engine/Filter/PlaceholderExec: src/PlaceholderExec src/version.sh
	@mkdir -p $(APP_RNTM)/Engine/Filter
	sed 's/EPIVERSION/$(VERSION)/g' $< > $@


# *** LEGACY UPDATE CODE ***

$(APP_RNTM)/Resources/Scripts/runtime.sh: src/runtime.sh
	@mkdir -p $(APP_RNTM)/Resources/Scripts
	cp '$<' '$@'
