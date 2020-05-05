#!/bin/bash

ext="$1" ; shift
[[ "$ext" ]] && ext="_$ext"
ver="$1" ; shift
[[ "$ver" ]] && ver="; s/^SSBVersion=.*\$/SSBVersion='$ver'/"

sed -E -i '' "s/^SSBCommandLine=.*\$/SSBCommandLine=( 'https:\/\/www.wikipedia.org\/' 'https:\/\/imdb.com\/' )/$ver" 'Test Beta9 Chrome 01.app/Contents/Resources/script' && \
    chmod 755 'Test Beta9 Chrome 01.app/Contents/Resources/script' && \
    tar czf "app$ext.zip" 'Test Beta9 Chrome 01.app'
