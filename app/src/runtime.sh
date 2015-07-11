#!/bin/sh
#
#  runtime.sh: runtime utility functions for Chrome SSBs
#
#  Copyright (C) 2015 David Marmor
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


# NOTE: functions in this script put any error text into the variable cmdtext
#       and return 1 on error, or 0 on success


# CONSTANTS

# app executable name
CFBundleExecutable="ChromeSSB"

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="doc.icns"

# app paths -- relative to app Contents directory
appInfoPlist="Info.plist"
appConfigScript="Resources/Scripts/config.sh"
appStringsScript="Resources/Scripts/strings.py"
appScriptingSdef="Resources/scripting.sdef"
appChromeLink="MacOS/Chrome"


# TEMPNAME: internal version of mktemp
function tempname {
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    result="${1}.${RANDOM}${2}"
    while [ -e "$result" ] ; do
	result="${result}.${RANDOM}${2}"
    done

    echo "$result"
}


# PERMANENT: move temporary file or directory to permanent location safely
function permanent {

    local result=0
    
    local temp="$1"
    local perm="$2"
    local filetype="$3"
    local saveTempOnError="$4"  # optional argument
    
    local permOld=
    

    # MOVE OLD FILE OUT OF THE WAY, MOVE TEMP FILE TO PERMANENT NAME, DELETE OLD FILE
    
    # move the permanent file to a holding location for later removal
    if [ -e "$perm" ] ; then
	permOld=$(tempname "$perm")
	cmdtext=$(/bin/mv "$perm" "$permOld" 2>&1)
	if [ $? != 0 ] ; then
	    cmdtext="Unable to move old $filetype."
	    permOld=
	    result=1
	fi
    fi
    
    # move the temp file or directory to its permanent name
    if [ $result = 0 ] ; then
	cmdtext=$(/bin/mv -f "$temp" "$perm" 2>&1)
	if [ $? != 0 ] ; then
	    cmdtext="Unable to move new $filetype into place."
	    result=1
	fi
    fi
    
    # remove the old permanent file or folder if there is one
    if [ $result = 0 ] ; then
	temp=
	if [ -e "$permOld" ]; then
	    cmdtext=$(/bin/rm -rf "$permOld" 2>&1)
	    if [ $? != 0 ] ; then
		cmdtext="Unable to remove old $filetype."
		result=1
	    fi
	fi
    fi

    
    # IF WE FAILED, CLEAN UP

    if [ $result != 0 ] ; then
	
	# move old permanent file back
	if [ "$permOld" ] ; then
	    /bin/mv "$permOld" "$perm" > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to restore old $filetype."
	fi
	
	# delete temp file
	[ \( ! "$saveTempOnError" \) -a \( -e "$temp" \) ] && rmtemp "$temp" "$filetype"
    else
	cmdtext=
    fi
    
    return $result
}


# SAFECOPY: safely copy a file or directory to a new location
function safecopy {

    local result=0
    cmdtext=
    
    # copy in custom icon
    local src="$1"
    local dst="$2"
    local filetype="$3"

    # get dirname for destination
    local dstDir="$(dirname "$dst")"
    if [ $? != 0 ] ; then
	cmdtext="Unable to get destination directory listing for $filetype."
	return 1
    fi

    # make sure destination directory exists
    /bin/mkdir -p "$dstDir" > /dev/null 2>&1
    if [ $? != 0 ] ; then
	cmdtext="Unable to create the destination directory for $filetype."
	return 1
    fi
    
    # copy to temporary location
    local dstTmp=$(tempname "$dst")
    /bin/cp -a "$src" "$dstTmp" > /dev/null 2>&1
    if [ $? = 0 ] ; then
	# move file to permanent home
	permanent "$dstTmp" "$dst" "$filetype"
	[ $? != 0 ] && result=1
    else
	# failure
	cmdtext="Unable to copy $filetype."
	result=1
    fi
    
    return $result
}


