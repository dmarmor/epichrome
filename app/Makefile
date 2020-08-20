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

CODESIGN_IDENTITY:=$(shell cat private/codesign_identity.txt)

THISYEAR:=$(shell date '+%Y')

GITHUB_UPDATE_URL:=https:\/\/github.com\/dmarmor\/epichrome\/releases\/latest


# VERSION INFO

VERSION:=$(shell source src/version.sh && echo "$$epiVersion")

BUILDNUM:=$(shell source src/version.sh ; \
			read -p "$$(printf 'Bump build number (%03d -> %03d)? [n] ' $$epiBuildNum $$(($$epiBuildNum + 1)))" ans && \
			if [[ "$$ans" =~ ^[Yy] ]] ; then \
				epiBuildNum="$$(($$epiBuildNum + 1))" ; \
				sed -i '' -E 's/^epiBuildNum=.*$$/epiBuildNum='"$$epiBuildNum"'/' src/version.sh ; \
			fi ; \
			echo "$$epiBuildNum")

VERSIONMAJOR:=$(shell version='$(VERSION)' && echo "$${version%.*}")

VERSIONCODE:=$(shell src/versioncode.sh '$(VERSION)[$(BUILDNUM)]')
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

# CHROMIUM:=$(shell ls Engines/Chromium* 2> /dev/null | sort -r | head -n 1)
# ifeq ($(CHROMIUM),)
# $(error Unable to find Chromium archive)
# endif
# ifneq ($(suffix $(CHROMIUM)),.tgz)
# ifneq ($(suffix $(CHROMIUM)),.zip)
# $(error Unrecognized file in Engines directory: $(CHROMIUM))
# endif
# CHROMIUM:=$(CHROMIUM:.zip=.tgz)
# endif
# CHROMIUM_VERSION:=$(shell if [[ '$(CHROMIUM)' =~ [0-9][0-9.]*[0-9] ]] ; then \
# 				echo "$${BASH_REMATCH[0]}" ; else echo ERROR ; fi)
# ifeq ($(CHROMIUM_VERSION),ERROR)
# $(error Unable to retrieve Chromium version from $(CHROMIUM))
# endif


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
$(error Unable to retrieve Brave version from $(BRAVE))
endif


# NOTARIZE INFO

NOTARIZE_REQUEST_FILE:=$(shell ls epichrome-$(VERSION).notarize_request_*.txt 2> /dev/null | sort | tail -n 1)


# BETA CONDITIONAL INFO

ifeq ($(BETA),_beta)
DEBUG_SH:=1
DEBUG_PY:=debug = True
LOGPRESERVE_SH:=9
BACKUPPRESERVE_SH:=9
EPICHROME_DISPNAME:=Epichrome Beta
PACKAGE_README:=build/resources/readme.rtf
else
DEBUG_SH:=
DEBUG_PY:=debug = False
LOGPRESERVE_SH:=4
BACKUPPRESERVE_SH:=4
EPICHROME_DISPNAME:=Epichrome
PACKAGE_README:=build/resources/readme.rtf
endif


NMH_EXTN_IDS:="chrome-extension:\/\/$(EXTN_ID_RELEASE)\/",'\\$$'\n''        "chrome-extension:\/\/$(EXTN_ID_BETA)\/"


# APP PATHS

APP_CT:=$(APP)/Contents
APP_RNTM:=$(APP_CT)/Resources/Runtime
APP_RNTM_HLPR:=$(APP_RNTM)/Contents/Resources/EpichromeMonitor.app
APP_RNTM_HLPR_CT:=$(APP_RNTM_HLPR)/Contents


# META-TARGETS

INTERMEDIATES:=\
	build/main.js \
	build/launch.js \
	build/engine/Brave \
	build/engine/Chromium \
	build/engine_tmp/brave \
	build/engine_tmp/brave_dmg \
	build/engine_tmp/brave_recodesign.sh \
	build/engine_tmp/brave_signature.txt \
	build/engine_tmp/brave_entitlements.plist \
	build/fake.icns \
	build/fake.sh \
	build/Chromium.app \
	build/package \
	build/epichrome-$(VERSION)-main.plist \
	build/epichrome-$(VERSION)-dist.xml


