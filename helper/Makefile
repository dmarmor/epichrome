#
#  Makefile: Build rules for the Epichrome Runtime extension.
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

EXTDIR:=extension

ICON_SIZES:=16 48 128
EXTVERSION:=$(shell sed -En 's/^[^"]*"version"[^:]*:[^"]*"([^"]+)".*$$/\1/p' src/manifest.json)
ZIPPREFIX:=epichrome-helper-
ZIP_RELEASE:=${ZIPPREFIX}${EXTVERSION}.zip
ZIP_BETA:=${ZIPPREFIX}beta-${EXTVERSION}.zip
SRC_CP:=src/manifest.json $(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
SRC_JS:=$(patsubst src/jquery%,,$(wildcard src/*.js))

OUT_CP:=$(subst src/,${EXTDIR}/,${SRC_CP})
OUT_JS:=$(subst src/,${EXTDIR}/,${SRC_JS})

OUT_ICONS:=$(patsubst %,${EXTDIR}/icon%.png,${ICON_SIZES})

OUT_IMAGES:=${EXTDIR}/install-bg.png
INPLACE_ICONS:=$(subst ${EXTDIR}/,src/,${OUT_ICONS})
INPLACE_IMAGES:=$(subst ${EXTDIR}/,src/,${OUT_IMAGES})

.PHONY: release beta debug nocompress inplace
.PHONY: build store store-dir clean clean-inplace clean-store clean-all
.PHONY: link-icon-src

UGLIFY_FLAGS=--screw-ie8 --mangle --compress --comments '/^!/' --lint --verbose
UGLIFY_RELEASE_FLAGS=--define RELEASE=true


#.PRECIOUS: ${ICONS}

release: BUILDTYPE:=release
release: UGLIFY_FLAGS+=$(UGLIFY_RELEASE_FLAGS)
release: ${EXTDIR}/.build-release link-release-icons build ${ZIP_RELEASE}

beta: BUILDTYPE:=beta
beta: ${EXTDIR}/.build-beta link-beta-icons build store ${ZIP_BETA}

debug: BUILDTYPE:=debug
debug: ICON_SOURCE=${ICON_PATH}_debug
debug: ${EXTDIR}/.build-debug link-debug-icons build

nocompress: BUILDTYPE:=nocompress
nocompress: ICON_SOURCE=${ICON_PATH}_nocompress
nocompress: NOCOMPRESS=1
nocompress: ${EXTDIR}/.build-nocompress link-nocompress-icons build

inplace: BUILDTYPE:=inplace
inplace: ${INPLACE_ICONS} ${INPLACE_IMAGES}

build: ${OUT_CP} ${OUT_JS} ${OUT_ICONS} ${OUT_IMAGES}

%.zip:
	rm -f $@
	zip --recurse-paths $@ ${EXTDIR} --exclude '*/.*' '*~'

store: store-dir store/icon.png

clean: clean-inplace clean-store
	rm -f ${ZIPPREFIX}*.zip
	rm -rf ${EXTDIR}
	rm -rf images/icons/current

clean-inplace:
	rm -f ${INPLACE_ICONS} ${INPLACE_IMAGES}

clean-store:
	rm -rf store

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;

store-dir:
	@mkdir -p store

store/icon.png: images/icons/release/icon128.psd images/icons/beta/icon128.psd
	sips -s format png -z 122 122 -p 128 128 images/icons/$(BUILDTYPE)/icon128.psd --out $@

# ${EXTDIR}/%.html: src/%.html
# 	@echo htmlminify $< $@

${OUT_CP}: ${EXTDIR}/%: src/%
	cp -p $< $@

# compression relies on node.js package uglify-js
# > brew install node
# > mkdir -p node ; cd node ; npm install uglify-js
${EXTDIR}/%.js: src/%.js
	@if [[ "$(NOCOMPRESS)" ]] ; then \
	  echo cp -p $< $@ ; \
	  cp -p $< $@ ; \
	else \
	  echo node/node_modules/uglify-js/bin/uglifyjs $< --output $@ $(UGLIFY_FLAGS) ; \
	  node/node_modules/uglify-js/bin/uglifyjs $< --output $@ $(UGLIFY_FLAGS) ; \
	fi

${OUT_IMAGES}: ${EXTDIR}/%.png: images/%.psd
	sips -s format png $< --out $@
${INPLACE_IMAGES}: src/%.png: images/%.psd
	sips -s format png $< --out $@

# flurf: ${ICON_PATH}_$$(BUILDTYPE)16.psd
# 	echo $<


link-%-icons:
	rm -rf images/icons/current
	ln -s $(BUILDTYPE) images/icons/current

${OUT_ICONS}: ${EXTDIR}/icon%.png: images/icons/current/icon%.psd
	sips -s format png -z $* $* $< --out $@
${INPLACE_ICONS}: src/icon%.png: images/icons/inplace/icon%.psd
	sips -s format png -z $* $* $< --out $@

${EXTDIR}/.build-%:
	mkdir -p ${EXTDIR}
	rm -f ${OUT_JS} ${OUT_ICONS} ${EXTDIR}/.build-*
	touch $@
