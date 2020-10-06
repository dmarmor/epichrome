#!/bin/bash
#
#  mode_payload.sh: mode script for creating engine payload
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


# PROGRESS BAR SETUP

# step calibration
stepStart=0
step1=416
stepIEng1=1146
stepIEng2=916
stepIEng3=2125
stepEEng1=745
stepEEng2=464
stepEEng3=918
stepEEng4=2686
stepEEng5=27522
stepEEng6=434

# set up progress total based on what we're doing in this update
progressTotal=$(( $stepStart + $step1 ))
 
# progress for internal vs. external engine
if [[ "${SSBEngineType%%|*}" = internal ]] ; then
    progressTotal=$(( $progressTotal + $stepIEng1 + $stepIEng2 + $stepIEng3 ))
else
    progressTotal=$(( $progressTotal + $stepEEng1 + $stepEEng2 + $stepEEng3 + $stepEEng4 + $stepEEng5 + $stepEEng6 ))
fi


# FUNCTION DEFINITIONS

# CLEANUP: clean up any incomplete payload prior to exit
payloadComplete=
function cleanup {
    
    if [[ ! "$payloadComplete" ]] ; then    
        debuglog "Cleaning up..."
        deletepayload
    fi
}


# --- MAIN BODY ---

# start progress bar
progress 'stepStart'  # $$$

# $$$
# sleep 10

# import app array variables
importarray SSBEngineSourceInfo


# CLEAR OUT ANY OLD PAYLOAD

deletepayload MUSTSUCCEED

progress 'step1'  # $$$


# CREATE NEW ENGINE PAYLOAD

if [[ ! -d "$SSBPayloadPath" ]] ; then
    
    # if payload is in a per-user directory that doesn't exist, mark it for chmod
    if [[ ! "$myStatusPayloadUserDir" || -d "$myStatusPayloadUserDir" ]] ; then
        myStatusPayloadUserDir=
    fi
    
    # create the payload path
    try /bin/mkdir -p "$SSBPayloadPath" 'Unable to create payload path.'
    [[ "$ok" ]] || abort
    
    # make user dir accessible only by the user (fail silently)
    if [[ "$myStatusPayloadUserDir" ]] ; then
        try /bin/chmod 700 "$myStatusPayloadUserDir" \
				'Unable to change permissions for payload user directory.'
        ok=1 ; errmsg=
    fi
fi
debuglog "Creating ${SSBEngineType%%|*} ${SSBEngineSourceInfo[$iName]} engine payload in '$SSBPayloadPath'."

