#
#  Makefile: Build rules for the project.
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

BETAVERSION:=02

VERSION:=$(shell source src/version.sh ; echo "$$mcssbVersion")

APP:=Epichrome.app
RUNTIMEBG:=../runtime/src/background.js
#DEBUG_UPDATE_FREQ:=30
HOSTID:=$(shell sed -En 's/^.*chrome\.runtime\.connectNative[^a-zA-Z]+([a-zA-Z]([a-zA-Z0-9._-]*[a-zA-Z])?).*$$/\1/p' ${RUNTIMEBG})
HOSTID_OLD:=org.epichrome.helper
RUNTIMEID:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
RUNTIMEID_BETA:=cknkfdhlojihpopgbmoknioompcojicj
RUNTIMEID_INPLACE:=nhlnhgkagbiplaohhpmnhekngkckccfh

HOSTMANIFEST_SED_COMMON:="chrome-extension:\/\/$(RUNTIMEID)\/",\\\n        "chrome-extension:\/\/$(RUNTIMEID_BETA)\/"
HOSTMANIFEST_SED_RELEASE:=-e $$'s/SSBRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON)/'
HOSTMANIFEST_SED_BETA:=-e $$'s/SSBRUNTIMEIDS/$(HOSTMANIFEST_SED_COMMON),\\\n        "chrome-extension:\/\/$(RUNTIMEID_INPLACE)\/"/'

HOSTMANIFEST_SED:=$(HOSTMANIFEST_SED_RELEASE)

EXEC_SED:=-e 's/SSBHOSTID1/$(HOSTID)/' -e 's/SSBHOSTID2/$(HOSTID_OLD)/'
#EXEC_SED_BETA:=; s/--user-data-dir/--extensions-update-frequency=${DEBUG_UPDATE_FREQ}\ --user-data-dir/

# app paths
APP_CTNT:=${APP}/Contents
APP_RSRC:=${APP_CTNT}/Resources
APP_SCPT:=${APP_RSRC}/Scripts
APP_RNTM:=${APP_RSRC}/Runtime
APP_RNTM_RSRC:=${APP_RNTM}/Resources
APP_RNTM_SCPT:=${APP_RNTM_RSRC}/Scripts
APP_RNTM_NMHT:=${APP_RNTM_RSRC}/NativeMessagingHosts
APP_RNTM_NMEX:=${APP_RNTM_RSRC}/External\ Extensions
APP_RNTM_FRUN:=${APP_RNTM_RSRC}/FirstRun
APP_RNTM_MCOS:=${APP_RNTM}/MacOS

# for codesigning runtime
APP_RAPP:=${APP_RSRC}/Runtime.app
APP_RAPP_CTNT:=${APP_RAPP}/Contents

INSTALL_PATH:=/Applications/Epichrome.app

.PHONY: touchversion beta install clean clean-all

.PRECIOUS: icons/app.icns icons/document.icns icons/app_beta.icns icons/document_beta.icns welcome/img/icon128.png

${APP}: touchversion ${APP_SCPT}/main.scpt \
	${APP_CTNT}/Info.plist \
	${APP_RSRC}/applet.icns \
	${APP_RSRC}/docbg.png \
	${APP_SCPT}/version.sh \
	${APP_SCPT}/build.sh \
	${APP_SCPT}/pathinfo.sh \
	${APP_SCPT}/updatecheck.sh \
	${APP_SCPT}/makeicon.sh \
	${APP_RNTM_MCOS}/Epichrome \
	${APP_RNTM_SCPT}/runtime.sh \
	${APP_RNTM_SCPT}/getversion.py \
	${APP_RNTM_SCPT}/infoplist.py \
	${APP_RNTM_SCPT}/strings.py \
	${APP_RNTM_NMHT}/$(HOSTID).json \
	${APP_RNTM_NMHT}/$(HOSTID_OLD).json \
	${APP_RNTM_NMHT}/epichromeruntimehost.py \
	${APP_RNTM_NMEX}/$(RUNTIMEID).json \
	${APP_RNTM_FRUN}/welcome.html \
	${APP_RNTM_FRUN}/welcome.css \
	${APP_RNTM_FRUN}/img/icon128.png \
	${APP_RNTM_FRUN}/img/m1s1.png \
	${APP_RNTM_FRUN}/img/m1s2.png \
	${APP_RNTM_FRUN}/img/m2s1.png \
	${APP_RNTM_FRUN}/img/m2s2.png \
	${APP_RNTM_FRUN}/img/m3s1.png \
	${APP_RNTM_RSRC}/app.icns \
	${APP_RNTM_RSRC}/document.icns \
	src/Info.plist.runtime
	mkdir ${APP_RAPP}
	mv ${APP_RNTM} ${APP_RAPP_CTNT}
	cp src/Info.plist.runtime ${APP_RAPP_CTNT}/Info.plist
	rm -rf ${APP_RAPP_CTNT}/_CodeSignature
	codesign -s 'David Marmor' -vv ${APP_RAPP}
	codesign --verify --deep --strict --verbose=2 ${APP_RAPP}
	spctl --assess --type execute --verbose=4 ${APP_RAPP}
	rm ${APP_RAPP_CTNT}/Info.plist
	mv ${APP_RAPP_CTNT} ${APP_RNTM}
	rmdir ${APP_RAPP}

