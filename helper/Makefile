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


EXTDIR:=build
ZIPDIR:=zip

TARGETS=release beta

EXTVERSION:=$(shell sed -En 's/^[^"]*"version"[^:]*:[^"]*"([^"]+)".*$$/\1/p' src/manifest.json)

ZIP_RELEASE:=${ZIPDIR}/epichrome-runtime-${EXTVERSION}.zip
ZIP_BETA:=${ZIPDIR}/epichrome-runtime-beta-${EXTVERSION}.zip

CP_SRC:=src/manifest.json $(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
JS_SRC:=$(patsubst src/jquery%,,$(wildcard src/*.js))

CP_RELEASE:=$(CP_SRC:src/%=$(EXTDIR)/release/%)
JS_RELEASE:=$(JS_SRC:src/%=$(EXTDIR)/release/%)

CP_BETA:=$(CP_SRC:src/%=$(EXTDIR)/beta/%)
JS_BETA:=$(JS_SRC:src/%=$(EXTDIR)/beta/%)

ICONS:=icon16.png icon48.png icon128.png
IMAGES:=install-bg.png

ICONS_RELEASE:=$(ICONS:%=$(EXTDIR)/release/%)
IMAGES_RELEASE:=$(IMAGES:%=$(EXTDIR)/release/%)

ICONS_BETA:=$(ICONS:%=$(EXTDIR)/beta/%)
IMAGES_BETA:=$(IMAGES:%=$(EXTDIR)/beta/%)

ICONS_INPLACE:=$(ICONS:%=src/%)
IMAGES_INPLACE:=$(IMAGES:%=src/%)

.PHONY: release beta inplace build-release build-beta
.PHONY: store store-dir clean clean-inplace clean-store clean-all
.PHONY: link-icon-src

UGLIFY_FLAGS=--screw-ie8 --mangle --compress --comments '/^!/' --lint --verbose
UGLIFY_RELEASE_FLAGS=--define RELEASE=true


# BUILD TARGETS

release: UGLIFY_FLAGS+=$(UGLIFY_RELEASE_FLAGS)
release: $(EXTDIR)/release $(CP_RELEASE) $(JS_RELEASE) $(ICONS_RELEASE) $(IMAGES_RELEASE) $(ZIP_RELEASE)
$(CP_RELEASE) $(JS_RELEASE): $(EXTDIR)/release/%: src/%
$(ICONS_RELEASE): ../images/icons/app.psd
$(IMAGES_RELEASE): $(EXTDIR)/release/%.png: images/%.psd
store/icon_release.png: ../images/icons/app.psd
$(ZIP_RELEASE): $(EXTDIR)/release

beta: $(EXTDIR)/beta $(CP_BETA) $(JS_BETA) $(ICONS_BETA) $(IMAGES_BETA) $(ZIP_BETA)
$(CP_BETA) $(JS_BETA): $(EXTDIR)/beta/%: src/%
$(EXTDIR)/beta/icon48.png $(EXTDIR)/beta/icon128.png: ../images/icons/app_beta.psd
$(EXTDIR)/beta/icon16.png: images/icons/beta16.psd
$(IMAGES_BETA): $(EXTDIR)/beta/%.png: images/%.psd
store/icon_beta.png: ../images/icons/app_beta.psd
$(ZIP_BETA): $(EXTDIR)/beta

inplace: $(ICONS_INPLACE) $(IMAGES_INPLACE)
src/icon48.png src/icon128.png: images/icons/inplace.psd
src/icon16.png: images/icons/inplace16.psd
$(IMAGES_INPLACE): src/%.png: images/%.psd


# BUILD RULES

clean: clean-inplace clean-store
	rm -rf zip
	rm -rf ${EXTDIR}

clean-inplace:
	rm -f $(ICONS_INPLACE) $(IMAGES_INPLACE)

clean-store:
	rm -rf store

clean-all: clean
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;


$(TARGETS:%=$(EXTDIR)/%):
	mkdir -p $@

%.zip:
	@mkdir -p ${ZIPDIR}
	rm -f $@
	zip --recurse-paths $@ $< --exclude '*/.*' '*~'


# STORE ICONS

store: store-dir store/icon_release.png store/icon_beta.png

store-dir:
	@mkdir -p store

store/icon_%.png:
	sips -s format png -z 122 122 -p 128 128 $< --out $@

# ${EXTDIR}/%.html: src/%.html
# 	@echo htmlminify $< $@

$(CP_RELEASE) $(CP_BETA):
	cp -p $< $@

# compression relies on node.js package uglify-js
# > brew install node
# > mkdir -p node ; cd node ; npm install uglify-js
$(JS_RELEASE) $(JS_BETA):
	node/node_modules/uglify-js/bin/uglifyjs $< --output $@ $(UGLIFY_FLAGS)

$(IMAGES_RELEASE) $(IMAGES_BETA) $(IMAGES_INPLACE):
	sips -s format png $< --out $@

$(ICONS_RELEASE) $(ICONS_BETA) $(ICONS_INPLACE):
	@size="$@" ; size="$${size##*icon}" ; size="$${size%.png}" && \
	cmd=( sips -s format png -z $$size $$size $< --out $@ ) && \
	echo "$${cmd[*]}" && \
	"$${cmd[@]}"
