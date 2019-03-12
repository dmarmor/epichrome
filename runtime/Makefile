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


# EXTENSION INFO
EXTNAME:=Epichrome Runtime
EXTVERSION:=1.2.0
EXTVERSION_BETA:=1.1.99.2

EXTVERSIONNAME:=$(EXTVERSION)

BUILDDIR:=build
ZIPDIR:=$(BUILDDIR)/zip

TARGETS=release beta

ZIP_RELEASE:=$(ZIPDIR)/epichrome-runtime-$(EXTVERSION).zip
ZIP_BETA:=$(ZIPDIR)/epichrome-runtime-beta-$(EXTVERSION_BETA).zip

CP_SRC:=$(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
JS_SRC:=$(patsubst src/jquery%,,$(wildcard src/*.js))

CP_RELEASE:=$(CP_SRC:src/%=$(BUILDDIR)/release/%)
JS_RELEASE:=$(JS_SRC:src/%=$(BUILDDIR)/release/%)

CP_BETA:=$(CP_SRC:src/%=$(BUILDDIR)/beta/%)
JS_BETA:=$(JS_SRC:src/%=$(BUILDDIR)/beta/%)

ICONS:=icon16.png icon48.png icon128.png
IMAGES:=install-bg.png

ICONS_RELEASE:=$(ICONS:%=$(BUILDDIR)/release/%)
IMAGES_RELEASE:=$(IMAGES:%=$(BUILDDIR)/release/%)

ICONS_BETA:=$(ICONS:%=$(BUILDDIR)/beta/%)
IMAGES_BETA:=$(IMAGES:%=$(BUILDDIR)/beta/%)

ICONS_INPLACE:=$(ICONS:%=src/%)
IMAGES_INPLACE:=$(IMAGES:%=src/%)

.PHONY: release beta inplace build-release build-beta
.PHONY: store store-dir clean clean-inplace clean-store clean-all
.PHONY: link-icon-src

UGLIFY_FLAGS=--screw-ie8 --mangle --compress --comments '/^!/' --lint --verbose
UGLIFY_RELEASE_FLAGS=--define RELEASE=true


# BUILD TARGETS

release: UGLIFY_FLAGS+=$(UGLIFY_RELEASE_FLAGS)
release: $(BUILDDIR)/release $(BUILDDIR)/release/manifest.json $(CP_RELEASE) $(JS_RELEASE) $(ICONS_RELEASE) $(IMAGES_RELEASE) $(ZIP_RELEASE)
$(BUILDDIR)/release/manifest.json: src/manifest.json
$(CP_RELEASE) $(JS_RELEASE): $(BUILDDIR)/release/%: src/%
$(ICONS_RELEASE): ../images/icons/app.psd
$(IMAGES_RELEASE): $(BUILDDIR)/release/%.png: images/%.psd
store/icon_release.png: ../images/icons/app.psd
$(ZIP_RELEASE): $(BUILDDIR)/release

beta: EXTVERSIONNAME:=$(EXTVERSION) beta $(shell x="$(EXTVERSION_BETA)" ; echo "$${x##*.}")
beta: EXTVERSION:=$(EXTVERSION_BETA)
beta: EXTNAME:=$(EXTNAME) BETA
beta: $(BUILDDIR)/beta $(BUILDDIR)/beta/manifest.json $(CP_BETA) $(JS_BETA) $(ICONS_BETA) $(IMAGES_BETA) $(ZIP_BETA)
$(BUILDDIR)/beta/manifest.json: src/manifest.json
$(CP_BETA) $(JS_BETA): $(BUILDDIR)/beta/%: src/%
$(BUILDDIR)/beta/icon128.png: ../images/icons/app_beta.psd
$(BUILDDIR)/beta/icon48.png $(BUILDDIR)/beta/icon16.png: images/icons/beta16.psd
$(IMAGES_BETA): $(BUILDDIR)/beta/%.png: images/%.psd
store/icon_beta.png: ../images/icons/app_beta.psd
$(ZIP_BETA): $(BUILDDIR)/beta

inplace: $(ICONS_INPLACE) $(IMAGES_INPLACE)
src/icon128.png: images/icons/inplace.psd
src/icon48.png src/icon16.png: images/icons/inplace16.psd
$(IMAGES_INPLACE): src/%.png: images/%.psd


# BUILD RULES

clean:
	rm -rf $(BUILDDIR)

clean-inplace:
	rm -f $(ICONS_INPLACE) $(IMAGES_INPLACE)

clean-store:
	rm -rf store

clean-all: clean clean-inplace clean-store
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;


$(TARGETS:%=$(BUILDDIR)/%):
	mkdir -p $@

%.zip:
	@mkdir -p $(ZIPDIR)
	rm -f $@
	zip --recurse-paths $@ $< --exclude '*/.*' '*~'


# STORE ICONS

store: store-dir store/icon_release.png store/icon_beta.png

store-dir:
	@mkdir -p store

store/icon_%.png:
	sips -s format png -z 122 122 -p 128 128 $< --out $@

# $(BUILDDIR)/%.html: src/%.html
# 	@echo htmlminify $< $@

%.json:
	sed -e 's/Epichrome Runtime DEV/$(EXTNAME)/' \
	-e 's/0\.0\.0/$(EXTVERSION)/' \
	-e "s/src directory/$(EXTVERSIONNAME)/" \
	$< > $@

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
