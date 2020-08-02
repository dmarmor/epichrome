#!/bin/bash
#
#  update.sh: functions for updating/or creating Epichrome apps
#
#  Copyright (C) 2020  David Marmor
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


# VERSION

updateVersion='EPIVERSION'


# PATH TO THIS SCRIPT'S EPICHROME APP BUNDLE

updateEpichromeResources="${BASH_SOURCE[0]%/Contents/Resources/Scripts/update.sh}/Contents/Resources"
updateEpichromeRuntime="$updateEpichromeResources/Runtime"


# WORKING PATHS FOR CLEANUP

updateContentsTmp=
updateBackupFile=


# BOOTSTRAP MY VERSION OF CORE.SH & LAUNCH.SH

if [[ "$updateVersion" != "$coreVersion" ]] ; then
    if ! source "$updateEpichromeRuntime/Contents/Resources/Scripts/core.sh" "$@" ; then
        ok=
        errmsg="Unable to load core $updateVersion."
        errlog "$errmsg"
    fi
fi

if [[ "$ok" ]] ; then
    if ! source "$updateEpichromeRuntime/Contents/Resources/Scripts/launch.sh" ; then
        ok=
        errmsg="Unable to load launch.sh $updateVersion."
        errlog "$errmsg"
    fi
fi


# FUNCTION DEFINITIONS

# ESCAPEHTML: escape HTML-reserved characters in a string
function escapehtml {  # ( str )

    # argument
    local str="$1" ; shift

    # escape HTML characters & ignore errors
    echo "$str" | try '-1' /usr/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' \
            "Unable to escape HTML characters in string '$str'"
    ok=1 ; errmsg=
}


# UPDATECLEANUP: clean up from an aborted update

function updatecleanup {
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

    # only run this once
    unset -f updatecleanup
}


