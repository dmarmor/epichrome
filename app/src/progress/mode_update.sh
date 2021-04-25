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
step01=250
step02=2200
step03=700
step04=570
step05=730
step06=500
step07=800
stepIconA1=850
stepMakeiconA=4360
stepMakeiconB=11200
stepMakeiconC=1080
stepMakeiconD=1290
stepMakeiconE1=1395
stepMakeiconE2=1055
stepMakeiconE3=645
stepMakeiconE4=565
stepMakeiconF=585
stepMakeiconG=815
stepMakeiconH1=795
stepMakeiconH2=860
stepMakeiconH3=615
stepMakeiconH4=625
stepIconA2=2800
stepIconA3=1164
stepIconB1=840
stepIconB2=820
stepIconB3=1230
stepIconB4=310
stepIconB5=740
stepIconB6=250
step08=690
step09=610
step10=510
stepIEng1=835
stepIEng2=863
stepIEng3=860
stepIEng4=15000

# data backup step calibration
dbTimePerStep=2500 # 1 second == 10000
dbItemsPerStep=60  # based on calibrated avg of .004166 ticks / item
dbStepName='stepDB'

# set up progress total based on what we're doing in this update
progressTotal=$(( $stepStart + $step01 + $step02 + $step03 + $step04 + $step05 + $step06 + $step07 + $step08 + $step09 + $step10 ))
 
# custom icon progress
if [[ "$SSBCustomIcon" != 'No' ]] ; then
    if [[ "$epiIconSource" ]] ; then
        
        # add steps for app and doc icon-creation
        progressTotal=$(( $progressTotal + $stepIconA1 + $stepMakeiconA + $stepMakeiconE1 + $stepMakeiconE2 + $stepMakeiconE3 + $stepMakeiconE4 + $stepMakeiconF + $stepMakeiconG + $stepMakeiconH1 + $stepMakeiconH2 + $stepMakeiconH3 + $stepMakeiconH4 + $stepIconA2 + $stepIconA3 ))
        
        # add steps specific to Big Sur vs. old-style icons
        if [[ "$epiIconCompSize" ]] ; then
            progressTotal=$(( $progressTotal + $stepMakeiconB + $stepMakeiconC ))
        else
            progressTotal=$(( $progressTotal + $stepMakeiconD ))
        fi
    else
        # add steps for default icon
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
updateBackupAppFile=
updateBackupDataFile=


# FUNCTION DEFINITIONS

# CLEANUP: clean up any incomplete update prior to exit
function cleanup {
    
    local iAppIsClean=1
    
    debuglog "Cleaning up..."
    
    # clean up any temporary contents folder
    if [[ "$updateContentsTmp" && -d "$updateContentsTmp" ]] ; then
        rmtemp "$updateContentsTmp" 'Contents folder'
        [[ "$?" != 0 ]] && iAppIsClean=
    fi
    updateContentsTmp=
    
    # clean up any app backup, unless we failed to restore the app
    if [[ "$iAppIsClean" && "$updateBackupAppFile" && -f "$updateBackupAppFile" ]] ; then
        tryalways /bin/rm -f "$updateBackupAppFile" 'Unable to remove app backup.'
    fi
    updateBackupAppFile=

    # clean up any data backup
    if [[ "$updateBackupDataFile" && -f "$updateBackupDataFile" ]] ; then
        tryalways /bin/rm -f "$updateBackupDataFile" 'Unable to remove app browser data backup.'
    fi
    updateBackupDataFile=
}


# DATABACKUPPROGRESS: display progress updates during data backup
#   databackupprogress(aStepStem aNumSteps aNumLines)
function databackupprogress {
    
    [[ "$ok" ]] || return 1
    
    # arguments
    local aStepStem="$1" ; shift
    local aNumSteps="$1" ; shift
    local aNumLines="$1" ; shift ; aNumLines=$(( $aNumLines * 1000 ))
    
    # calculate
    
    # loop through lines, sending progress at proper intervals
    local curLine=0
    local curStep=1
    local nextStepLine=$(( $aNumLines / $aNumSteps ))
    local iIgnore
    while read iIgnore ; do
        if [[ ( $curLine -ge $nextStepLine ) && ( $curStep -le $aNumSteps ) ]] ; then
            progress "$aStepStem$curStep"
            curStep=$(( $curStep + 1 ))
            nextStepLine=$(( ( $aNumLines * $curStep ) / $aNumSteps ))
        fi
        curLine=$(( $curLine + 1000 ))
    done
    
    # emit any remaining steps
    while [[ $curStep -le $aNumSteps ]] ; do
        progress "$aStepStem$curStep"
        curStep=$(( $curStep + 1 ))
    done
    
    # if calibrating, write out calibration time
    if [[ "$progressDoCalibrate" ]] ; then
        try "$stdoutTempFile<" echo "$progressCalibrateEndTime" \
                'Unable to write out progress calibration time.'
        ok=1 ; errmsg=
    fi
}


