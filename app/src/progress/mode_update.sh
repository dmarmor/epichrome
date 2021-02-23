#!/bin/bash
#
#  mode_update.sh: mode script for updating/creating an app
#
#  Copyright (C) 2021  David Marmor
#
#  https://github.com/dmarmor/epichrome
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


# PROGRESS BAR SETUP

# step calibration
stepStart=0
step01=500
step02=224
step03=604
step04=738
step05=936
step06=1179
step07=1732
stepIconA1=850
stepIconA2=20000
stepIconA3=1164
stepIconB1=783
stepIconB2=930
stepIconB3=1230
stepIconB4=269
stepIconB5=782
stepIconB6=221
step08=1100
step09=750
step10=450
stepIEng1=835
stepIEng2=863
stepIEng3=860
stepIEng4=15000

# set up progress total based on what we're doing in this update
progressTotal=$(( $stepStart + $step01 + $step02 + $step03 + $step04 + $step05 + $step06 + $step07 + $step08 + $step09 + $step10 ))
 
# custom icon progress
if [[ "$SSBCustomIcon" = Yes ]] ; then
    if [[ "$epiIconSource" ]] ; then
        progressTotal=$(( $progressTotal + $stepIconA1 + $stepIconA2 + $stepIconA3 ))
    else
        progressTotal=$(( $progressTotal + $stepIconB1 + $stepIconB2 + $stepIconB3 + $stepIconB4 + $stepIconB5 + $stepIconB6 ))
    fi
fi

# internal engine progress
[[ "${SSBEngineType%%|*}" = internal ]] && progressTotal=$(( $progressTotal + $stepIEng1 + $stepIEng2 + $stepIEng3 + $stepIEng4 ))


# PATH TO THIS APP'S PARENT EPICHROME APP BUNDLE

updateEpichromeResources="${myScriptPathEpichrome%/Scripts}"
updateEpichromeRuntime="$updateEpichromeResources/Runtime"


# WORKING PATHS FOR CLEANUP

updateContentsTmp=
updateBackupFile=


# FUNCTION DEFINITIONS

