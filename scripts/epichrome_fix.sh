#!/bin/sh

# NEWVERSION (V1 V2) -- if V1 < V2, return (and echo) 1, else return 0
function newversion {
    local re='^([0-9]+)\.([0-9]+)\.([0-9]+)'
    if [[ "$1" =~ $re ]] ; then
	old=("${BASH_REMATCH[@]:1}")
    else
	old=( 0 0 0 )
    fi
    if [[ "$2" =~ $re ]] ; then
	new=("${BASH_REMATCH[@]:1}")
    else
	new=( 0 0 0 )
    fi
    
    local i= ; local idx=( 0 1 2 )
    for i in "${idx[@]}" ; do
	if [[ "${old[$i]}" -lt "${new[$i]}" ]] ; then
	    echo "1"
	    return 1
	fi
	[[ "${old[$i]}" -gt "${new[$i]}" ]] && return 0
    done
    
    return 0
}


# FIND EPICHROME

mcssbPath=

# try app ID first
mcssbPath=$(mdfind "kMDItemCFBundleIdentifier == 'org.epichrome.builder'" 2> /dev/null)
mcssbPath="${mcssbPath%%$'\n'*}"


# maybe Spotlight is off, try last-ditch
if [[ ! -d "$mcssbPath" ]]; then
    mcssbPath='/Applications/Epichrome.app'
fi
if [[ ! -d "$mcssbPath" ]]; then
    mcssbPath=~/'Applications/Epichrome.app'
fi

# not found
if [[ ! -d "$mcssbPath" ]] ; then
    echo "Unable to find Epichrome.app. Please turn on Spotlight or move Epichrome.app to /Applications or ~/Applications."
    exit 1
fi


if [[ "$#" -gt 0 ]] ; then
    findpaths=("$@")
else
    findpaths=(/Applications ~/Applications)
fi

oldifs="$IFS"
IFS=$'\n'
apps=( $(find "${findpaths[@]}" -path '*/Contents/MacOS/Epichrome' -print) )
IFS="$oldifs"

for curapp in "${apps[@]}" ; do
    # get paths
    apppath="${curapp%/Contents/MacOS/Epichrome}"
    appdir=$(dirname "$apppath")
    appbase=$(basename "$apppath")

    # get version
    source "$apppath/Contents/Resources/Scripts/config.sh"

    echo "$apppath (version $SSBVersion):"
    
    # make backup
    echo "    - backing up untouched app"
    pushd "$appdir" > /dev/null
    zip --quiet --recurse-paths --symlinks "$appbase-$SSBVersion.zip" "$appbase"
    popd > /dev/null

    fixed=
    
    # fix strings.py
    if [[ $(newversion "$SSBVersion" "2.1.12") ]] ; then
	echo "    - fixing strings.py"
	/bin/cp "$mcssbPath/Contents/Resources/Runtime/Resources/Scripts/strings.py" "$apppath/Contents/Resources/Scripts"
	fixed=1
    fi
    
    # fix update dialog
    if [[ $(newversion "$SSBVersion" "2.1.14") ]] ; then
	echo "    - fixing update dialog"
	fixed=1
	/usr/bin/sed -i .bak 's/for button in $@ ; do/for button in "$@" ; do/' "$apppath/Contents/MacOS/Epichrome"
    fi

    if [[ "$fixed" ]] ; then
	# we fixed stuff, so make another backup
	echo "    - backing up FIXED app"
	pushd "$appdir" > /dev/null
	zip --quiet --recurse-paths --symlinks "$appbase-$SSBVersion-FIXED.zip" "$appbase"
	popd > /dev/null
    fi

    echo
done