if [[ "${SSBEngineType%%|*}" != internal ]] ; then
    
    # EXTERNAL ENGINE
    
    # make sure we have a source for the engine payload
    if [[ ! -d "${SSBEngineSourceInfo[$iPath]}" ]] ; then
        
        # we should already have this, so as a last ditch, ask the user to locate it
        myExtEngineSourcePath=
        myExtEngineName=
        getbrowserinfo 'myExtEngineName'
        myExtEngineName="${myExtEngineName[$iDisplayName]}"
        [[ "$myExtEngineName" ]] || myExtEngineName="${SSBEngineType#*|}"
        
        try 'myExtEngineSourcePath=' osascript -e \
				"return POSIX path of (choose application with title \"Locate $myExtEngineName\" with prompt \"Please locate $myExtEngineName\" as alias)" \
                "Locate engine app dialog failed."
		myExtEngineSourcePath="${myExtEngineSourcePath%/}"
        
        if [[ ! "$ok" ]] ; then
            
            # we've failed to find the engine browser
            [[ "$errmsg" ]] && errmsg=" ($errmsg)"
            errmsg="Unable to find $myExtEngineName.$errmsg"
            abort
        fi
        
        # user selected a path, so check it
        getextenginesrcinfo "$myExtEngineSourcePath"
        
        if [[ ! "${SSBEngineSourceInfo[$iPath]}" ]] ; then
            ok= ; errmsg="Selected app is not a valid instance of $myExtEngineName."
            abort
        fi
    fi
    
    # make sure external browser is on the same volume as the payload
    if ! issamedevice "${SSBEngineSourceInfo[$iPath]}" "$SSBPayloadPath" ; then
        ok= ; errmsg="${SSBEngineSourceInfo[$iDisplayName]} is not on the same volume as this app."
        abort
    fi
    
    # create Engine/Resources directory
    try /bin/mkdir -p "$myPayloadEnginePath/Resources" \
            "Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
    
    # turn on extended glob for copying
    shoptState=
    shoptset shoptState extglob
    
    progress 'stepEEng1'  # $$$

    # copy all of the external browser except Framework and Resources
    allExcept='!(Frameworks|Resources)'
    try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/"$allExcept \
			"$myPayloadEnginePath" \
            "Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
	
    progress 'stepEEng2'  # $$$

	# copy Resources, except icons
    allExcept='!(*.icns)'
    try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/Resources/"$allExcept \
			"$myPayloadEnginePath/Resources" \
            "Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine resources to payload."
	
    progress 'stepEEng3'  # $$$

    # restore extended glob
    shoptrestore shoptState
    
    # hard link to external engine browser Frameworks
    linktree "${SSBEngineSourceInfo[$iPath]}/Contents" "$myPayloadEnginePath" \
			"${SSBEngineSourceInfo[$iDisplayName]} app engine" 'payload' 'Frameworks'
	
    progress 'stepEEng4'  # $$$

	# filter localization files
    filterlproj "$myPayloadEnginePath/Resources" \
			"${SSBEngineSourceInfo[$iDisplayName]} app engine" '' 'stepEEng5'
	
    # progress 'stepEEng5'  # CALIBRATE ONLY $$$

	# copy app's icons
    try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
			"$myPayloadEnginePath/Resources/${SSBEngineSourceInfo[$iAppIconFile]}" \
            "Unable to copy app icon to ${SSBEngineSourceInfo[$iDisplayName]} app engine."
	try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
			"$myPayloadEnginePath/Resources/${SSBEngineSourceInfo[$iDocIconFile]}" \
            "Unable to copy document icon file to ${SSBEngineSourceInfo[$iDisplayName]} app engine."

    progress 'stepEEng6'  # $$$

else
    
    # INTERNAL ENGINE
    
    # make sure we have the current version of Epichrome
    if [[ ! -d "$epiCurrentPath" ]] ; then
        ok= ; errmsg="Unable to find this app's version of Epichrome ($SSBVersion)."
        if vcmp "$epiLatestVersion" '>' "$SSBVersion" ; then
            errmsg+=" The app can't be run until it's reinstalled or the app is updated."
        else
            errmsg+=" It must be reinstalled before the app can run."
        fi
        abort
    fi
    
    # make sure Epichrome is on the same volume as the engine
    if ! issamedevice "$epiCurrentPath" "$SSBPayloadPath" ; then
        ok= ; errmsg="Epichrome is not on the same volume as this app's data directory."
        abort
    fi
    
    # copy main payload from app
    try /bin/cp -PR "$SSBAppPath/Contents/$appEnginePath" \
			"$SSBPayloadPath" \
            'Unable to copy app engine payload.'
	
    progress 'stepIEng1'  # $$$

	# copy icons to payload
    safecopy "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
			"$myPayloadEnginePath/Resources/$CFBundleIconFile" \
            "engine app icon"
	safecopy "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
			"$myPayloadEnginePath/Resources/$CFBundleTypeIconFile" \
            "engine document icon"
	
    progress 'stepIEng2'  # $$$
    
    # hard link large payload items from Epichrome
    linktree "$epiCurrentPath/Contents/Resources/Runtime/Engine/Link" \
			"$myPayloadEnginePath" 'app engine' 'payload'

    progress 'stepIEng3'  # $$$
fi

[[ "$ok" ]] || abort

# link to engine  $$$$ GET RID OF THIS?
if [[ "$ok" ]] ; then
    try /bin/ln -s "$SSBPayloadPath" "$myDataPath/Engine" \
			'Unable create to link to engine in data directory.'
    ok=1 ; errmsg=
fi

progress 'end'  # $$$

# signal that we're done to cleanup function
payloadComplete=1
