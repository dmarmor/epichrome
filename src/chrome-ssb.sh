#!/bin/bash


# White Space Trimming: http://codesnippets.joyent.com/posts/show/1816
trim() {
  local var=$1
  var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
  /bin/echo -n "$var"
}


### Get Input
/bin/echo "What should the Application be called?"
read inputline
name=`trim "$inputline"`

/bin/echo "What is the url (e.g. https://www.google.com/calendar/render)?"
read inputline
url=`trim "$inputline"`

/bin/echo "What is the full path to the icon (e.g. /Users/username/Desktop/icon.png)?"
read inputline
icon=`trim "$inputline"`


#### Find Chrome. If its not in the standard spot, try using spotlight.
chromePath="/Applications/Google Chrome.app"
if [ ! -d "$chromePath" ] ; then
    chromePath=`mdfind "kMDItemCFBundleIdentifier == 'com.google.Chrome'" | head -n 1`
    if [ -z "$chromePath" ] ; then
	/bin/echo "ERROR. Where is chrome installed?!?!"
	exit 1
    fi
fi
chromeExecPath="$chromePath/Contents/MacOS/Google Chrome"

# Let's make the app whereever we call the script from...
appRoot=`/bin/pwd`

# various paths used when creating the app
resourcePath="$appRoot/$name.app/Contents/Resources"
execPath="$appRoot/$name.app/Contents/MacOS" 
plistPath="$appRoot/$name.app/Contents/Info.plist"
versionsPath="$appRoot/$name.app/Contents/Versions"

# make the directories
/bin/mkdir -p  "$resourcePath" "$execPath"

# convert the icon and copy into Resources
if [ -f "$icon" ] ; then
    if [ ${icon: -5} == ".icns" ] ; then
        /bin/cp "$icon" "$resourcePath/icon.icns"
    else
        sips -s format tiff "$icon" --out "$resourcePath/icon.tiff" --resampleWidth 128 >& /dev/null
        tiff2icns -noLarge "$resourcePath/icon.tiff" >& /dev/null
    fi
fi

# Save a symlink to the location of the Chrome executable to be copied when the SSB is started.
/bin/ln -s "$chromeExecPath" "$execPath/Chrome"

### Create the wrapper executable
/bin/cat >"$execPath/$name" <<EOF
#!/bin/sh
ABSPATH=\$(cd "\$(dirname "\$0")"; pwd)
PROFILEPATH="\${HOME}/Library/Application Support/Chrome SSB/$name"
exec "\$ABSPATH/Chrome" --app="$url" --user-data-dir="\$PROFILEPATH" "\$@"
EOF
/bin/chmod +x "$execPath/$name"

### create the Info.plist 
/bin/cat > "$plistPath" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" “http://www.apple.com/DTDs/PropertyList-1.0.dtd”>
<plist version=”1.0″>
<dict>
<key>CFBundleExecutable</key>
<string>$name</string>
<key>CFBundleName</key>
<string>$name</string>
<key>CFBundleIconFile</key>
<string>icon.icns</string>
<key>NSHighResolutionCapable</key>
<string>True</string>
<key>KSProductID</key>
<string>com.google.Chrome.$name</string>
<key>CFBundleIdentifier</key>
<string>com.google.Chrome.$name</string>
<key>CFBundleShortVersionString</key>
<string>1.0</string>
<key>CFBundleURLTypes</key>
<array>
<dict>
<key>CFBundleURLName</key>
<string>Web site URL</string>
<key>CFBundleURLSchemes</key>
<array>
<string>http</string>
<string>https</string>
</array>
</dict>
</array>
</dict>
</plist>
EOF

### link the Versions directory
/bin/ln -s "$chromePath/Contents/Versions" "$versionsPath"

### create a default (en) localization to name the app
/bin/mkdir -p "$resourcePath/en.lproj"
/bin/cat > "$resourcePath/en.lproj/InfoPlist.strings" <<EOF
CFBundleDisplayName = "$name";
CFBundleName = "$name";
EOF

### tell the user where the app is located so that they can move it to
### /Applications if they wish
/bin/cat <<EOF
Finished! The app has been installed in 
$appRoot/$name.app
EOF
