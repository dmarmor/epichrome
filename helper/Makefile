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
ICON_PATH:=images/icons/icon
EXTVERSION:=$(shell sed -En 's/^.*"version"[^0-9]*([0-9][0-9.]*[0-9]).*$$/\1/p' src/manifest.json)
ZIPPREFIX:=epichrome-runtime-
ZIP:=${ZIPPREFIX}${EXTVERSION}.zip

SRC_CP:=src/manifest.json $(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
SRC_JS:=$(patsubst src/jquery%,,$(wildcard src/*.js))

OUT_CP:=$(subst src/,${EXTDIR}/,${SRC_CP})
OUT_JS:=$(subst src/,${EXTDIR}/,${SRC_JS})

OUT_ICONS:=$(patsubst %,${EXTDIR}/icon%.png,${ICON_SIZES})
OUT_IMAGES:=${EXTDIR}/install-bg.png
INPLACE_ICONS:=$(subst ${EXTDIR}/,src/,${OUT_ICONS})
INPLACE_IMAGES:=$(subst ${EXTDIR}/,src/,${OUT_IMAGES})

STORE_FILES:=store/icon.png

.PHONY: release beta debug nocompress inplace
.PHONY: build zip store store-dir clean clean-inplace clean-store clean-all

UGLIFY_FLAGS=--screw-ie8 --mangle --compress --comments '/^!/' --lint --verbose
UGLIFY_RELEASE_FLAGS=--define RELEASE=true




#.PRECIOUS: ${ICONS}

.SECONDEXPANSION:



release: BUILDTYPE:=release
release: UGLIFY_FLAGS+=$(UGLIFY_RELEASE_FLAGS)
release: ${EXTDIR}/.build-release build

beta: ICON_SOURCE=${ICON_PATH}_beta
beta: ${EXTDIR}/.build-beta build store

debug: ICON_SOURCE=${ICON_PATH}_debug
debug: ${EXTDIR}/.build-debug build

nocompress: ICON_SOURCE=${ICON_PATH}_nocompress
nocompress: NOCOMPRESS=1
nocompress: ${EXTDIR}/.build-nocompress build

inplace: BUILDTYPE:=inplace
inplace: ${INPLACE_ICONS} ${INPLACE_IMAGES}

build: ${OUT_CP} ${OUT_JS} ${OUT_ICONS} ${OUT_IMAGES}

zip: ${ZIP}

${ZIP}: release
	rm -f ${ZIP}
	zip --recurse-paths $@ ${EXTDIR} --exclude '*/.*' '*~'

store: store-dir ${STORE_FILES}

clean: clean-inplace clean-store
	rm -f ${ZIPPREFIX}*.zip
	rm -rf ${EXTDIR}

clean-inplace:
	rm -f ${INPLACE_ICONS} ${INPLACE_IMAGES}

clean-store:
	rm -rf store

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;

store-dir:
	@mkdir -p store

${STORE_FILES}: $(ICON_SOURCE)
	sips -s format png -z 122 122 -p 128 128 $(ICON_SOURCE) --out $@

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

*/%.png: images/%.psd
	sips -s format png $< --out $@

*/icon%.png: ${ICON_PATH}_$${BUILDTYPE}%.psd
	sips -s format png -z $* $* $< --out $@

${EXTDIR}/.build-%:
	mkdir -p ${EXTDIR}
	rm -f ${OUT_JS} ${EXTDIR}/.build-*
	touch $@