# --- MAIN BODY ---

# set up initial settings for backup
doDataBackup=
if [[ "$epiAction" != 'build' ]] ; then
    
    # if ID is changing, make sure to put backups in old directory (may be duplicative with core.sh)
    [[ "$epiOldIdentifier" ]] && myBackupDir="$appDataPathBase/$epiOldIdentifier/$appDataBackupDir"
    
    # get data path for the app
    iDataPath="$myBackupDir/.."
    
    # set up for a separate backup progress message if we're backing up browser data
    if [[ ( "$SSBBackupData" = 'Yes' ) && ( -d "$iDataPath/$appDataProfileDir" ) ]] ; then
        
        doDataBackup=1
        
        # set backup progress action
        dbSaveProgressAction="$progressAction"
        progressAction="Backing up \"${progressAction##* \"}"
        
        # pre-start progress bar to set message
        progress 'stepStart'
        
        # get number of files/directories in UserData
        try 'dbNumItems=(n)' /usr/bin/find "$iDataPath/$appDataProfileDir" \
                'Unable to list contents of UserData.'
        if [[ "$ok" ]] ; then
            dbNumItems="${#dbNumItems[@]}"
        else
            dbNumItems=2000  # fallback: average number of files/directories in UserData
            ok=1 ; errmsg=
        fi
        
        # determine number of steps
        dbNumSteps=$(( ( ( ( $dbNumItems * 10 ) / $dbItemsPerStep ) + 5 ) / 10 ))
        [[ "$dbNumSteps" -gt 1 ]] || dbNumSteps=2
        
        # set backup step variable values
        for (( i = 1; $i <= $dbNumSteps; i++)) ; do
            eval "$dbStepName$i=$dbTimePerStep"
        done
        # save progress total for update steps
        dbSaveProgressTotal=$(( $progressTotal - ( $step01 + $step02 ) ))
        
        # set progress total for backup steps only
        progressTotal=$(( $stepStart + $step01 + $step02 + ( $dbNumSteps * $dbTimePerStep ) ))
    fi
fi

[[ "$doDataBackup" ]] || progress 'stepStart'


# check for app path
if [[ ! "$updateAppPath" ]] ; then
    ok= ; errmsg='No app path.'
    abortreport
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

myBackupAppTrimList=()
myBackupDataTrimList=()
if [[ "$epiAction" != 'build' ]] ; then
    
    # set up action postfix
    myAction="$epiAction"
    [[ "$myAction" ]] || myAction='update'
    myActionText="$myAction"
    if [[ "$myAction" = 'edit' ]] && vcmp "$SSBVersion" '<' "$progressVersion" ; then
        myAction='edit-update'
        myActionText='edit & update'
    fi
    
    # make sure backup directory exists
    if [[ -d "$myBackupDir" ]] ; then
        
        # rename old *.tgz backups to *.app.tgz
        if vcmp "$SSBVersion" '<=' '2.4.2' ; then
            # get all .tgz files in directory
            iShoptState=
            shoptset iShoptState nullglob
            iOldBackups=( "$myBackupDir"/*.tgz )
            shoptrestore iShoptState
            
            # rename any that are not .app.tgz or .data.tgz
            for curBackup in "${iOldBackups[@]}" ; do
                if [[ ( "$curBackup" != *'.app.tgz' ) && ( "$curBackup" != *'.data.tgz' ) ]] ; then
                    try /bin/mv "$curBackup" "${curBackup%.tgz}.app.tgz" \
                            'Unable to rename old backups. These may have to be deleted manually.'
                fi
            done
            ok=1 ; errmsg=
        fi
        
        # trim backup directory to make room for new app backup
        trimsaves "$myBackupDir" "$backupPreserve" \
                '.app.tgz' 'app backups' myBackupAppTrimList
        
        # trim backup directory to make room for new data backup if set to
        if [[ "$doDataBackup" ]] ; then
            trimsaves "$myBackupDir" "$backupPreserve" \
                    '.data.tgz' 'app browser data backups' myBackupDataTrimList
        fi
    else
        
        # create directory
        try /bin/mkdir -p "$myBackupDir" \
                'Unable to create app backup directory.'
    fi
    
    # set up timestamp prefix
    myBackupTimestamp="${myRunTimestamp#_}"
    [[ "$myBackupTimestamp" ]] && myBackupTimestamp+='-'
    
    # set up path to stem of both backup files
    updateBackupAppFile="$myBackupDir/${myBackupTimestamp}$CFBundleDisplayName-${SSBVersion}-$myAction"
    
    # set up path to data backup file
    [[ "$doDataBackup" ]] && \
        updateBackupDataFile="$updateBackupAppFile.data.tgz"
    
    # finish app backup filename
    updateBackupAppFile+='.app.tgz'
    
    # back up app
    try /usr/bin/tar czf "$updateBackupAppFile" --cd "$updateAppPath/.." "${updateAppPath##*/}" \
            "Unable to back up app prior to $myActionText."
    
    # ignore any errors
    if [[ "$ok" ]] ; then
        debuglog "Created backup of app at \"$updateBackupAppFile\""
    else
        ok=1 ; errmsg=
    fi
    
    progress 'step02'
    
    # back up data if set to
    if [[ "$doDataBackup" ]] ; then
        
        # run data backup and pipe to progress counter
        try '-2' /usr/bin/tar czvf "$updateBackupDataFile" --cd "$iDataPath" "$appDataProfileDir" \
                "Unable to back up app browser data prior to $myActionText." 2>&1 | \
            databackupprogress "$dbStepName" "$dbNumSteps" "$dbNumItems"
        
        # ignore any errors
        if [[ "$ok" ]] ; then
            debuglog "Created backup of app browser data at \"$updateBackupDataFile\""
        else
            ok=1 ; errmsg=
        fi
        
        # update progress variables lost in the pipe
        if [[ "$progressDoCalibrate" ]] ; then
            
            # calibrating, so set calibration variables (lost because of pipe)
            
            # set calibration time
            try 'progressCalibrateEndTime=' /bin/cat "$stdoutTempFile" \
                    'Unable to read in progress calibration time.'
            ok=1 ; errmsg=
            
            # set progress ID variables
            progressLastId="$dbStepName$dbNumSteps"
            for ((i = 1 ; i <= $dbNumSteps ; i++)) ; do
                progressIdList+=( "$dbStepName$i" )
            done
        else
            # revert to update progress & reset progress bar
            progressAction="$dbSaveProgressAction"
            progressTotal="$dbSaveProgressTotal"
            progressCumulative=0
            progress '!stepStart'
        fi
    fi
