#!/bin/bash

logNoStderr=1

# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi
epipath="$mypath/.."

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
oldBraveVersion=
function update_brave {

    [[ "$ok" ]] || return 1
    
    # notify user
    echo '## Checking Brave version...' 1>&2
    
    # get brave version
    braveVersion="$("$mypath/updatebrave.sh")"
    if [[ "$?" != 0 ]] ; then
        ok= ; errmsg='Unable to get Brave version.' ; errlog ; return 1
    fi
    
    # set current and old versions
    braveVersion="${braveVersion#*|}"
    oldBraveVersion="${braveVersion%|*}"
    [[ "$oldBraveVersion" = "$braveVersion" ]] && oldBraveVersion=
    
    return 0
}


# LATEST_VERSION: get latest installed version of Epichrome
latestVersion=
function latest_version {

    [[ "$ok" ]] || return 1
    
    try 'latestVersion=' /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
        '/Applications/Epichrome/Epichrome.app/Contents/Info.plist' \
        'Unable to get version of latest installed Epichrome.'
    
    [[ "$ok" ]] && return 0 || return 1
}


# UPDATE_VERSION: optionally bump version number
epiIsBumped=  ## $$$$ DELET THIS?
epiChangeList=()
epiFixList=()
function update_version {
    
    [[ "$ok" ]] || return 1
    
    # get current version
    local iVersionFile="$epipath/src/version.sh"
    local iVersionTmp="$(tempname "$iVersionFile")"
    safesource "$iVersionFile"
    [[ "$ok" ]] || return 1
        
    # get previous & potential new version
    local iNewVersion="${epiVersion%.*}.$(( ${epiVersion##*.} + 1 ))"
    
    # Brave update message
    local iBraveUpdateMsg="Built-in engine updated to Brave $braveVersion"
    
    local curDesc=
    
    # is current version already bumped from latest installed?
    if vcmp "$epiVersion" '=' "$latestVersion" ; then
        
        # determine if we have an engine update
        if [[ ! "$oldBraveVersion" ]] ; then
            ok= ; errmsg='No new Brave engine found, so no need to bump and build.' ; errlog; return 1
        fi
        
        # confirm version bump and build
        if prompt "Bump version from $epiVersion to $iNewVersion and build release?" y ; then
            
            # notify user
            echo "## Bumping version from $epiVersion to $iNewVersion and building..." 1>&2
            
            epiIsBumped=1
            
            # update version variables
            epiVersion="$iNewVersion"
            epiBuildNum=1
            epiDesc=( "$iBraveUpdateMsg" )
            
            # update changelog/readme variables
            epiChangeList=( "${epiDesc[@]}" )
            epiFixList=()

        elif [[ ! "$ok" ]] ; then
            ok= ; errmsg='Unable to ask whether to bump version.' ; errlog ; return 1
        else
            # user elected not to continue
            ok= ; errmsg='Process canceled.' ; errlog ; return 1
        fi
    elif vcmp "$latestVersion" '<' "$epiVersion" ; then
        
        # version has already been set
        if prompt "Update docs for version $epiVersion and build release?" y ; then
            
            # notify user
            echo "## Building version $epiVersion..." 1>&2
            
            # update descriptions based on engine update
            local newDescList=()
            local iAddBraveDesc=1
            local iBraveRe='^(.*) Brave ([0-9]+\.[0-9]+\.[0-9]+)(.*)$'
            for curDesc in "${epiDesc[@]}" ; do
                if [[ "$curDesc" =~ $iBraveRe ]] ; then
                    iAddBraveDesc=
                    local iBumpBrave=
                    if [[ "${BASH_REMATCH[2]}" != "$braveVersion" ]] ; then

                        if prompt "Bump message \"$curDesc\" to Brave $braveVersion?" y ; then
                            iBumpBrave=1
                        elif [[ ! "$ok" ]] ; then
                            echo "Error displaying prompt. Bumping message \"$curDesc\" to Brave $braveVersion."
                            iBumpBrave=1
                        fi
                    fi
                    
                    if [[ "$iBumpBrave" ]] ; then
                        newDescList+=( "${BASH_REMATCH[1]} Brave $braveVersion${BASH_REMATCH[3]}" )
                    else
                        newDescList+=( "$curDesc" )
                    fi
                else
                    newDescList+=( "$curDesc" )
                fi
            done
            
            if [[ "$oldBraveVersion" && "$iAddBraveDesc" ]] ; then
                newDescList+=( "$iBraveUpdateMsg" )
            fi
            
            # update epiDesc
            epiDesc=( "${newDescList[@]}" )
            
            # categorize all changes
            epiChangeList=()
            epiFixList=()
            for curDesc in "${epiDesc[@]}" ; do
                if prompt "Is \"$curDesc\" a bug fix?" ; then
                    epiFixList+=( "$curDesc" )
                else
                    epiChangeList+=( "$curDesc" )
                fi
            done

        elif [[ ! "$ok" ]] ; then
            ok= ; errmsg='Unable to ask whether to build.' ; errlog ; return 1
        else
            # user elected not to continue
            ok= ; errmsg='Process canceled.' ; errlog ; return 1
        fi
        
    else
        
        # our version is less than the latest installed!
        ok= ; errmsg="Build version $epiVersion is older than installed $latestVersion!" ; errlog ; return 1
    fi
    
    # let us know what change/fix descriptions we'll have in the docs
    if [[ "${epiDesc[*]}" ]] ; then
        echo 'Documents will be updated with the following descriptions:'
        for curDesc in "${epiDesc[@]}" ; do
            echo "   $(formatscalar "$curDesc")"
        done
    else
        echo 'Documents will be updated with NO descriptions.'
    fi
    
    
    # UPDATE VERSION.SH WITH CHANGES
    
    # read version.sh into variable
    local iVersionData=
    try 'iVersionData=' /bin/cat "$iVersionFile" \
            'Unable to read in version.sh.'
    [[ "$ok" ]] || return 1
    
    # parse version.sh
    local iVersionRe=$'^(.*epiVersion=)[^\n]+(.*epiBuildNum=)[^\n]+(.*epiDesc=\().*(\) *# END_epiDesc.*)$'
    if [[ "$iVersionData" =~ $iVersionRe ]] ; then
        
        # format descriptions
        local iEpiDescData=
        if [[ "${epiDesc[*]}" ]] ; then
            iEpiDescData=$' \\\n'
            for curDesc in "${epiDesc[@]}" ; do
                iEpiDescData+="        $(formatscalar "$curDesc")"$' \\\n'
            done
            iEpiDescData+='    '
        fi
        
        # build new version.sh
        iVersionData="${BASH_REMATCH[1]}$epiVersion"
        iVersionData+="${BASH_REMATCH[2]}$epiBuildNum"
        iVersionData+="${BASH_REMATCH[3]}$iEpiDescData"
        iVersionData+="${BASH_REMATCH[4]}"
    else
        ok= ; errmsg="Unable to parse version.sh." ; errlog ; return 1
    fi
    
    # write out new temp version.sh  $$$$
    try "$iVersionTmp<" echo "$iVersionData" \
            'Unable to write updated version.sh.'

    [[ "$ok" ]] && return 0 || return 1
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

    local curDesc
    
    # make sure our version isn't already in changelog
    if [[ "${iChangelog%%$'\n'## \[$epiVersion\]*}" != "$iChangelog" ]] ; then
        ok= ; errmsg="CHANGELOG.md already has an entry for $epiVersion." ; errlog ; return 1
    fi
    
    # break up the changelog into before & after where our version should go
    local iPrefix="${iChangelog%%$'\n'## [*}"
    local iBody="${iChangelog#*$'\n'## [}"
    if [[ ( "$iPrefix" = "$iChangelog" ) || ( "$iBody" = "$iChangelog" ) ]] ; then
        ok= ; errmsg='Unable to parse CHANGELOG.md.' ; errlog ; return 1
    fi
    iBody="## [$iBody"
    
    # build fix and change lists
    local iChangeList="$(join_array $'\n- ' "${epiChangeList[@]}")"
    local iFixList="$(join_array $'\n- ' "${epiFixList[@]}")"
    [[ "$iChangeList" ]] && iChangeList=$'\n### Changed\n- '"$iChangeList"
    [[ "$iFixList" ]] && iFixList=$'\n### Fixed\n- '"$iFixList"
    [[ ( ! "$iChangeList" ) && ( ! "$iFixList" ) ]] && iChangeList=$'\n- No changes'
    
    try "$iChangelogTmp<" \
            echo "$iPrefix"$'\n'"## [$epiVersion] - $iCurDate$iChangeList$iFixList"$'\n\n\n'"$iBody" \
            'Unable to update CHANGELOG.md.'
    
    # $$$$
    # [[ "$ok" ]] && permanent "$iChangelogTmp" "$iChangelogFile"
    # tryalways /bin/rm -f "$iChangelogTmp" 'Unable to remove temporary CHANGELOG.md.'
    
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
    if [[ "$iReadme" = *"<span id=\"epiversion\">$epiVersion</span>"* ]] ; then
        ok= ; errmsg="README.md already at version $epiVersion." ; errlog ; return 1
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

    # replace change list  $$$$ categorize & add ###Changes, etc if necessry
    # build fix and change lists
    local iChangeList="$(join_array $'.\n\n- ' "${epiChangeList[@]}")"
    local iFixList="$(join_array $'.\n\n- ' "${epiFixList[@]}")"
    [[ "$iChangeList" ]] && iChangeList=$'\n\n- '"$iChangeList."
    [[ "$iFixList" ]] && iFixList=$'\n\n- '"$iFixList."
    if [[ "$iChangeList" && "$iFixList" ]] ; then
        iChangeList=$'\n\n### Changed:'"$iChangeList"
        iFixList=$'\n\n### Fixed:'"$iFixList"
    elif [[ ( ! "$iChangeList" ) && ( ! "$iFixList" ) ]] ; then
        iChangeList=$'\n\n- No changes.'
    fi
    
    try "$iReadmeTmp1<" echo "$iPrefix$iChangesStart$iChangeList$iFixList"$'\n\n'"$iChangesEnd$iPostfix" \
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
    
    # $$$$ put back "$iReadmeTmp2" \ to temp removal
    # [[ "$ok" ]] && permanent "$iReadmeTmp2" "$iReadmeFile"
    tryalways /bin/rm -f "$iReadmeTmp1" \
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
    local aPrompt="$1" ; shift ; aPrompt="$(escapejson "$aPrompt")"
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
    zsh -c "read \"ans?>>$aPrompt [$aDefault] \"; [[ \"\$ans\" = [$iAnswerPattern]* ]] && exit $iCodeNondefault || exit $iCodeDefault"
    local iResult="$?"
    
    if [[ "$?" = 1 ]] ; then
        # prompt failed
        ok= ; errmsg='Error prompting for input.' ; return 1
    fi
    
    return "$iResult"
}


# --- RUN UPDATES ---

# run doc updates
#check_repository
update_brave
latest_version
update_version
update_changelog
update_readme
[[ "$ok" ]] || abort
cleanexit
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
if ! prompt 'Does Epichrome.app pass basic testing?' y ; then
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
if ! prompt 'Does installer package pass basic testing?' y ; then
    if [[ "$ok" ]] ; then
        abort 'Installer package failed test!'
    else
        echo 'Unable to ask about installer package testing. Assuming success.' 1>&2
        ok=1 ; errmsg=
    fi
fi

# create new release on GitHub
create_github_release
if [[ ! "$ok" ]] ; then
    echo "Unable to create GitHub release." 1>&2
    ok=1 ; errmsg=
fi

# notarize package
"$mypath/notarize.sh" "$epiVersion"

[[ "$ok" ]] && cleanexit || abort