# RMTEMP: remove a temporary file or directory on failure
function rmtemp {
    local temp="$1"
    local filetype="$2"
    local result=0
    
    # delete the temp file
    if [ -e "$temp" ] ; then
	/bin/rm -f "$tmpInfoPlist" > /dev/null 2>&1
    fi
    if [ $? != 0 ] ; then
	if [ "$cmdtext" ] ; then
	    cmdtext="$cmdtext Also unable"
	else
	    cmdtext="Unable"
	fi
	cmdtext="$cmdtext to remove temporary $filetype."
	result=1
    fi
    
    return $result
}


# DIRLIST: get (and possibly filter) a directory listing
function dirlist {
    local dir="$1"
    local outname="$2"
    local fileinfo="$3"
    local filter="$4"
    
    local files=($(unset CLICOLOR ; /bin/ls "$dir" 2>&1))
    if [ $? != 0 ] ; then
	cmdtext="Unable to retrieve $fileinfo list."
	return 1
    fi

    if [ "$filter" ] ; then
	local filteredfiles=()
	local f=
	for f in "${files[@]}" ; do
	    [[ "$f" =~ $filter ]] && filteredfiles=("${filteredfiles[@]}" "$f")
	done
	files=("${filteredfiles[@]}")
    fi
    
    eval "${outname}=(\"\${files[@]}\")"

    return 0
}


# NEWVERSION (V1 V2) -- check if the V1 < V2
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
	if [ "${old[$i]}" -lt "${new[$i]}" ] ; then
	    echo "1"
	    return 1
	fi
	[ "${old[$i]}" -gt "${new[$i]}" ] && return 0
    done
    
    return 0
}


# MCSSBINFO: get absolute path and version info for MakeChromeSSB
function mcssbinfo {
    # default value
    mcssbVersion="$SSBVersion"
    
    # default location for MakeChromeSSB
    if [ "$1" ] ; then
	mcssbPath="$1"
    else
	mcssbPath="/Applications/Make Chrome SSB.app"    
	
	# if it's not in the standard spot, try using spotlight.
	if [ ! -d "$mcssbPath" ] ; then
	    mcssbPath=$(mdfind "kMDItemCFBundleIdentifier == 'com.dmarmor.MakeChromeSSB'" | head -n 1)
	fi
    fi
    
    # not found
    if [ ! -d "$mcssbPath" ] ; then
	mcssbPath=
	cmdtext="Unable to find MakeChromeSSB app."
	return 1
    fi
    
    # get current value for mcssbVersion
    source "${mcssbPath}/Contents/Resources/Scripts/version.sh"
    if [ $? != 0 ] ; then
	cmdtext="Unable to load MakeChromeSSB version."
	return 2
    fi
        
    return 0
}


