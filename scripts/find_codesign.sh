#!/bin/sh

find "$1" -not -type l -exec codesign --verify --strict -v '{}' ';' 2>&1 | \
    sed -E '/^.*: bundle format unrecognized, invalid, or unsuitable$/d;
/^.*: code object is not signed at all$/d;
s/^(.*): .*$/\1/' | uniq
