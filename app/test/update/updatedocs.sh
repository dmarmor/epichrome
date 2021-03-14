#!/bin/bash

logNoStderr=1

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
[[ "$gitbranch" = 'master' ]] || abort 'Not on git master branch.'

try 'gitstatus=' /usr/bin/git -C "$epipath" status --porcelain \
        'Unable to get git status.'
[[ "$ok" ]] || abort
[[ "$gitstatus" ]] && abort 'Git repository is not clean.'

# get brave version
braveVersion="$("$mypath/updatebrave.sh" "$epipath/Engines")"
[[ "$?" = 0 ]] || abort 'Unable to get Brave version.'
braveVersion="${braveVersion#*|}"


# --- FUNCTIONS ---

# UPDATE_VERSION: optionally bump version number
prevVersion=
function update_version {
    
    [[ "$ok" ]] || return 1
    
    # get current version
    local iVersionFile="$epipath/src/version.sh"
    local iVersionTmp="$(tempname "$iVersionFile")"
    safesource "$iVersionFile"
    [[ "$ok" ]] || return 1
    
    # get previous & potential new version
    prevVersion="${epiVersion%.*}.$(( ${epiVersion##*.} - 1 ))"
    local iNewVersion="${epiVersion%.*}.$(( ${epiVersion##*.} + 1 ))"
    
    try '-2' read -p "Bump version from $epiVersion to $iNewVersion? [n] " ans \
            'Unable to ask whether to bump version.'
    [[ "$ok" ]] || return 1
    
    if [[ "$ans" =~ ^[Yy] ]] ; then
        
        # notify user
        echo "## Bumping version from $epiVersion to $iNewVersion..." 1>&2
        
        try "$iVersionTmp<" /usr/bin/sed -E -e "s/^epiVersion=.*$/epiVersion=$iNewVersion/" \
                -e 's/^epiBuildNum=.*$/epiBuildNum=1/' "$iVersionFile" \
                'Unable to update version.sh.'
        
        [[ "$ok" ]] && permanent "$iVersionTmp" "$iVersionFile"
        tryalways /bin/rm -f "$iVersionTmp" 'Unable to remove temporary version.sh.'
        [[ "$ok" ]] || return 1
        
        # update version variables
        epiVersion="$iNewVersion"
        prevVersion="${epiVersion%.*}.$(( ${epiVersion##*.} - 1 ))"
    fi
    
    return 0
}


# UPDATE_CHANGELOG
function update_changelog {
    
    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Updating CHANGELOG.md...' 1>&2
    
    # path to changelog
    local iChangelogFile="$epipath/CHANGELOG.md"
    local iChangelogTmp="$(tempname "$iChangelogFile")"

    local iChangelog iCurDate
    try 'iChangelog=' /bin/cat  "$iChangelogFile" \
            'Unable to read in CHANGELOG.md.'
    try 'iCurDate=' /bin/date '+%Y-%m-%d' \
            'Unable to parse date for CHANGELOG.md.'
    [[ "$ok" ]] || return 1
    
    # ensure we don't already have this version in the changelog
    local iChangeVerRe='## \[([0-9.]+)\] - [0-9]{4}-[0-9]{2}-[0-9]{2}'
    if [[ "$iChangelog" =~ $iChangeVerRe ]] ; then
        if [[ "${BASH_REMATCH[1]}" != "$prevVersion" ]] ; then
            ok=
            errmsg="CHANGELOG.md at unexpected version ${BASH_REMATCH[1]} (expected $prevVersion)."
            errlog
            return 1
        fi
    else
        ok= ; errmsg='Unable to parse latest version in CHANGELOG.md.' ; errlog ; return 1
    fi
    
    # parse file
    local iPrefix="${iChangelog%%$'\n'## [*}"
    local iPostfix="${iChangelog#*$'\n'## [}"
    
    if [[ ( "$iPrefix" = "$iChangelog" ) || ( "$iPostfix" = "$iChangelog" ) ]] ; then
        ok= ; errmsg='Unable to parse CHANGELOG.md.'
        errlog
        return 1
    fi
    
    # parsed correctly
    try "$iChangelogTmp<" echo "$iPrefix
## [$epiVersion] - $iCurDate
### Changed
- Updated built-in engine to Brave $braveVersion


## [$iPostfix" 'Unable to update CHANGELOG.md.'
    
    [[ "$ok" ]] && permanent "$iChangelogTmp" "$iChangelogFile"
    tryalways /bin/rm -f "$iChangelogTmp" 'Unable to remove temporary CHANGELOG.md.'
    
    [[ "$ok" ]] && return 0 || return 1
}