# MAKEICONS: use makeicon.php to build icons
#  makeicons(aIconSource aAppIcon aDocIcon aWelcomeIcon aCrop aCompSize aCompBG aDoProgress)
# MAKEICONS_START
function makeicons {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local aIconSource="$1" ; shift
    local aAppIcon="$1" ; shift
    local aDocIcon="$1" ; shift
    local aWelcomeIcon="$1" ; shift
    local aCrop="$1" ; shift ; [[ "$aCrop" ]] && aCrop='true' || aCrop='false'
    local aCompSize="$1" ; shift
    local aCompBG="$1" ; shift
    local aDoProgress="$1" ; shift
        
    [[ "$aDoProgress" ]] && progress '!stepIconA1'
    
    # makeicon script location
    if [[ ! "$iMakeIconScript" ]] ; then
        local iMakeIconScript="$updateEpichromeResources/Scripts/makeicon.php"
    fi
    if [[ ! -e "$iMakeIconScript" ]] ; then
        ok= ; errmsg="Unable to locate icon creation script."
        errlog "$errmsg"
        return 1
    fi
    
    # path to icon templates
    if [[ ! "$iIconTemplatePath" ]] ; then
        local iIconTemplatePath="$updateEpichromeResources/Icons"
    fi
    
    # path to iconset directories
    local iAppIconset="${aAppIcon%.icns}.iconset"
    [[ "$aDocIcon" ]] && local iDocIconset="${aDocIcon%.icns}.iconset"
    
    # delete existing iconsets
    local iExistingIconsets=()
    [[ -e "$iAppIconset" ]] && iExistingIconsets+=( "$iAppIconset" )
    [[ "$aDocIcon" && -d "$iAppIconset" ]] && iExistingIconsets+=( "$iDocIconset" )
    if [[ "${iExistingIconsets[*]}" ]] ; then
        try /bin/rm -rf "${iExistingIconsets[@]}" \
            'Unable to delete existing iconset directories.'
    fi
    
    # create empty iconset directories
    local iNewIconsets=( "$iAppIconset" )
    [[ "$aDocIcon" ]] && iNewIconsets+=( "$iDocIconset" )
    try /bin/mkdir -p "${iNewIconsets[@]}" \
        'Unable to create temporary iconset directories.'
    
    [[ "$ok" ]] || return 1
        
    # set up Big Sur icon comp commands
    if [[ "$aCompSize" ]] ; then
        
        # pre-set comp sizes
        local iAppIconComp_small=0.556640625 # 570x570
        local iAppIconComp_medium=0.69921875 # 716x716
        local iAppIconComp_large=0.8046875   # 824x824
        
        # set comp size
        eval "local iAppIconCompSize=\"\$iAppIconComp_$aCompSize\""
        [[ "$iAppIconCompSize" ]] || iAppIconCompSize="$iAppIconComp_medium"
        
        # set comp background
        local iAppIconCompBGPrefix="$iIconTemplatePath/apptemplate_bg"
        eval "local iAppIconCompBG=\"\${iAppIconCompBGPrefix}_\${aCompBG}.png\""
        if [[ ! -f "$iAppIconCompBG" ]] ; then
            iAppIconCompBG="${iAppIconCompBGPrefix}_white.png"
            if [[ ! -f "$iAppIconCompBG" ]] ; then
                ok= ; errmsg="Unable to find Big Sur icon background ${iAppIconCompBG##*/}."
                errlog "$errmsg"
            fi
        fi
        
        # create comp commands
        local iAppIconCompCmd='
        {
            "action": "composite",
            "options": {
                "crop": '"$aCrop"',
                "size": '"$iAppIconCompSize"',
                "clip": true,
                "with": [ {
                    "action": "read",
                    "path": "'"$iAppIconCompBG"'"
                } ]
            }
        },
        {
            "action": "composite",
            "options": {
                "with": [ {
                    "action": "read",
                    "path": "'"$iIconTemplatePath/apptemplate_shadow.png"'"
                } ]
            }
        },'
    else
        
        # don't comp this in any way, just use the straight image
        local iAppIconCompCmd='
        {
            "action": "composite",
            "options": {
                "crop": '"$aCrop"'
            }
        },'
    fi
    
    # build doc icon command
    local iDocIconCmd=
    if [[ "$aDocIcon" ]] ; then
        iDocIconCmd=',
        [
            {
                "action": "composite",
                "options": {
                    "crop": '"$aCrop"',
                    "size": 0.5,
                    "ctrY": 0.48828125,
                    "with": [
                        {
                            "action": "read",
                            "path": "'"$iIconTemplatePath/doctemplate_bg.png"'"
                        }
                    ]
                }
            },
            {
                "action": "composite",
                "options": {
                    "compUnder": true,
                    "with": [
                        {
                            "action": "read",
                            "path": "'"$iIconTemplatePath/doctemplate_fg.png"'"
                        }
                    ]
                }
            },
            {
                "action": "write_iconset",
                "path": "'"$iDocIconset"'"
            }
        ]'
    fi
    
    # build final makeicon.php command
    local iMakeIconCmd='
[
    {
        "action": "read",
        "path": "'"$aIconSource"'"
    },
    ['"$iAppIconCompCmd"'
        {
            "action": "write_iconset",
            "path": "'"$iAppIconset"'"
        }
    ]'"$iDocIconCmd"'
]'
    
    # run PHP script to convert image into app (and maybe doc icons)
    local iMakeIconErr=
    try 'iMakeIconErr&=' /usr/bin/php "$iMakeIconScript" "$iMakeIconCmd" ''
    
    if [[ "$ok" ]] ; then
        # convert iconsets to ICNS
        try /usr/bin/iconutil -c icns -o "$aAppIcon" "$iAppIconset" \
            'Unable to create app icon from temporary iconset.'
        [[ "$aDocIcon" ]] &&
            try /usr/bin/iconutil -c icns -o "$aDocIcon" "$iDocIconset" \
                'Unable to create app icon from temporary iconset.'
    else
        # handle messaging for makeicon.php errors
        errmsg="Unable to create icon"
        iMakeIconErr="${iMakeIconErr#*Error: }"
        iMakeIconErr="${iMakeIconErr%.*}"
        [[ "$iMakeIconErr" ]] && errmsg+=" ($iMakeIconErr)"
        errmsg+='.'
        errlog "$errmsg"
    fi
    
    [[ "$aDoProgress" ]] && progress 'stepIconA2'
    
    if [[ "$ok" && "$aWelcomeIcon" ]] ; then
        
        # CREATE WELCOME PAGE ICON
        
        # try copying 128x128 icon first
        local iWelcomeIconSrc="$iAppIconset/icon_128x128.png"
        
        if [[ -f "$iWelcomeIconSrc" ]] ; then
            permanent "$iWelcomeIconSrc" "$aWelcomeIcon" \
                'welcome page icon'
        else
            # 128x128 not found, so scale progressively smaller ones
            local curSize
            for curSize in 512 256 64 32 16 ; do
                iWelcomeIconSrc="$iAppIconset/icon_${curSize}x${curSize}.png"
                if [[ -f "$iWelcomeIconSrc" ]] ; then
                    try '!1' /usr/bin/sips --setProperty format png --resampleHeightWidthMax 128 \
                        "$iWelcomeIconSrc" --out "$aWelcomeIcon" \
                        'Unable to create welcome page icon.'
                    break
                fi
                iWelcomeIconSrc=
            done
            if [[ ! "$iWelcomeIconSrc" ]] ; then
                # no size found!
                ok= ; errmsg='Unable to find image to create welcome page icon.'
                errlog
            fi
        fi
        
        # error is nonfatal, we'll just use the default from boilerplate
        if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi
    fi
    
    # destroy iconset directories
    tryalways /bin/rm -rf "${iNewIconsets[@]}" \
        'Unable to remove temporary iconset directories.'
    
    [[ "$aDoProgress" ]] && progress 'stepIconA3'
    
    [[ "$ok" ]] && return 0 || return 1
}
# MAKEICONS_END


