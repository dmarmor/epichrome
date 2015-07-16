#!/bin/sh
#
#  runtime.sh: runtime utility functions for Epichrome creator & apps
#  Copyright (C) 2015  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
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


# NOTE: the "try" function and many other functions in this system clear
#       the "ok" global variable on error, set a message in "errmsg",
#       and return 0 on success, non-zero on error


# CONSTANTS

# app executable name
CFBundleExecutable="Epichrome"

# icon names
CFBundleIconFile="app.icns"
CFBundleTypeIconFile="doc.icns"

# app paths -- relative to app Contents directory
appInfoPlist="Info.plist"
appConfigScript="Resources/Scripts/config.sh"
appStringsScript="Resources/Scripts/strings.py"
appScriptingSdef="Resources/scripting.sdef"
appChromeLink="MacOS/Chrome"

# profile base
appProfileBase="Library/Application Support/Epichrome/Apps"


# TRY: try to run a command, as long as no errors have already been thrown
#
#      usage:
#        try 'varname=' cmd arg arg arg 'Error message.'
#        try 'filename.txt<' cmd arg arg arg 'Error message.'
#        try cmd arg arg arg 'Error message.'
#
# get first line of a variable: "${x%%$'\n'*}"
#
ok=1
errmsg=
function try {
    # only run if no prior error
    if [[ "$ok" ]]; then
	
	# see if we're storing output
	local target="$1"
	local type="${target:${#target}-1}"
	if [[ "$type" = "=" ]]; then
	    # storing in a variable
	    target="${target%=}"
	    type=var
	    shift
	elif [[ "$type" = "<" ]]; then
	    # storing in a file
	    target="${target%<}"
	    type=
	    if [[ "${target:${#target}-1}" = '<' ]] ; then
		# append to file
		target="${target%<}"
		type=append
	    fi
	    shift
	else
	    # not storing
	    target='/dev/null'
	    type=
	fi
	
	# get command-line args
	local args=("$@")
	
	# last arg is error message
	local last=$((${#args[@]} - 1))
	local myerrmsg="${args[$last]}"
	unset args[$last]
	
	# run the command
	local result=
	if [[ "$type" = var ]] ; then
	    # store result in named variable
	    local temp="$("${args[@]}" 2>&1)"
	    result="$?"
	    eval "${target}=$(printf '%q' "$temp")"
	elif [[ "$type" = append ]] ; then
	    # append result to a file or /dev/null
	    "${args[@]}" >> "$target" 2>&1
	    result="$?"
	else
	    # store result in a file or /dev/null
	    "${args[@]}" > "$target" 2>&1
	    result="$?"
	fi

	# check result
	if [[ "$result" != 0 ]]; then
	    [[ "$myerrmsg" ]] && errmsg="$myerrmsg"
	    ok=
	    return "$result"
	fi
    fi
    
    return 0
}


# ONERR -- like TRY above, but it only runs if there's already been an error
function onerr {
    
    # try a command, but only if there's already been an error
    
    if [[ ! "$ok" ]] ; then
	
	# save old error message
	local olderrmsg="$errmsg"

	# run the command
	ok=1
	try "$@"
	local result="$?"
	ok=
	
	# add new error message
	if [[ "$errmsg" ]] ; then
	    errmsg="$olderrmsg $errmsg"
	else
	    errmsg="$olderrmsg"
	fi
	
	return "$result"
    fi

    return 0
}


# ISARRAY -- echo "true" and return 0 if a named variable is an array
function isarray {
    if [[ "$(declare -p "$1")" =~ ^declare\ -a ]] ; then
	echo true
	return 0
    else
	return 1
    fi
}


# SAFESOURCE -- safely source a script
function safesource {
    
    # only run if no error
    if [[ "$ok" ]]; then
	
	local fileinfo=
	
	# get file info string
	if [ "$2" ] ; then
	    fileinfo="$2"
	else	
	    [[ "$fileinfo" =~ /([^/]+)$ ]] && fileinfo="${BASH_REMATCH[1]}"
	fi

	# try to source the file
	if [ -e "$1" ] ; then
	    try source "$1" "Unable to load $fileinfo."
	else
	    errmsg="Unable to find $fileinfo."
	    ok=
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# TEMPNAME: internal version of mktemp
function tempname {
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    local result="${1}.${RANDOM}${2}"
    while [ -e "$result" ] ; do
	result="${result}.${RANDOM}${2}"
    done

    echo "$result"
}


# PERMANENT: move temporary file or directory to permanent location safely
function permanent {

    if [[ "$ok" ]]; then
	
	local temp="$1"
	local perm="$2"
	local filetype="$3"
	local saveTempOnError="$4"  # optional argument
	
	local permOld=
	
	# MOVE OLD FILE OUT OF THE WAY, MOVE TEMP FILE TO PERMANENT NAME, DELETE OLD FILE
	
	# move the permanent file to a holding location for later removal
	if [ -e "$perm" ] ; then
	    permOld=$(tempname "$perm")
	    try /bin/mv "$perm" "$permOld" "Unable to move old $filetype."
	    [[ "$ok" ]] || permOld=
	fi
	
	# move the temp file or directory to its permanent name
	try /bin/mv -f "$temp" "$perm" "Unable to move new $filetype into place."
	
	# remove the old permanent file or folder if there is one
	if [[ "$ok" ]] ; then
	    temp=
	    if [ -e "$permOld" ]; then
		try /bin/rm -rf "$permOld" "Unable to remove old $filetype."
	    fi
	fi
	
	# IF WE FAILED, CLEAN UP
	
	if [[ ! "$ok" ]] ; then
	    
	    # move old permanent file back
	    if [ "$permOld" ] ; then
		onerr /bin/mv "$permOld" "$perm" "Also unable to restore old $filetype."
	    fi
	    
	    # delete temp file
	    [[ ( ! "$saveTempOnError" ) && ( -e "$temp" ) ]] && rmtemp "$temp" "$filetype"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# SAFECOPY: safely copy a file or directory to a new location
function safecopy {
    
    if [[ "$ok" ]]; then
	
	# copy in custom icon
	local src="$1"
	local dst="$2"
	local filetype="$3"
	
	# get dirname for destination
	local dstDir=
	try 'dstDir=' dirname "$dst" "Unable to get destination directory listing for $filetype."
	
	# make sure destination directory exists
	try /bin/mkdir -p "$dstDir" "Unable to create the destination directory for $filetype."
	
	# copy to temporary location
	local dstTmp=$(tempname "$dst")
	try /bin/cp -a "$src" "$dstTmp" "Unable to copy $filetype."
	
	# move file to permanent home
	permanent "$dstTmp" "$dst" "$filetype"
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# RMTEMP: remove a temporary file or directory (whether $ok or not)
function rmtemp {
    local temp="$1"
    local filetype="$2"
    
    # delete the temp file
    if [ -e "$temp" ] ; then
	if [[ "$ok" ]] ; then
	    try /bin/rm -rf "$temp" "Unable to remove temporary $filetype."
	else
	    onerr /bin/rm -rf "$temp" "Also unable to remove temporary $filetype."
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# DIRLIST: get (and possibly filter) a directory listing
function dirlist {

    if [[ "$ok" ]]; then

	local dir="$1"
	local outname="$2"
	local fileinfo="$3"
	local filter="$4"
	
	local files=($(unset CLICOLOR ; /bin/ls "$dir" 2>&1))
	if [ $? != 0 ] ; then
	    errmsg="Unable to retrieve $fileinfo list."
	    ok=
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

    fi
    
    [[ "$ok" ]] && return 0
    return 1
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


# MCSSBINFO: get absolute path and version info for Epichrome
function mcssbinfo {
    
    if [[ "$ok" ]]; then
	
	# default value
	mcssbVersion="$SSBVersion"
	mcssbPath=
	
	# find Epichrome
	
	if [ "$1" ] ; then
	    # we've been told where it is
	    mcssbPath="$1"
	else
	    # otherwise use spotlight to find it
	    if [ ! -d "$mcssbPath" ] ; then
		# try new app ID first
		mcssbPath=
		try 'mcssbPath=' mdfind "kMDItemCFBundleIdentifier == 'org.epichrome.builder'" 'Unable to find Epichrome.'
		if [[ ! "$mcssbPath" ]]; then
		    try 'mcssbPath=' mdfind "kMDItemCFBundleIdentifier == 'com.dmarmor.MakeChromeSSB'" 'Unable to find Epichrome.'
		fi
		# pull out the first instance
		mcssbPath="${mcssbPath%%$'\n'*}"
	    fi
	fi
	
	# not found
	if [[ ! -d "$mcssbPath" ]] ; then
	    mcssbPath=
	    errmsg="Unable to find Epichrome."
	    ok=
	    return 1
	fi
	
	# get current value for mcssbVersion
	try source "${mcssbPath}/Contents/Resources/Scripts/version.sh" 'Unable to load Epichrome version.'
    fi
    
    [[ "$ok" ]] && return 0
    return 1
}


# CHROMEINFO: find absolute paths to and info on relevant Google Chrome items
function chromeinfo {
    
    if [[ "$ok" ]]; then
	
	# default location for Chrome -- first try the config value
	if [ "$SSBChromePath" ] ; then
	    chromePath="$SSBChromePath"
	else
	    chromePath=
	fi

	# if it's not where we left it, try using spotlight
	if [ ! -d "$chromePath" ] ; then
	    try 'chromePath=' mdfind "kMDItemCFBundleIdentifier == 'com.google.Chrome'" ''
	    
	    # find first instance
	    chromePath="${chromePath%%$'\n'*}"	    
	fi
	
	if [[ ! "$ok" || ! -d "$chromePath" ]] ; then
	    
	    # last-ditch - ask the user to locate it
	    try 'chromePath=' osascript -e 'return POSIX path of (choose application with title "Locate Chrome" with prompt "Please locate Google Chrome" as alias)'
	    chromePath="${chromePath%/}"
	    
	    if [ ! -d "$chromePath" ] ; then
		chromePath=
		[[ "$errmsg" ]] && errmsg=" ($errmsg)"
		errmsg="Unable to find Google Chrome application.$errmsg"
		ok=
		return 1
	    fi
	fi

	# if we hit an error, abort
	[[ "$ok" ]] || return 1
	
	# Chrome executable
	chromeExec="${chromePath}/Contents/MacOS/Google Chrome"
	if [ ! -x "$chromeExec" ] ; then
	    chromeExec=
	    errmsg='Unable to find Google Chrome executable.'
	    ok=
	    return 1
	fi
	
	# Chrome Info.plist
	chromeInfoPlist="${chromePath}/Contents/Info.plist"
	if [ ! -e "$chromeInfoPlist" ] ; then
	    chromeInfoPlist=
	    errmsg='Unable to find Google Chrome Info.plist file.'
	    ok=
	    return 1
	fi
	
	# Chrome scripting.sdef
	chromeScriptingSdef="${chromePath}/Contents/Resources/scripting.sdef"
	if [ ! -e "$chromeScriptingSdef" ] ; then
	    chromeScriptingSdef=
	    errmsg='Unable to find Google Chrome scripting.sdef file.'
	    ok=
	    return 1
	fi

	# Chrome version
	local re='^kMDItemVersion = "(.*)"$'
	try 'chromeVersion=' mdls -name kMDItemVersion "$chromePath" 'Unable to retrieve Chrome version.'
	[[ "$ok" ]] || return 1
	if [[ "$chromeVersion" =~ $re ]] ; then
	    chromeVersion="${BASH_REMATCH[1]}"
	else
	    chromeVersion=
	    errmsg='Unable to retrieve Chrome version.'
	    ok=
	    return 1
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# LINKCHROME: link to absolute path to Google Chrome executable inside its app bundle
function linkchrome {  # $1 = destination app bundle Contents directory

    if [[ "$ok" ]]; then
	# full path to Chrome link
	local fullChromeLink="$1/$appChromeLink"
	
	# find Chrome paths if necessary
	[[ ! "$chromePath" ]] && chromeinfo
	
	# make the new link in a temporary location
	local tmpChromeLink=$(tempname "$fullChromeLink")
	
	# create temporary link
	try /bin/ln -s "$chromeExec" "$tmpChromeLink" 'Unable to create link to Chrome executable.'
	
	# overwrite permanent link
	permanent "$tmpChromeLink" "$fullChromeLink" "Chrome executable link"
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# WRITEPLIST: write out new Info.plist file
function writeplist {  # $1 = destination app bundle Contents directory
    
    if [[ "$ok" ]]; then
	
	# ensure Chrome's Info.plist file is where we think it is
	if [ ! -f "$chromeInfoPlist" ] ; then
	    errmsg="Unable to find Google Chrome Info.plist file."
	    ok=
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
					CFBundleShortVersionString string "$SSBVersion" \
					CFBundleVersion string "$SSBVersion" \
					CFBundleTypeIconFile string "$CFBundleTypeIconFile" \
					CFBundleSignature string '????' \
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
	if [[ "$SSBRegisterBrowser" != "Yes" ]] ; then
	    filterkeys+=( CFBundleURLTypes '' \
					   NSPrincipalClass '' \
					   NSUserActivityTypes '' )
	fi
	
	# run python script to filter Info.plist
	local pyerr=
	try 'pyerr=' python "$1/Resources/Scripts/infoplist.py" \
	    "$chromeInfoPlist" \
	    "$tmpInfoPlist" \
	    "${filterkeys[@]}" 'Error filtering Info.plist file.'
	if [[ ! "$ok" ]] ; then
	    errmsg="$errmsg ($pyerr)"
	    
	    # delete the temp file
	    rmtemp "$tmpInfoPlist" "Info.plist"
	    return 1
	else
	    # move temp file to permanent location
	    permanent "$tmpInfoPlist" "$fullInfoPlist" "Info.plist"
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# COPYCHROMELPROJ: copy Google Chrome .lproj directories and update localization strings
function copychromelproj {  # $1 = destination app bundle Contents directory

    if [[ "$ok" ]] ; then
	
	# full path to Resources directory
	local appResources="$1/Resources"
	
	local chromeResources="${chromePath}/Contents/Resources"
        
	local oldlprojholder=$(tempname "$appResources/oldlproj")
	local newlprojholder=$(tempname "$appResources/newlproj")

	# get listing of all .lproj directories
	local oldlprojlist=
	dirlist "$appResources" lprojlist "old localizations" '\.lproj$'
	[[ "$ok" ]] || return 1
	
	# move any existing .lproj directories to holder
	if [ "${#lprojlist[@]}" -gt 0 ] ; then
	    try /bin/mkdir "$oldlprojholder" 'Unable to create temporary folder for old localizations.'
	    try /bin/mv "$appResources/"*.lproj "$oldlprojholder" 'Unable to move old localizations.'
	fi
	
	# copy all .lproj directories from Chrome
	try /bin/mkdir "$newlprojholder" 'Unable to create temporary folder for new localizations.'
	try /bin/cp -a "$chromeResources/"*.lproj "$newlprojholder" 'Unable to copy new localizations.'
	
	# run python script to filter the InfoPlist.strings files for the .lproj directories
	local pyerr=
	try 'pyerr=' /usr/bin/python \
	    "$appResources/Scripts/strings.py" "$CFBundleDisplayName" "$CFBundleName" "$newlprojholder/"*.lproj \
	    'Error filtering Info.plist.'
	[[ "$ok" ]] || errmsg="$errmsg ($pyerr)"
	
	# move new .lproj directories to permanent location
	try /bin/mv "$newlprojholder/"*.lproj "$appResources" 'Unable to move new localizations to permanent folder.'
	try /bin/rmdir "$newlprojholder" 'Unable to remove temporary folder for new localizations.'
	
	# remove old .lproj directories
	try /bin/rm -rf "$oldlprojholder" 'Unable to remove old localizations.'
	
	# on error, clean up as best we can
	if [[ ! "$ok" ]] ; then
	    if [ -d "$newlprojholder" ] ; then
		onerr /bin/rm -rf "$newlprojholder" 'Also unable to clean up temporary new localization folder.'
	    fi
	    if [ -d "$oldlprojholder" ] ; then
		onerr /bin/mv "$oldlprojholder/"* "$appResources" 'Also unable to move old localizations back into place.'
	    fi
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # $1 = destination app bundle Contents directory

    if [[ "$ok" ]] ; then

	# these are the variables we write
	local configvars=( CFBundleDisplayName \
			       CFBundleName \
			       CFBundleIdentifier \
			       SSBVersion \
			       SSBProfilePath \
			       SSBChromePath \
			       SSBChromeVersion \
			       SSBRegisterBrowser \
			       SSBCustomIcon \
			       SSBFirstRunSinceVersion \
			       SSBHostInstallError \
			       SSBCommandLine )
	
	local var=
	local value=
	local arr=()
	local i
	
	# full path to final config script
	local fullConfigScript="$1/$appConfigScript"
	
	# temporary config file
	local tmpAppConfigScript=$(tempname "$fullConfigScript")

	# start temp config file
	local myDate=
	try 'myDate=' /bin/date ''
	if [[ ! "$ok" ]] ; then ok=1 ; myDate= ; fi
	try "${tmpAppConfigScript}<" echo "# config.sh -- autogenerated $myDate" 'Unable to create config file.'
	try "${tmpAppConfigScript}<<" echo "" 'Unable to write to config file.'

	if [[ "$ok" ]] ; then
	    
	    # go through each config variable
	    for var in "${configvars[@]}" ; do
		
		if [[ "$(isarray "$var")" ]]; then
		    
		    # variable holds an array, so start the array
		    value="("
		    
		    # pull out the array value
		    eval "arr=(\"\${$var[@]}\")"
		    
		    # go through each value and build the array
		    for i in "${arr[@]}" ; do
			
			# escape \ to \\
			i="${i//\\/\\\\}"
			
			# add array value, escaping spaces and quotes
			value="${value} $(printf "%q" "$i")"
		    done
		    
		    # close the array
		    value="${value} )"
		else
		    
		    # scalar value, so pull out the value
		    eval "value=\"\${$var}\""
		    
		    # escape \ to \\
		    value="${value//\\/\\\\}"
		    
		    # escape spaces and quotes
		    value=$(printf '%q' "$value")
		fi
		
		try "${tmpAppConfigScript}<<" echo "${var}=${value}" 'Unable to write to config file.'
		[[ "$ok" ]] || break
	    done
	fi
	
	# move the temp file to its permanent place
	permanent "$tmpAppConfigScript" "$fullConfigScript" "config file"
	
	# on error, remove temp config file
	[[ "$ok" ]] || rmtemp "$tmpAppConfigScript" "config file"
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}


# UPDATESSB: function that actually populates an app bundle with the SSB
function updatessb {
    
    if [[ "$ok" ]] ; then
	
	# command-line arguments
	local appPath="$1"
	local customIconFile="$2"
	local chromeOnly="$3"  # if non-empty, we're ONLY updating Chrome stuff
	
	# initially set this to permanent Contents directory
	local contentsTmp="$appPath/Contents"
	
	
	# FULL UPDATE OPERATION
	
	if [ ! "$chromeOnly" ] ; then
	    
	    # we need an actual temporary Contents directory
	    local contentsTmp=$(tempname "$appPath/Contents")
	    
	    # copy in the boilerplate for the app
	    try /bin/cp -a "$mcssbPath/Contents/Resources/Runtime" "$contentsTmp" 'Unable to populate app bundle.'
	    
	    # place custom icon, if any
	    
	    # check if we are copying from an old version of a custom icon
	    if [ \( ! "$customIconFile" \) -a \( "$SSBCustomIcon" = "Yes" \) ] ; then
		customIconFile="$appPath/Contents/Resources/$CFBundleIconFile"
	    fi
	    
	    # if there's a custom icon, copy it in
	    if [ -e "$customIconFile" ] ; then
		# copy in custom icon
		safecopy "$customIconFile" "${contentsTmp}/Resources/${CFBundleIconFile}" "custom icon"
	    fi
	    
	    # link to Chrome
	    linkchrome "$contentsTmp"
	    
	    # create a bundle identifier if necessary
	    local idbase="org.epichrome.app."
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
		local randext="000"
		while [[ 1 ]] ; do
		    CFBundleIdentifier="${idbase}$bid"
		    try 'idfound=' mdfind "kMDItemCFBundleIdentifier == '$CFBundleIdentifier'" 'Unable to search system for bundle identifier.'

		    # exit loop on error, or on not finding this ID
		    [[ "$ok" && "$idfound" ]] || break
		    
		    # try to create a new unique ID
		    randext=$(((${RANDOM} * 100 / 3279) + 1000))  # 1000-1999
		    bid="${bid::$bidbase}${randext:1:3}"
		done
		
		# if we got out of the loop, we have a unique ID (or we got an error)
	    fi

	    # set profile path
	    appProfilePath="${appProfileBase}/${CFBundleIdentifier##*.}"
	    
	    # get the old profile path, if any
	    if [[ "$SSBProfilePath" ]] ; then
		if [[ "$(isarray SSBProfilePath)" ]] ; then
		    oldProfilePath="${SSBProfilePath[0]}"
		else
		    oldProfilePath="$SSBProfilePath"
		fi
	    else
		# this is the old-style profile path, from before it got saved
		oldProfilePath="Library/Application Support/Chrome SSB/${CFBundleDisplayName}"
	    fi
	    
	    # if old path is different, save it in an array for migration on first run
	    if [[ "$oldProfilePath" != "$appProfilePath" ]] ; then
		SSBProfilePath=("$appProfilePath" "$oldProfilePath")
	    else
		SSBProfilePath="$appProfilePath"
	    fi
	    
	    # set up first-run notification
	    if [[ "$SSBVersion" ]] ; then
		SSBFirstRunSinceVersion="$SSBVersion"
	    else
		SSBFirstRunSinceVersion="0.0.0"
	    fi

	    # update SSBVersion
	    SSBVersion="$mcssbVersion"

	    # clear host install error state
	    SSBHostInstallError=
	elif [[ ! "$SSBVersion" ]] ; then

	    # this should never be reached, but just in case, we set SSBVersion
	    SSBVersion="$mcssbVersion"
	fi
	
	
	# OPERATIONS FOR UPDATING CHROME
	
	# write out Info.plist
	writeplist "$contentsTmp"
	
	# copy Chrome .lproj directories and modify InfoPlist.strings files    
	copychromelproj "$contentsTmp"
	
	# copy scripting.sdef
	safecopy "$chromeScriptingSdef" "$contentsTmp/$appScriptingSdef" "Chrome scripting.sdef file"
	
	
	# WRITE OUT CONFIG FILE
	
	# set up output versions of Chrome variables
	SSBChromePath="$chromePath"    
	SSBChromeVersion="$chromeVersion"
	
	# write the config file
	writeconfig "$contentsTmp"
	
	
	# MOVE CONTENTS TO PERMANENT HOME
	
	if [ ! "$chromeOnly" ] ; then
	    # only need to do this if we were doing a full update
	    permanent "$contentsTmp" "$appPath/Contents" "app bundle Contents directory"
	else
	    # remove temp contents on error
	    [[ "$ok" ]] || rmtemp "$contentsTmp" 'Contents folder'
	fi
    fi
    
    [[ "$ok" ]] && return 0
    return 1    
}