# UPDATEAPP: populate an app bundle
function updateapp {  # ( updateAppPath [NORELAUNCH] )

    # only run if we're OK
    [[ "$ok" ]] || return 1

    # arguments
    local updateAppPath="$1" ; shift
    local noRelaunch="$1" ; shift

    # make sure we're logging
    [[ "$myLogFile" ]] || initlogfile

    # on engine change, restore last-run engine for update purposes
    if [[ "${myStatusEngineChange[0]}" ]] ; then
        SSBLastRunEngineType="${myStatusEngineChange[0]}"
    fi

    # make sure we have info on the engine
    [[ "${#SSBEngineSourceInfo[@]}" -gt "$iDisplayName" ]] || getbrowserinfo SSBEngineSourceInfo


    # LOAD FILTER.SH

    safesource "$updateEpichromeRuntime/Contents/Resources/Scripts/filter.sh"
    [[ "$ok" ]] || return 1


    # SET APP BUNDLE ID

    local myAppBundleID="$appIDBase.$SSBIdentifier"


    # BACK UP APP

    local myBackupTrimList=()
    if [[ "$epiAction" != 'build' ]] ; then

        # set up action postfix
        local myAction="$epiAction"
        [[ "$myAction" ]] || myAction='update'
        local myActionText="$myAction"
        if [[ "$myAction" = 'edit' ]] && vcmp "$SSBVersion" '<' "$updateVersion" ; then
            myAction='edit-update'
            myActionText='edit & update'
        fi

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
        local myBackupTimestamp="${myRunTimestamp#_}"
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
            ok=1 ; errmsg
        fi
    fi


    # SET APP VERSION

    SSBVersion="$coreVersion"


    # BEGIN POPULATING APP BUNDLE

    # put updated bundle in temporary Contents directory
    updateContentsTmp="$(tempname "$updateAppPath/Contents")"
    local resourcesTmp="$updateContentsTmp/Resources"

    # copy in the boilerplate for the app
    try /bin/cp -PR "$updateEpichromeRuntime/Contents" "$updateContentsTmp" 'Unable to populate app bundle.'
    if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi

    # copy executable into place
    safecopy "$updateEpichromeRuntime/Exec/Epichrome" \
            "$updateContentsTmp/MacOS/Epichrome" \
            'app executable.'


    # FILTER APP INFO.PLIST INTO PLACE

    # set up default PlistBuddy commands
    local filterCommands=( "set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
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


    # FILTER APP MAIN SCRIPT INTO PLACE

    # create SSBEngineSourceInfo line
    local appExecEngineSource=
    if [[ "${SSBEngineType%%|*}" = internal ]] ; then
        appExecEngineSource="SSBEngineSourceInfo=$(formatarray "${SSBEngineSourceInfo[@]}")"
    else
        appExecEngineSource="# SSBEngineSourceInfo set in config.sh"
    fi

    # create edited timestamp
    local editedTimestamp=
    [[ "$epiAction" = 'edit' ]] && editedTimestamp="${myRunTimestamp//_/}"

    filterfile "$updateEpichromeRuntime/Filter/AppExec" \
            "$resourcesTmp/script" \
            'app executable' \
            APPID "$(formatscalar "$SSBIdentifier")" \
            APPDISPLAYNAME "$(formatscalar "$CFBundleDisplayName")" \
            APPBUNDLENAME "$(formatscalar "$CFBundleName")" \
            APPCUSTOMICON "$(formatscalar "$SSBCustomIcon")" \
            APPREGISTERBROWSER "$(formatscalar "$SSBRegisterBrowser")" \
            APPENGINETYPE "$(formatscalar "$SSBEngineType")" \
            APPENGINESOURCE "$appExecEngineSource" \
            APPCOMMANDLINE "$(formatarray "${SSBCommandLine[@]}")" \
            APPEDITED "$(formatscalar "$editedTimestamp")"

    if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi


    # COPY OR CREATE CUSTOM APP ICONS

    if [[ "$SSBCustomIcon" = Yes ]] ; then

        # relative path for welcome icon
        local welcomeIconBase="$appWelcomePath/img/app_icon.png"

        if [[ "$epiIconSource" ]] ; then

            # CREATE NEW CUSTOM ICONS

            # ensure a valid source image file
            try '!1' /usr/bin/sips --getProperty format "$epiIconSource" \
                    "Unable to parse icon source file."
            if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi

            # find makeicon.sh
            makeIconScript="$updateEpichromeResources/Scripts/makeicon.sh"
            if [[ ! -e "$makeIconScript" ]] ; then
                ok= ; errmsg="Unable to locate icon creation script."
                updatecleanup
                return 1
            fi
            if [[ ! -x "$makeIconScript" ]] ; then
                ok= ; errmsg="Unable to run icon creation script."
                updatecleanup
                return 1
            fi

            # build command-line
            local docArgs=(-c "$updateEpichromeResources/docbg.png" \
                    256 286 512 "$epiIconSource" "$resourcesTmp/$CFBundleTypeIconFile")

            # run script to convert image into an ICNS
            local makeIconErr=
            try 'makeIconErr&=' "$makeIconScript" -f -o "$resourcesTmp/$CFBundleIconFile" "${docArgs[@]}" ''

            # handle errors
            if [[ ! "$ok" ]] ; then
                errmsg="Unable to create icon"
                makeIconErr="${makeIconErr#*Error: }"
                makeIconErr="${makeIconErr%.*}"
                [[ "$makeIconErr" ]] && errmsg+=" ($makeIconErr)"
                errmsg+='.'
                updatecleanup
                return 1
            fi


            # CREATE WELCOME PAGE ICON

            try '!1' /usr/bin/sips --setProperty format png --resampleHeightWidthMax 128 \
                    "$epiIconSource" --out "$updateContentsTmp/$welcomeIconBase" \
                    'Unable to create welcome page icon.'

            # error is nonfatal, we'll just use the default from boilerplate
            if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi

        else


            # COPY ICONS FROM EXISTING APP

            # MAIN ICONS

            local iconSourcePath="$updateAppPath/Contents/Resources"
            safecopy "$iconSourcePath/$CFBundleIconFile" \
                    "$resourcesTmp/$CFBundleIconFile" "app icon"
            safecopy "$iconSourcePath/$CFBundleTypeIconFile" \
                    "$resourcesTmp/$CFBundleTypeIconFile" "document icon"
            if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi


            # WELCOME PAGE ICON

            local welcomeIconSourcePath="$updateAppPath/Contents/$welcomeIconBase"
            local tempIconset=

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

                if [[ "$ok" ]] ; then

                    # pull out the PNG closest to 128x128
                    local f=
                    local curMax=()
                    local curSize=
                    local iconRe='icon_([0-9]+)x[0-9]+(@2x)?\.png$'
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

            # copy welcome icon
            if [[ "$welcomeIconSourcePath" ]] ; then
                safecopy "$welcomeIconSourcePath" \
                        "$updateContentsTmp/$welcomeIconBase" \
                        'Unable to add app icon to welcome page.'
            fi

            # get rid of any temp iconset we created
            [[ "$tempIconset" && -e "$tempIconset" ]] && \
                    tryalways /bin/rm -rf "$tempIconset" \
                            'Unable to remove temporary iconset.'

            # welcome page icon error is nonfatal, just log it
            if [[ ! "$ok" ]] ; then ok=1 ; errmsg= ; fi
        fi
    fi


    # FILTER NATIVE MESSAGING HOST INTO PLACE

    local updateNMHFile="$resourcesTmp/NMH/$appNMHFile"
    filterfile "$updateEpichromeRuntime/Filter/$appNMHFile" \
            "$updateNMHFile" \
            'native messaging host' \
            APPID "$(escapejson "$SSBIdentifier")" \
            APPDISPLAYNAME "$(escapejson "$CFBundleDisplayName")" \
            APPBUNDLENAME "$(escapejson "$CFBundleName")"
    try /bin/chmod 755 "$updateNMHFile" \
            'Unable to set permissions for native messaging host.'

    if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi


    # FILTER WELCOME PAGE INTO PLACE

    filterfile "$updateEpichromeRuntime/Filter/$appWelcomePage" \
            "$updateContentsTmp/$appWelcomePath/$appWelcomePage" \
            'welcome page' \
            APPBUNDLENAME "$(escapehtml "$CFBundleName")" \
            APPDISPLAYNAME "$(escapehtml "$CFBundleDisplayName")"


    # SELECT MASTER PREFS

    # select different prefs if we're creating an app with no URL
    local nourl=
    [[ "${#SSBCommandLine[@]}" = 0 ]] && nourl='_nourl'

    # copy correct prefs file into app bundle
    local engineID="${SSBEngineType#*|}"
    safecopy "$updateEpichromeRuntime/Filter/Prefs/prefs${nourl}_${engineID//./_}.json" \
            "$updateContentsTmp/$appMasterPrefsPath" \
            'Unable to create app master prefs.'


    # FILTER PROFILE BOOKMARKS FILE INTO PLACE

    filterfile "$updateEpichromeRuntime/Filter/$appBookmarksFile" \
            "$updateContentsTmp/$appBookmarksPath" \
            'bookmarks template' \
            APPBUNDLENAME "$(escapejson "$CFBundleName")"

    if [[ ! "$ok" ]] ; then updatecleanup ; return 1 ; fi


    # POPULATE ENGINE

    # path to engine
    local updateEnginePath="$resourcesTmp/Engine"

    # create engine directory
    try mkdir -p "$updateEnginePath" 'Unable to create app engine.'

    if [[ "${SSBEngineType%%|*}" != internal ]] ; then

        # EXTERNAL ENGINE

        # filter placeholder executable into place
        filterfile "$updateEpichromeRuntime/Engine/Filter/PlaceholderExec" \
                "$updateEnginePath/PlaceholderExec" \
                "${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder executable" \
                APPID "$(formatscalar "$SSBIdentifier")" \
                APPBUNDLEID "$(formatscalar "$myAppBundleID")"
        try /bin/chmod 755 "$updateEnginePath/PlaceholderExec" \
                "Unable to set permissions for ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder executable."

        # copy in core script
        try /bin/mkdir -p "$updateEnginePath/Scripts" \
                "Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder scripts."
        try /bin/cp "$updateEpichromeRuntime/Contents/Resources/Scripts/core.sh" \
                "$updateEnginePath/Scripts" \
                "Unable to copy core to ${SSBEngineSourceInfo[$iDisplayName]} app engine placeholder."

    else

        # INTERNAL ENGINE

        # CREATE PAYLOAD

        # copy in main payload
        try /bin/cp -PR "$updateEpichromeRuntime/Engine/Payload" \
                "$updateEnginePath" \
                'Unable to populate app engine payload.'

        # path to payload
        local updatePayloadPath="$updateEnginePath/Payload"

        # copy executable into place
        safecopy "$updateEpichromeRuntime/Engine/Exec/${SSBEngineSourceInfo[$iExecutable]}" \
                "$updatePayloadPath/MacOS/${SSBEngineSourceInfo[$iExecutable]}" \
                'app engine payload executable'

        # filter payload Info.plist into place
        filterplist "$updateEpichromeRuntime/Engine/Filter/Info.plist" \
                "$updatePayloadPath/Info.plist" \
                "app engine payload Info.plist" \
                "Set :CFBundleDisplayName $(escape "$CFBundleDisplayName" "\"'")" \
                "Set :CFBundleName $(escape "$CFBundleName" "\"'")" \
                "Set :CFBundleIdentifier ${appEngineIDBase}.$SSBIdentifier"

        # filter localization strings in place
        filterlproj "$updatePayloadPath/Resources" 'app engine' \
                "${SSBEngineSourceInfo[$iName]}"


        # CREATE PLACEHOLDER

        # path to placeholder
        local updatePlaceholderPath="$updateEnginePath/Placeholder"

        # make sure placeholder exists
        try /bin/mkdir -p "$updatePlaceholderPath/MacOS" \
                'Unable to create app engine placeholder.'

        # filter placeholder Info.plist from payload
        filterplist "$updatePayloadPath/Info.plist" \
                "$updatePlaceholderPath/Info.plist" \
                "app engine placeholder Info.plist" \
                'Add :LSUIElement bool true'

        # filter placeholder executable into place
        local updatePlaceholderExec="$updatePlaceholderPath/MacOS/${SSBEngineSourceInfo[$iExecutable]}"
        filterfile "$updateEpichromeRuntime/Engine/Filter/PlaceholderExec" \
                "$updatePlaceholderExec" \
                'app engine placeholder executable' \
                APPID "$(formatscalar "$SSBIdentifier")" \
                APPBUNDLEID "$(formatscalar "$myAppBundleID")"
                try /bin/chmod 755 "$updatePlaceholderExec" \
                'Unable to set permissions for app engine placeholder executable.'
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
        unset -f updatecleanup
        permanent "$updateContentsTmp" "$updateAppPath/Contents" 'app bundle Contents directory'
        [[ "$ok" ]] || return 1
    else
        updatecleanup
        return 1
    fi


    # RUNNING IN APP -- UPDATE CONFIG & RELAUNCH

    if [[ ( "$coreContext" = 'app' ) && ( ! "$noRelaunch" ) ]] ; then
        updaterelaunch  # this will always quit
    fi


    # RUNNING IN EPICHROME -- RETURN SUCCESS
    return 0
}


# UPDATERELAUNCH -- relaunch an updated app
function updaterelaunch {

    # only run if we're OK
    [[ "$ok" ]] || return 1

    # write out config
    writeconfig "$myConfigFile" FORCE
    local myCleanupErr=
    if [[ ! "$ok" ]] ; then
        tryalways /bin/rm -f "$myConfigFile" \
                'Unable to delete old config file.'
        myCleanupErr="Update succeeded, but unable to update settings. ($errmsg) The welcome page will not have accurate info about the update."
        ok=1 ; errmsg=
    fi

    # launch helper
    launchhelper Relaunch

    # if relaunch failed, report it
    if [[ ! "$ok" ]] ; then
        [[ "$myCleanupErr" ]] && myCleanupErr+=' Also, ' || myCleanupErr='Update succeeded, but'
        myCleanupErr+="$myCleanupErr the updated app didn't launch. ($errmsg)"
    fi

    # show alert with any errors
    [[ "$myCleanupErr" ]] && alert "$myCleanupErr" 'Update' '|caution'

    # no matter what, we quit now
    cleanexit
}
