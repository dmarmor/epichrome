#!/bin/sh

shopt -s nullglob

theApp=( *.app )
if [[ ! "$theApp" ]] ; then
    tar xzf app.zip
    if [[ "$?" != 0 ]] ; then
	echo "Couldn't restore app."
	exit 1
    fi
    theApp=( *.app )
fi
theApp="${theApp[0]}"
if [[ ! "$theApp" ]] ; then
    echo "No app found!"
    exit 1
fi

read -p "OPERATING ON '${theApp%.app}'. Copy to clipboard & continue? " yn
case $yn in
    [Yy]* ) break;;
    * ) exit;;
esac

appcopy="${theApp%.app}"
appcopy="${appcopy//\\/\\\\\\}"
appcopy="${appcopy//\"/\\\"}"
osascript -e "set the clipboard to \"$appcopy\""
[[ "$?" = 0 ]] || echo "Unable to copy app name to clipboard. Do it manually..."

echo
echo "Step 1: Create a BRAVE app with display name '${theApp%.app}'"

rm -rf "$theApp"
open ~/Scratch/Epichrome/Epichrome.app

read -p "  Hit enter when done... "

if [[ ! -d "$theApp" ]] ; then
    echo
    echo "'$theApp' has not been created!"
    exit 1
fi

echo
echo "Creating app_brave..."
./mkapp.sh brave
# ./mkapp.sh v8b '2.3.0b8'
if [[ "$?" != 0 ]] ; then
    echo "Creation failed!"
    exit 1
fi


echo
echo "Step 2: Create a CHROME app with display name '${theApp%.app}'"

rm -rf "$theApp"
open ~/Scratch/Epichrome/Epichrome.app

read -p "  Hit enter when done... "

if [[ ! -d "$theApp" ]] ; then
    echo
    echo "'$theApp' has not been created!"
    exit 1
fi

echo
echo "Creating app..."
./mkapp.sh
# ./mkapp.sh v8c '2.3.0b8'
if [[ "$?" != 0 ]] ; then
    echo "Creation failed!"
    exit 1
fi
