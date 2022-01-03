#
#  Makefile: Build rules for the Epichrome Runtime extension.
#  Copyright (C) 2022  David Marmor
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


# EXTENSION VERSION
EXTVERSION:=$(shell scripts/version.sh $(filter bump,$(MAKECMDGOALS)))
EXTVERSIONZIP:=$(shell v='$(EXTVERSION)' ; echo "$${v%[*}")
EXTVERSIONCODE:=$(shell scripts/version.sh code)
EXTISBETA:=$(shell if [[ '$(EXTVERSION)' =~ b ]] ; then echo TRUE ; else echo '' ; fi)

# EXTENSION BUILD DIRECTORY
BUILDDIR:=build/epichrome_runtime


# SOURCE & BUILD PATHS
CP_SRC:=$(wildcard src/*.html) $(wildcard src/*.css) $(wildcard src/jquery*.js)
JS_SRC:=$(patsubst src/jquery%,,$(wildcard src/*.js))
ifeq ($(EXTISBETA),TRUE)
CP_SRC:=$(CP_SRC) $(JS_SRC)
JS_SRC:=
endif
CP_BUILD:=$(CP_SRC:src/%=$(BUILDDIR)/%)
JS_BUILD:=$(JS_SRC:src/%=$(BUILDDIR)/%)

# ICONS & IMAGES
ICON16_BUILD:=$(BUILDDIR)/icon16.png
ICON48_BUILD:=$(BUILDDIR)/icon48.png
ICON128_BUILD:=$(BUILDDIR)/icon128.png
ICONS_BUILD:=$(ICON16_BUILD) $(ICON48_BUILD) $(ICON128_BUILD)

ICON16_SRC:=$(ICON16_BUILD:$(BUILDDIR)/%=src/%)
ICON48_INPLACE:=$(ICON48_BUILD:$(BUILDDIR)/%=src/%)
ICON128_INPLACE:=$(ICON128_BUILD:$(BUILDDIR)/%=src/%)
ICONS_INPLACE:=$(ICON16_INPLACE) $(ICON48_INPLACE) $(ICON128_INPLACE)

ifeq ($(EXTISBETA),TRUE)
ICON16_SRC:=images/icons/beta16.psd
ICON48_SRC:=images/icons/beta16.psd
ICON128_SRC:=../images/icons/app_core_beta.psd
else
ICON16_SRC:=../images/icons/app_core.psd
ICON48_SRC:=$(ICON16_SRC)
ICON128_SRC:=$(ICON16_SRC)
endif

# ZIP FILE
ifeq ($(EXTISBETA),TRUE)
ZIP:=build/epichrome-runtime-beta-$(EXTVERSIONZIP).zip
else
ZIP:=build/epichrome-runtime-$(EXTVERSIONZIP).zip
endif

# PHONY TARGETS
.PHONY: build package zip inplace
.PHONY: store store-dir
.PHONY: clean clean-inplace clean-store clean-all
.PHONY: test-nmh

# TERSER INFO
TERSER_VERSION=5.7.0
TERSER_FLAGS:=--compress --comments '/^!/'
ifeq ($(EXTISBETA),)
TERSER_FLAGS:=$(TERSER_FLAGS) --define RELEASE=true
endif

# EXTENSION IDS
TEST_ID_INPLACE=nhlnhgkagbiplaohhpmnhekngkckccfh
TEST_ID_UNPACKED=nkomgphegnjbinlnadabeacplpdfdiee
TEST_ID_SED:=s/(chrome-extension:\/\/[a-z]+\/")$$/\1,\'$$'\n''        "chrome-extension:\/\/TESTID\/"/;

# MANIFEST FILTERING
EXTNAME_RE=^(.*"name": ")(.*[^A-Z])( [A-Z ]+)?(".*)$$
	
ifeq ($(EXTISBETA),TRUE)
EXTNAME_UNPACKED_EXT=BETA
EXTNAME_ZIP_EXT=\ $(EXTNAME_UNPACKED_EXT)
else
EXTNAME_UNPACKED_EXT=RELEASE
EXTNAME_ZIP_EXT=
endif

	
# MAIN BUILD TARGETS

build: clean $(BUILDDIR) $(BUILDDIR)/manifest.json $(CP_BUILD) $(JS_BUILD) $(ICONS_BUILD)

package: $(ZIP)
zip: package

inplace: clean-inplace $(ICONS_INPLACE)


# STORE ICONS

store: store/icon_release.png store/icon_beta.png

store/icon_%.png:
	@mkdir -p store
	sips -s format png -z 122 122 -p 128 128 $< --out $@


# UTILITY TARGETS

clean:
	rm -rf build

clean-inplace:
	rm -f $(ICONS_INPLACE)

clean-store:
	rm -rf store

clean-all: clean clean-inplace clean-store
	find . \( -name '*~' -or -name '.DS_Store' \) -exec rm {} \;

test-nmh: ~/Library/Application\ Support/Google/Chrome/NativeMessagingHosts/org.epichrome.runtime.json
	@if ! grep -q $(TEST_ID_INPLACE) '$<' ; then \
		echo 'Adding in-place ID to NMH manifest...' 1>&2 ; \
		if [[ -f '$<.orig' ]] ; then ext= ; else ext=.orig ; fi ; \
		sed -i "$$ext" -E '$(subst TESTID,$(TEST_ID_INPLACE),$(TEST_ID_SED))' '$<' ; \
	fi
	@if ! grep -q $(TEST_ID_UNPACKED) '$<' ; then \
		echo 'Adding unpacked ID to NMH manifest...' 1>&2 ; \
		if [[ -f '$<.orig' ]] ; then ext= ; else ext=.orig ; fi ; \
		sed -i "$$ext" -E '$(subst TESTID,$(TEST_ID_UNPACKED),$(TEST_ID_SED))' '$<' ; \
	fi


# INTERMEDIATE DEPENDENCIES

$(CP_BUILD) $(JS_BUILD): $(BUILDDIR)/%: src/%

$(ICON16_BUILD): $(ICON16_SRC)
$(ICON48_BUILD): $(ICON48_SRC)
$(ICON128_BUILD): $(ICON128_SRC)

$(ICON16_INPLACE) $(ICON48_INPLACE): images/icons/inplace16.psd
$(ICON128_INPLACE): images/icons/inplace.psd

store/icon_release.png: ../images/icons/app_core.psd
store/icon_beta.png: ../images/icons/app_core_beta.psd


# BUILD RULES

$(BUILDDIR):
	mkdir -p $@

$(ZIP): build
	mv $(BUILDDIR)/manifest.json build
	sed -E -e 's/$(EXTNAME_RE)/\1\2$(EXTNAME_ZIP_EXT)\4/' \
		-e 's/^(.*"version_name": ")(.*)(".*)$$/\1$(EXTVERSIONZIP)\3/' \
		build/manifest.json > $(BUILDDIR)/manifest.json
	cd build && zip --recurse-paths $(notdir $@) $(notdir $(BUILDDIR)) --exclude '*/.*' '*~'
	rm -rf $(BUILDDIR)/manifest.json
	mv build/manifest.json $(BUILDDIR)
	
$(BUILDDIR)/manifest.json: src/manifest.json
	sed -E 's/$(EXTNAME_RE)/\1\2 BUILD $(EXTNAME_UNPACKED_EXT)\4/' $< > $@

$(CP_BUILD):
	cp $< $@

# compression relies on node.js package terser
$(JS_BUILD):
	@if ! which -s node ; then \
		echo 'Unable to find node.js. Please install via homebrew or https://nodejs.org/ and add to your environment.' 1>&2 ; \
		false ; \
	fi
	@if [[ ( ! -d node/node_modules/terser ) || \
		( ! -x node/node_modules/.bin/terser ) || \
		( "$$(node/node_modules/.bin/terser --version)" != \
			"terser $(TERSER_VERSION)" ) ]] ; then \
		echo 'You must install terser $(TERSER_VERSION): mkdir -p node && cd node && npm install terser@$(TERSER_VERSION) && cd ..' 1>&2 ; \
		false ; \
	fi
	node/node_modules/.bin/terser $< --output $@ $(TERSER_FLAGS)

%.png:
	@size="$@" ; size="$${size##*icon}" ; size="$${size%.png}" && \
	cmd=( sips -s format png -z $$size $$size $< --out $@ ) && \
	echo "$${cmd[*]}" && \
	"$${cmd[@]}"