# CHROMEINFO: find absolute paths to and info on relevant Google Chrome items
function chromeinfo {
    # default location for Chrome -- first try the config value
    if [ "$SSBChromePath" ] ; then
	chromePath="$SSBChromePath"
    else
	chromePath="/Applications/Google Chrome.app"
    fi
    
    
    # if it's not in the standard spot, try using spotlight.
    if [ ! -d "$chromePath" ] ; then
	chromePath=$(mdfind "kMDItemCFBundleIdentifier == 'com.google.Chrome'" | head -n 1)
    fi

    if [ ! -d "$chromePath" ] ; then

	# last-ditch - ask the user to locate it
	chromePath=$(osascript -e 'return POSIX path of (choose application with title "Locate Chrome" with prompt "Please locate Google Chrome" as alias)' 2> /dev/null)
	chromePath="${chromePath%/}"

	if [ ! -d "$chromePath" ] ; then
	    chromePath=
	    cmdtext="Unable to find Google Chrome application."
	    return 1
	fi
    fi
    
    # Chrome executable
    chromeExec="${chromePath}/Contents/MacOS/Google Chrome"
    if [ ! -x "$chromeExec" ] ; then
	chromeExec=
	cmdtext="Unable to find Google Chrome executable."
	return 1
    fi
    
    # Chrome Info.plist
    chromeInfoPlist="${chromePath}/Contents/Info.plist"
    if [ ! -e "$chromeInfoPlist" ] ; then
	chromeInfoPlist=
	cmdtext="Unable to find Google Chrome Info.plist file."
	return 1
    fi
    
    # Chrome scripting.sdef
    chromeScriptingSdef="${chromePath}/Contents/Resources/scripting.sdef"
    if [ ! -e "$chromeScriptingSdef" ] ; then
	chromeScriptingSdef=
	cmdtext="Unable to find Google Chrome scripting.sdef file."
	return 1
    fi

    # Chrome version
    local re='^kMDItemVersion = "(.*)"$'
    chromeVersion=$(/usr/bin/mdls -name kMDItemVersion "$chromePath")
    if [[ "$chromeVersion" =~ $re ]] ; then
	chromeVersion="${BASH_REMATCH[1]}"
    else
	cmdtext="Unable to retrieve Chrome version."
	return 1
    fi
    
    # (alternate version not using mdls)
    #     local re='<key>CFBundleShortVersionString</key>[ 	
    # ]*<string>([^<]*)</string>'
    #     local infoplist=$(/bin/cat "$chromeInfoPlist" 2> /dev/null)
    #     if [ $? != 0 ] ; then
    # 	cmdtext="Unable to read Chrome Info.plist."
    # 	return 1
    #     fi
    #     if [[ "$infoplist" =~ $re ]] ; then
    # 	chromeVersion="${BASH_REMATCH[1]}"
    #     else
    # 	cmdtext="Unable to retrieve Chrome version."
    #   return 1
    #     fi
    
    cmdtext=
    return 0
}


# LINKCHROME: link to absolute path to Google Chrome executable inside its app bundle
function linkchrome {  # $1 = destination app bundle Contents directory

    # full path to Chrome link
    local fullChromeLink="$1/$appChromeLink"
    
    # find Chrome paths if necessary
    [ ! "$chromePath" ] && chromeinfo
    
    # make the new link in a temporary location
    local tmpChromeLink=$(tempname "$fullChromeLink")
    
    # create temporary link
    cmdtext=$(/bin/ln -s "$chromeExec" "$tmpChromeLink" 2>&1)
    if [ "$?" != "0" ] ; then
	cmdtext="Unable to create link to Chrome executable."
	return 1
    fi
    
    # overwrite permanent link
    permanent "$tmpChromeLink" "$fullChromeLink" "Chrome executable link"
    [ $? != 0 ] && return 1
    
    cmdtext=
    return 0
}


# WRITEPLIST: write out new Info.plist file
function writeplist {  # $1 = destination app bundle Contents directory

    # ensure Chrome's Info.plist file is where we think it is
    if [ ! -f "$chromeInfoPlist" ] ; then
	cmdtext="Unable to find Google Chrome Info.plist file."
	return 1
    fi
    
    # full path to Info.plist file
    local fullInfoPlist="$1/$appInfoPlist"
    
    # create name for temp Info.plist file
    local tmpInfoPlist=$(tempname "$fullInfoPlist")
        
    # create list of keys to filter
    filterkeys=(CFBundleDisplayName string "$CFBundleDisplayName" \
				    CFBundleExecutable string "$CFBundleExecutable" \
				    CFBundleIconFile string "$CFBundleIconFile" \
				    CFBundleIdentifier string "$CFBundleIdentifier" \
				    CFBundleName string "$CFBundleName" \
				    CFBundleShortVersionString string "$mcssbVersion" \
				    CFBundleVersion string "$mcssbVersion" \
				    CFBundleTypeIconFile string "$CFBundleTypeIconFile" \
				    CFBundleSignature '' \
				    SCMRevision '' \
				    DTSDKBuild '' \
				    DTSDKName '' \
				    DTXcode '' \
				    DTXcodeBuild '' \
				    KSChannelID-32bit '' \
				    KSChannelID-32bit-full '' \
				    KSChannelID-full '' \
				    KSProductID '' \
				    KSUpdateURL '' \
				    KSVersion '' \
				    NSHighResolutionCapable true )
    
    # if we're not registering as a browser, delete these keys too
    if [ "$SSBRegisterBrowser" != "Yes" ] ; then
	filterkeys+=( CFBundleURLTypes '' \
				       NSPrincipalClass '' \
				       NSUserActivityTypes '' )
    fi
    
    # run python script to filter Info.plist
    cmdtext=$(/usr/bin/python "$1/Resources/Scripts/infoplist.py" \
			      "$chromeInfoPlist" \
			      "$tmpInfoPlist" \
			      "${filterkeys[@]}" 2>&1)
    if [ $? != 0 ] ; then
	cmdtext="Error filtering Info.plist file: $cmdtext."
	
	# delete the temp file
	rmtemp "$tmpInfoPlist" "Info.plist"
	return 1
    else
	# move temp file to permanent location
	permanent "$tmpInfoPlist" "$fullInfoPlist" "Info.plist"
	[ $? != 0 ] && return 1
    fi
    
    return 0
}