# UPDATE_README
function update_readme {
    
    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Updating README.md...' 1>&2
    
    # path to readme
    local iReadmeFile="$epipath/../README.md"
    local iReadmeTmp1="$(tempname "$iReadmeFile")"
    
    # read in readme
    local iReadme
    try 'iReadme=' /bin/cat  "$iReadmeFile" \
            'Unable to read in README.md.'
    [[ "$ok" ]] || return 1
    
    # check readme file version
    local iReadmeVerRe='<span id="epiversion">([0-9.]+)</span>'
    if [[ "$iReadme" =~ $iReadmeVerRe ]] ; then
        if [[ "${BASH_REMATCH[1]}" != "$prevVersion" ]] ; then
            ok=
            errmsg="README.md at unexpected version ${BASH_REMATCH[1]} (expected $prevVersion)."
            errlog
            return 1
        fi
    else
        ok= ; errmsg='Unable to parse latest version in README.md.' ; errlog ; return 1
    fi
    
    # parse readme file
    local iChangesStart='<!-- CHANGES_START -->'
    local iChangesEnd='<!-- CHANGES_END -->'
    local iPrefix="${iReadme%%$iChangesStart*}"
    local iPostfix="${iReadme#*$iChangesEnd}"
    
    if [[ ( "$iPrefix" = "$iReadme" ) || ( "$iPostfix" = "$iReadme" ) ]] ; then
        ok= ; errmsg='Unable to parse README.md.'
        errlog
        return 1
    fi
    
    # update Epichrome, OS & Chrome versions
    local iOSVersion iOSName iChromeVersion

    local iOSVerRe=$'ProductVersion:[ \t]*([^\n]+)'
    try 'iOSVersion=' /usr/bin/sw_vers  'Unable to get macOS version.'
    if [[ "$iOSVersion" =~ $iOSVerRe ]] ; then
        iOSVersion="${BASH_REMATCH[1]}"
    else
        ok= ; errmsg='Unable to parse macOS version number.' ; errlog ; return 1
    fi
    
    iOSName="$(/usr/bin/awk '/SOFTWARE LICENSE AGREEMENT FOR macOS/' '/System/Library/CoreServices/Setup Assistant.app/Contents/Resources/en.lproj/OSXSoftwareLicense.rtf' | awk -F 'macOS ' '{print $NF}' | awk '{print substr($0, 0, length($0)-1)}')"
    if [[ "$?" != 0 ]] ; then
        ok= ; errmsg='Unable to parse macOS version name.' ; errlog ; return 1
    fi
    
    try 'iChromeVersion=' /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
            '/Applications/Google Chrome.app/Contents/Info.plist' \
            'Unable to get Chrome version number.'

    # replace change list
    try "$iReadmeTmp1<" echo "$iPrefix$iChangesStart

- The built-in engine has been updated to Brave $braveVersion.


$iChangesEnd$iPostfix" \
            'Unable to replace change list in README.md.'
    
    # replace Epichrome, OS & Chrome versions
    local iReadmeTmp2="$(tempname "$iReadmeFile")"
    try "$iReadmeTmp2<" /usr/bin/sed -E \
            -e 's/<span id="epiversion">[^<]*<\/span>/<span id="epiversion">'"$epiVersion"'<\/span>/g' \
            "$iReadmeTmp1" \
            'Unable to update version numbers in README.md.'
    
    [[ "$ok" ]] && permanent "$iReadmeTmp2" "$iReadmeFile"
    tryalways /bin/rm -f "$iReadmeTmp1" "$iReadmeTmp2" \
            'Unable to remove temporary README.md files.'
    
    [[ "$ok" ]] && return 0 || return 1
}


# UPDATE_WELCOME
function update_welcome {
    
    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Updating welcome.html...' 1>&2
    
    # path to Welcome
    local iWelcomeFile="$epipath/src/welcome/welcome.html"
    local iWelcomeTmp="$(tempname "$iWelcomeFile")"
    
    # read in Welcome
    local iWelcome
    try 'iWelcome=' /bin/cat  "$iWelcomeFile" \
            'Unable to read in welcome.html.'
    [[ "$ok" ]] || return 1
    
    # parse Welcome file
    local iChangesStart='<ul id="changes_minor_ul">'
    local iChangesEnd='</ul><!-- #changes_minor_ul -->'
    local iPrefix="${iWelcome%%$iChangesStart*}"
    local iPostfix="${iWelcome#*$iChangesEnd}"
    
    if [[ ( "$iPrefix" = "$iWelcome" ) || ( "$iPostfix" = "$iWelcome" ) ]] ; then
        ok= ; errmsg='Unable to parse welcome.html.' ; errlog ; return 1
    fi
    
    # replace change list
    try "$iWelcomeTmp<" echo "$iPrefix$iChangesStart
                  <li>Updated built-in engine to Brave $braveVersion</li>
                $iChangesEnd$iPostfix" \
            'Unable to replace change list in welcome.html.'
    
    [[ "$ok" ]] && permanent "$iWelcomeTmp" "$iWelcomeFile"
    tryalways /bin/rm -f "$iWelcomeTmp" 'Unable to remove temporary welcome.html.'
    
    [[ "$ok" ]] && return 0 || return 1
}


# $$$ACTIVATE
update_version
update_changelog
update_readme
update_welcome
[[ "$ok" ]] || abort

cleanexit