touchversion:
	@touch src/version.sh

beta: VERSION:=$(VERSION)b$(BETAVERSION)
beta: HOSTMANIFEST_SED:=$(HOSTMANIFEST_SED_BETA)
#debug: EXEC_SED='${EXEC_SED_COMMON}${EXEC_SED_BETA}'
beta: ${APP} ${APP_RSRC}/applet_beta.icns ${APP_RNTM_RSRC}/app_beta.icns ${APP_RNTM_RSRC}/document_beta.icns
	mv -f ${APP_RSRC}/applet_beta.icns ${APP_RSRC}/applet.icns
	mv -f ${APP_RNTM_RSRC}/app_beta.icns ${APP_RNTM_RSRC}/app.icns
	mv -f ${APP_RNTM_RSRC}/document_beta.icns ${APP_RNTM_RSRC}/document.icns
	rm ${APP_SCPT}/version.sh
	sed -E 's/^(mcssbVersion=.*)$$/\1b$(BETAVERSION)/' src/version.sh > $(APP_SCPT)/version.sh

clean:
	rm -rf ${APP}

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	rm -rf icons
	rm -f welcome/img/icon128.png

install: ${APP}
	if [[ -e "${INSTALL_PATH}" ]] ; then rm -rf "${INSTALL_PATH}" ; fi
	cp -a ${APP} "${INSTALL_PATH}"

${APP_SCPT}/main.scpt: src/main.applescript
	@rm -rf ${APP}
	chmod 444 $<
	osacompile -o ${APP} -x -d $<
	chmod 644 $<
	chmod 444 $@  # lock main.scpt so codesigning works
	@rm -f ${APP_CTNT}/Info.plist ${APP_RSRC}/applet.icns
	mkdir -p ${APP_RNTM_SCPT}
	mkdir -p ${APP_RNTM_MCOS}
	mkdir -p ${APP_RNTM_NMHT}
	mkdir -p ${APP_RNTM_NMEX}
	mkdir -p ${APP_RNTM_FRUN}
	touch ${APP}

${APP_CTNT}/Info.plist: src/Info.plist src/version.sh
	sed "s/SSBVERSION/$(VERSION)/" $< > $@
	@touch ${APP} ${APP_CTNT}

${APP_RSRC}/applet.icns: icons/epichrome.icns
${APP_RSRC}/applet_beta.icns: icons/epichrome_beta.icns

${APP_RSRC}/applet.icns ${APP_RSRC}/applet_beta.icns:
	cp -p $< $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC}

${APP_RSRC}/docbg.png: ../images/icons/docbg.png
	cp -p $< $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC}

${APP_SCPT}/%: src/%
	cp -p $< ${APP_SCPT}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_SCPT}

${APP_RNTM_MCOS}/Epichrome: src/epichrome ${RUNTIMEBG}
	sed -E $(EXEC_SED) $< > $@
	chmod 755 $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_MCOS}

${APP_RNTM_SCPT}/%: src/%
	cp -p $< ${APP_RNTM_SCPT}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_SCPT}

${APP_RNTM_NMHT}/${HOSTID}.json: src/epichromeruntimehost.json src/version.sh
	sed -E -e 's/SSBHOSTID/$(HOSTID)/' -e 's/SSBVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMHT}

# remove this after Epichrome Runtime 1.2.0 release
${APP_RNTM_NMHT}/${HOSTID_OLD}.json: src/epichromeruntimehost.json src/version.sh
	sed -E -e 's/SSBHOSTID/$(HOSTID_OLD)/' -e 's/SSBVERSION/$(VERSION)/' $(HOSTMANIFEST_SED) $< > $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMHT}

${APP_RNTM_NMHT}/epichromeruntimehost.py: src/epichromeruntimehost.py src/version.sh
	sed 's/SSBVERSION/${VERSION}/' $< > $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMHT}

${APP_RNTM_NMEX}/${RUNTIMEID}.json: src/install-extension.json
	cp -p $< "$@"
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMEX}

${APP_RNTM_FRUN}/welcome.%: welcome/welcome.%
	cp -p $< ${APP_RNTM_FRUN}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_FRUN}

${APP_RNTM_FRUN}/img/%.png: welcome/img/%.png
	mkdir -p ${APP_RNTM_FRUN}/img
	cp -p $< ${APP_RNTM_FRUN}/img
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_FRUN} ${APP_RNTM_FRUN}/img

welcome/img/icon128.png: ../images/icons/app.psd
	@mkdir -p icons
	sips -s format png -z 128 128 $< --out $@

${APP_RNTM_RSRC}/%.icns: icons/%.icns
	cp -p $< ${APP_RNTM_RSRC}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC}

icons/%.icns: ../images/icons/%.psd
	@mkdir -p icons
	src/makeicon.sh -f $< $@