# COPYCHROMELPROJ: copy Google Chrome .lproj directories and update localization strings
function copychromelproj {  # $1 = destination app bundle Contents directory

    # full path to Resources directory
    local appResources="$1/Resources"

    local chromeResources="${chromePath}/Contents/Resources"
        
    local result=0
    local oldlprojholder=$(tempname "$appResources/oldlproj")
    local newlprojholder=$(tempname "$appResources/newlproj")
    
    # move any existing .lproj directories to holder
    local oldlprojlist=
    dirlist "$appResources" lprojlist "old localizations" '\.lproj$'
    if [ "${#lprojlist[@]}" -gt 0 ] ; then
	/bin/mkdir "$oldlprojholder" > /dev/null 2>&1
	[ $? != 0 ] && result=1
	if [ $result = 0 ] ; then
	    /bin/mv "$appResources/"*.lproj "$oldlprojholder" > /dev/null 2>&1
	    if [ $? != 0 ] ; then
		/bin/rmdir "$oldlprojholder" > /dev/null 2>&1
		result=1
	    fi
	fi
	[ $result != 0 ] && cmdtext="Unable to relocate old localization directories."
    fi
    
    # copy all .lproj directories from Chrome
    if [ $result = 0 ] ; then
	/bin/mkdir "$newlprojholder" > /dev/null 2>&1
	[ $? != 0 ] && result=1
	if [ $result = 0 ] ; then
	    /bin/cp -a "$chromeResources/"*.lproj "$newlprojholder" > /dev/null 2>&1
	    [ $? != 0 ] && result=1
	fi
	[ $result != 0 ] && cmdtext="Unable to copy localization directories."
    fi
    
    # filter the InfoPlist.strings files for the .lproj directories
    if [ $result = 0 ] ; then
	# run python script to do unicode filtering
	cmdtext=$(/usr/bin/python "$appResources/Scripts/strings.py" "$CFBundleDisplayName" "$CFBundleName" "$newlprojholder/"*.lproj 2>&1)
	[ $? != 0 ] && result=1
    fi

    # move new .lproj directories to permanent location
    if [ $result = 0 ] ; then
	/bin/mv "$newlprojholder/"*.lproj "$appResources" > /dev/null 2>&1
	if [ $? = 0 ] ; then
	    /bin/rmdir "$newlprojholder" > /dev/null 2>&1
	    if [ $? != 0 ] ; then
		cmdtext="Unable to remove temporary new localization container."
		result=1
	    fi
	else
	    cmdtext="Unable to move new localization directories to permanent location."
	    result=1
	fi
    fi
    
    # remove old .lproj directories
    if [ $result = 0 ] ; then
	/bin/rm -rf "$oldlprojholder" > /dev/null 2>&1
	if [ $? != 0 ] ; then
	    cmdtext="Unable to remove old localization directories."
	    result=1
	fi
    fi
    
    # on error, clean up as best we can
    if [ $result != 0 ] ; then
	if [ -d "$newlprojholder" ] ; then
	    /bin/rm -rf "$newlprojholder" > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to clean up new localization directories."
	fi
	if [ -d "$oldlprojholder" ] ; then
	    /bin/mv "$oldlprojholder/"* "$appResources"  > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to move old localization directories back into place."
	fi
    fi
    
    return $result
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # $1 = destination app bundle Contents directory

    local configvars=( CFBundleDisplayName \
			   CFBundleName \
			   CFBundleIdentifier \
			   SSBVersion \
			   SSBProfilePath \
			   SSBChromePath \
			   SSBChromeVersion \
			   SSBRegisterBrowser \
			   SSBCustomIcon \
			   SSBExtInstallError \
			   SSBHostInstallError \
			   SSBCommandLine )
    
    local re='^declare -a'
    local var=
    local value=
    local arr=()
    local i

    # full path to final config script
    local fullConfigScript="$1/$appConfigScript"
    
    # make temporary config file
    local tmpAppConfigScript=$(tempname "$fullConfigScript")

    local result=0
    echo "# config.sh -- autogenerated $(/bin/date)" > "$tmpAppConfigScript" 2>&1
    [ $? != 0 ] && result=1
    
    if [ $result = 0 ] ; then
	echo "" >> "$tmpAppConfigScript"
	[ $? != 0 ] && result=1
    fi
    
    if [ $result = 0 ] ; then
	for var in "${configvars[@]}" ; do
	    if [[ "$(declare -p "$var")" =~ $re ]]; then
		value="("
		eval "arr=(\${$var[@]})"
		for i in "${arr[@]}" ; do
		    value="${value} $(printf "%q" "$i")"
		done
		value="${value} )"
	    else
		value=$(eval "printf '%q' \"\$$var\"")  #"echo \"\\\"\$$var\\\"\"")"
	    fi
	    
	    echo "${var}=${value}" >> "$tmpAppConfigScript"
	    if [ $? != 0 ] ; then
		result=1
		break
	    fi
	done
    fi
    
    # move the temp file to its permanent place
    if [ $result = 0 ] ; then
	permanent "$tmpAppConfigScript" "$fullConfigScript" "config file"
	[ $? != 0 ] && result=1
    else
	# error earlier trying to write the temp config file
	cmdtext="Unable to write config file."
	rmtemp "$tmpAppConfigScript" "config file"
    fi
    
    return $result
}


