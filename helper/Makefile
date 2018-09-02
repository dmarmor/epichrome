#
#  Makefile: Build rules for the Epichrome Runtime extension.
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

ICON_SIZES:=16 48 128
ICON_SOURCE:=../images/icons/app.psd
EXTVERSION:=$(shell sed -En 's/^.*"version"[^0-9]*([0-9][0-9.]*[0-9]).*$$/\1/p' src/manifest.json)
ZIPPREFIX:=epichrome-runtime-
ZIP:=${ZIPPREFIX}${EXTVERSION}.zip

SRC_CP:=src/manifest.json $(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
SRC_JS:=$(patsubst src/jquery%,,$(wildcard src/*.js))

OUT_CP:=$(subst src/,extension/,${SRC_CP})
OUT_JS:=$(subst src/,extension/,${SRC_JS})

OUT_ICONS:=$(patsubst %,extension/icon%.png,${ICON_SIZES})
OUT_IMAGES:=extension/install-bg.png
INPLACE_FILES:=$(subst extension/,src/,${OUT_ICONS}) $(subst extension/,src/,${OUT_IMAGES})

STORE_FILES:=store/icon.png

.PHONY: release debug nocompress inplace build zip store store-dir clean clean-inplace clean-store clean-all

UGLIFY_FLAGS=--screw-ie8 --mangle --compress --comments '/^!/' --lint --verbose
UGLIFY_RELEASE_FLAGS=--define RELEASE=true



#.PRECIOUS: ${ICONS}

release: UGLIFY_FLAGS+=$(UGLIFY_RELEASE_FLAGS) 
release: extension/.build-release build

debug: extension/.build-debug build

nocompress: NOCOMPRESS=1
nocompress: extension/.build-nocompress build

inplace: ${INPLACE_FILES}

build: ${OUT_CP} ${OUT_JS} ${OUT_ICONS} ${OUT_IMAGES}

zip: ${ZIP}

${ZIP}: release
	rm -f ${ZIP}
	zip --recurse-paths $@ extension --exclude '*/.*' '*~'

store: store-dir ${STORE_FILES}

clean: clean-inplace clean-store
	rm -f ${ZIPPREFIX}*.zip
	rm -rf extension

clean-inplace:
	rm -f ${INPLACE_FILES}

clean-store:
	rm -rf store

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;

store-dir:
	@mkdir -p store

${STORE_FILES}: ${ICON_SOURCE}
	sips -s format png -z 122 122 -p 128 128 $< --out $@

extension/%.html: src/%.html
	@mkdir -p extension
	@echo htmlminify $< $@

${OUT_CP}: extension/%: src/%
	@mkdir -p extension
	cp -p $< $@

${OUT_JS}: extension/%: src/%
	@mkdir -p extension
	@nocompress=$(NOCOMPRESS) ; \
	if [ \! "$$nocompress" ] ; then \
	  uglify=$$(which uglifyjs) ; \
	  if [ $$? != 0 ] ; then \
	    echo ; \
	    echo "**** WARNING: uglify not found -- JavaScript will not be minified." ; \
	    echo "     Please install node.js (https://nodejs.org/download/) and then run" ; \
	    echo "     > sudo npm install uglify-js --global" ; \
	    echo ; \
	    nocompress=1 ; \
	  fi ; \
	fi ; \
	if [ "$$nocompress" ] ; then \
	  echo cp -p $< $@ ; \
	  cp -p $< $@ ; \
	else \
	  echo uglifyjs $< --output $@ $(UGLIFY_FLAGS) ; \
	  uglifyjs $< --output $@ $(UGLIFY_FLAGS) ; \
	fi

extension/%.png: images/%.psd
	@mkdir -p extension
	sips -s format png $< --out $@

extension/%.gif: images/%.gif
	@mkdir -p extension
	cp -p $< $@

${OUT_ICONS}: extension/icon%.png: ${ICON_SOURCE}
	@mkdir -p extension
	sips -s format png -z $* $* $< --out $@

${INPLACE_FILES}: src/%: extension/%
	cp -p $< $@

extension/.build-%:
	rm -f ${OUT_JS} extension/.build-*
	@mkdir -p extension
	touch $@
