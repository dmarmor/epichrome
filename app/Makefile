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

VERSION:=$(shell source src/version.sh ; echo "$$mcssbVersion")

APP:=epichrome.app
HELPERBG:=../helper/src/background.js
DEBUG_UPDATE_FREQ:=30
HOSTID:=$(shell sed -En 's/^.*chrome\.runtime\.connectNative[^a-zA-Z]+([a-zA-Z]([a-zA-Z0-9._-]*[a-zA-Z])?).*$$/\1/p' ${HELPERBG})
HELPERID:=ngbmbabjgimgbfobhfhjpfhpmpnhbeea
HELPERID_DEBUG1:=kgjjaagidkkjmochgjapgepeecdgdple
HELPERID_DEBUG2:=pdofehfblahphhhpffpbihdkffkgnbnp

HOSTMANIFEST_SED_COMMON:=s/SSBHOSTID/${HOSTID}/; s/SSBVERSION/${VERSION}/; 
HOSTMANIFEST_SED_RELEASE:=s/SSBHELPERID/${HELPERID}/
HOSTMANIFEST_SED_DEBUG:=s/("chrome-extension:\/\/)SSBHELPERID(\/")/'"$$nl"'        \1${HELPERID}\2,'"$$nl"'        "chrome-extension:\/\/${HELPERID_DEBUG1}\/",'"$$nl"'        "chrome-extension:\/\/${HELPERID_DEBUG2}\/"/

HOSTMANIFEST_SED='${HOSTMANIFEST_SED_COMMON}${HOSTMANIFEST_SED_RELEASE}'

EXEC_SED_COMMON:=s/SSBHOSTID/${HOSTID}/
EXEC_SED_DEBUG:=; s/--user-data-dir/--extensions-update-frequency=${DEBUG_UPDATE_FREQ}\ --user-data-dir/
EXEC_SED='${EXEC_SED_COMMON}'

APP_CTNT:=${APP}/Contents
APP_RSRC:=${APP_CTNT}/Resources
APP_SCPT:=${APP_RSRC}/Scripts
APP_RNTM:=${APP_RSRC}/Runtime
APP_RNTM_RSRC:=${APP_RNTM}/Resources
APP_RNTM_SCPT:=${APP_RNTM_RSRC}/Scripts
APP_RNTM_NMHT:=${APP_RNTM_RSRC}/NativeMessagingHosts
APP_RNTM_NMEX:=${APP_RNTM_RSRC}/External\ Extensions
APP_RNTM_MCOS:=${APP_RNTM}/MacOS

INSTALL_PATH:=/Applications/Epichrome.app

.PHONY: install clean clean-all debug

.PRECIOUS: icons/app.icns icons/doc.icns


${APP}: ${APP_SCPT}/main.scpt \
	${APP_CTNT}/Info.plist \
	${APP_RSRC}/applet.icns \
	${APP_SCPT}/version.sh \
	${APP_SCPT}/build.sh \
	${APP_SCPT}/pathinfo.sh \
	${APP_SCPT}/makeicon.sh \
	${APP_RNTM_MCOS}/Epichrome \
	${APP_RNTM_SCPT}/runtime.sh \
	${APP_RNTM_SCPT}/infoplist.py \
	${APP_RNTM_SCPT}/strings.py \
	${APP_RNTM_NMHT}/${HOSTID}.json \
	${APP_RNTM_NMHT}/${HOSTID}-host.py \
	${APP_RNTM_NMEX}/${HELPERID}.json \
	${APP_RNTM_RSRC}/app.icns \
	${APP_RNTM_RSRC}/doc.icns

debug: HOSTMANIFEST_SED='${HOSTMANIFEST_SED_COMMON}${HOSTMANIFEST_SED_DEBUG}'
debug: EXEC_SED='${EXEC_SED_COMMON}${EXEC_SED_DEBUG}'
debug: ${APP}

clean:
	rm -rf ${APP}

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;
	rm icons/*.icns

install: ${APP}
	if [ -e "${INSTALL_PATH}" ] ; then osascript -e 'tell application "Finder" to move ((POSIX file "${INSTALL_PATH}") as alias) to trash' ; fi
	cp -a ${APP} "${INSTALL_PATH}"

${APP_SCPT}/main.scpt: src/main.applescript
	@rm -rf ${APP}
	osacompile -x -o ${APP} src/main.applescript
	@rm -f ${APP_CTNT}/Info.plist ${APP_RSRC}/applet.icns
	mkdir -p ${APP_RNTM_SCPT}
	mkdir -p ${APP_RNTM_MCOS}
	mkdir -p ${APP_RNTM_NMHT}
	mkdir -p ${APP_RNTM_NMEX}
	touch ${APP}

${APP_CTNT}/Info.plist: src/Info.plist src/version.sh
	sed "s/SSBVERSION/${VERSION}/" $< > $@
	@touch ${APP} ${APP_CTNT}

${APP_RSRC}/applet.icns: icons/epichrome.icns
	cp -p $< $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC}

${APP_SCPT}/%: src/%
	cp -p $< ${APP_SCPT}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_SCPT}

${APP_RNTM_MCOS}/Epichrome: src/epichrome ${HELPERBG}
	sed -E $(EXEC_SED) $< > $@
	chmod 755 $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_MCOS}

${APP_RNTM_SCPT}/%: src/%
	cp -p $< ${APP_RNTM_SCPT}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_SCPT}

${APP_RNTM_NMHT}/${HOSTID}.json: src/host-manifest.json src/version.sh
	nl=\\$$'\n' ; sed -E $(HOSTMANIFEST_SED) $< > $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMHT}

${APP_RNTM_NMHT}/${HOSTID}-host.py: src/host-script.py src/version.sh
	sed "s/SSBVERSION/${VERSION}/" $< > $@
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMHT}

${APP_RNTM_NMEX}/${HELPERID}.json: src/install-extension.json
	cp -p $< ${APP_RNTM_NMEX}/${HELPERID}.json
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC} ${APP_RNTM_NMEX}

${APP_RNTM_RSRC}/%.icns: icons/%.icns
	cp -p $< ${APP_RNTM_RSRC}/
	@touch ${APP} ${APP_CTNT} ${APP_RSRC} ${APP_RNTM} ${APP_RNTM_RSRC}

%.icns: %.psd
	src/makeicon.sh -f $< $@