# ESCAPEHTML: escape HTML-reserved characters in a string
function escapehtml {  # ( str )

    # argument
    local str="$1" ; shift

    # escape HTML characters & ignore errors
    echo "$str" | try '-1' /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
            "Unable to escape HTML characters in string '$str'"
    ok=1 ; errmsg=
}


# CLEANUP: clean up any incomplete update prior to exit
function cleanup {
    
    local cleaned=1
    
    debuglog "Cleaning up..."
    
    # clean up any temporary contents folder
    if [[ "$updateContentsTmp" && -d "$updateContentsTmp" ]] ; then
        rmtemp "$updateContentsTmp" 'Contents folder'
        [[ "$?" != 0 ]] && cleaned=
    fi
    updateContentsTmp=
    
    # clean up any app backup
    if [[ "$cleaned" && "$updateBackupFile" && -f "$updateBackupFile" ]] ; then
        tryalways /bin/rm -f "$updateBackupFile" 'Unable to remove app backup.'
    fi
    updateBackupFile=
}


# --- MAIN BODY ---

progress 'stepStart'

# check for app path
if [[ ! "$updateAppPath" ]] ; then
    ok= ; errmsg='No app path.'
    abort
fi

# import app array variables
importarray SSBCommandLine myStatusEngineChange

# on engine change, restore last-run engine for update purposes
if [[ "${myStatusEngineChange[0]}" ]] ; then
    SSBLastRunEngineType="${myStatusEngineChange[0]}"
fi

# get current info for the engine
getbrowserinfo SSBEngineSourceInfo

progress 'step01'


# SET APP BUNDLE ID

myAppBundleID="$appIDBase.$SSBIdentifier"


# BACK UP APP