PRECIOUS_INTERMEDIATES:=\
	../images/icons/app.png \
	../images/icons/app_beta.png \
	../images/icons/docbg.png \
	../images/icons/document.png \
	../images/icons/document_beta.png \
	../images/icons/epichrome.png \
	../images/icons/epichrome_beta.png \
	../images/icons/folder.png \
	build/icons/app.icns \
	build/icons/app_beta.icns \
	build/icons/document.icns \
	build/icons/document_beta.icns \
	build/icons/epichrome.icns \
	build/icons/epichrome_beta.icns \
	build/icons/folder.icns \
	build/img/app_icon.png \
	build/img/app_icon_beta.png \
	build/img/epichrome_icon.png \
	build/epichrome-$(VERSION)-main.pkg \
	build/resources/background.png \
	build/resources/license.rtf \
	build/resources/readme.rtf \
	build/resources/welcome.rtf

.DELETE_ON_ERROR:

.PHONY: internal package clean clean-package clean-engine clean-all verify notarize notarize-check notarize-staple

.PRECIOUS: $(PRECIOUS_INTERMEDIATES)

.INTERMEDIATE: main engine runtime $(INTERMEDIATES) $(PRECIOUS_INTERMEDIATES)


# INTERNAL BUILD (DEFAULT TARGET)

internal: NMH_EXTN_IDS:=$(NMH_EXTN_IDS),'\\$$'\n''        "chrome-extension:\/\/$(EXTN_ID_INTERNAL)\/"

internal: VERSION:=$(VERSION)[$(shell printf '%03d' '$(BUILDNUM)')]

internal: $(APP)


# UTILITY TARGETS

clean:
	rm -rf Epichrome/Epichrome.app
	rm -rf build/main* build/runtime* build/engine build/engine_tmp build/resources $(INTERMEDIATES)
	@hdiutil detach build/dmg 2> /dev/null || true

clean-package:
	rm -f epichrome-*.pkg
	rm -rf build/resources build/epichrome-*.pkg build/epichrome-*.xml build/main* build/runtime* $(INTERMEDIATES)

clean-engine:
	rm -f $(BRAVE)

