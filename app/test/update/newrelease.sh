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


# --- FUNCTIONS ---

# CHECK_REPOSITORY
function check_repository {
    
    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Checking git repository...' 1>&2
    
    # ensure we are on the master branch
    try 'gitbranch=' /usr/bin/git -C "$epipath" branch --show-current \
            'Unable to get current git branch.'
    [[ "$ok" ]] || return 1
    if [[ "$gitbranch" != 'master' ]] ; then
        ok= ; errmsg='Not on git master branch.' ; errlog ; return 1
    fi

    try 'gitstatus=' /usr/bin/git -C "$epipath" status --porcelain \
            'Unable to get git status.'
    [[ "$ok" ]] || return 1
    if [[ "$gitstatus" ]] ; then
        ok= ; errmsg='Git repository is not clean.' ; errlog ; return 1
    fi
    
    return 0
}


# UPDATE_BRAVE: get latest Brave version
braveVersion=
function update_brave {

    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Checking Brave version...' 1>&2
    
    # get brave version
    braveVersion="$("$mypath/updatebrave.sh" "$epipath/Engines")"
    if [[ "$?" != 0 ]] ; then
        ok= ; errmsg='Unable to get Brave version.' ; errlog ; return 1
    fi
    braveVersion="${braveVersion#*|}"
    
    return 0
}


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
    
    if prompt "Bump version from $epiVersion to $iNewVersion?" ; then
        
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
    elif [[ ! "$ok" ]] ; then
        ok= ; errmsg='Unable to ask whether to bump version.' ; errlog ; return 1
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
            -e 's/<span id="osname">[^<]*<\/span>/<span id="osname">'"$iOSName"'<\/span>/g' \
            -e 's/<span id="osversion">[^<]*<\/span>/<span id="osversion">'"$iOSVersion"'<\/span>/g' \
            -e 's/<span id="chromeversion">[^<]*<\/span>/<span id="chromeversion">'"$iChromeVersion"'<\/span>/g' \
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


# CREATE_GITHUB_RELEASE
function create_github_release {
    
    [[ "$ok" ]] || return 1
    
    if ! source "$epipath/src/launch.sh" ; then
        ok= ; errmsg='Unable to load launch.sh.' ; errlog ; return 1
    fi
    
    # base url
    local iUrl='https://github.com/dmarmor/epichrome/releases/new'

    #title=testest&body=%0A%0A%0A---%0AI%27m+a+human.+Please+be+nice.'
    
    # notify user
    echo '## Creating GitHub release...' 1>&2
    
    # build release body
    local iReleaseBody='<!--<epichrome>
   ▪️ Updates built-in engine to Brave '"$braveVersion"'
</epichrome>-->

This release updates the built-in engine to Brave '"$braveVersion"'.

***IMPORTANT NOTE***: Epichrome 2.3 has not been developed or fully tested with Big Sur. If you rely on Epichrome apps, if possible please wait until Epichrome 2.4 is released before updating to Big Sur.

---

<p align="center"><a href="https://www.patreon.com/bePatron?u=27108162"><img src="https://github.com/dmarmor/epichrome/blob/master/images/readme/patreon_button.svg" width="176" height="35" alt="Become a patron"/></a></p>
<p align="center">This release was made possible by our Patreon patrons.<br />
If Epichrome is useful to you, please consider joining them!</p>'
    
    # open URL
    try /usr/bin/open "$iUrl?title=$(encodeurl "Version $epiVersion")&body=$(encodeurl "$iReleaseBody")" \
            'Unable to create GitHub release.'
}


# PROMPT: prompt for an answer
#   prompt(aPrompt aDefault)
function prompt {
    
    [[ "$ok" ]] || return 1
    
    # arguments
    local aPrompt="$1" ; shift
    local aDefault="$1" ; shift ; [[ "$aDefault" != [yn] ]] && aDefault='n'
    local iAnswerPattern iCodeDefault iCodeNondefault
    if [[ "$aDefault" = y ]] ; then
        iAnswerPattern='Nn'
        iCodeDefault=0
        iCodeNondefault=2
    else
        iAnswerPattern='Yy'
        iCodeDefault=2
        iCodeNondefault=0
    fi
    # show prompt
    zsh -c "read \"ans?$aPrompt [$aDefault] \"; [[ \"\$ans\" = [$iAnswerPattern]* ]] && exit $iCodeNondefault || exit $iCodeDefault"
    local iResult="$?"
    
    if [[ "$?" = 1 ]] ; then
        # prompt failed
        ok= ; errmsg='Error prompting for input.' ; return 1
    fi
    
    return "$iResult"
}


# --- RUN UPDATES ---

# run doc updates
check_repository
update_brave
update_version
update_changelog
update_readme
update_welcome
[[ "$ok" ]] || abort

# build package
echo "## Building epichrome-$epiVersion.pkg..." 1>&2
make --directory="$epipath" clean clean-package package
[[ "$?" = 0 ]] || abort "Package build failed."

# test epichrome
echo "## Testing Epichrome.app..." 1>&2
try open -W "$epipath/Epichrome/Epichrome.app" \
        'Unable to launch Epichrome.app.'
if ! prompt 'Does Epichrome.app pass basic testing?' ; then
    if [[ "$ok" ]] ; then
        abort 'Epichrome.app failed test!'
    else
        echo 'Unable to ask about Epichrome testing. Assuming success.' 1>&2
        ok=1 ; errmsg=
    fi
fi

# test package
echo "## Testing epichrome-$epiVersion.pkg..." 1>&2
try open -W "$epipath/epichrome-$epiVersion.pkg" \
        "Unable to launch epichrome-$epiVersion.pkg."
if ! prompt 'Does installer package pass basic testing?' ; then
    if [[ "$ok" ]] ; then
        abort 'Installer package failed test!'
    else
        echo 'Unable to ask about installer package testing. Assuming success.' 1>&2
        ok=1 ; errmsg=
    fi
fi

# notarize package
make --directory="$epipath" notarize
[[ "$?" = 0 ]] || abort 'Package notarization failed.'

# staple notarization
echo 'Waiting 5 minutes for package to be approved...' 1>&2
sleep 300

# staple notarization
make --directory="$epipath" notarize
[[ "$?" = 0 ]] || abort 'Package notarization failed.'

# create new release on GitHub
create_github_release

[[ "$ok" ]] && cleanexit || abort
