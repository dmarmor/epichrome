#!/bin/bash
#
#  makeicon.sh: function for creating app & doc icons
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


# BOOTSTRAP CORE.SH IF NECESSARY

if [[ ! "$coreVersion" ]] ; then
    source "${BASH_SOURCE[0]%/*}/core.sh" 'coreDoInit=1' || exit 1
    [[ "$ok" ]] || abortreport
fi


# SET PHP PATH

myPHPPath='/usr/bin/php'
if [[ ! -x "$myPHPPath" ]] ; then
    myPHPPath='/usr/local/bin/php@7.3'
    if [[ ! -x "$myPHPPath" ]] ; then
        abort "PHP not found! (PHP has been removed under macOS 12 or higher. If you are running one of these versions of macOS and wish to auto-create icons with Epichrome, please check the README page on Github for instructions on how to install the correct version of PHP.)"
    fi
fi


# MAKEICON: use makeicon.php to build icons
#  makeicon(aIconSource aAppIcon [aDocIcon aWelcomeIcon aCrop aCompSize aCompBG aDoProgress aMaxSize aMinSize aSourceSizeVar])
function makeicon {
    
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
    local aMaxSize="$1" ; shift
    local aMinSize="$1" ; shift
    local aSourceSizeVar="$1" ; shift
    
    debuglog 'Starting makeicon.'  # $$$
    
    [[ "$aDoProgress" ]] && progress '!stepIconA1'
    
    # makeicon script location
    if [[ ! "$iMakeIconScript" ]] ; then
        local iMakeIconScript="$myScriptPathEpichrome/makeicon.php"
    fi
    if [[ ! -e "$iMakeIconScript" ]] ; then
        ok= ; errmsg="Unable to locate icon creation script."
        errlog
        return 1
    fi
    
    # path to icon templates
    if [[ ! "$iIconTemplatePath" ]] ; then
        local iIconTemplatePath="${myScriptPathEpichrome%/Scripts}/Icons"
    fi
    
    # path to iconset directories
    local iAppIconset="${aAppIcon%.icns}.iconset"
    [[ "$aDocIcon" ]] && local iDocIconset="${aDocIcon%.icns}.iconset"
    
    # delete existing iconsets
    local iExistingIconsets=()
    [[ -e "$iAppIconset" ]] && iExistingIconsets+=( "$iAppIconset" )
    [[ "$aDocIcon" && -d "$iAppIconset" ]] && iExistingIconsets+=( "$iDocIconset" )
    if [[ "${iExistingIconsets[*]}" ]] ; then
        debuglog 'Deleting existing iconsets.'  # $$$
        
        try /bin/rm -rf "${iExistingIconsets[@]}" \
            'Unable to delete existing iconset directories.'
    fi
    
    # IF NECESSARY, CONVERT TO A FORMAT MAKEICON.PHP CAN READ
    
    # JSON for original source path (if necessary)
    local iOrigSourcePath=
    
    # regex to pull out sips info
    local iSipsRe='format: *([^ ]+).*pixelWidth: *([0-9]+).*pixelHeight: *([0-9]+)'
    # list of formats PHP can read without conversion
    local iFormatRe='^(jpeg|png|gif|bmp)$'
    
    # source for PHP script (assume just the original source)
    local iPHPSource="$aIconSource"
    local iPHPSourceFormat=
    
    debuglog "Getting image properties for \"$aIconSource\"."  # $$$
    
    # check format of icon source
    local iSourceInfo=
    try 'iSourceInfo=' /usr/bin/sips \
            --getProperty format --getProperty pixelWidth --getProperty pixelHeight \
            "$aIconSource" \
            "File \"${aIconSource##*/}\" is not a known image type."
    [[ "$ok" ]] || return 1
    
    # pull out info
    local iSourceFormat=
    if [[ "$iSourceInfo" =~ $iSipsRe ]] ; then
        iSourceFormat="${BASH_REMATCH[1]}"
        
        if [[ "$aSourceSizeVar" ]] ; then
            # set aSourceSizeVar to array with width & height
            eval "$aSourceSizeVar=( \"\${BASH_REMATCH[2]}\" \"\${BASH_REMATCH[3]}\" )"
        fi
    else
        errlog FATAL "$iSourceInfo"
        ok= ; errmsg="Unable to parse file info for \"${aIconSource##*/}\"."
        errlog
        return 1
    fi
    
    # if imagecreatefromwebp is ever implemented in PHP:
    # if [[ "$aIconSource" = *'.'[wW][eE][bB][pP] ]] ; then
    #     iPHPSourceFormat='webp'
    
    if [[ "$iSourceFormat" =~ $iFormatRe ]] ; then
        # set source format
        iPHPSourceFormat="${iSourceFormat##*format: }"
    else
        
        # image is not in a format PHP can understand, so convert
        
        # temporary PNG file
        iPHPSource="$(tempname "${aAppIcon%.icns}" ".png")"
        iPHPSourceFormat='png'
        
        debuglog "Converting \"$aIconSource\" to PNG."  # $$$
        
        # convert input source
        try '!1' /usr/bin/sips --setProperty format png --out "$iPHPSource" "$aIconSource" \
            'Unable to create temporary PNG for processing.'
        [[ "$ok" ]] || return 1
        
        # add origPath argument to PHP
        iOrigSourcePath=',
            "origPath": "'"$(escapejson "$aIconSource")"'"'
    fi
    
    debuglog 'Creating empty iconset directories.'  # $$$
    
    # create empty iconset directories
    local iNewIconsets=( "$iAppIconset" )
    [[ "$aDocIcon" ]] && iNewIconsets+=( "$iDocIconset" )
    try /bin/mkdir -p "${iNewIconsets[@]}" \
        'Unable to create temporary iconset directories.'
    
    if [[ "$ok" ]] ; then
        
        debuglog 'Building makeicon.php command.'  # $$$
        
        # set up progress info in case it's requested
        if [[ "$aDoProgress" ]] ; then
            function iStepJson {
                local iComma= ; [[ "$2" ]] || iComma=','
                echo "$iComma"$'\n            "progress'"$2"'": "stepMakeicon'"$1"'"' ; }
        else
            function iStepJson { : ; }
        fi
        
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
                    errlog
                fi
            fi
            
            # create comp commands
            local iAppIconCompCmd='
        {
            "action": "composite"'"$(iStepJson B)"',
            "options": {
                "crop": '"$aCrop"',
                "size": '"$iAppIconCompSize"',
                "clip": true,
                "with": [ {
                    "action": "read",
                    "options": {
                        "format": "png",
                        "path": "'"$(escapejson "$iAppIconCompBG")"'"
                    }
                } ]
            }
        },
        {
            "action": "composite"'"$(iStepJson C)"',
            "options": {
                "with": [ {
                    "action": "read",
                    "options": {
                        "format": "png",
                        "path": "'"$(escapejson "$iIconTemplatePath/apptemplate_shadow.png")"'"
                    }
                } ]
            }
        },'
            
            # steps specific to compositing an app icon
            local iAppSteps=( 'stepMakeiconB' 'stepMakeiconC' )
        else
            
            # don't comp this in any way, just use the straight image
            local iAppIconCompCmd='
        {
            "action": "composite"'"$(iStepJson D)"',
            "options": {
                "crop": '"$aCrop"'
            }
        },'
            
            # steps specific to an making an old-style icon
            local iAppSteps=( 'stepMakeiconD' )
        fi
        
        # build options for icon max & min sizes
        if [[ "$aMaxSize" || "$aMinSize" ]] ; then
            local iLimitOpts=()
            [[ "$aMaxSize" ]] && iLimitOpts+=( '"maxSize": '"$aMaxSize" )
            [[ "$aMinSize" ]] && iLimitOpts+=( '"minSize": '"$aMinSize" )
        fi
        
        # option list for write_iconset command
        local iWriteIconsetOpts
        
        # build doc icon command
        local iDocIconCmd=
        if [[ "$aDocIcon" ]] ; then
            
            # set write_iconset options
            iWriteIconsetOpts=( "${iLimiOpts[@]}" )
            [[ "$aDoProgress" ]] && iWriteIconsetOpts+=( "$(iStepJson H Stem)" )
            
            iDocIconCmd=',
        [
            {
                "action": "composite"'"$(iStepJson F)"',
                "options": {
                    "crop": '"$aCrop"',
                    "size": 0.5,
                    "ctrY": 0.48828125,
                    "with": [
                        {
                            "action": "read",
                            "options": {
                                "format": "png",
                                "path": "'"$(escapejson "$iIconTemplatePath/doctemplate_bg.png")"'"
                            }
                        }
                    ]
                }
            },
            {
                "action": "composite"'"$(iStepJson G)"',
                "options": {
                    "compUnder": true,
                    "with": [
                        {
                            "action": "read",
                            "options": {
                                "format": "png",
                                "path": "'"$(escapejson "$iIconTemplatePath/doctemplate_fg.png")"'"
                            }
                        }
                    ]
                }
            },
            {
                "action": "write_iconset",
                "path": "'"$(escapejson "$iDocIconset")"'",
                "options": {
                    '"$(join_array ",
                    " "${iWriteIconsetOpts[@]}")"'
                }
            }
        ]'
        fi
        
        # set write_iconset options
        iWriteIconsetOpts=( "${iLimiOpts[@]}" )
        [[ "$aDoProgress" ]] && iWriteIconsetOpts+=( "$(iStepJson E Stem)" )

        # build final makeicon.php command
        local iMakeIconCmd='
[
    {
        "action": "read"'"$(iStepJson A)"',
        "options": {
            "format": "'"$iPHPSourceFormat"'",
            "path": "'"$(escapejson "$iPHPSource")"'"'"$iOrigSourcePath"'
        }
    },
    ['"$iAppIconCompCmd"'
        {
            "action": "write_iconset",
            "path": "'"$(escapejson "$iAppIconset")"'",
            "options": {
                '"$(join_array ",
                " "${iWriteIconsetOpts[@]}")"'
            }
        }
    ]'"$iDocIconCmd"'
]'
        
        # set list of steps for current icon creation
        local iSteps=( 'stepMakeiconA' "${iAppSteps[@]}" \
                'stepMakeiconE1' 'stepMakeiconE2' 'stepMakeiconE3' 'stepMakeiconE4' )
        [[ "$iDocIconCmd" ]] && \
            iSteps+=( 'stepMakeiconF' 'stepMakeiconG' \
                    'stepMakeiconH1' 'stepMakeiconH2' 'stepMakeiconH3' 'stepMakeiconH4' )
        
        
        # RUN PHP SCRIPT TO CONVERT IMAGE INTO APP (AND MAYBE DOC ICONS)
        
        local iMakeIconErr=
        
        debuglog 'Running makeicon.php.'  # $$$
        
        if [[ "$aDoProgress" ]] ; then
            # run through a pipe for progress updates
            try '-12' "$myPHPPath" "$iMakeIconScript" "$iMakeIconCmd" '' 2>&1 | makeiconprogress
            
            # retrieve any output
            try 'iMakeIconErr=' /bin/cat "$stdoutTempFile" 'Unable to read output from makeicon.'
            if [[ "$ok" ]] ; then
                if [[ "$iMakeIconErr" = 'PROGRESSERR|'* ]] ; then
                    iMakeIconErr="${iMakeIconErr#PROGRESSERR|}"
                    ok=
                fi
            elif [[ ! "$progressDoCalibrate" ]] ; then
                # if not calibrating, we don't really need these messages
                ok=1 ; errmsg=
            fi
            
            if [[ "$ok" ]] ; then
                if [[ "$progressDoCalibrate" ]] ; then
                    
                    # calibrating, so set calibration variables (lost because of pipe)
                    
                    # set calibration time
                    progressCalibrateEndTime="$iMakeIconErr"
                    iMakeIconErr=
                    
                    # set progress ID variables
                    progressLastId="${iSteps[@]:$((${#iSteps[@]}-1))}"
                    progressIdList+=( "${iSteps[@]}" )
                else
                    # add in times from makeicon steps we just ran
                    local iCurStep=
                    for iCurStep in "${iSteps[@]}" ; do
                        eval "progressCumulative=\$(( \$progressCumulative + \$$iCurStep ))"
                    done
                fi
            fi
        else
            try '-1' 'iMakeIconErr=2' "$myPHPPath" "$iMakeIconScript" "$iMakeIconCmd" ''
        fi
        
        # log any stderr output
        local iMakeIconOutput="${iMakeIconErr%PHPERR|*}"
        [[ "$iMakeIconOutput" ]] && errlog STDERR "$iMakeIconOutput"
        
        if [[ "$ok" ]] ; then
            
            debuglog 'Converting iconset to ICNS.'  # $$$
            
            # convert iconsets to ICNS
            try /usr/bin/iconutil -c icns -o "$aAppIcon" "$iAppIconset" \
                'Unable to create app icon from temporary iconset.'
            [[ "$aDocIcon" ]] && \
                try /usr/bin/iconutil -c icns -o "$aDocIcon" "$iDocIconset" \
                    'Unable to create document icon from temporary iconset.'
        else
            # handle messaging for makeicon.php errors
            errmsg="${iMakeIconErr#*PHPERR|}"
            errlog
        fi
    fi
    
    [[ "$aDoProgress" ]] && progress 'stepIconA2'
    
    if [[ "$ok" && "$aWelcomeIcon" ]] ; then
        
        # CREATE WELCOME PAGE ICON
        
        # try copying 128x128 icon first
        local iWelcomeIconSrc="$iAppIconset/icon_128x128.png"
        
        if [[ -f "$iWelcomeIconSrc" ]] ; then
            debuglog 'Copying 128x128 icon to welcome page.'  # $$$
            
            permanent "$iWelcomeIconSrc" "$aWelcomeIcon" \
                'welcome page icon'
        else
            debuglog 'Resizing icon to 128x128 for welcome page.'  # $$$

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
    
    debuglog 'Removing temporary iconset directories.'  # $$$
    
    # destroy iconset directories
    tryalways /bin/rm -rf "${iNewIconsets[@]}" \
        'Unable to remove temporary iconset directories.'
    [[ "$iOrigSourcePath" ]] && \
        tryalways /bin/rm -f "$iPHPSource" \
            'Unable to remove temporary PNG.'
    
    [[ "$aDoProgress" ]] && progress 'stepIconA3'
    
    [[ "$ok" ]] && return 0 || return 1
}


# MAKEICONPROGRESS: display progress updates while making an icon
#   makeiconprogress()
function makeiconprogress {
    
    [[ "$ok" ]] || return 1
    
    local iErrOutput=
    
    # send any progress steps that come through
    local iStep
    while read iStep ; do
        
        if [[ "$iStep" = 'step'* ]] ; then
            progress "$iStep"
        else
            if [[ ! "$iErrOutput" ]] ; then
                iStep="PROGRESSERR|$iStep"
                iErrOutput=1
            fi
            try "$stdoutTempFile<<" echo "$iStep" \
                    'Unable to write out makeicon.php error.'
        fi
    done
    
    # if calibrating, write out calibration time
    if [[ "$progressDoCalibrate" && ( ! "$iErrOutput" ) ]] ; then
        try "$stdoutTempFile<" echo "$progressCalibrateEndTime" \
                'Unable to write out progress calibration time.'
        ok=1 ; errmsg=
    fi
}