# UPDATESSB: function that actually populates an app bundle with the SSB
function updatessb {
    # command-line arguments
    local appPath="$1"
    local customIconFile="$2"
    local chromeOnly="$3"  # if non-empty, we're ONLY updating Chrome stuff
    
    local result=0

    # initially set this to permanent Contents directory
    local contentsTmp="$appPath/Contents"
    
    
    # FULL UPDATE OPERATION
    
    if [ ! "$chromeOnly" ] ; then
	
	# we need an actual temporary Contents directory
	local contentsTmp=$(tempname "$appPath/Contents")
	
	# copy in the boilerplate for the app
	/bin/cp -a "$mcssbPath/Contents/Resources/Runtime" "$contentsTmp" > /dev/null 2>&1
	if [ $? != 0 ] ; then
	    cmdtext="Unable to populate app bundle."
	    result=1
	fi
	
	# place custom icon, if any
	if [ $result = 0 ] ; then
	    
	    # check if we are copying from an old version of a custom icon
	    if [ \( ! "$customIconFile" \) -a \( "$SSBCustomIcon" = "Yes" \) ] ; then
		customIconFile="$appPath/Contents/Resources/$CFBundleIconFile"
	    fi
	    
	    # if there's a custom icon, copy it in
	    if [ -e "$customIconFile" ] ; then	    
		# copy in custom icon
		safecopy "$customIconFile" "${contentsTmp}/Resources/${CFBundleIconFile}" "custom icon"
		[ $? != 0 ] && result=1
	    fi
	fi
	
	# link to Chrome
	if [ $result = 0 ] ; then	
	    linkchrome "$contentsTmp"
	    [ $? != 0 ] && result=1
	fi

	# create a bundle identifier if necessary
	if [ $result = 0 ] ; then
	    local idbase="com.google.SSB."
	    local idre="^${idbase//./\\.}"

	    # make a new identifier if: either we're making a new SSB, or
	    # updating an old enough version that there's either no
	    # CFBundleIdentifier or an old format one
	    
	    if [[ ! "$CFBundleIdentifier" || ! ( "$CFBundleIdentifier" =~ $idre ) ]] ; then
		
		# create a bundle identifier
		local maxbidlength=$((30 - ${#idbase}))       # identifier must be 30 characters or less
		local bid="${CFBundleName//[^-a-zA-Z0-9_]/}"  # remove all undesirable characters
		[ ! "$bid" ] && bid="generic"                 # if trimmed away to nothing, use a default name
		bid="${bid::$maxbidlength}"
		local bidbase="${bid::$(($maxbidlength - 3))}" ; bidbase="${#bidbase}"  # length of the ID's base if using uniquifying numbers
		
		# if this identifier already exists on the system, create a unique one
		local idfound=0
		local notunique=1
		local randext="000"
		while [ "$notunique" ] ; do
		    CFBundleIdentifier="${idbase}$bid"
		    idfound=$(mdfind "kMDItemCFBundleIdentifier == '$CFBundleIdentifier'" | wc -l)
		    if [ $? != 0 ] ; then
			cmdtext="Unable to search system for bundle identifier."
			notunique=
			result=1
		    fi
		    
		    if [ "$idfound" -le 0 ] ; then
			notunique=
		    else
			# try to create a unique identifier
			randext=$(((${RANDOM} * 100 / 3279) + 1000))  # 1000-1999
			bid="${bid::$bidbase}${randext:1:3}"
		    fi
		done
		
		# if we got out of that loop, we have a unique ID (or we got an error)
	    fi
	fi
	
	if [ $result = 0 ] ; then
	    [ "$SSBProfilePath" ] || SSBProfilePath="${HOME}/Library/Application Support/Chrome SSB/${CFBundleDisplayName}"
	fi
    fi
    
    
    # OPERATIONS FOR UPDATING CHROME

    # write out Info.plist
    if [ $result = 0 ] ; then
	writeplist "$contentsTmp"
	[ $? != 0 ] && result=1
    fi
    
    # copy Chrome .lproj directories and modify InfoPlist.strings files    
    if [ $result = 0 ] ; then
	copychromelproj "$contentsTmp"
	[ $? != 0 ] && result=1
    fi
    
    # copy scripting.sdef
    if [ $result = 0 ] ; then
	safecopy "$chromeScriptingSdef" "$contentsTmp/$appScriptingSdef" "Chrome scripting.sdef file"
	[ $? != 0 ] && result=1
    fi
    
    
    # WRITE OUT CONFIG FILE
    
    if [ $result = 0 ] ; then
	# set up output versions of config variables
	SSBVersion="$mcssbVersion"
	SSBChromePath="$chromePath"    
	SSBChromeVersion="$chromeVersion"

	# clear error state for installing extension and messaging host
	SSBExtInstallError=
	SSBHostInstallError=
	
	# write the config file
	writeconfig "$contentsTmp"
	[ $? != 0 ] && result=1
    fi    

    
    # MOVE CONTENTS TO PERMANENT HOME
    
    if [ ! "$chromeOnly" ] ; then
	# only need to do this if we were doing a full update
	if [ $result = 0 ] ; then
	    permanent "$contentsTmp" "$appPath/Contents" "app bundle Contents directory"
	    [ $? != 0 ] && result=1
	else
	    # error -- delete temporary Contents directory
	    rmtemp "$contentsTmp"
	fi
    fi

    return $result
}