myBackupTrimList=()
if [[ "$epiAction" != 'build' ]] ; then
    
    # set up action postfix
    myAction="$epiAction"
    [[ "$myAction" ]] || myAction='update'
    myActionText="$myAction"
    if [[ "$myAction" = 'edit' ]] && vcmp "$SSBVersion" '<' "$progressVersion" ; then
        myAction='edit-update'
        myActionText='edit & update'
    fi
    
    # if ID is changing, put backups in old directory
    [[ "$epiOldIdentifier" ]] && myBackupDir="$appDataPathBase/$epiOldIdentifier/$appDataBackupDir"
    
    # make sure backup directory exists
    if [[ -d "$myBackupDir" ]] ; then
        
        # trim backup directory to make room for new backup
        trimsaves "$myBackupDir" "$backupPreserve" '.tgz' 'app backups' myBackupTrimList
    else
        
        # create directory
        try /bin/mkdir -p "$myBackupDir" \
                'Unable to create app backup directory.'
    fi
    
    # set up timestamp prefix
    myBackupTimestamp="${myRunTimestamp#_}"
    [[ "$myBackupTimestamp" ]] && myBackupTimestamp+='-'
    
    # set up path to backup file
    updateBackupFile="$myBackupDir/${myBackupTimestamp}$CFBundleDisplayName-${SSBVersion}-$myAction.tgz"
    
    # back up app
    try /usr/bin/tar czf "$updateBackupFile" --cd "$updateAppPath/.." "${updateAppPath##*/}" \
            "Unable to back up app prior to $myActionText."
    
    # ignore any errors
    if [[ "$ok" ]] ; then
        debuglog "Created backup of app at \"$updateBackupFile\""
    else
        ok=1 ; errmsg=
    fi
fi

progress 'step02'


# SET APP VERSION

SSBVersion="$coreVersion"


# BEGIN POPULATING APP BUNDLE

# put updated bundle in temporary Contents directory
updateContentsTmp="$(tempname "$updateAppPath/Contents")"
resourcesTmp="$updateContentsTmp/Resources"

# copy in the boilerplate for the app
try /bin/cp -PR "$updateEpichromeRuntime/Contents" "$updateContentsTmp" \
        'Unable to populate app bundle.'
[[ "$ok" ]] || abort

progress 'step03'

# copy executable into place
safecopy "$updateEpichromeRuntime/Exec/Epichrome" \
        "$updateContentsTmp/MacOS/Epichrome" \
        'app executable.'

progress 'step04'


# FILTER APP INFO.PLIST INTO PLACE

# set up default PlistBuddy commands
filterCommands=( "set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
        "set :CFBundleName $(escape "$CFBundleName" "\"'")" \
        "set :CFBundleIdentifier $myAppBundleID" )

# if not registering as browser, delete URI handlers
[[ "$SSBRegisterBrowser" = "No" ]] && \
        filterCommands+=( "Delete :CFBundleURLTypes" )

# filter boilerplate Info.plist with info for this app
filterplist "$updateEpichromeRuntime/Filter/Info.plist" \
        "$updateContentsTmp/Info.plist" \
        "app Info.plist" \
        "${filterCommands[@]}"

progress 'step05'


# FILTER APPEXEC & MAIN.SH INTO PLACE

# create SSBEngineSourceInfo line
iEngineSource=
if [[ "${SSBEngineType%%|*}" = internal ]] ; then
    iEngineSource="SSBEngineSourceInfo=$(formatarray "${SSBEngineSourceInfo[@]}")"
else
    iEngineSource="# SSBEngineSourceInfo set in config.sh"
fi

# create edited timestamp
editedTimestamp=
[[ "$epiAction" = 'edit' ]] && editedTimestamp="${myRunTimestamp//_/}"

# filter AppExec
filterfile "$updateEpichromeRuntime/Filter/AppExec" \
        "$resourcesTmp/script" \
        'app bootstrap script' \
        APPID "$(formatscalar "$SSBIdentifier")"
    
progress 'step06'

# filter main.sh & make executable
iMainScript="$resourcesTmp/Scripts/main.sh"
filterfile "$updateEpichromeRuntime/Filter/main.sh" \
        "$iMainScript" \
        'main app script' \
        APPID "$(formatscalar "$SSBIdentifier")" \
        APPDISPLAYNAME "$(formatscalar "$CFBundleDisplayName")" \
        APPBUNDLENAME "$(formatscalar "$CFBundleName")" \
        APPCUSTOMICON "$(formatscalar "$SSBCustomIcon")" \
        APPREGISTERBROWSER "$(formatscalar "$SSBRegisterBrowser")" \
        APPENGINETYPE "$(formatscalar "$SSBEngineType")" \
        APPENGINESOURCE "$iEngineSource" \
        APPUPDATEACTION "$(formatscalar "$SSBUpdateAction")" \
        APPCOMMANDLINE "$(formatarray "${SSBCommandLine[@]}")" \
        APPEDITED "$(formatscalar "$editedTimestamp")"
