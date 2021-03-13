#!/bin/bash


# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi
epipath="$mypath/../.."

# load core.sh
if ! source "$epipath/src/core.sh" ; then
    echo "Unable to load core.sh." 1>&2
    exit 1
fi

# ensure we are on the master branch

try 'gitbranch=' /usr/bin/git -C "$epipath" branch --show-current \
        'Unable to get current git branch.'
[[ "$ok" ]] || abort

if [[ "$gitbranch" != 'master' ]] ; then
    abort 'Not on git master branch.'
fi

echo here
cleanexit

# UPDATE_VERSION
function update_version {
    
    [[ "$ok" ]] || return 1
    
    # get current version
    local iVersionFile="$epipath/src/version.sh"
    safesource "$iVersionFile"
    [[ "$ok" ]] || return 1
    
    # get potential new version
    local iNewVersion="${epiVersion%.*}.$(( ${epiVersion##*.} + 1 ))"
    
    try '-2' read -p "Bump version from $epiVersion to $iNewVersion? [n] " ans \
            'Unable to ask whether to bump version.'
    [[ "$ok" ]] || return 1
    
    if [[ "$ans" =~ ^[Yy] ]] ; then
        try "$iVersionFile.new<" /usr/bin/sed -e "s/^epiVersion=.*$/epiVersion=$iNewVersion/" \
        -e 's/^epiBuildNum=.*$/epiBuildNum=1/' "$iVersionFile" \
        'Unable to update version.sh.'
        permanent "$iVersionFile.new" "$iVersionFile"
        [[ "$ok" ]] || return 1
        
        epiVersion="$iNewVersion"
    fi
    
    return 0
}





# GET BRAVE VERSION

braveversion="$("$mypath/updatebrave.sh" "$epipath/Engines")"
[[ "$?" = 0 ]] || abort 'Unable to get Brave version.'
braveversion="${braveversion#*|}"


# UPDATE CHANGELOG

changelog_file="$epipath/CHANGELOG.md"


try 'changelog=' /bin/cat  "$changelog_file" \
        'Unable to read in CHANGELOG.md.'
try 'curdate=' /bin/date '+%Y-%m-%d' \
        'Unable to parse date for CHANGELOG.md.'

if [[ "$ok" ]] ; then
    
    # parse file
    prefix="${changelog%%$'\n'## [*}"
    postfix="${changelog#*$'\n'## [}"
    
    if [[ ( "$prefix" != "$changelog" ) && ( "$postfix" != "$changelog" ) ]] ; then
        # parsed correctly $$$ GET RID OF .NEW
        try "$changelog_file.new<" echo "$prefix
## [$newversion] - $curdate
### Changed
- Updated built-in engine to Brave $braveversion


## [$postfix" 'Unable to update CHANGELOG.md.'

    else
        errlog 'Unable to parse CHANGELOG.md.'
    fi
else
    # move on even if this failed
    ok=1 ; errmsg=
fi


# UPDATE README.MD

# all Epichrome [0-9]*.[0-9]*.[0-9]* > newverions
# ## New in version XXX -> updated
### New in version 2.3.28
#
# - The built-in engine has been updated to Brave 1.X.
#
#
# *Check out the [**change log**](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG.md") for the full list.*

# macOS name x.x.x -> updated
osnum="$(sw_vers | sed -n -e 's/^ProductVersion:[      ]*//p')"
osname="$(awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')"

# Google Chrome version XXXX -> updated
try 'chromeversion=' /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
        /Applications/Google\ Chrome.app/Contents/Info.plist \
        'Unable to get Chrome version number'


# WELCOME.HTML

# <ul>
#   <!-- <li>TURNED OFF FOR .0 RELEASE</li> -->
#   <li>Completely rewritten for full compatibility with macOS 10.15 Catalina, including accessing the system microphone and cam
# era from within apps and interacting with AppleScript</li>
#   <li>Optional built-in Chrome-compatible <a href="https://github.com/brave/brave-browser" target="_blank">Brave Browser</a> engine added for more app-like behavior</li>
#   <li>Welcome page (this page!) now gives useful information and prompts for important actions like (re)installing extensions</li>
#   <li>Many, many under-the-hood improvements, including better logging and more robust error-handling</li>
# </ul>

# $$$ACTIVATE
#update_version

cleanexit