clean-all: clean clean-package clean-engine
	rm -rf build
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	for psd in ../images/icons/*.psd ../images/package/*.psd ; do \
		echo rm -f "$${psd%.psd}.png" ; done

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
		--sign '$(CODESIGN_IDENTITY)' \
		'$@'

build/epichrome-$(VERSION)-main.pkg: $(APP) build/icons/folder.icns
	@rm -f '$@'
	xattr -cr $(APP)
	rm -rf build/package/Applications
	mkdir -p build/package/Applications/Epichrome/EpichromeEngines.noindex
	chmod 1777 build/package/Applications/Epichrome/EpichromeEngines.noindex
	../modules/fileicon/bin/fileicon set \
		build/package/Applications/Epichrome \
		build/icons/folder.icns
	touch build/package/Applications/Epichrome/EpichromeEngines.noindex/.preserve
	mv $(APP) 'build/package/Applications/Epichrome/$(EPICHROME_DISPNAME).app'
	if ! ( pkgbuild --analyze --root build/package $(@:.pkg=).plist && \
	/usr/libexec/PlistBuddy -c 'Set 0:BundleIsRelocatable false' $(@:.pkg=).plist && \
	pkgbuild --root build/package --component-plist $(@:.pkg=).plist '$@' && \
	rm -f '$(@:.pkg=).plist' ) ; then \
		mv 'build/package/Applications/Epichrome/$(EPICHROME_DISPNAME).app' $(APP) ; false ; fi
	mv 'build/package/Applications/Epichrome/$(EPICHROME_DISPNAME).app' $(APP)
	rm -rf build/package/Applications
	@cd build ; rmdir -p package

build/resources/background.png: ../images/package/background$(BETA).png
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

build/resources/welcome.rtf: src/package/welcome$(BETA).rtf src/version.sh
	@mkdir -p '$(dir $@)'
	sed 's/EPIVERSION/$(VERSIONTEXT)/g' '$<' > '$@'

build/resources/license.rtf: src/package/license.rtf src/version.sh
	@mkdir -p '$(dir $@)'
	sed 's/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

build/resources/readme.rtf: src/package/readme.rtf src/version.sh
	@mkdir -p '$(dir $@)'
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

notarize:
#	https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
#	sudo xcode-select -r
#	  # to find ProviderShortname for --asc-provider
#	xcrun altool --list-providers -u "dmarmor@gmail.com" -p "@keychain:AppleID altool notarize"
#	  # to store AppleID app password credential in keychain:
#	xcrun altool --store-password-in-keychain-item 'KEYCHAIN_ITEM' -u 'USERNAME' -p 'PASSWORD'
	@if [[ ! -f 'epichrome-$(VERSION).pkg' ]] ; then \
		echo '*** Unable to find epichrome-$(VERSION).pkg' ; false ; \
	fi
	@echo '*** This should only be done after thorough testing that the package is correct.' ; \
	read -p "Send epichrome-$(VERSION).pkg to Apple for notarization? (y/n [n]) " -r ; \
	if [[ "$$REPLY" =~ ^[Yy]$$ ]] ; then \
		request_id='notarize-request.'"$$(date '+%Y%m%d-%H%M%S')" ; \
		xcrun altool --notarize-app \
               --primary-bundle-id 'org.epichrome.Epichrome.$(VERSION).'"$$request_id" \
               $(NOTARIZE_CREDENTIALS) \
               --file epichrome-$(VERSION).pkg > 'epichrome-$(VERSION).'"$$request_id"'.txt' ; \
		result=$$? ; cat 'epichrome-$(VERSION).'"$$request_id"'.txt' ; exit $$result ; fi

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

notarize-staple: notarize-check
	@if [[ ! -f 'epichrome-$(VERSION).pkg' ]] ; then \
		echo '*** Unable to find epichrome-$(VERSION).pkg' ; false ; \
	fi
	@echo '*** This should only be done after notarization has been accepted by Apple.' ; \
	read -p "Staple notarization for epichrome-$(VERSION).pkg? (y/n [n]) " -r ; \
	if [[ "$$REPLY" =~ ^[Yy]$$ ]] ; then \
		xcrun stapler staple 'epichrome-$(VERSION).pkg' ; fi


# CODESIGNING

%.app: src/package/entitlements.plist
	xattr -cr '$@'
	codesign -vv --force --options runtime --entitlements src/package/entitlements.plist \
		-s '$(CODESIGN_IDENTITY)' '$@'
	codesign --verify --deep --strict --verbose=2 '$@'
	spctl --assess --type execute --verbose=4 '$@'
	touch '$@'

verify:
	codesign --verify --deep --strict --verbose=2 '$(APP)'
	spctl --assess --type execute --verbose=4 '$(APP)'


# *** MAIN APP ***

# MAIN APP DEPENDENCIES

$(APP):	$(APP_CT)/PkgInfo \
	$(APP_CT)/MacOS/droplet \
	$(APP_CT)/Resources/droplet.rsrc \
	$(APP_CT)/Resources/Scripts/main.scpt \
	\
	$(APP_CT)/Info.plist \
	\
	$(APP_CT)/Resources/droplet.icns \
	$(APP_CT)/Resources/docbg.png \
	\
	$(APP_CT)/Resources/Scripts/epichrome.sh \
	$(APP_CT)/Resources/Scripts/makeicon.sh \
	$(APP_CT)/Resources/Scripts/update.sh \
	$(APP_CT)/Resources/Scripts/version.sh \
	$(APP_CT)/Resources/Scripts/epichromeruntimehost.py \
	\
	$(APP_RNTM)/Filter/Info.plist \
	$(APP_RNTM)/Filter/AppExec \
	$(APP_RNTM)/Filter/main.sh \
	$(APP_RNTM)/Filter/epichromeruntimehost.py \
	$(APP_RNTM)/Filter/welcome.html \
	$(APP_RNTM)/Filter/Bookmarks \
	$(APP_RNTM)/Filter/Prefs/prefs_com_brave_Browser.json \
	$(APP_RNTM)/Filter/Prefs/prefs_com_google_Chrome.json \
	$(APP_RNTM)/Filter/Prefs/prefs_nourl_com_brave_Browser.json \
	$(APP_RNTM)/Filter/Prefs/prefs_nourl_com_google_Chrome.json \
	\
	$(APP_RNTM)/Exec/Epichrome \
	\
	$(APP_RNTM)/Contents/Resources/MainMenu.nib \
	$(APP_RNTM)/Contents/Resources/AppSettings.plist \
	$(APP_RNTM)/Contents/Resources/app.icns \
	$(APP_RNTM)/Contents/Resources/document.icns \
	\
	$(APP_RNTM)/Contents/Resources/Scripts/core.sh \
	$(APP_RNTM)/Contents/Resources/Scripts/filter.sh \
	$(APP_RNTM)/Contents/Resources/Scripts/launch.sh \
	$(APP_RNTM)/Contents/Resources/Scripts/launch.scpt \
	\
	$(APP_RNTM)/Contents/Resources/NMH/$(NMH_ID).json \
	\
	$(APP_RNTM)/Contents/Resources/Welcome/welcome.css \
	$(APP_RNTM)/Contents/Resources/Welcome/welcome.js \
	$(APP_RNTM)/Contents/Resources/Welcome/img/app_icon.png \
	$(APP_RNTM)/Contents/Resources/Welcome/img/bookmark.png \
	$(APP_RNTM)/Contents/Resources/Welcome/img/epichrome_icon.png \
	$(APP_RNTM)/Contents/Resources/Welcome/img/ext_generic_icon.png \
	$(APP_RNTM)/Contents/Resources/Welcome/img/passwords_button.png \
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

$(APP_CT)/PkgInfo $(APP_CT)/MacOS/droplet \
$(APP_CT)/Resources/droplet.rsrc \
$(APP_CT)/Resources/Scripts/main.scpt: src/main.js src/liblaunch.js src/version.sh main

main:
	@mkdir -p build
	@rm -rf build/main.app build/main
	sed -e 's/EPIVERSION/$(VERSION)/g; s/GITHUBUPDATEURL/$(GITHUB_UPDATE_URL)/g' \
		src/main.js > build/main.js
	echo >> build/main.js
	cat src/liblaunch.js >> build/main.js
	osacompile -l JavaScript -x -o build/main.app build/main.js
	chmod 444 build/main.app/Contents/Resources/Scripts/main.scpt  # lock main.scpt so it doesn't get altered with each run
	@mv build/main.app build/main
	@rm -f build/main.js
	@cd build/main/Contents && rm -f Info.plist Resources/droplet.icns
	@mkdir -p $(APP_CT)/MacOS $(APP_CT)/Resources/Scripts
	mv -f build/main/Contents/Resources/Scripts/main.scpt $(APP_CT)/Resources/Scripts/main.scpt
	@touch $(APP_CT)/Resources/Scripts/main.scpt
	mv -f build/main/Contents/PkgInfo $(APP_CT)/PkgInfo
	mv -f build/main/Contents/MacOS/droplet $(APP_CT)/MacOS/droplet
	mv -f build/main/Contents/Resources/droplet.rsrc $(APP_CT)/Resources/droplet.rsrc
	@touch $(APP_CT)/PkgInfo $(APP_CT)/MacOS/droplet $(APP_CT)/Resources/droplet.rsrc
	rmdir build/main/Contents/MacOS
	@cd build && if ! rmdir -p main/Contents/Resources/Scripts ; then \
		echo "*** Unexpected files found in main app (check build/main)." 1>&2 ; false ; fi
	@touch $(APP)


# MAIN APP BUNDLE ELEMENTS

$(APP_CT)/Info.plist: src/Info.plist src/version.sh
	@mkdir -p '$(dir $@)'
	sed 's/EPIDISPNAME/$(EPICHROME_DISPNAME)/g; s/EPISHORTNAME/$(EPICHROME_DISPNAME)/g; s/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

$(APP_CT)/Resources/droplet.icns: build/icons/epichrome$(BETA).icns
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_CT)/Resources/docbg.png: ../images/icons/docbg.png
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_CT)/Resources/Scripts/version.sh: src/version.sh
	@mkdir -p '$(dir $@)'
	sed -E 's/^epiVersion=.*$$/epiVersion='\''$(VERSION)'\''/' '$<' > '$@'

$(APP_CT)/Resources/Scripts/update.sh: src/update.sh src/version.sh
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSION/$(VERSION)/g' '$<' > '$@'

$(APP_CT)/Resources/Scripts/%.sh: src/%.sh
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_CT)/Resources/Scripts/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSION/$(VERSION)/g' \
		-e 's/debug = True/$(DEBUG_PY)/g' \
		-e 's/APPID//g' \
		-e 's/APPBUNDLENAME//g' \
		-e 's/APPDISPLAYNAME//g' \
		'$<' > '$@'
	chmod 755 '$@'


# *** RUNTIME CORE ***

# RUNTIME CORE

$(APP_RNTM)/Exec/Epichrome \
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
		 --interpreter /bin/bash \
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
	mv build/runtime.app/Contents build/runtime
	rmdir build/runtime.app
	@rm build/fake.icns build/fake.sh
	@cd build/runtime && rm -f Info.plist Resources/*.icns Resources/script
	@mkdir -p $(APP_RNTM)/Contents/Resources
	mv -f build/runtime/Resources/MainMenu.nib $(APP_RNTM)/Contents/Resources/MainMenu.nib
	mv -f build/runtime/Resources/AppSettings.plist $(APP_RNTM)/Contents/Resources/AppSettings.plist
	@mkdir -p $(APP_RNTM)/Exec
	mv -f 'build/runtime/MacOS/Epichrome' $(APP_RNTM)/Exec
	xattr -c $(APP_RNTM)/Exec/Epichrome
	codesign -vv -s '$(CODESIGN_IDENTITY)' \
		--identifier 'org.epichrome.launcher' \
		--option runtime \
		--entitlements 'src/package/entitlements.plist' \
		$(APP_RNTM)/Exec/Epichrome
	@rmdir build/runtime/MacOS
	@cd build && if ! rmdir -p runtime/Resources ; then \
		echo '*** Unexpected files found in Platypus runtime app (check build/runtime).' 1>&2 ; false ; fi


# RUNTIME FILTER ELEMENTS

$(APP_RNTM)/Filter/Info.plist: src/Info.plist.runtime src/version.sh
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

$(APP_RNTM)/Filter/AppExec: src/AppExec src/version.sh
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'
	
$(APP_RNTM)/Filter/main.sh: src/main.sh src/version.sh
	sed -e 's/EPIVERSION/$(VERSION)/g' $< > $@

$(APP_RNTM)/Filter/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSION/$(VERSION)/g; s/debug = True/$(DEBUG_PY)/g' $< > $@


# RUNTIME ICONS

$(APP_RNTM)/Contents/Resources/%.icns: build/icons/%$(BETA).icns src/version.sh
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

build/icons/%.icns: ../images/icons/%.png
	@mkdir -p '$(dir $@)'
	src/makeicon.sh -f $< $@


# EPICHROME MONITOR

$(APP_RNTM_HLPR): $(APP_RNTM_HLPR_CT)/Info.plist \
	$(APP_RNTM_HLPR_CT)/MacOS/EpichromeMonitor

$(APP_RNTM_HLPR_CT)/Info.plist: src/monitor/Info.plist
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSIONCODE/$(VERSIONCODE)/g; s/EPIVERSION/$(VERSION)/g; s/THISYEAR/$(THISYEAR)/g' '$<' > '$@'

$(APP_RNTM_HLPR_CT)/MacOS/EpichromeMonitor: src/monitor/EpichromeMonitor
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'


# RUNTIME SCRIPTS

$(APP_RNTM)/Contents/Resources/Scripts/core.sh: src/core.sh src/version.sh
	@mkdir -p '$(dir $@)'
	sed 's/EPIVERSION/$(VERSION)/g; s/EPIDEBUG/$(DEBUG_SH)/g; s/EPILOGPRESERVE/$(LOGPRESERVE_SH)/g; s/EPIBACKUPPRESERVE/$(BACKUPPRESERVE_SH)/g' '$<' > '$@'

$(APP_RNTM)/Contents/Resources/Scripts/launch.sh: src/launch.sh
	@mkdir -p '$(dir $@)'
	sed 's/EPIEXTIDRELEASE/$(EXTN_ID_RELEASE)/g; s/GITHUBUPDATEURL/$(GITHUB_UPDATE_URL)/g' '$<' > '$@'

$(APP_RNTM)/Contents/Resources/Scripts/launch.scpt: build/launch.js
	osacompile -l JavaScript -x -o '$@' '$<'
	
build/launch.js: src/launch.js src/liblaunch.js
	sed 's/EPIVERSION/$(VERSION)/g' '$<' > '$@'
	cat 'src/liblaunch.js' >> '$@'

$(APP_RNTM)/Contents/Resources/Scripts/%.sh: src/%.sh
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'


# PROFILE FILES

$(APP_RNTM)/Filter/Bookmarks: src/profile/bookmarks.json
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_RNTM)/Filter/Prefs/prefs_nourl_%.json: src/profile/prefs_%.json
	@mkdir -p '$(dir $@)'
	sed 's/"restore_on_startup": 5/"restore_on_startup": 1/' '$<' > '$@'

$(APP_RNTM)/Filter/Prefs/%.json: src/profile/%.json
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'


# CHROME EXTENSION

$(APP_RNTM)/Contents/Resources/NMH/$(NMH_ID).json: src/$(NMH_ID).json src/version.sh
	@mkdir -p '$(dir $@)'
	sed -E -e 's/EPIVERSION/$(VERSION)/g; s/EPIRUNTIMEIDS/$(NMH_EXTN_IDS)/' $< > $@


# WELCOME PAGE

$(APP_RNTM)/Filter/welcome.html: src/welcome/welcome.html src/version.sh
	@mkdir -p '$(dir $@)'
	sed -e 's/EPIVERSION/$(VERSION)/g; s/EPIMAJORVERSION/$(VERSIONMAJOR)/g; s/EPIEXTIDRELEASE/$(EXTN_ID_RELEASE)/g; s/EPIEXTIDBETA/$(EXTN_ID_BETA)/g' '$<' > '$@'

$(APP_RNTM)/Contents/Resources/Welcome/welcome.%: src/welcome/welcome.%
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_RNTM)/Contents/Resources/Welcome/img/app_icon.png: build/img/app_icon$(BETA).png
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_RNTM)/Contents/Resources/Welcome/img/epichrome_icon.png: build/img/epichrome_icon.png
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

$(APP_RNTM)/Contents/Resources/Welcome/img/%: src/welcome/img/%
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'

build/img/app_icon$(BETA).png: ../images/icons/app$(BETA).png
	@mkdir -p '$(dir $@)'
	sips -z 128 128 $< --out $@

build/img/epichrome_icon.png: ../images/icons/app.png
	@mkdir -p '$(dir $@)'
	sips -z 128 128 $< --out $@


# *** ENGINE ***

build/engine/%:
	@rm -rf build/engine/$*
	@mkdir -p '$(dir $@)'
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
	rm -f build/chromium/Contents/CodeResources
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

BRAVE_FRAMEWORK:=build/engine_tmp/brave/Contents/Frameworks/Brave Browser Framework.framework
$(BRAVE): build/engine_tmp/brave
	@rm -rf build/engine/Brave
	@mkdir -p build/engine
	mv build/engine_tmp/brave/Contents build/engine/Brave
	rmdir build/engine_tmp/brave
	tar czvf '$@' --cd build/engine Brave
	@touch build/engine/Brave
	rm -rf build/engine_tmp

build/engine_tmp/brave: build/engine_tmp/brave_dmg build/engine_tmp/brave_recodesign.sh
	@rm -rf '$@'
	mv -f '$<' '$@'
	codesign --remove-signature build/engine_tmp/brave
	rmdir build/engine_tmp/brave/Contents/_CodeSignature
	rm build/engine_tmp/brave/Contents/CodeResources
	mkdir build/engine_tmp/brave/Contents/Exec
	mv -f 'build/engine_tmp/brave/Contents/MacOS/Brave Browser' build/engine_tmp/brave/Contents/Exec
	rmdir build/engine_tmp/brave/Contents/MacOS
	xattr -c 'build/engine_tmp/brave/Contents/Exec/Brave Browser'
	/bin/sh 'build/engine_tmp/brave_recodesign.sh'
	codesign --display -vv --entitlements - 'build/engine_tmp/brave/Contents/Exec/Brave Browser' 1>&2
	rm -f 'build/engine_tmp/brave_recodesign.sh' 'build/engine_tmp/brave_entitlements.plist'
	@if [[ ! -d '$(BRAVE_FRAMEWORK)/Versions/Current/Frameworks/Sparkle.framework' ]] ; then \
		echo '*** Unable to find Sparkle.framework' 1>&2 ; false ; fi
	rm -rf '$(BRAVE_FRAMEWORK)/Versions/Current/Frameworks/Sparkle.framework'
	xattr -cr build/engine_tmp/brave
	src/signmatch.sh '' \
		'$(BRAVE_FRAMEWORK)/Versions/Current/Helpers/'* \
		'$(BRAVE_FRAMEWORK)/Versions/Current/Libraries/'*.dylib \
		'$(BRAVE_FRAMEWORK)/Versions/Current/XPCServices/AlertNotificationService.xpc' \
		'$(BRAVE_FRAMEWORK)'

#flags="$${opts#*CodeDirectory}" && flags="$${flags%%Signature*}"
build/engine_tmp/brave_recodesign.sh:
	@mkdir -p build/engine_tmp
	printf "codesign -s '$(CODESIGN_IDENTITY)' -vv --identifier org.epichrome.engine.brave" > '$@'
	opts="$$(codesign --display -v --entitlements - 'build/engine_tmp/brave_dmg/Contents/MacOS/Brave Browser' 2>&1)" && \
	ents="<?xml$${opts##*<?xml}" && \
	touch 'build/engine_tmp/brave_entitlements.plist' && \
	if [[ "$$opts" =~ flags=0x[0-9a-z]+\(([^ ]+)\) ]] ; then \
		if [[ "$${BASH_REMATCH[1]}" != 'none' ]] ; then \
			printf " --options \"$${BASH_REMATCH[1]}\"" >> '$@' ; \
			if [[ "$$ents" != "$$opts" ]] ; then \
				echo "$$ents" > 'build/engine_tmp/brave_entitlements.plist' ; \
				printf " --entitlements 'build/engine_tmp/brave_entitlements.plist'" >> '$@' ; \
				/usr/libexec/PlistBuddy \
					-c 'Set :com.apple.application-identifier $(CODESIGN_IDENTITY).org.epichrome.engine.brave'  \
					-c 'Delete :keychain-access-groups' \
					'build/engine_tmp/brave_entitlements.plist' ; \
			fi ; \
		fi ; \
	fi
	printf " 'build/engine_tmp/brave/Contents/Exec/Brave Browser'" >> '$@'

build/engine_tmp/brave_dmg: $(BRAVE:.tgz=.dmg)
	@rm -rf build/engine_tmp
	@mkdir -p build/engine_tmp
	hdiutil attach -nobrowse -mountpoint build/dmg '$<' && \
	cp -PRv 'build/dmg/Brave Browser.app' build/engine_tmp/brave_dmg ; \
	hdiutil detach build/dmg
	touch build/engine_tmp/brave_dmg


# ENGINE FILTER ELEMENTS

$(APP_RNTM)/Engine/Filter/Info.plist \
$(APP_RNTM)/Engine/Exec/Brave Browser \
$(APP_RNTM)/Engine/Payload \
$(APP_RNTM)/Engine/Link/Frameworks: \
		$(BRAVE) src/version.sh engine

engine: build/engine/Brave
	@if [[ "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' build/engine/Brave/Info.plist)" != 'app.icns' ]] ; then \
		echo '*** Internal engine app icon name has changed.' 1>&2 ; false ; fi
	/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString $(VERSION)' \
				-c 'Delete :CFBundleDocumentTypes' \
				-c 'Delete :CFBundleURLTypes' \
				build/engine/Brave/Info.plist
	@mkdir -p $(APP_RNTM)/Engine/Filter
	mv -f build/engine/Brave/Info.plist $(APP_RNTM)/Engine/Filter/Info.plist
	rm -rf $(APP_RNTM)/Engine/Exec $(APP_RNTM)/Engine/Link $(APP_RNTM)/Engine/Payload
	mv -f build/engine/Brave/Exec $(APP_RNTM)/Engine
	mkdir -p $(APP_RNTM)/Engine/Link
	mv build/engine/Brave/Frameworks $(APP_RNTM)/Engine/Link/Frameworks
	@touch $(APP_RNTM)/Engine/Link/Frameworks
	rm -f build/engine/Brave/Resources/*.icns
	@mkdir -p $(APP_RNTM)/Engine/Exec
#	openssl AES-128-CBC -k data -in 'build/engine/Brave/MacOS/Brave Browser' -out '$(APP_RNTM)/Engine/exec.dat'
#	rm 'build/engine/Brave/MacOS/Brave Browser'
#	rmdir build/engine/Brave/MacOS
	mv build/engine/Brave $(APP_RNTM)/Engine/Payload
	@touch $(APP_RNTM)/Engine/Payload

$(APP_RNTM)/Engine/Filter/PlaceholderExec: src/PlaceholderExec src/version.sh
	@mkdir -p '$(dir $@)'
	sed 's/EPIVERSION/$(VERSION)/g' $< > $@


# *** LEGACY UPDATE CODE ***

$(APP_RNTM)/Resources/Scripts/runtime.sh: src/runtime.sh
	@mkdir -p '$(dir $@)'
	cp '$<' '$@'