try /bin/chmod 755 "$iMainScript" 'Unable to set permissions for main app script.'
[[ "$ok" ]] || abort

progress '!step07'


# COPY OR CREATE CUSTOM APP ICONS

if [[ "$SSBCustomIcon" = Yes ]] ; then
    
    # relative path for welcome icon
    welcomeIconBase="$appWelcomePath/img/app_icon.png"
    
    if [[ "$epiIconSource" ]] ; then
        
        # CREATE NEW CUSTOM ICONS
        
        # ensure a valid source image file
        try '!1' /usr/bin/sips --getProperty format "$epiIconSource" \
                "Unable to parse icon source file."
        [[ "$ok" ]] || abort
        
        # $$$$ CONVERT TO A FORMAT MAKEICON.PHP CAN READ IF NECESSARY
        
        makeicons "$epiIconSource" \
            "$resourcesTmp/$CFBundleIconFile" \
            "$resourcesTmp/$CFBundleTypeIconFile" \
            "$updateContentsTmp/$welcomeIconBase" \
            "$epiIconCrop" "$epiIconCompSize" "$epiIconCompBG" DOPROGRESS
        [[ "$ok" ]] || abort
        
    else
        
        
        # COPY ICONS FROM EXISTING APP
        
        # MAIN ICONS
        
        iconSourcePath="$updateAppPath/Contents/Resources"
        safecopy "$iconSourcePath/$CFBundleIconFile" \
                "$resourcesTmp/$CFBundleIconFile" "app icon"
        
        progress 'stepIconB1'

        safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
                "$resourcesTmp/$CFBundleTypeIconFile" "document icon"
        
        progress 'stepIconB2'
        
        [[ "$ok" ]] || abort
        
        
        # WELCOME PAGE ICON
        
        welcomeIconSourcePath="$updateAppPath/Contents/$welcomeIconBase"
        tempIconset=
        
        # check if welcome icon exists in bundle
        if [[ ! -f "$welcomeIconSourcePath" ]] ; then
            
            # welcome icon not found, so try to create one
            debuglog 'Extracting icon image for welcome page.'
            
            # fallback to generic icon already in bundle
            welcomeIconSourcePath=
            
            # create iconset from app icon
            tempIconset="$(tempname "$updateContentsTmp/$appWelcomePath/img/app" ".iconset")"
            try /usr/bin/iconutil -c iconset \
                    -o "$tempIconset" \
                    "$iconSourcePath/$CFBundleIconFile" \
                    'Unable to convert app icon to iconset.'
            
            progress 'stepIconB3'
            
            if [[ "$ok" ]] ; then
                
                # pull out the PNG closest to 128x128
                f=
                curMax=()
                curSize=
                iconRe='icon_([0-9]+)x[0-9]+(@2x)?\.png$'
                for f in "$tempIconset"/* ; do
                    if [[ "$f" =~ $iconRe ]] ; then
                        
                        # get actual size of this image
                        curSize="${BASH_REMATCH[1]}"
                        [[ "${BASH_REMATCH[2]}" ]] && curSize=$(($curSize * 2))
                        
                        # see if this is a better match
                        if [[ (! "${curMax[0]}" ) || \
                                ( ( "${curMax[0]}" -lt 128 ) && \
                                ( "$curSize" -gt "${curMax[0]}" ) ) || \
                                ( ( "$curSize" -ge 128 ) && \
                                ( "$curSize" -lt "${curMax[0]}" ) ) ]] ; then
                            curMax=( "$curSize" "$f" )
                        fi
                    fi
                done
                
                # if we found a suitable image, use it
                [[ -f "${curMax[1]}" ]] && welcomeIconSourcePath="${curMax[1]}"
                
            else
                # fail silently, we'll just use the default
                ok=1 ; errmsg=
            fi
        else
            debuglog 'Found existing icon image for welcome page.'
        fi
        
        progress 'stepIconB4'
        
        # copy welcome icon
        if [[ "$welcomeIconSourcePath" ]] ; then
            safecopy "$welcomeIconSourcePath" \
                    "$updateContentsTmp/$welcomeIconBase" \
                    'Unable to add app icon to welcome page.'
        fi
        
        progress 'stepIconB5'
        
        # get rid of any temp iconset we created
        [[ "$tempIconset" && -e "$tempIconset" ]] && \
            tryalways /bin/rm -rf "$tempIconset" \
                    'Unable to remove temporary iconset.'

        # welcome page icon error is nonfatal, just log it
        if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi
        
        progress 'stepIconB6'
    fi

fi



# FILTER WELCOME PAGE INTO PLACE

filterfile "$updateEpichromeRuntime/Filter/$appWelcomePage" \
        "$updateContentsTmp/$appWelcomePath/$appWelcomePage" \
        'welcome page' \
        APPBUNDLENAME "$(escapehtml "$CFBundleName")" \
        APPDISPLAYNAME "$(escapehtml "$CFBundleDisplayName")"

progress 'step08'


# SELECT MASTER PREFS

# select different prefs if we're creating an app with no URL
nourl=
[[ "${#SSBCommandLine[@]}" = 0 ]] && nourl='_nourl'

# copy correct prefs file into app bundle
engineID="${SSBEngineType#*|}"
safecopy "$updateEpichromeRuntime/Filter/Prefs/prefs${nourl}_${engineID//./_}.json" \
        "$updateContentsTmp/$appMasterPrefsPath" \
        'Unable to create app master prefs.'


progress 'step09'


# FILTER PROFILE BOOKMARKS FILE INTO PLACE

filterfile "$updateEpichromeRuntime/Filter/$appBookmarksFile" \
        "$updateContentsTmp/$appBookmarksPath" \
        'bookmarks template' \
        APPBUNDLENAME "$(escapejson "$CFBundleName")"
[[ "$ok" ]] || abort

progress 'step10'


# POPULATE INTERNAL ENGINE DIRECTORY

if [[ "${SSBEngineType%%|*}" = internal ]] ; then
    
    # path to engine
    updateEnginePath="$resourcesTmp/Engine"
    
    # copy in main payload
    try /bin/cp -PR "$updateEpichromeRuntime/Engine/Payload" \
            "$updateEnginePath" \
            'Unable to populate app engine payload.'
    
    progress 'stepIEng1'
    
    # copy payload executable into place
    safecopy "$updateEpichromeRuntime/Engine/Exec/${SSBEngineSourceInfo[$iExecutable]}" \
            "$updateEnginePath/MacOS/${SSBEngineSourceInfo[$iExecutable]}" \
            'app engine payload executable'
    
    progress 'stepIEng2'
    
    # filter payload Info.plist into place
    filterplist "$updateEpichromeRuntime/Engine/Filter/Info.plist" \
            "$updateEnginePath/Info.plist" \
            "app engine payload Info.plist" \
            "Set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
            "Set :CFBundleName $(escape "$CFBundleName" "\"'")" \
            "Set :CFBundleIdentifier $myAppBundleID"
    
    progress 'stepIEng3'
    
    # filter localization strings in place
    filterlproj "$updateEnginePath/Resources" 'app engine' \
            "${SSBEngineSourceInfo[$iName]}" 'stepIEng4'
fi


# MOVE CONTENTS TO PERMANENT HOME

if [[ "$ok" ]] ; then

    # no matter what happens now, we'll keep the backup, so trim old backups, ignoring errors
    backupContentsTmp=
    if [[ "${myBackupTrimList[*]}" ]] ; then
        try /bin/rm -f "${myBackupTrimList[@]}" 'Unable to remove old app backups.'
        ok=1 ; errmsg=
    fi
    
    # make the contents permanent
    permanent "$updateContentsTmp" "$updateAppPath/Contents" 'app bundle Contents directory'
    updateBackupFile=
    updateContentsTmp=
    [[ "$ok" ]] || abort
else
    abort
fi

progress 'end'