fi


# SET APP VERSION

SSBVersion="$coreVersion"


# BEGIN POPULATING APP BUNDLE

# put updated bundle in temporary Contents directory
updateContentsTmp="$(tempname "$updateAppPath/Contents")"
resourcesTmp="$updateContentsTmp/Resources"

# copy in the boilerplate for the app
try /bin/cp -PR "$updateEpichromeRuntime/Contents" "$updateContentsTmp" \
        'Unable to populate app bundle.'
[[ "$ok" ]] || abortreport

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
        APPBACKUPDATA "$(formatscalar "$SSBBackupData")" \
        APPCOMMANDLINE "$(formatarray "${SSBCommandLine[@]}")" \
        APPEDITED "$(formatscalar "$editedTimestamp")"
try /bin/chmod 755 "$iMainScript" 'Unable to set permissions for main app script.'
[[ "$ok" ]] || abortreport

progress '!step07'


# COPY OR CREATE CUSTOM APP ICONS

if [[ "$SSBCustomIcon" != 'No' ]] ; then
    
    # relative path for welcome icon
    welcomeIconBase="$appWelcomePath/img/app_icon.png"
    
    if [[ "$epiIconSource" ]] ; then
        
        # CREATE NEW CUSTOM ICONS
        
        # load makeicon.sh
        safesource "$myScriptPathEpichrome/makeicon.sh"
        [[ "$ok" ]] || abortreport
        
        makeicon "$epiIconSource" \
            "$resourcesTmp/$CFBundleIconFile" \
            "$resourcesTmp/$CFBundleTypeIconFile" \
            "$updateContentsTmp/$welcomeIconBase" \
            "$epiIconCrop" "$epiIconCompSize" "$epiIconCompBG" DOPROGRESS
        isreportable && doReport=1 || doReport=
        [[ "$(msg)" ]] && errmsg=" ($(msg))"
        errmsg="Unable to create icon.$(msg)"
        [[ "$doReport" ]] && reportmsg
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
        
        [[ "$ok" ]] || abortreport
        
        
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
[[ "$ok" ]] || abortreport

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

    # no matter what happens now, we'll keep backup(s), so trim old backups, ignoring errors
    updateBackupAppFile=
    if [[ "${myBackupAppTrimList[*]}" ]] ; then
        try /bin/rm -f "${myBackupAppTrimList[@]}" 'Unable to remove old app backups.'
        ok=1 ; errmsg=
    fi
    updateBackupDataFile=
    if [[ "${myBackupDataTrimList[*]}" ]] ; then
        try /bin/rm -f "${myBackupDataTrimList[@]}" 'Unable to remove old app browser data backups.'
        ok=1 ; errmsg=
    fi
    
    # make the contents permanent
    permanent "$updateContentsTmp" "$updateAppPath/Contents" 'app bundle Contents directory'
    [[ "$ok" ]] || abortreport
    updateContentsTmp=
else
    abortreport
fi

progress 'end'
