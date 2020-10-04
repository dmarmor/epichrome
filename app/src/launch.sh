#!/bin/bash
#
#  launch.sh: utility functions for building and launching an Epichrome engine
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


# REQUIRES FILTER.SH

safesource "$myScriptPath/filter.sh"


# CONSTANTS

# IDs of allowed external engine browsers
appExtEngineBrowsers=( 'com.microsoft.edgemac' \
						'com.vivaldi.Vivaldi' \
						'com.operasoftware.Opera' \
						'com.brave.Browser' \
						'org.chromium.Chromium' \
						'com.google.Chrome' )

# native messaging host manifests
nmhDirName=NativeMessagingHosts
nmhManifestNewID="org.epichrome.runtime"
nmhManifestOldID="org.epichrome.helper"
nmhManifestNewFile="$nmhManifestNewID.json"
nmhManifestOldFile="$nmhManifestOldID.json"

# first-run files
myFirstRunFile="$myProfilePath/First Run"
myPreferencesFile="$myProfilePath/Default/Preferences"

# welcome directory
myWelcomePath="$myDataPath/$appDataWelcomeDir"


# EPICHROME VERSION-CHECKING FUNCTIONS

# VISBETA -- if version is a beta, return 0, else return 1
function visbeta { # ( version )
    [[ "$1" =~ [bB] ]] && return 0
    return 1
}


# ENCODEURL -- encode a string for URL
function encodeurl {  # ( input [safe] )
	
	# arguments
	local input="$1" ; shift ; local input_err="$input"
	local safe="$1" ; shift
	
	# quote strings for python
	input="${input//\\/\\\\}"
	input="${input//\'/\'}"
	safe="${safe//\\/\\\\}"
	safe="${safe//\'/\'}"
	
	# use python urllib to urlencode string
	local encoded=
	try 'encoded=' /usr/bin/python2.7 \
			-c 'import urllib ; print urllib.quote('\'"$input"\'', '\'"$safe"\'')' \
			"Error URL-encoding string '$input_err'."
	
	if [[ ! "$ok" ]] ; then
		
		# fallback if python fails -- adapted from https://gist.github.com/cdown/1163649
		local LC_COLLATE=C
		local length="${#input_err}"
		local i= ; local c=
		local result=
		for (( i = 0; i < length; i++ )); do
			c="${input_err:i:1}"
			case $c in
				[a-zA-Z0-9.~_-]) result+="$(printf "$c")" ;;
				*) result+="$(printf '%%%02X' "'$c")" ;;
			esac
		done
		echo "$result"
		
		ok=1 ; errmsg=
		return 1
	else
		echo "$encoded"
		return 0
	fi
}


# READJSONKEYS: pull keys out of a JSON string
# readjsonkeys(jsonVar key [key.subkey ...])
function readjsonkeys {
	#  for each key found, sets the variable <jsonVar>_<key>

	# pull json string from first arg
	local jsonVar="$1" ; shift
	local json
	eval "json=\"\$$jsonVar\""
	
	local jsonResult=
	try 'jsonResult=' /usr/bin/osascript "$myScriptPath/json.js" "$json" "$jsonVar" "$@" \
			'Unknown error reading JSON keys.'
	if [[ "$ok" && ( "${jsonResult%%|*}" = 'ERROR' ) ]] ; then
		ok= ; errmsg="${jsonResult#ERROR|}"
		errlog "Unable to read JSON keys: $errmsg"
	fi
	
	if [[ "$ok" ]] ; then
		
		# eval the result
		eval "$jsonResult"
		
		return 0
	else
		ok=1 ; errmsg=
		return 1
	fi
}


# GETEPICHROMEINFO: find Epichrome instances on the system & get info on them
function getepichromeinfo {
	# populates the following globals (if found):
	#    epiCurrentPath -- path to version of Epichrome that corresponds to this app
	#    epiCurrentMissing -- non-empty if no current version found & we have an internal engine
	#    epiLatestVersion/Path/Desc -- version/path/description of the latest Epichrome found
	#    epiUpdateVersion/Path/Desc -- version/path/description of the latest Epichrome eligible for update
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# default global return values
	epiCurrentPath= ; epiCurrentMissing=
	epiLatestVersion= ; epiLatestPath= ; epiLatestDesc=
	epiUpdateVersion= ; epiUpdatePath= ; epiUpdateDesc=
	
	# current version to test against
	local myVersion=
	if [[ "$coreContext" = 'app' ]] ; then
		
		myVersion="$SSBVersion"
		
		# housekeeping: update list of versions to ignore for updating
		local newIgnoreList=()
		local curIgnoreVersion=
		for curIgnoreVersion in "${SSBUpdateIgnoreVersions[@]}" ; do
			if vcmp "$curIgnoreVersion" '>' "$SSBVersion" ; then
				newIgnoreList+=( "$curIgnoreVersion" )
			fi
		done
		SSBUpdateIgnoreVersions=( "${newIgnoreList[@]}" )
	else
		myVersion="$coreVersion"
	fi
	
	# start with preferred install locations: the engine path & default user & global paths
	local preferred=()
	if [[ "$coreContext" = 'app' ]] ; then
		[[ -d "$SSBPayloadPath" ]] && preferred+=( "${SSBPayloadPath%/$epiPayloadPathBase/*}/Epichrome.app" )
	fi
	local globalDefaultEpichrome='/Applications/Epichrome/Epichrome.app'
	local userDefaultEpichrome="${HOME}$globalDefaultEpichrome"
	[[ "${preferred[0]}" != "$userDefaultEpichrome" ]] && preferred+=( "$userDefaultEpichrome" )
	[[ "${preferred[0]}" != "$globalDefaultEpichrome" ]] && preferred+=( "$globalDefaultEpichrome" )
	
	# use spotlight to search the system for all Epichrome instances
	local spotlight=()
	try 'spotlight=(n)' /usr/bin/mdfind \
			"kMDItemCFBundleIdentifier == '${appIDRoot}.Epichrome'" \
			'error'
	if [[ ! "$ok" ]] ; then
		# ignore mdfind errors
		ok=1
		errmsg=
	fi
	
	# merge spotlight instances with preferred ones
	local instances=()
	local pref=
	
	# go through preferred paths
	for pref in "${preferred[@]}" ; do
		
		# check current preferred path against each spotlight path
		local i=0 ; local path= ; local found=
		for path in "${spotlight[@]}" ; do
			
			# path found by spotlight
			if [[ "$pref" = "$path" ]] ; then
				found="$i"
				break
			fi
			
			i=$(($i + 1))
		done

		if [[ "$found" ]] ; then
			
			# remove matching path from spotlight list & add to instances
			instances+=( "$pref" )
			spotlight=( "${spotlight[@]::$found}" "${spotlight[@]:$(($found + 1))}" )
			
		elif [[ -d "$pref" ]] ; then
			
			# path not found by spotlight, but it exists, so check it
			instances+=( "$pref" )
		fi
		
	done
	
	# add all remaining spotlight paths
	instances+=( "${spotlight[@]}" )
	
	# determine if we are running a beta version
	local myVersionIsRelease=1
	visbeta "$myVersion" && myVersionIsRelease=
	
	if [[ "$coreContext" = 'epichrome' ]] ; then
		# current path should always be ours
		epiCurrentPath="$myEpichromePath"
	fi
	
	# check instances of Epichrome to find the current and latest
	local curInstance= ; local curVersion= ; local curDesc=
	local doIgnoreCurVersion=
	for curInstance in "${instances[@]}" ; do
		if [[ -d "$curInstance" ]] ; then
			
			# get this instance's version & optional description
			curVersion="$( safesource "$curInstance/Contents/Resources/Scripts/version.sh" && if [[ "$epiVersion" ]] ; then echo "$epiVersion" ; else echo "$mcssbVersion" ; fi && echo "$epiDesc" )"			
			if [[ ( "$?" != 0 ) || ( ! "$curVersion" ) ]] ; then
				curVersion=0.0.0
				curDesc=
			fi
			
			# parse out version & description
			curDesc="${curVersion#*$'\n'}"
			curVersion="${curVersion%%$'\n'*}"
			
			# if we are a release version, only look at release versions
			if [[ "$myVersionIsRelease" ]] && visbeta "$curVersion" ; then
				debuglog "Ignoring '$curInstance' (beta version $curVersion)."
				
			elif vcmp "$curVersion" '>=' "$myVersion" ; then
				
				debuglog "Found Epichrome $curVersion at '$curInstance'."
				
				# see if this is the first instance we've found of the current version
				if [[ "$coreContext" = 'epichrome' ]] ; then
					if [[ "$debug" && ( "$curInstance" = "$epiCurrentPath" ) ]] ; then
						errlog DEBUG '  (This is the currently running instance of Epichrome.)'
					fi
				elif vcmp "$curVersion" '==' "$myVersion" ; then
					[[ "$epiCurrentPath" ]] || epiCurrentPath="$(canonicalize "$curInstance")"
				else
					
					# this instance is later than our version, so check it for update
					doIgnoreCurVersion=
					for curIgnoreVersion in "${SSBUpdateIgnoreVersions[@]}" ; do
						if vcmp "$curIgnoreVersion" '=' "$curVersion" ; then
							debuglog "Ignoring version $curVersion for updating."
							doIgnoreCurVersion=1
							break
						fi
					done
					
					# if not ignored, see if it's newer than the current update version
					if [[ ! "$doIgnoreCurVersion" ]] && \
							( [[ ! "$epiUpdatePath" ]] || \
							vcmp "$epiUpdateVersion" '<' "$curVersion" ) ; then
						epiUpdatePath="$(canonicalize "$curInstance")"
						epiUpdateVersion="$curVersion"
						epiUpdateDesc="$curDesc"
					fi
				fi
				
				# see if this is newer than the current latest Epichrome
				if [[ ! "$epiLatestPath" ]] || \
						vcmp "$epiLatestVersion" '<' "$curVersion" ; then
					epiLatestPath="$(canonicalize "$curInstance")"
					epiLatestVersion="$curVersion"
					epiLatestDesc="$curDesc"
				fi
				
			elif [[ "$debug" ]] ; then
				if vcmp "$curVersion" '>' 0.0.0 ; then
					# old version
					debuglog "Ignoring '$curInstance' (old version $curVersion)."
				else
					# failed to get version, so assume this isn't really Epichrome
					debuglog "Ignoring '$curInstance' (unable to get version)."
				fi
			fi
		fi
	done
	
	# check if there's no current Epichrome installed & we have a built-in engine
	if [[ ( ! "$epiCurrentPath" ) && ( "${SSBEngineType%%|*}" = internal ) ]] ; then
		
		# flag that current Epichrome is missing
		epiCurrentMissing=1
		
		# make sure we have a version to update to if possible
		if [[ ! "$epiUpdatePath" ]] && vcmp "$epiLatestVersion" '>' "$myVersion" ; then
			epiUpdatePath="$epiLatestPath"
			epiUpdateVersion="$epiLatestVersion"
			epiUpdateDesc="$epiLatestDesc"
		fi
	fi
	
	# log versions found
	if [[ "$debug" ]] ; then
		[[ "$epiCurrentPath" ]] && \
			debuglog "Current version of Epichrome ($myVersion) found at '$epiCurrentPath'"
		[[ "$epiLatestPath" && ( "$epiLatestPath" != "$epiCurrentPath" ) ]] && \
			debuglog "Latest version of Epichrome ($epiLatestVersion) found at '$epiLatestPath'"
		[[ "$epiUpdatePath" && ( "$epiUpdatePath" != "$epiLatestPath" ) ]] && \
			debuglog "Version of Epichrome ($epiUpdateVersion) found for update at '$epiUpdatePath'"
	fi
	
	# return code based on what we found
	if [[ "$epiCurrentPath" && "$epiLatestPath" && "$epiUpdatePath" ]] ; then
		return 0
	elif [[ "$epiLatestPath" && "$epiUpdatePath" ]] ; then
		return 2
	elif [[ "$epiCurrentPath" && "$epiLatestPath" ]] ; then
		return 3
	elif [[ "$epiLatestPath" ]] ; then
		return 4
	else
		# nothing found
		return 1
	fi
}


# CHECKAPPUPDATE -- check for a new version of Epichrome and offer to update app
function checkappupdate { 
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# this app is set to never update itself
	if [[ "$SSBUpdateAction" = 'Never' ]] ; then
		debuglog 'This app is set to never update itself.'
		return 0
	fi
	
	# if there's no version to update to, we're done
	if [[ ! "$epiUpdateVersion" ]] ; then
		debuglog 'No newer version found.'
		return 0
	fi
	
	# assume success
	local result=0
	
	# set dialog buttons
	local updateBtnUpdate='Update'
	local updateBtnLater='Later'
	
	# by default, don't update
	local doUpdate="$updateBtnLater"
	
	if [[ "$SSBUpdateAction" = 'Auto' ]] ; then
		
		debuglog 'Automatically updating.'
		
		# don't ask, just update
		doUpdate="$updateBtnUpdate"
	else
		
		# set dialog info
		local updateMsg="A new version of Epichrome was found ($epiUpdateVersion). This app is using version $SSBVersion. Would you like to update it? This update contains the following changes:"
		[[ "$epiUpdateDesc" ]] && updateMsg+=$'\n\n'"$epiUpdateDesc"
		local updateButtonList=( "+$updateBtnUpdate" "-$updateBtnLater" )
		
		
		# update dialog info if the new version is beta
		if visbeta "$epiUpdateVersion" ; then
			updateMsg="$updateMsg"$'\n\n'"⚠️ IMPORTANT NOTE: This is a BETA release, and may be unstable. If anything goes wrong, you can find a backup of the app in your Backups folder ($myBackupDir)."
			# updateButtonList=( "+$updateBtnLater" "$updateBtnUpdate" )
		fi
		
		# if the Epichrome version corresponding to this app's version is not found, and
		# the app uses an internal engine, don't allow the user to ignore this version
		if [[ ! "$epiCurrentMissing" ]] ; then
			updateButtonList+=( "Don't Ask Again For This Version" )
		fi
		
		# display update dialog
		dialog doUpdate \
				"$updateMsg" \
				"Update" \
				"|caution" \
				"${updateButtonList[@]}"
		
		if [[ ! "$ok" ]] ; then
			alert "Epichrome version $epiUpdateVersion was found (this app is using version $SSBVersion) but the update dialog failed. ($errmsg) If you don't want to update the app, you'll need to use Activity Monitor to quit now." 'Update' '|caution'
			doUpdate="Update"
			ok=1 ; errmsg=
		fi
	fi
	
	# act based on dialog
	case "$doUpdate" in
		$updateBtnUpdate)
		
			# save my core script path
			local myCore="$myScriptPath/core.sh"
			
			# load the update script
			if ! source "${epiUpdatePath}/Contents/Resources/Scripts/update.sh" ; then
				ok= ; errmsg="Unable to load update script $epiUpdateVersion."
			fi
			
			# use new runtime to update the app
			updateapp "$SSBAppPath" "Updating \"${SSBAppPath##*/}\""
			# EXITS ON SUCCESS
			
			
			# IF WE GET HERE, UPDATE FAILED
			
			# alert the user to any error, but don't throw an exception
			ok=1
			if [[ "$errmsg" != 'CANCEL' ]] ; then
				[[ "$errmsg" ]] && errmsg=" ($errmsg)"
				errmsg="Unable to complete update.$errmsg"
			fi
			result=1
			;;
			
		$updateBtnLater)
			# do nothing
			;;
			
		*)
			# pretend we're already at the new version
			[[ "$SSBUpdateIgnoreVersions" ]] || SSBUpdateIgnoreVersions=()
			SSBUpdateIgnoreVersions+=( "$epiUpdateVersion" )
			;;
	esac
	
	return "$result"
}


# FUNCTIONS TO CHECK FOR A NEW VERSION OF EPICHROME ON GITHUB

# CHECKGITHUBUPDATE -- check if there's a new version of Epichrome on GitHub and offer to download
#  checkgithubupdate([aJsonVar]) -- jsonVar: optional variable to write JSON to
function checkgithubupdate {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local aJsonVar="$1" ; shift ; [[ "$aJsonVar" ]] && eval "$aJsonVar="
	
	# if we're skipping all versions, we're done
	[[ "$SSBUpdateCheckSkip" = 'All' ]] && return 0
	
	
	# READ GITHUB UPDATE INFO FILE & GET CURRENT DATE
	
	# info file read/write error variable
	local iInfoFileError=
	
	# initialize variables to force update check
	local iGithubNextDate=0
	local iGithubCurVersion=
	local iGithubLastError=
	
	if [[ -f "$epiGithubCheckFile" ]]; then
		
		# read update check info
		try 'iGithubNextDate=' /bin/cat "$epiGithubCheckFile" \
				'Unable to read update check info file.'
		
		# ensure we can write back to the info file
		if [[ ! -w "$epiGithubCheckFile" ]] ; then
			ok= ; errmsg='Unable to write to update check info file.'
			errlog "$errmsg"
		fi
		
		if [[ "$ok" ]] ; then
			
			# parse out info
			
			# get last error, if any
			iGithubLastError="${iGithubNextDate##*|}"
			if [[ "$iGithubLastError" = "$iGithubNextDate" ]] ; then
				iGithubLastError=
			else
				# trim off last error
				iGithubNextDate="${iGithubNextDate%|*}"
				
				# get already-downloaded version, if any
				iGithubCurVersion="${iGithubNextDate#*|}"
				
				if [[ "$iGithubCurVersion" = "$iGithubNextDate" ]] ; then
					iGithubCurVersion=
				else
					# trim off downloaded version
					iGithubNextDate="${iGithubNextDate%%|*}"
				fi
			fi		
			
			# integrity-check date
			if [[ ! "$iGithubNextDate" =~ ^[1-9][0-9]*$ ]] ; then
				errlog "Malformed date '$iGithubNextDate' found in update check info file."
				iGithubNextDate=0
			fi
			
			# if we're set to ignore a version that's now installed, clear the state
			# (this also integrity-checks version, as a malformed version will compare as 0.0.0)
			if [[ "$iGithubCurVersion" ]] && \
					vcmp "$iGithubCurVersion" '<=' "$epiLatestVersion" ; then
				iGithubCurVersion=
			fi
		fi
	else
		debuglog 'No update check info file found.'
		
		# ensure we can write to the info file
		try /bin/mkdir -p "$epiDataPath" 'Unable to create Epichrome data directory.'
		try '-12' /usr/bin/touch "$epiGithubCheckFile" 'Unable to create update check info file.'
	fi
		
	# get current date
	local iCurDate=0
	try 'iCurDate=' /bin/date '+%s' 'Unable to get date for update check.'
	
	if [[ "$ok" ]] ; then
	
		# CHECK FOR UPDATES ON GITHUB
		
		# result variables
		local iResultCheckDate=
		local iResultVersion=
		local iResultMsg=
		local iResultUrls=()
		
		# check for updates if we couldn't read the info file, if we've never run a check,
		# or if the next check date is in the past
		if [[ "$iInfoFileError" || ( "$iGithubNextDate" -lt "$iCurDate" ) ]] ; then
			
			# regex for pulling out version
			local s="[$epiWhitespace]*"
			local iVersionRe='"tag_name"'"$s"':'"$s"'"v('"$epiVersionRe"')"'
			
			# check github for the latest version
			local iGithubInfo=
			try '!2' 'iGithubInfo=' /usr/bin/curl --connect-timeout 5 --max-time 10 \
					'https://api.github.com/repos/dmarmor/epichrome/releases/latest' \
					'Unable to retrieve data from GitHub.'
			
			if [[ "$ok" ]] ; then
				
				# parse results
				if [[ "$iGithubInfo" =~ $iVersionRe ]] ; then
					
					# extract version number from regex
					local iGithubLatestVersion="${BASH_REMATCH[1]}"
					
					# choose version to compare -- either the one in the info file or latest on the system
					local iGithubCheckVersion="$epiLatestVersion"
					[[ "$iGithubCurVersion" ]] && iGithubCheckVersion="$iGithubCurVersion"
					
					# compare versions
					if vcmp "$iGithubCheckVersion" '<' "$iGithubLatestVersion" ; then
						
						# GitHub version is newer
						debuglog "Found new Epichrome version $iGithubLatestVersion on GitHub."
						
						# save version
						iResultVersion="$iGithubLatestVersion"
						
						# try to extract package download URL
						local iUrlRe='"browser_download_url"'"$s"':'"$s"'"([^"]+)"'
						if [[ "$iGithubInfo" =~ $iUrlRe ]] ; then
							iResultUrls+=( "$(unescapejson "${BASH_REMATCH[1]}")" )
						fi
						
						# finish result URLs
						iResultUrls+=( 'GITHUBUPDATEURL' )
						
						# start result message
						iResultMsg="A new version of Epichrome ($iGithubLatestVersion) is available on GitHub."
						
						# try to extract description of the update
						local iUpdateDescRe='<epichrome>(.*)</epichrome>'
						if [[ "$iGithubInfo" =~ $iUpdateDescRe ]] ; then
							
							local iUpdateDesc=
							unescapejson "${BASH_REMATCH[1]}" iUpdateDesc
							
							# remove leading & trailing whitespace
							local iWsRe="^$s(.*[^$epiWhitespace])?"
							if [[ "$iUpdateDesc" =~ $iWsRe ]] ; then
								iUpdateDesc="${BASH_REMATCH[1]}"
							fi
							
							# add any description to message
							[[ "$iUpdateDesc" ]] && iResultMsg+=' This update includes the following changes:'$'\n\n'"$iUpdateDesc"
						fi					
					else
						debuglog "Latest Epichrome version on GitHub ($iGithubLatestVersion) is not newer than $iGithubCheckVersion."
					fi
					
				else
					
					ok= ; errmsg='No Epichrome release found on GitHub.'			
					errlog  "$errmsg"
				fi
			fi
		else
			
			# no check, so we're all done
			debuglog 'Not yet due for GitHub update check.'
			return 0
		fi
	
	
		# HANDLE UPDATE
		
		if [[ "$iResultVersion" ]] ; then
			
			# HANDLE AVAILABLE UPDATE
			
			if [[ "$aJsonVar" ]] ; then
				
				# EXPORT JSON TO EPICHROME.SH
				
				local tab='   '
				eval "$aJsonVar=\"{
$tab$tab\\\"checkDate\\\": \\\"\$(escapejson \"\$iCurDate\")\\\",
$tab$tab\\\"version\\\": \\\"\$(escapejson \"\$iResultVersion\")\\\",
$tab$tab\\\"prevGithubVersion\\\": \\\"\$(escapejson \"\$iGithubCurVersion\")\\\",
$tab$tab\\\"lastError\\\": \\\"\$(escapejson \"\$iGithubLastError\")\\\",
$tab$tab\\\"message\\\": \\\"\$(escapejson \"\$iResultMsg\")\\\",
$tab$tab\\\"urls\\\": [
$tab$tab$tab\"\$(jsonarray \$',\n         ' \"\${iResultUrls[@]}\")\"
$tab$tab]
$tab}\""
				
			else
				
				# DISPLAY DIALOG
				
				# buttons
				local iBtnDownload='Download'
				local iBtnLater='Remind Me Later'
				local iBtnIgnore='Ignore This Version'
				
				# display dialog
				local doEpichromeUpdate=
				dialog doEpichromeUpdate \
				"$iResultMsg" \
				"Update Available" \
				"|caution" \
				"+$iBtnDownload" \
				"-$iBtnLater" \
				"$iBtnIgnore"
				if [[ "$ok" ]] ; then
					
					# act based on dialog
					case "$doEpichromeUpdate" in
						$iBtnDownload)
						# open the update URL
						try /usr/bin/open "${iResultUrls[@]}" ''
						# open didn't work
						if [[ ! "$ok" ]] ; then
							# still consider this version downloaded
							ok=1 ; errmsg=
							alert $'Unable to open update page on GitHub. Please try downloading this update yourself at the following URL:\n\n'"${iResultUrls[1]}" \
									'Unable To Download' '|caution'
							ok=1 ; errmsg=
						fi
						;;
						
						$iBtnLater)
						# don't consider this version downloaded
						iResultVersion=
						;;
						
						*)
						# consider this version downloaded
						;;
					esac
				else
					# error showing dialog
					errmsg='Unable to display update dialog.'
					errlog "$errmsg"
					iResultVersion="$iGithubCurVersion"
				fi
			fi
		fi
		
		if [[ ( ! "$iResultVersion" ) || ( ! "$aJsonVar" ) ]] ; then
			
			# if no update found, stick with what's already in the info file
			[[ ! "$iResultVersion" ]] && iResultVersion="$iGithubCurVersion"
			
			# save error state
			local iUpdateOK="$ok" ; ok=1
			local iUpdateError="$errmsg" ; errmsg=
			
			# write out info file
			if ! checkgithubinfowrite "$iCurDate" "$iResultVersion" "$iUpdateError" ; then
				iInfoFileError="$errmsg"
			else
				# restore error state
				ok="$iUpdateOK"
			fi
			
			# restore any update error
			errmsg="$iUpdateError"
		fi
	else
		# we got fatal errors reading the info file or getting date
		iInfoFileError="$errmsg"
		errmsg=
	fi
	
	# if we ran into any errors, handle them
	if [[ ! "$ok" ]] ; then
		checkgithubhandleerr "$iGithubLastError" "$iInfoFileError" "$aJsonVar"
		return 1
	fi
	
	# if we got here, everything went well
	return 0
}


# CHECKGITHUBINFOWRITE: update and write back info for the next Github check
#  checkgithubinfowrite(aCheckDate aNextVersion aUpdateError)
#    aCheckDate: date of the current check
#    aNextVersion: if empty, don't change check version, if not, use this version
#    aUpdateError: any error received doing the last check
function checkgithubinfowrite {

	# arguments
	local aCheckDate="$1" ; shift
	local aNextVersion="$1" ; shift
	local aUpdateError="$1" ; shift	
	
	# update next check date
	local iGithubNextDate=7
	[[ "$aUpdateError" ]] && iGithubNextDate=3
	iGithubNextDate=$(($aCheckDate + ($iGithubNextDate * 24 * 60 * 60)))
	
	# write out update check info
	if ! try "${epiGithubCheckFile}<" echo "${iGithubNextDate}|${aNextVersion}|${aUpdateError}" \
			'Unable to write update check info file.' ; then
		return 1
	else
		return 0
	fi
}


# CHECKGITHUBHANDLEERR: update persistent error variable to report error only on second occurrence
#  checkgithubhandleerr( aLastError [aFatalError aJsonVar] )
#    aLastError -- if set, this is the error message we got last time we ran this check
#    aFatalError -- if set, this is a message for a fatal error that should disable future checks
#    aJsonVar -- optional variable to write JSON to
function checkgithubhandleerr {
	
	# arguments
	local aLastError="$1" ; shift
	local aFatalError="$1" ; shift
	local aJsonVar="$1" ; shift ; [[ "$aJsonVar" ]] && eval "$aJsonVar="
	
	# if the current non-fatal error is a repeat of the last one, don't report it
	[[ "$aLastError" && ( "$aLastError" = "$errmsg" ) ]] && errmsg=
	
	# create error message
	local iErrWarning=
	if [[ "$aFatalError" ]] ; then
		
		# log the end of github-checking
		errlog "GitHub checking will be disabled."
		
		iErrWarning="Warning: A serious error occurred while checking GitHub for new versions of Epichrome. ($aFatalError)"
		
		if [[ "$errmsg" ]] ; then
			iErrWarning+=$'\n\n'"A less serious error also occurred. ($errmsg)"
		fi
		
		iErrWarning+=$'\n\nGitHub checks must be disabled. Epichrome and your apps will not be able to notify you of future versions.'
	else
		if [[ "$errmsg" ]] ; then
			iErrWarning+="Warning: An error occurred while checking GitHub for a new version of Epichrome. ($errmsg)"$'\n\nThis alert will only be shown once. All errors can be found in the app log.'
		fi
	fi
	
	if [[ "$aJsonVar" ]] ; then
		
		# export JSON info
		local tab='   '
		eval "$aJsonVar=\"{
$tab$tab\\\"error\\\": \\\"\$(escapejson \"\$iErrWarning\")\\\",
$tab$tab\\\"isFatal\\\": \\\"\$(escapejson \"\$aFatalError\")\\\"
$tab}\""
		
	else
		# in apps, only report non-fatal errors -- fatal errors are only reported in Epichrome
		if [[ "$iErrWarning" ]] ; then		
			# we have a new error to report
			alert "⚠️ $iErrWarning" 'Checking For Update' '|caution'
		fi
		
		# set fatal error flag
		SSBLastErrorGithubFatal="$aFatalError"
	fi
	
	# clear error state
	ok=1 ; errmsg=
}


# UPDATEDATADIR -- make sure an app's data directory is ready for the run
function updatedatadir {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	errmsg=
	
	# if we don't have a data path, abort (safety check before rm -rf)
	if [[ "$myDataPath" != "$appDataPathBase"* ]] ; then
		ok= ; errmsg='Data path is not properly set!'
		return 1
	fi
	
	
	# UPDATE WELCOME PAGE
	
	if [[ "$myStatusNewApp" || "$myStatusNewVersion" || "$myStatusEdited" || \
			"${myStatusEngineChange[0]}" || "$myStatusReset" || \
			( ! -e "$myWelcomePath/$appWelcomePage" ) ]] ; then
		
		debuglog 'Updating welcome page assets.'
		
		# copy welcome page into data directory
		safecopy "$SSBAppPath/Contents/$appWelcomePath" "$myWelcomePath" \
				"Unable to create welcome page. You will not see important information on the app's first run."
		if [[ "$ok" ]] ; then
			
			# link to master directory of extension icons
			try /bin/ln -s "../../../../$epiDataExtIconDir" "$myWelcomePath/img/ext" \
					'Unable to link to extension icon directory.'
		fi
		
		# errors here are non-fatal
		ok=1
	fi
	
	# return code
	[[ "$errmsg" ]] && return 1 || return 0
}


# SETWELCOMEPAGE -- configure any welcome page to be shown on this run
#                   sets myStatusWelcomeURL
function setwelcomepage {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# basic welcome page URL
	local baseURL="file://$(encodeurl "$myWelcomePath/$appWelcomePage" '/')?v=$SSBVersion&e=$(encodeurl "$SSBEngineType")"
	
	if [[ "$myStatusNewApp" ]] ; then
		
		# simplest case: new app
		debuglog "Creating new app welcome page."
		myStatusWelcomeURL="$baseURL"
		myStatusWelcomeTitle="App Created ($SSBVersion)"
		
	elif [[ "$myStatusNewVersion" ]] ; then
		
		# updated app
		debuglog "Creating app update welcome page."
		myStatusWelcomeURL="$baseURL&ov=$(encodeurl "$myStatusNewVersion")"
		if [[ "$myStatusEdited" ]] ; then
			myStatusWelcomeTitle="App Edited and Updated "
		else
			myStatusWelcomeTitle="App Updated "
		fi
		myStatusWelcomeTitle+="($myStatusNewVersion -> $SSBVersion)"
	fi
	
	if [[ ! "$myStatusNewApp" ]] ; then
		
		if [[ "$myStatusEdited" ]] ; then
			
			# edited app
			if [[ ! "$myStatusWelcomeURL" ]] ; then
				
				debuglog "Creating edited app welcome page."
				myStatusWelcomeURL="$baseURL"
				myStatusWelcomeTitle="App Edited"
			fi
			
			# set up arguments
			myStatusWelcomeURL+="&ed=1"
		fi
		
		if [[ "${myStatusEngineChange[0]}" ]] ; then
			
			# engine change
			if [[ ! "$myStatusWelcomeURL" ]] ; then
				
				# this is the only trigger to show the page
				debuglog "Creating app engine change welcome page."
				myStatusWelcomeURL="$baseURL"
				myStatusWelcomeTitle="App Engine Changed (${myStatusEngineChange[$iName]} -> ${SSBEngineSourceInfo[$iName]})"
			fi
			
			# set up arguments
			myStatusWelcomeURL+="&oe=$(encodeurl "${myStatusEngineChange[0]}")"
		fi
		
		if [[ "$myStatusReset" ]] ; then
			
			# reset profile
			if [[ ! "$myStatusWelcomeURL" ]] ; then
				debuglog "Creating app reset welcome page."
				myStatusWelcomeURL="$baseURL"
				myStatusWelcomeTitle="App Settings Reset"
			fi
			
			# add reset argument
			myStatusWelcomeURL+='&r=1'
			
		fi
	fi
	
	# if we're already showing a page, check for extensions
	if [[ "$myStatusWelcomeURL" && \
			( ! -d "$myProfilePath/Default/Extensions" ) ]] ; then
		
		# no extensions, so give the option to install them
		debuglog 'App has no extensions, so offering browser extensions.'
		
		# collect data directories for all known browsers
		extDirs=()
		for browser in "${appExtEngineBrowsers[@]}" ; do
			getbrowserinfo browserInfo "$browser"
			if [[ "${browserInfo[$iLibraryPath]}" ]] ; then
				browserInfo="$userSupportPath/${browserInfo[$iLibraryPath]}"
				[[ -d "$browserInfo" ]] && extDirs+=( "$browserInfo" )
			else
				errlog "Unable to get info on browser ID $browser."
			fi
		done
		
		# mine extensions from all browsers
		local extArgs=
		getextensioninfo extArgs "${extDirs[@]}"
		
		# if any extensions found, add them to the page
		[[ "$extArgs" ]] && myStatusWelcomeURL+="&xi=1&$extArgs"
	fi
	
	return 0
}


# UPDATEPROFILEDIR -- ensure the profile directory is ready for this run
function updateprofiledir {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# ensure we have a configured profile path
	if [[ ! "$myProfilePath" ]] ; then
		ok= ; errmsg='No profile path configured!'
		return 1
	fi
	
	# ensure profile directory exists
	if [[ ! -d "$myProfilePath" ]] ; then
		
		debuglog "Creating profile directory '$myProfilePath'."
		
		# ensure data & profile directories exists
		try /bin/mkdir -p "$myProfilePath" 'Unable to create app engine profile folder.'
		
		# if we couldn't create the directory, that's a fatal error
		[[ "$ok" ]] || return 1
	fi
	
	# check on runtime extension status
	
	# implicit argument to signal welcome page to offer a new install of the extension
	local runtimeExtArg=0
	
	# remove old External Extensions directory
	local externalExtsDir="$myProfilePath/External Extensions"
	local externalExtsManifest="$externalExtsDir/EPIEXTIDRELEASE.json"
	if [[ "$myStatusNewVersion" ]] && \
			vcmp "$myStatusNewVersion" '<' '2.3.0b9' && \
			[[ -e "$externalExtsManifest" ]] ; then
		
		# if the runtime extension is still installed, save its settings
		if [[ -d "$myProfilePath/Default/Extensions/EPIEXTIDRELEASE" ]] ; then
			
			debuglog "Saving Epichrome Helper settings."
			
			# preserve runtime extension settings
			myStatusFixRuntime=( "$myProfilePath/Default/Local Extension Settings/EPIEXTIDRELEASE" \
					"$myDataPath/EPIEXTIDRELEASE" )
			safecopy "${myStatusFixRuntime[0]}" "${myStatusFixRuntime[1]}" \
					'Unable to save Epichrome Helper settings.'
			if [[ ! "$ok" ]] ; then
				ok=1 ; errmsg=
				myStatusFixRuntime=
				
				# tell welcome page we couldn't save settings
				runtimeExtArg=3
			else
				
				# tell welcome page to ask user to reinstall extension due to update
				runtimeExtArg=1
			fi
		fi
		
		debuglog "Removing old external extensions directory."
		
		# remove External Extensions auto-install of Epichrome Helper
		try /bin/rm -f "$externalExtsManifest" \
				'Unable to remove old Epichrome Helper auto-install script.'
		try /bin/rmdir "$externalExtsDir" \
				'Unable to remove old External Extensions directory.'
		if [[ ! "$ok" ]] ; then
			ok=1 ; errmsg=
		fi
	fi
	
	# error states
	local myErrDelete=
	local myErrAllExtensions=
	local myErrSomeExtensions=
	local myErrBookmarks=
	
	
	# CLEAN UP PROFILE DIRECTORY ON ENGINE CHANGE
	
	errmsg=
	
	# triple check the directory as we're using rm -rf
	if [[ "${myStatusEngineChange[0]}" && \
			"$appDataPathBase" && ( "${myProfilePath#$appDataPathBase}" != "$myProfilePath" ) && \
			"$HOME" && ( "${myProfilePath#$HOME}" != "$myProfilePath" ) ]] ; then
		
		debuglog "Switching engines from ${myStatusEngineChange[$iID]#*|} to ${SSBEngineType#*|}. Cleaning up profile directory."
		
		# turn on extended glob
		local shoptState=
		shoptset shoptState extglob
		
		# remove all of the UserData directory except Default
		local allExcept='!(Default)'
		saferm 'Error deleting top-level files.' "$myProfilePath/"$allExcept
		if [[ ! "$ok" ]] ; then
			myErrDelete="$errmsg"
			ok=1 ; errmsg=
		fi
		
		if [[ ( "${myStatusEngineChange[$iID]#*|}" = 'com.google.Chrome' ) || \
				( "${SSBEngineType#*|}" = 'com.google.Chrome' ) ]] ; then
			
			# SWITCHING BETWEEN GOOGLE CHROME AND CHROMIUM-BASED ENGINE
			
			debuglog "Clearing profile directory for engine switch between incompatible engines ${myStatusEngineChange[$iID]#*|} and ${SSBEngineType#*|}."
			
			# if there are any extensions, try to save them
			local oldExtensionArgs=
			getextensioninfo 'oldExtensionArgs'
			if [[ "$?" = 1 ]] ; then
				local myErrAllExtensions=1
			elif [[ "$?" = 2 ]] ; then
				local myErrSomeExtensions="$errmsg"
			fi
			
			# add to welcome page
			[[ "$oldExtensionArgs" ]] && myStatusWelcomeURL+="&$oldExtensionArgs"
			
			# delete everything from Default except:
			#  Bookmarks, Favicons, History, Local Extension Settings
			allExcept='!(Bookmarks|databases|Favicons|History|Local?Extension?Settings)'
			saferm 'Error deleting browser profile files.' \
					"$myProfilePath/Default/"$allExcept
			
			if [[ ! "$ok" ]] ; then
				[[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
				ok=1 ; errmsg=
			fi
			
			# add reset argument
			myStatusWelcomeURL+='&r=1'
			
			# update runtime extension argument if not already set for update warning
			[[ "$runtimeExtArg" = 0 ]] && runtimeExtArg=2
			
		else
			
			# CATCH-ALL FOR SWITCHING FROM ONE FLAVOR OF CHROMIUM TO ANOTHER
			
			debuglog "Clearing profile directory for engine switch between compatible engines ${myStatusEngineChange[$iID]#*|} and ${SSBEngineType#*|}."
			
			#    - delete Login Data & Login Data-Journal so passwords will work (will need to be reimported)
			try /bin/rm -f "$myProfilePath/Default/Login Data"* \
					'Error deleting login data.'
			if [[ ! "$ok" ]] ; then
				[[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
				ok=1 ; errmsg=
			fi
		fi

		# restore extended glob
		shoptrestore shoptState
		
	fi
	
	
	# SET UP PROFILE DIRECTORY
	
	# if this is our first-run, get Preferences and First Run file in consistent state
	if [[ "$myStatusReset" ]] ; then
		
		# we're missing either First Run or Prefs file, so delete both
		try /bin/rm -f "$myFirstRunFile" "$myPreferencesFile" \
				'Error deleting first-run files.'
		if [[ ! "$ok" ]] ; then
			[[ "$myErrDelete" ]] && myErrDelete+=' ' ; myErrDelete+="$errmsg"
			ok=1 ; errmsg=
		fi
	fi
	
	
	# WELCOME PAGE ACTIONS
	
	if [[ "$myStatusWelcomeURL" ]] ; then
		
		# LET WELCOME PAGE KNOW ABOUT RUNTIME EXTENSION
		
		[[ "$runtimeExtArg" != 0 ]] && \
			myStatusWelcomeURL+="&rt=$runtimeExtArg"
		
		
		# INSTALL/UPDATE BOOKMARKS FILE
		
		local bookmarkResult=
		
		local myBookmarksFile="$myProfilePath/Default/Bookmarks"
		
		if [[ ! -e "$myBookmarksFile" ]] ; then
			
			# no bookmarks found, create new file with welcome page
			
			debuglog 'Creating new app bookmarks.'
			
			[[ -d "$myProfilePath/Default" ]] || \
				try /bin/mkdir -p "$myProfilePath/Default" \
						'Unable to create browser profile directory.'
			
			# new bookmark folder
			bookmarkResult=2
			
			filterfile "$SSBAppPath/Contents/$appBookmarksPath" \
					"$myBookmarksFile" \
					'bookmarks file' \
					APPWELCOMETITLE "$(escapejson "$myStatusWelcomeTitle")" \
					APPWELCOMEURL "$(escapejson "${myStatusWelcomeURL}&b=$bookmarkResult")"
			
			if [[ ! "$ok" ]] ; then
				
				# non-serious error, fail silently
				myErrBookmarks=3  # error trying to add bookmark
				ok=1 ; errmsg=
			fi
			
		else
			
			# bookmarks found, so try to add welcome page to our folder
			
			debuglog 'Checking app bookmarks...'
			
			# read in bookmarks file
			local bookmarksJson=
			try 'bookmarksJson=' /bin/cat "$myBookmarksFile" \
					'Unable to read in app bookmarks.'
			
			if [[ "$ok" ]] ; then
				
				# status variable
				local bookmarksChanged=
				
				# utility regex
				local s="[$epiWhitespace]*"
				
				# regex to parse bookmarks JSON file for our folder
				local bookmarkRe='^((.*)"checksum"'"$s:$s"'"[^"]+"'"$s,$s)?(.*[^[:blank:]]([[:blank:]]*)"'"children"'"$s:$s"'\['"($s{.*})?)$s(]$s,[^]}]*"'"guid"'"$s:$s"'"e91c4703-ee91-c470-3ee9-1c4703ee91c4"[^]}]*"type"'"$s:$s"'"folder".*)$'
				
				if [[ "$bookmarksJson" =~ $bookmarkRe ]] ; then
					
					debuglog "Adding welcome page bookmark to existing folder."
					
					bookmarksJson=
					
					# if there's a checksum, remove it
					[[ "${BASH_REMATCH[1]}" ]] && bookmarksJson="${BASH_REMATCH[2]}"
					
					# insert section before our bookmark
					bookmarksJson+="${BASH_REMATCH[3]}"
					
					# if there are other bookmarks in our folder, add a comma
					[[ "${BASH_REMATCH[5]}" ]] && bookmarksJson+=','
					
					# bookmark added to existing folder
					bookmarkResult=1
					
					# add our bookmark & the rest of the file
					bookmarksJson+=" {
${BASH_REMATCH[4]}   \"name\": \"$(escapejson "$myStatusWelcomeTitle")\",
${BASH_REMATCH[4]}   \"type\": \"url\",
${BASH_REMATCH[4]}   \"url\": \"$(escapejson "${myStatusWelcomeURL}&b=$bookmarkResult")\"
${BASH_REMATCH[4]}} ${BASH_REMATCH[6]}"
							
					bookmarksChanged=1
					
				elif ( [[ "$myStatusNewVersion" ]] && \
						vcmp "$myStatusNewVersion" '<' '2.3.0b9' ) ; then
					
					# updating from before 2.3.0b9, so seed bookmark file with our folder
					
					debuglog "Adding folder for welcome pages to bookmarks."
					
					# new regex to insert our bookmarks folder into JSON file
					local bookmarkRe='^((.*)"checksum"'"$s:$s"'"[^"]+"'"$s,$s)?"'(.*"bookmark_bar"'"$s:$s{"'([[:blank:]]*'$'\n'')?([[:blank:]]*)"children"'"$s:$s"'\[)'"$s"'(({?).*)$'
					
					if [[ "$bookmarksJson" =~ $bookmarkRe ]] ; then
						
						bookmarksJson=
						
						# if there's a checksum, remove it
						[[ "${BASH_REMATCH[1]}" ]] && bookmarksJson="${BASH_REMATCH[2]}"
						
						# insert section before our folder
						bookmarksJson+="${BASH_REMATCH[3]}"
						
						# new bookmark folder
						bookmarkResult=2
						
						# add our bookmark
						bookmarksJson+=" {
${BASH_REMATCH[5]}   \"children\": [ {
${BASH_REMATCH[5]}      \"name\": \"$(escapejson "$myStatusWelcomeTitle")\",
${BASH_REMATCH[5]}      \"type\": \"url\",
${BASH_REMATCH[5]}      \"url\": \"$(escapejson "${myStatusWelcomeURL}&b=$bookmarkResult")\"
${BASH_REMATCH[5]}} ],
${BASH_REMATCH[5]}   \"guid\": \"e91c4703-ee91-c470-3ee9-1c4703ee91c4\",
${BASH_REMATCH[5]}   \"name\": \"$(escapejson "$CFBundleName App Info")\",
${BASH_REMATCH[5]}   \"type\": \"folder\"
${BASH_REMATCH[5]}}"
			
						# if there are other items in the bookmark bar, add a comma
						[[ "${BASH_REMATCH[7]}" ]] && bookmarksJson+=','
						
						# add the rest of the file
						bookmarksJson+=" ${BASH_REMATCH[6]}"
						
						bookmarksChanged=1
						
					else
						errlog 'Unable to add welcome page folder to app bookmarks.'
						myErrBookmarks=3  # error trying to add bookmark
					fi
				else
					debuglog 'Welcome page folder not found in app bookmarks.'
					myErrBookmarks=4  # folder deleted
				fi
				
				# write bookmarks file back out
				if [[ "$bookmarksChanged" ]] ; then
					try "${myBookmarksFile}<" echo "$bookmarksJson" \
							'Error writing out app bookmarks file.'
					if [[ ! "$ok" ]] ; then
						myErrBookmarks="$errmsg"  # error writing bookmarks file
						ok=1 ; errmsg=
					fi
				fi
				
			else
				
				# non-serious error (couldn't read in bookmarks file), fail silently
				myErrBookmarks=3  # error trying to add bookmark
				ok=1 ; errmsg=
			fi
		fi
		
		# override bookmark result based on error code
		if [[ "${#myErrBookmarks}" -gt 1 ]] ; then
			
			# error writing out bookmark file
			bookmarkResult=5
			
		elif [[ "$myErrBookmarks" ]] ; then
			
			# numeric bookmark errors, just use the code
			bookmarkResult="$myErrBookmarks"
			
			# numeric errors are non-serious, so clear it
			myErrBookmarks=
		fi
		
		# let the page know the result of this bookmarking	
		[[ "$bookmarkResult" ]] && myStatusWelcomeURL+="&b=$bookmarkResult"
	fi
	
	
	# REPORT NON-FATAL ERRORS
	
	if [[ "$myErrDelete" ]] ; then
		errmsg="Unable to remove old profile files. ($myErrDelete) The app's settings may be corrupted and might need to be deleted."
	fi
	if [[ "$myErrBookmarks" ]] ; then
		if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
		errmsg+=" to write to the bookmarks file. The app's bookmarks may be lost."
	fi
	if [[ "$myErrAllExtensions" ]] ; then
		if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
		errmsg+=" to save extensions that will be uninstalled in the engine change. You will have to reinstall the app's extensions manually."
	elif [[ "$myErrSomeExtensions" ]] ; then
		if [[ "$errmsg" ]] ; then errmsg+=' Also unable ' ; else errmsg='Unable ' ; fi
		errmsg="to save some of the extensions that will be uninstalled in the engine change. You will have to reinstall the following extensions manually: $myErrSomeExtensions"
	fi
	
	[[ "$errmsg" ]] && return 1 || return 0
}


# GETEXTENSIONINFO -- collect info on a set of extensions & format into URL variables
function getextensioninfo {  # ( resultVar [dir dir ...] )
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local resultVar="$1" ; shift
	local result=
	
	local mySearchPaths=( "$@" )
	if [[ "${#mySearchPaths[@]}" = 0 ]] ; then
		mySearchPaths=( "$myProfilePath/Default" )
	fi
	
	# error states
	local myGlobalError=
	local myFailedExtensions=()
	local mySuccessfulExtensions=()
	
	# turn on nullglob & extglob
	local myShoptState=
	shoptset myShoptState nullglob extglob
	
	# find all requested extensions directories
	local myExtDirPaths=()
	local d sd
	for d in "${mySearchPaths[@]}" ; do
		if [[ -d "$d/Extensions" ]] ; then
			
			# we're in an actual profile directory
			myExtDirPaths+=( "$d/Extensions" )
		else
			
			# we're in a root browser data directory
			for sd in "$d"/* ; do
				if [[ ( -d "$sd" ) && ( -d "$sd/Extensions" ) ]] ; then
					myExtDirPaths+=( "$sd/Extensions" )
				fi
			done
		fi
	done
	
	# set backstop directory to return to
	try '!1' pushd . \
			'Unable to save working directory.'
	if [[ ! "$ok" ]] ; then
		ok=1 ; return 1
	fi
	
	# get extension IDs, excluding weird internal Chrome ones
	local allExcept="!(Temp|coobgpohoikkiipiblmjeljniedjpjpf|nmmhkkegccagdldgiimedpiccmgmieda|pkedcjkdefgpdelpbcmbmeomcjbeemfm)"
	
	# find all valid extensions in each path
	local myExtensions=
	local curExtensionList=()
	local curExtDirPath=
	local curExt curExtID
	for curExtDirPath in "${myExtDirPaths[@]}" ; do
		
		# move into this Extensions directory
		try cd "$curExtDirPath" \
				"Unable to navigate to extensions directory '$curExtDirPath'."
		if [[ ! "$ok" ]] ; then
			myGlobalError=1
			ok=1
			continue
		fi
		
		# grab all valid extension IDs
		curExtensionList=( $allExcept )
		
		# append each one with its path
		for curExt in "${curExtensionList[@]}" ; do
			
			# only operate on valid extension IDs
			if [[ "$curExt" =~ ^[a-z]{32}$ ]] ; then
				myExtensions+="${curExt}|$curExtDirPath"$'\n'
			fi
		done
	done
	
	# move back out of extensions directory
	try '!1' popd 'Unable to restore working directory.'
	if [[ ! "$ok" ]] ; then
		myGlobalError=1 ; ok=1
	fi
	
	# sort extension IDs
	local oldIFS="$IFS" ; IFS=$'\n'
	curExtensionList=( $(echo "$myExtensions" | \
			try '-1' /usr/bin/sort 'Unable to sort extensions.' ) )
	if [[ "$?" != 0 ]] ; then
		ok=1 ; errmsg="Unable to create list of installed extensions."
		IFS="$oldIFS"
		return 1
	fi
	IFS="$oldIFS"
	
	# uniquify extension IDs
	local prevExtID=
	myExtensions=()
	for curExt in "${curExtensionList[@]}" ; do
		
		curExtID="${curExt%%|*}"
		if [[ "$curExtID" = 'EPIEXTIDRELEASE' ]] ; then
			
			# don't include the Epichrome Runtime extension
			prevExtId="$curExtID"
			
		elif [[ "$prevExtID" != "$curExtID" ]] ; then
			
			# first time seeing this ID, so add id
			myExtensions+=( "$curExt" )
			prevExtID="$curExtID"
		fi
	done
	
	# SET LOCALE
	
	local iLocale=
	if [[ "$LC_ALL" ]] ; then
		iLocale="$LC_ALL"
	elif [[ "$LC_MESSAGES" ]] ; then
		iLocale="$LC_MESSAGES"
	elif [[ "$LANG" ]] ; then
		iLocale="$LANG"
	else
		iLocale='en_US'
	fi
	
	# cut off any cruft
	iLocale="${iLocale%%.*}"	
	
	
	# IMPORTANT PATHS
	
	local welcomeExtGenericIcon="$SSBAppPath/Contents/$appWelcomePath/img/ext_generic_icon.png"
	local iExtIconPath="$epiDataPath/$epiDataExtIconDir"
	local iExtInfoFile="$iExtIconPath/${epiDataExtInfoFile/LANG/$iLocale}"
	
	# ensure extension icons directory exists
	if [[ "${#myExtensions[@]}" != 0 ]] ; then
		
		try /bin/mkdir -p "$iExtIconPath" \
				'Unable to create extension icon directory.'
		if [[ ! "$ok" ]] ; then
			ok=1
			return 1
		fi
	fi
	
	
	# try to read in cached extension info
	local iRewriteInfoFile=
	local iExtInfoList=()
	local iExtNewInfoList=()
	if [[ -f "$iExtInfoFile" ]] ; then
		try 'iExtInfoList=(n)' /bin/cat "$iExtInfoFile" 'Unable to read cached extension names.'
		ok=1; errmsg=
		
		# parse cached names
		eval "${iExtInfoList[*]}"
		
		# transform iExtInfoList into list of cached IDs  $$$$ CLEAN UP ERRLOGS
		local curExtName i=0
		for ((i=0; i<${#iExtInfoList[@]}; i++)) ; do
			curExtName="${iExtInfoList[$i]#local iExtInfo_}"
			iExtInfoList[$i]="${curExtName%%=*}"
		done
	fi
	
	
	# GET INFO ON ALL EXTENSIONS
	
	# status variables & constants
	local c
	local curExtPath curExtVersionList curExtVersion curExtVersionPath curExtInfo
	local curExtName curExtIcon curExtLog
	local curDoGetInfo curSkip
	local mani mani_icons mani_name mani_default_locale mani_app
	local curIconSrc curBiggestIcon curIconType
	local curExtLocalePath
	local curMessageID msg msg_message
	local iconRe='^([0-9]+):(.+)$'
	
	# loop through every extension
	for curExt in "${myExtensions[@]}" ; do
		
		# reset name & icon info
		curExtName=
		curExtIcon=
		curDoGetInfo=
		curSkip=
		
		# break out extension ID & path
		curExtID="${curExt%%|*}"
		curExtPath="${curExt#*|}/$curExtID"
		
		debuglog "Processing extension ID $curExtID for welcome page."		
		
		# get any cached info for this ID
		eval "curExtInfo=\"\$iExtInfo_$curExtID\""
		
		# cached apps should be skipped without even checking version
		if [[ "$curExtInfo" = 'APP' ]] ; then
			debuglog '  Skipping cached app.'
			continue
		fi
		
		
		# GET LATEST VERSION FOR THIS ID
		
		# get extension version directories
		curExtVersionList=( "$curExtPath"/* )
		if [[ ! "${curExtVersionList[*]}" ]] ; then
			errlog "Unable to get version for extension $curExtID."
			myFailedExtensions+=( "$curExtID" )
			continue
		fi
		
		# get latest version path
		curExtVersionPath=
		for c in "${curExtVersionList[@]}" ; do
			[[ "$c" > "$curExtVersionPath" ]] && curExtVersionPath="$c"
		done
		curExtVersion="${curExtVersionPath##*/}"
		curExtPath="$curExtVersionPath"
		
		
		# CHECK IF WE HAVE A CACHED ICON/NAME FOR THIS VERSION
		
		if [[ "$curExtInfo" ]] ; then
			
			if [[ "${curExtInfo%%|*}" = "$curExtVersion" ]] ; then
				
				# get name for this version
				curExtName="${curExtInfo#*|}"
				
				[[ "$debug" ]] && curExtLog='  Cached info:'
				
				if [[ "$debug" ]] ; then
					[[ "$curExtName" ]] && curExtLog+=" name '$curExtName'" || curExtLog+=' no name'
				fi
				
				# check for cached icon
				curExtIcon=( "$iExtIconPath/$curExtID".* )
				if [[ -f "${curExtIcon[0]}" ]] ; then
					
					# found cached icon for this ID
					curExtIcon="${curExtIcon[0]##*/}"
					[[ "$debug" ]] && curExtLog+=", icon $curExtIcon"
				else
					curExtIcon=
					[[ "$debug" ]] && curExtLog+=', no icon'
				fi
				
				# log result
				debuglog "${curExtLog}."
				
			elif [[ ( "$curExtInfo" = 'BAD|'* ) && ( "${curExtInfo#*|}" = "$curExtVersion" ) ]] ; then
				
				# cached version is current, and should be skipped
				debuglog '  Skipping cached unreadable extension.'
				continue
				
			else
				
				# cached version is out of date
				iRewriteInfoFile=1
				curDoGetInfo=1
				debuglog "  Cached extension is out of date (${curExtInfo%%|*} -> $curExtVersion)."
			fi
		else
			curDoGetInfo=1
			iExtNewInfoList+=( "$curExtID" )
			debuglog "  Extension not in cache."
		fi
		
		
		# IF CACHE MISSING/OUT-OF-DATE, GO TO THE MANIFEST
		
		if [[ "$curDoGetInfo" ]] ; then
			
			# read manifest
			try 'mani=' /bin/cat "$curExtPath/manifest.json" \
					"Unable to read manifest for $curExt."
			if [[ "$ok" ]] ; then
				
				# pull out icon and name info
				readjsonkeys mani icons name default_locale app
				
				# for now, ignore apps
				if [[ "$mani_app" ]] ; then
					curSkip=1
					eval "local iExtInfo_$curExtID='APP'"
					debuglog '  Skipping app.'
				fi
			else
				myFailedExtensions+=( "$curExtID" )
				ok=1 ; errmsg=
				curSkip=1
				eval "local iExtInfo_$curExtID=\"BAD|\$curExtID\""
				debuglog '  Skipping unreadable extension.'
			fi
			
			if [[ ! "$curSkip" ]] ; then
				
				debuglog '  Reading extension.'
				
				# FIND BIGGEST ICON
				
				curIconSrc=
				curBiggestIcon=0
				if [[ "$mani_icons" ]] ; then
					# remove all newlines
					mani_icons="${mani_icons//$'\n'/}"
					
					# munge entries into parsable lines
					oldIFS="$IFS" ; IFS=$'\n'
					mani_icons=( $(echo "$mani_icons" | \
							/usr/bin/sed -E \
									's/[^"]*"([0-9]+)"[ 	]*:[ 	]*"(([^\"]|\\\\|\\")*)"[^"]*/\1:\2\'$'\n''/g' 2> "$stderrTempFile") )
					if [[ "$?" = 0 ]] ; then
						
						IFS="$oldIFS"
						
						# find biggest icon
						for c in "${mani_icons[@]}" ; do
							if [[ "$c" =~ $iconRe ]] ; then
								if [[ "${BASH_REMATCH[1]}" -gt "$curBiggestIcon" ]] ; then
									curBiggestIcon="${BASH_REMATCH[1]}"
									curIconSrc="$(unescapejson "${BASH_REMATCH[2]}")"
								fi
							fi
						done
						
					else
						
						IFS="$oldIFS"
						local myStderr="$(/bin/cat "$stderrTempFile")"
						[[ "$myStderr" ]] && errlog 'STDERR|sed' "$myStderr"
						errlog "Unable to parse icons for extension $curExtID."
					fi
				fi
				
				# get full path to icon if one was found
				if [[ "$curIconSrc" ]] ; then
					debuglog "  Using icon '${curIconSrc##*/}'."
					
					# get full path to icon
					curIconSrc="$curExtPath/${curIconSrc#/}"
					
					# create welcome-page icon name
					curIconType="${curIconSrc##*.}"
					[[ "$curIconType" != "$curIconSrc" ]] || curIconType='png'
					curExtIcon="$curExtID.$curIconType"
					
					# copy icon to cache
					safecopy "$curIconSrc" "$iExtIconPath/$curExtIcon" \
							"icon for extension $curExtID"
					if [[ ! "$ok" ]] ; then
						curExtIcon=
						ok=1 ; errmsg=
					fi
				else
					debuglog '  No icon found.'
				fi
				
				
				# GET NAME
				
				if [[ "$mani_name" =~ ^__MSG_(.+)__$ ]] ; then
					
					# get message ID
					curMessageID="${BASH_REMATCH[1]}"
					
					# try to find the appropriate directory
					curExtLocalePath="$curExtPath/_locales"
					if [[ -d "$curExtLocalePath/$iLocale" ]] ; then
						curExtLocalePath="$curExtLocalePath/$iLocale"
					elif [[ -d "$curExtLocalePath/${iLocale%%_*}" ]] ; then
						curExtLocalePath="$curExtLocalePath/${iLocale%%_*}"
					elif [[ "$mani_default_locale" && -d "$curExtLocalePath/$mani_default_locale" ]] ; then
						curExtLocalePath="$curExtLocalePath/$mani_default_locale"
					else
						# failed to match, so pick any
						for c in "$curExtLocalePath"/* ; do
							if [[ -d "$c" ]] ; then
								curExtLocalePath="$c"
								break
							else
								curExtLocalePath=
							fi
						done
					fi
					
					# create local variable for message
					local "msg_${curMessageID}_message="
					
					# read in locale messages file
					msg="$curExtLocalePath/messages.json"
					if [[ "$curExtLocalePath" && ( -f "$msg" ) ]] ; then
						try 'msg=' /bin/cat "$msg" \
								"Unable to read locale ${curExtLocalePath##*/} messages for extension $curExtID. Using ID as name."
						if [[ "$ok" ]] ; then
							
							# clear mani_name
							mani_name=
							
							# try to pull out name message
							readjsonkeys msg "${curMessageID}.message"
							eval "mani_name=\"\$msg_${curMessageID}_message\""
							
							# check for error
							[[ "$mani_name" ]] || \
								errlog "Unable to get locale ${curExtLocalePath##*/} name for extension $curExtID. Using ID as name."
						else
							
							# failed to read locale JSON file, so no name
							mani_name=
							ok=1 ; errmsg=
						fi
					else
						mani_name=
						errlog "Unable to find locale ${curExtLocalePath##*/} messages for extension $curExtID. Using ID as name."
					fi
				fi
				
				# set extension name (or clear it if none found)
				curExtName="$mani_name"
				if [[ "$debug" ]] ; then
					if [[ "$curExtName" ]] ; then
						errlog DEBUG "  Found name '$curExtName'."
					else
						errlog DEBUG '  No name found.'
					fi
				fi
				
				
				# UPDATE INFO VARIABLE
				
				eval "local iExtInfo_$curExtID=\"\$curExtVersion|\$curExtName\""
				
			fi  # [[ ! "$curSkip" ]]
		fi # [[ "$curDoGetInfo" ]]
		
		
		# IF WE SUCCEEDED, ADD EXTENSION TO WELCOME PAGE ARGS
		
		if [[ ! "$curSkip" ]] ; then
			
			[[ "$result" ]] && result+='&'
			#[[ "$mani_app" ]] && result+='a=' || result+='x='
			[[ "$curExtIcon" ]] || curExtIcon="$curExtID"
			result+="x=$(encodeurl "${curExtIcon},$curExtName")"
			
			# report success
			mySuccessfulExtensions+=( "$curExtID" )
		fi
	done	    
	
	# restore nullglob and extended glob
	shoptrestore myShoptState
	
	# REWRITE CACHE IF NECESSARY & APPEND NEW EXTENSIONS TO CACHE
	
	# format new cache info
	[[ "$iRewriteInfoFile" ]] && iExtNewInfoList=( "${iExtInfoList[@]}" "${iExtNewInfoList[@]}" )
	local iExtNewInfoText=
	if [[ "${#iExtNewInfoList[@]}" -gt 0 ]] ; then
		iExtNewInfoText="local iExtInfo_${iExtNewInfoList[0]}=$(eval "formatscalar \"\$iExtInfo_${iExtNewInfoList[0]}\"")"
		for curExtID in "${iExtNewInfoList[@]:1}" ; do
			iExtNewInfoText+=$'\n'"local iExtInfo_$curExtID=$(eval "formatscalar \"\$iExtInfo_$curExtID\"")"
		done
	fi
	
	# write out new cache info
	if [[ "$iRewriteInfoFile" ]] ; then
		# rewrite entire info file
		debuglog 'Writing extension cache.'
		if [[ "$iExtNewInfoText" ]] ; then
			try "$iExtInfoFile<" echo "$iExtNewInfoText" 'Unable to write extension cache.'
		else
			try /bin/rm -f "$iExtInfoFile" 'Unable to remove empty extension cache file.'
		fi
	elif [[ "$iExtNewInfoText" ]] ; then
		# append to info file
		debuglog 'Adding new extensions to cache.'
		try "$iExtInfoFile<<" echo "$iExtNewInfoText" 'Unable to add to extension cache file.'
	fi
	ok=1 ; errmsg=
	

	# WRITE OUT RESULT VARIABLE
	
	eval "${resultVar}=\"\$result\""
	
	
	# RETURN ERROR STATES
	
	if [[ "$myGlobalError" || \
			( "${myFailedExtensions[*]}" && ! "${mySuccessfulExtensions[*]}" ) ]] ; then
		
		return 1
	elif [[ "${myFailedExtensions[*]}" && "${mySuccessfulExtensions[*]}" ]] ; then
		
		# some succeeded, some failed, so report list of failures
		errmsg="${myFailedExtensions[*]}"
		errmsg="${errmsg// /, }"
		return 2
	else
		return 0
	fi
}


# CANONICALIZE -- canonicalize a path
function canonicalize { # ( path )
	local rp=
	local result=
	if [[ "$path" ]] ; then
		result=$(unset CDPATH && try '!12' cd "$1" '' && try 'rp=' pwd -P '' && echo "$rp")
	fi
	[[ "$result" ]] && echo "$result" || echo "$1"
}


# LINKTREE: hard link to a directory or file
function linktree { # ( sourceDir destDir sourceErrID destErrID items ... )
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local sourceDir="$1"   ; shift
	local destDir="$1"     ; shift
	local sourceErrID="$1" ; shift
	local destErrID="$1"   ; shift
	local items=( "$@" )
	
	# pushd to source directory
	try '!1' pushd "$sourceDir" "Unable to navigate to $sourceErrID"
	[[ "$ok" ]] || return 1
	
	# if no items passed, link all items in source directory
	local shoptState=
	shoptset shoptState nullglob
	[[ "${items[*]}" ]] || items=( * )
	shoptrestore shoptState
	
	# loop through items creating hard links
	for curFile in "${items[@]}" ; do
		try /bin/pax -rwlpp "$curFile" "$destDir" \
				"Unable to link $sourceErrID $curFile to $destErrID."
	done
	
	# popd back from source directory
	try '!1' popd "Unable to navigate away from $sourceErrID."
}


# GETBROWSERINFO: try to return info on known browsers
#   getbrowserinfo(var [id])
function getbrowserinfo {
	
	# arguments
	local var="$1" ; shift
	local id="$1" ; shift
	
	[[ "$id" ]] || id="${SSBEngineType#*|}"
	
	if [[ "$id" ]] ; then
		eval "${var}=( \"\${appBrowserInfo_${id//./_}[@]}\" )"
	else
		eval "${var}="
	fi
}


# GETEXTENGINESRCINFO: find external engine source app on the system & get info on it
#                      if successful, it sets the SSBEngineSourceInfo variable
function getextenginesrcinfo { # ( [myExtEngineSrcPath] )
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# argument
	local myExtEngineSrcPath="$1" ; shift
	
	# set up list of search locations/methods
	local searchList=()
	if [[ "$myExtEngineSrcPath" ]] ; then
		
		# if we were passed a specific path, only check that
		searchList=( "$myExtEngineSrcPath" FAIL )
	else
		# otherwise, search known locations & spotlight
		
		# try to get the display name of the engine app
		local engineDispName=
		getbrowserinfo 'engineDispName'
		engineDispName="${engineDispName[$iDisplayName]}"
		
		# if we know the name of the app, search in the usual places
		if [[ "$engineDispName" ]] ; then
			searchList=( "$HOME/Applications/$engineDispName.app" \
					"/Applications/$engineDispName.app" )
		else
			engineDispName="${SSBEngineType#*|}"
		fi
		
		# always search with spotlight
		searchList+=( SPOTLIGHT FAIL )
	fi
	
	# assume failure
	SSBEngineSourceInfo=()
	
	# try various methods to find & validate external engine browser
	local myEngineSourcePath=
	for curPath in "${searchList[@]}" ; do
		
		if [[ "$curPath" = FAIL ]] ; then
			
			# failure
			debuglog 'External engine $engineDispName not found.'
			break
			
		elif [[ "$curPath" = SPOTLIGHT ]] ; then
			
			debuglog "Searching Spotlight for instances of $engineDispName..."
			
			# search spotlight
			try 'myEngineSourcePath=(n)' /usr/bin/mdfind \
					"kMDItemCFBundleIdentifier == '${SSBEngineType#*|}'" ''
			if [[ "$ok" ]] ; then
				
				# use the first instance
				myEngineSourcePath="${myEngineSourcePath[0]}"
			else
				debuglog "Spotlight found no instances of $engineDispName."
				myEngineSourcePath=
				ok=1 ; errmsg=
			fi
		else
			
			debuglog "Trying path '$curPath'..."
			
			# regular path, so check it
			if [[ -d "$curPath" ]] ; then
				myEngineSourcePath="$curPath"
			fi
		fi
		
		# if nothing found, try next
		[[ "$myEngineSourcePath" ]] || continue
		
		# validate any found path
		
		# check that Info.plist exists
		if [[ ! -e "$myEngineSourcePath/Contents/Info.plist" ]] ; then
			debuglog "No app found at '$myEngineSourcePath'"
			continue
		fi
		
		# parse Info.plist -- create list in same order as SSBEngineSourceInfo
		local infoPlist=()
		try 'infoPlist=(n)' /usr/libexec/PlistBuddy \
				-c 'Print CFBundleIdentifier' \
				-c 'Print CFBundleExecutable' \
				-c 'Print CFBundleName' \
				-c 'Print CFBundleDisplayName' \
				-c 'Print CFBundleShortVersionString' \
				-c 'Print CFBundleIconFile' \
				-c 'Print CFBundleDocumentTypes:0:CFBundleTypeIconFile' \
				"$myEngineSourcePath/Contents/Info.plist" ''
		if [[ ! "$ok" ]] ; then
			ok=1 ; errmsg=
			debuglog "Unable to parse Info.plist at '$myEngineSourcePath'"
			continue
		fi
		
		# check bundle ID
		if [[ "${infoPlist[$iID]}" != "${SSBEngineType#*|}" ]] ; then
			debuglog "Found ID ${infoPlist[$iID]} instead of ${SSBEngineType#*|} at '$myEngineSourcePath'"
			continue
		fi
		
		# make sure the executable is in place
		local curExecPath="$myEngineSourcePath/Contents/MacOS/${infoPlist[$iExecutable]}"
		if [[ ! ( -f "$curExecPath" && -x "$curExecPath" ) ]] ; then
			debuglog "No valid executable at '$myEngineSourcePath'"
			continue
		fi
		
		# if we got here, we have a complete copy of the browser,
		# so set SSBEngineSourceInfo & break out
		getbrowserinfo SSBEngineSourceInfo
		SSBEngineSourceInfo[$iID]="${infoPlist[$iID]}"
		SSBEngineSourceInfo[$iExecutable]="${infoPlist[$iExecutable]}"
		SSBEngineSourceInfo[$iName]="${infoPlist[$iName]}"
		SSBEngineSourceInfo[$iDisplayName]="${infoPlist[$iDisplayName]}"
		SSBEngineSourceInfo[$iVersion]="${infoPlist[$iVersion]}"
		SSBEngineSourceInfo[$iAppIconFile]="${infoPlist[$iAppIconFile]}"
		SSBEngineSourceInfo[$iDocIconFile]="${infoPlist[$iDocIconFile]}"
		SSBEngineSourceInfo[$iPath]="$myEngineSourcePath"
		
		debuglog "External engine ${SSBEngineSourceInfo[$iDisplayName]} ${SSBEngineSourceInfo[$iVersion]} found at '${SSBEngineSourceInfo[$iPath]}'."
		
		break	
	done
}


# INSTALLNMHS: install any native message host on system for this app
#   returns: 0 on success; 1 on error linking to central NMH dir; 2 on error installing Epichrome NMH
function installnmhs {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# get path to Google Chrome native messaging host manifests
	local iCentralNMHPath=
	getbrowserinfo 'centralNMHPath' 'com.google.Chrome'
	iCentralNMHPath="$userSupportPath/${centralNMHPath[$iLibraryPath]}/$nmhDirName"
	
	# install/update Epichrome Runtime NMH
	installepichromenmh "$iCentralNMHPath"
	local iEpichromeNMHError=
	if [[ ! "$ok" ]] ; then
		[[ "$errmsg" ]] && iEpichromeNMHError="$errmsg" || iEpichromeNMHError='Unknown error.'
		ok=1 ; errmsg=
	fi
	
	if [[ "${SSBEngineSourceInfo[$iNoNMHLink]}" ]] ; then

		# for engines that don't use a local link to NMH: remove any found in our UserData
		saferm 'Unable to remove app profile native messaging hosts directory.' "$myProfilePath/$nmhDirName"
		ok=1 ; errmsg=
	else
		# for engines that use a local link to NMH: link central NMH directory to our UserData
		saferm 'Unable to remove old native messaging hosts.' "$myProfilePath/$nmhDirName"
		try /bin/ln -sf "$iCentralNMHPath" "$myProfilePath" 'Unable to link to native messaging hosts.'
		
		if [[ ! "ok" ]] ; then
			if [[ "$iEpichromeNMHError" ]] ; then
				errmsg+=" Also unable to install Epichrome extension native messaging host: $iEpichromeNMHError"
			fi
			return 1
		fi
	fi
	
	if [[ "$iEpichromeNMHError" ]] ; then
		# if we got here our only error was installing the Epichrome extension NMH
		ok= ; errmsg="$iEpichromeNMHError"
		return 2
	fi
	
	return 0
}


# INSTALLEPICHROMENMH: install/update our native message host manifests centrally
function installepichromenmh {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local iNMHPath="$1" ; shift
	
	# paths to manifest files
	local oldManifestPath="$iNMHPath/$nmhManifestOldFile"
	local newManifestPath="$iNMHPath/$nmhManifestNewFile"
	
	# assume no update
	local doUpdate=
	
	# if either is missing, update both
	if [[ ! ( ( -f "$oldManifestPath" ) && ( -f "$newManifestPath" ) ) ]] ; then
		doUpdate=1
		debuglog 'One or more manifests missing.'
	fi
	
	local curManifest=
	if [[ ! "$doUpdate" ]] ; then
		
		# regex for version and path
		local s="[$epiWhitespace]*"
		local infoRe="\"path\"$s:$s\"(.*${appNMHFileBase}($epiVersionRe))\""
		
		# read in one of the manifests
		try 'curManifest=' /bin/cat "$newManifestPath" 'Unable to read installed native messaging host manifest.'
		if [[ ! "$ok" ]] ; then
			ok=1 ; errmsg=
			doUpdate=1
			
		# check current manifest version & path
		elif [[ "$curManifest" =~ $infoRe ]] ; then
			
			# bad path
			if [[ ! -f "${BASH_REMATCH[1]}" ]] ; then
				doUpdate=1
				debuglog 'Native messaging host path in manifest is out of date.'
			else
				
				# check if version is out of date
				if vcmp "${BASH_REMATCH[2]}" '<' "$SSBVersion" ; then
					doUpdate=1
					debuglog "Native messaging host version in manifest (${BASH_REMATCH[2]}) is older than this app ($SSBVersion)."
				fi
			fi
		else
			
			# unreadable manifest
			doUpdate=1
			errlog 'Unable to parse native messaging host manifest.'
		fi
	fi
	
	# abort if we're supposed to update but there's no current version of Epichrome
	if [[ "$doUpdate" && ( ! "$epiCurrentPath" ) ]] ; then
		ok= ; errmsg='Current Epichrome not found.'
		errlog "$errmsg"
		return 1
	fi
	
	# if any of the above triggered an update, do it now
	if [[ "$doUpdate" ]] ; then
		
		debuglog 'Installing native messaging host manifests.'
		
		# path to Epichrome NMH items
		local iSourceNMHDir="$epiCurrentPath/Contents/Resources/NMH"
		local nmhScript="$iSourceNMHDir/${appNMHFileBase}$SSBVersion"
		local sourceManifest="$iSourceNMHDir/$nmhManifestNewFile"
		
		# make sure source NMH exists and is executable
		if [[ ! -f "$nmhScript" ]] ; then
			ok= ; errmsg="Native messaging host $SSBVersion not found where expected."
			errlog "$errmsg"
		elif [[ ! -x "$nmhScript" ]] ; then
			ok= ; errmsg="Native messaging host $SSBVersion is not executable."
			errlog "$errmsg"
		fi
		
		# make sure directory exists
		try /bin/mkdir -p "$iNMHPath" \
				'Unable to create central native messaging host directory.'
		
		# new ID
		filterfile "$sourceManifest" \
				"$newManifestPath" \
				"$nmhManifestNewFile" \
				APPHOSTPATH "$(escapejson "$nmhScript")"
		
		# old ID
		filterfile "$sourceManifest" \
				"$oldManifestPath" \
				"$nmhManifestOldFile" \
				APPHOSTPATH "$(escapejson "$nmhScript")" \
				"$nmhManifestNewID" "$nmhManifestOldID"
	fi
	
	[[ "$ok" ]] && return 0 || return 1
}


# # LINKEXTERNALNMHS -- link to native message hosts in central Google Chrome directory
# function linkexternalnmhs {
# 
# 	# only run if we're OK
# 	[[ "$ok" ]] || return 1
# 
# 	# paths to NMH directories for compatible browsers
# 
# 	# get path to destination NMH manifest directory
# 	local myHostDir="$myProfilePath/$nmhDirName"
# 
# 	# list of NMH directories to search
# 	local myNMHBrowsers=()
# 
# 	# favor hosts from whichever browser our engine is using
# 	if [[ "${SSBEngineType%%|*}" != internal ]] ; then
# 
# 		# see if the current engine is in the list
# 		local curBrowser= ; local i=0
# 		for curBrowser in "${appExtEngineBrowsers[@]}" ; do
# 			if [[ "${SSBEngineType#*|}" = "$curBrowser" ]] ; then
# 
# 				debuglog "Prioritizing ${SSBEngineType#*|} native messaging hosts."
# 
# 				# engine found, so bump it to the end of the list (giving it top priority)
# 				myNMHBrowsers=( "${appExtEngineBrowsers[@]::$i}" \
# 						"${appExtEngineBrowsers[@]:$(($i + 1))}" \
# 						"$curBrowser" )
# 				break
# 			fi
# 			i=$(($i + 1))
# 		done
# 	fi
# 
# 	# for internal engine, or if external engine not found, use vanilla list
# 	[[ "${myNMHBrowsers[*]}" ]] || myNMHBrowsers=( "${appExtEngineBrowsers[@]}" )
# 
# 	# navigate to our host directory (report error)
# 	try '!1' pushd "$myHostDir" "Unable to navigate to '$myHostDir'."
# 	if [[ ! "$ok" ]] ; then
# 		ok=1 ; return 1
# 	fi
# 
# 	# turn on nullglob
# 	local shoptState=
# 	shoptset shoptState nullglob
# 
# 	# get list of host files currently installed
# 	hostFiles=( * )
# 
# 	# collect errors
# 	local myError=
# 
# 	# remove dead host links
# 	local curFile=
# 	for curFile in "${hostFiles[@]}" ; do
# 		if [[ -L "$curFile" && ! -e "$curFile" ]] ; then
# 			try rm -f "$curFile" "Unable to remove dead link to $curFile."
# 			if [[ ! "$ok" ]] ; then
# 				[[ "$myError" ]] && myError+=' '
# 				myError+="$errmsg"
# 				ok=1 ; errmsg=
# 				continue
# 			fi
# 		fi
# 	done
# 
# 	# link to hosts from both directories
# 	local curHost=
# 	local curHostDir=
# 	local curError=
# 	for curHost in "${myNMHBrowsers[@]}" ; do
# 
# 		# get only the data directory
# 		getbrowserinfo 'curHostDir' "$curHost"
# 		if [[ ! "${curHostDir[$iLibraryPath]}" ]] ; then
# 			curError="Unable to get data directory for browser $curHost."
# 			errlog "$curError"
# 			[[ "$myError" ]] && myError+=' '
# 			myError+="$curError"
# 			continue
# 		fi
# 		curHostDir="$userSupportPath/${curHostDir[$iLibraryPath]}/$nmhDirName"
# 
# 		if [[ -d "$curHostDir" ]] ; then
# 
# 			# get a list of all hosts in this directory
# 			try '!1' pushd "$curHostDir" "Unable to navigate to ${curHostDir}"
# 			if [[ ! "$ok" ]] ; then
# 				[[ "$myError" ]] && myError+=' '
# 				myError+="$errmsg"
# 				ok=1 ; errmsg=
# 				continue
# 			fi
# 
# 			hostFiles=( * )
# 
# 			try '!1' popd "Unable to navigate away from ${curHostDir}"
# 			if [[ ! "$ok" ]] ; then
# 				[[ "$myError" ]] && myError+=' '
# 				myError+="$errmsg"
# 				ok=1 ; errmsg=
# 				continue
# 			fi
# 
# 			# link to any hosts that are not already in our directory or are
# 			# links to a different file -- this way if a given host is in
# 			# multiple NMH directories, whichever we hit last wins
# 			for curFile in "${hostFiles[@]}" ; do
# 				if [[ ( ! -e "$curFile" ) || \
# 						( -L "$curFile" && \
# 						! "$curFile" -ef "${curHostDir}/$curFile" ) ]] ; then
# 
# 					debuglog "Linking to native messaging host at ${curHostDir}/$curFile."
# 
# 					# symbolic link to current native messaging host
# 					try ln -sf "${curHostDir}/$curFile" "$curFile" \
# 							"Unable to link to native messaging host ${curFile}."
# 					if [[ ! "$ok" ]] ; then
# 						[[ "$myError" ]] && myError+=' '
# 						myError+="$errmsg"
# 						ok=1 ; errmsg=
# 						continue
# 					fi
# 				fi
# 			done
# 		fi
# 	done
# 
# 	# silently return to original directory
# 	try '!1' popd "Unable to navigate away from '$myHostDir'."
# 	if [[ ! "$ok" ]] ; then
# 		[[ "$myError" ]] && myError+=' '
# 		myError+="$errmsg"
# 		ok=1 ; errmsg=
# 		continue
# 	fi
# 
# 	# restore nullglob
# 	shoptrestore shoptState
# 
# 	# return success or failure
# 	if [[ "$myError" ]] ; then
# 		errmsg="$myError"
# 		return 1
# 	else
# 		errmsg=
# 		return 0
# 	fi
# }


# CHECKENGINEPAYLOAD -- check if the app engine payload is in a good state
#   returns 0 if engine payload looks good; 1 if anything unexpected found
function checkenginepayload {
	
	# engine payload directory exists
	if [[ -d "$myPayloadEnginePath" ]] ; then

		# get a list of all items in the payload folder
		local iPayloadItems=( "$SSBPayloadPath"/* )

		# engine payload directory is only item 
		if [[ ( "${iPayloadItems[0]}" = "$myPayloadEnginePath" ) && \
				( "${#iPayloadItems[@]}" = 1 )]] ; then
			
			# engine is in a known state, so make sure both app bundles are complete
			if [[ -x "$myPayloadEnginePath/MacOS/${SSBEngineSourceInfo[$iExecutable]}" && \
					-f "$myPayloadEnginePath/Info.plist" ]] ; then
				
				# all checks passed
				debuglog 'Engine payload appears valid.'
				return 0
			else
				errlog 'Engine payload is appears corrupt.'
				return 1
			fi
		else
			errlog 'Extra items found in engine payload directory.'
			return 1
		fi
	else
		errlog 'Engine payload not found.'
		return 1
	fi
	
	return 0
}


# SETENGINESTATE -- set the engine to the active or inactive state
# setenginestate( ON|OFF [appID] )
function setenginestate {
	
	# only operate if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local newState="$1" ; shift
	local myAppID="$1" ; shift
	local myAppDebugID= myAppErrID=
	if [[ "$myAppID" ]] ; then
		myAppDebugID="  App $myAppID: "
		myAppErrID="Error restoring app $myAppID: "
	fi
	
	# assume we're in the opposite state we're setting to
	local oldInactivePath= ; local newInactivePath=
	local newStateName= newScriptPath=
	if [[ "$newState" = ON ]] ; then
		oldInactivePath="$myPayloadEnginePath"
		newStateName="activate"
		newInactivePath="$myPayloadLauncherPath"
		newScriptPath="$myPayloadLauncherPath/Resources/Scripts"
	else
		oldInactivePath="$myPayloadLauncherPath"
		newStateName="deactivate"
		newInactivePath="$myPayloadEnginePath"
		newScriptPath="$SSBAppPath/Contents/Resources/Scripts"
	fi
	
	# engine app contents
	local myContents="$SSBAppPath/Contents"
	
	# move the old payload out
	if [[ -d "$newInactivePath" ]] ; then
		ok= ; errmsg="${myAppErrID}Engine already ${newStateName}d."
		errlog "$errmsg"
	fi
	try /bin/mv "$myContents" "$newInactivePath" \
			"${myAppErrID}Unable to $newStateName engine."
	[[ "$ok" ]] || return 1
	
	# make double sure old payload is gone
	if [[ -d "$myContents" ]] ; then
		ok= ; errmsg="${myAppErrID}Unknown error moving old payload out of app."
		errlog "$errmsg"
		return 1
	fi
	
	# move the new payload in
	try /bin/mv "$oldInactivePath" "$myContents" \
			"${myAppErrID}Unable to $newStateName engine."
	
	# on error, try to restore the old payload
	if [[ ! "$ok" ]] ; then
		tryalways /bin/mv "$newInactivePath" "$myContents" \
				"${myAppErrID}Unable to restore old app state. This app may be damaged and unable to run."
		return 1
	fi
	
	# set script path
	myScriptPath="$newScriptPath"

	debuglog "${myAppDebugID}Engine ${newStateName}d."
	
	return 0
}


# DELETEPAYLOAD -- delete payload directory
#  deletepayload( [mustSucceed appID] )
#    mustSucceed: if set, failure is considered a fatal error
#    appID: if set, we're running in Epichrome Scan
function deletepayload {
	
	# arguments
	local mustSucceed="$1" ; shift
	local myAppID="$1" ; shift ; [[ "$myAppID" ]] && myAppID="App $myAppID: "
	
	# default function state
	local warning='Warning -- '
	local myTry=tryalways
	
	if [[ "$mustSucceed" ]] ; then
		
		# only run if we're OK
		[[ "$ok" ]] || return 1
		
		# reset function state
		warning=
		myTry=try
	else
		
		# save OK state
		local oldOK="$ok"
	fi
	
	if [[ -d "$SSBPayloadPath" ]] ; then

		if [[ ( ! "$myAppID" ) && \
				( -e "$myPayloadLauncherPath" ) && \
				(! -e "$myPayloadEnginePath" ) ]] ; then
			errmsg="Cannot delete payload while engine is active."
			errlog "$errmsg"
			ok=
		else
			debuglog "${myAppID}Deleting payload at '$SSBPayloadPath'"
			
			# delete payload
			saferm "${myAppID}Unable to delete payload." "$SSBPayloadPath"
			
			# make sure payload deleted
			if [[ "$?" = 0 ]] ; then
				# adapt app ID message for waitforcondition
				local myAppIDWait="${myAppID/A/a}"
				myAppIDWait="${myAppIDWait/:/}"
				if ! waitforcondition "${myAppIDWait}payload to delete" 5 .5 \
				test '!' -d "$SSBPayloadPath" ; then
					errmsg="${myAppID}Removal of payload failed."
					errlog "$errmsg"
					ok=
				fi
			fi
		fi
	fi
	
	# clean up parent directory & link to engine  $$$ MAYBE GET RID OF THIS LINK EVENTUALLY
	if [[ ! -d "$SSBPayloadPath" ]] ; then
		
		# save state
		local cleanOK="$ok"
		local cleanErrmgs="$errmsg"
		
		# try to remove parent user directory in case it's empty
		local myPayloadParent="${SSBPayloadPath%/*}"
		if [[ "$myPayloadParent" = *"/$USER" ]] ; then
			/bin/rmdir "$myPayloadParent" > /dev/null 2>&1
		fi
		
		# delete link to the engine directory
		tryalways /bin/rm -f "$myDataPath/Engine" \
				"Unable to remove link to old engine in data directory."
		
		# restore state
		ok="$cleanOK"
		errmsg="$cleanErrmgs"
	fi
	
	# handle errors
	if [[ ! "$ok" ]] ; then
		if [[ ! "$mustSucceed" ]] ; then
			ok="$oldOK"
			[[ "$ok" ]] && errmsg=
		fi
		return 1
	else
		return 0
	fi
}


# CREATEENGINEPAYLOAD -- create Epichrome engine payload
#  createenginepayload(aMsg1 aMsg2)
function createenginepayload {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# load subapp script
	safesource "$myScriptPath/subapp.sh"
	[[ "$ok" ]] || return 1
	
	# arguments
	local aMsg1="$1" ; shift
	if [[ "$aMsg1" ]] ; then
		local aMsg2="$1" ; shift
	else
		aMsg1='Creating'
		aMsg2='engine'
	fi
	
	# send action message to EpichromePayload.app
	progressAction="$aMsg1 \"${SSBAppPath##*/}\" $aMsg2"
    
    # export app scalar variables
    export progressAction \
			SSBVersion SSBIdentifier CFBundleDisplayName CFBundleName \
			SSBRegisterBrowser SSBCustomIcon SSBEngineType \
			SSBUpdateAction SSBEdited \
			SSBAppPath SSBPayloadPath \
			epiCurrentPath epiLatestVersion epiLatestPath \
			myPayloadEnginePath myPayloadLauncherPath \
			myStatusPayloadUserDir
	
    # export app array variables
	exportarray SSBEngineSourceInfo
	
	# run payload-creation sub-app
	runsubapp "${myScriptPath%/Scripts}/EpichromePayload.app/Contents/MacOS/EpichromePayload"
	
	# handle result
	if [[ "$ok" ]] ; then
		return 0
	else
		[[ "$errmsg" = 'CANCEL' ]] && errmsg='Operation canceled.'
		return 1
	fi
}


# SETMASTERPREFS: if needed, install master prefs to central engine data directory
myMasterPrefsState=
function setmasterprefs {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# initialize state
	myMasterPrefsState=
	
	if [[ ! ( -e "$myFirstRunFile" || -e "$myPreferencesFile" ) ]] ; then
		
		# this looks like a first run, so set master prefs
		debuglog "Setting master prefs for new profile."
		
		# get path to master prefs file for this engine
		local myEngineMasterPrefsDir="$userSupportPath/${SSBEngineSourceInfo[$iLibraryPath]}"
		local myEngineMasterPrefsFile="$myEngineMasterPrefsDir/${SSBEngineSourceInfo[$iMasterPrefsFile]}"
		local mySavedMasterPrefsFile="$myDataPath/${SSBEngineSourceInfo[$iMasterPrefsFile]}"
		
		# backup browser's master prefs
		if [[ -e "$myEngineMasterPrefsFile" ]] ; then
			
			debuglog "Backing up browser master prefs."
			
			try /bin/mv -f "$myEngineMasterPrefsFile" "$mySavedMasterPrefsFile" \
					'Unable to back up browser master prefs.'
		else
			
			# make sure master prefs directory exists
			try /bin/mkdir -p "$myEngineMasterPrefsDir" 'Unable to create browser master prefs directory.'
		fi
		
		# install master prefs
		try /bin/cp "$SSBAppPath/Contents/$appMasterPrefsPath" \
				"$myEngineMasterPrefsFile" \
				'Unable to install app master prefs.'
		
		if [[ "$ok" ]] ; then
			
			# success! set state
			myMasterPrefsState=( "$myEngineMasterPrefsFile" "$mySavedMasterPrefsFile" )
			
		else
			
			# on error, restore any backup we just made
			if [[ -e "$mySavedMasterPrefsFile" && ! -e "$myEngineMasterPrefsFile" ]] ; then
				tryalways /bin/mv -f "$mySavedMasterPrefsFile" "$myEngineMasterPrefsFile" \
						'Unable to restore browser master prefs.'
			fi
			
			return 1
		fi
	else
		
		# return state for no master prefs installed
		return 2
	fi
	
	return 0
}


# CLEARMASTERPREFS: wait for master prefs to be read, then clear master prefs file
function clearmasterprefs {
	
	# only run if we have actually set the master prefs
	if [[ "$myMasterPrefsState" ]] ; then
		
		if ! waitforcondition 'app prefs to appear' 10 .5 \
				test -e "$myPreferencesFile" ; then
			ok=
			errmsg="Timed out waiting for app prefs to appear."
			errlog "$errmsg"
		fi
		
		if [[ -e "${myMasterPrefsState[1]}" ]] ; then
			
			# backup found, so restore browser master prefs
			debuglog "Restoring browser master prefs."
			
			tryalways /bin/mv -f "${myMasterPrefsState[1]}" "${myMasterPrefsState[0]}" \
					'Unable to restore browser master prefs.'
			
			# on any error, remove any remaining backup master prefs
			[[ "$ok" ]] || tryalways /bin/rm -f "${myMasterPrefsState[1]}" \
					'Unable to remove backup browser master prefs.'
			
		else
			# no backup, so just remove app master prefs
			debuglog "Removing app master prefs."
			
			tryalways /bin/rm -f "${myMasterPrefsState[0]}" \
					'Unable to remove app master prefs.'
		fi
		
		# clear state
		myMasterPrefsState=	
	fi
	
	# return error state
	[[ "$ok" ]] && return 0 || return 1
}


# READCONFIG: read in config.sh file & save config versions to track changes
function readconfig { # ( myConfigFile )
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local myConfigFile="$1" ; shift
	
	# read in config file
	safesource "$myConfigFile" 'configuration file'
	[[ "$ok" ]] || return 1
	
	# save all relevant config variables prefixed with "config"
	for varname in "${appConfigVars[@]}" ; do
		
		if isarray "$varname" ; then
			
			# array value
			
			eval "config$varname=(\"\${$varname[@]}\")" # $$$$ ; export config$varname"
			[[ "$debug" ]] && eval "errlog DEBUG \"$varname=( \${config$varname[*]} )\""
		else
			
			# scalar value
			
			eval "config$varname=\"\${$varname}\"" # $$$$ ; export config$varname"
			[[ "$debug" ]] && eval "errlog DEBUG \"$varname='\$config$varname'\""
		fi
	done
	
}


# WRITECONFIG: write out config.sh file
function writeconfig {  # ( myConfigFile force )
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local myConfigFile="$1" ; shift
	local force="$1"        ; shift
	
	# determine if we need to write the config file
	
	# we're being told to write no matter what
	local doWrite="$force"
	
	# not being forced, so compare all config variables for changes
	if [[ ! "$doWrite" ]] ; then
		
		local varname=
		local configname=
		for varname in "${appConfigVars[@]}" ; do
			configname="config${varname}"
			
			# check if variable is an array
			isarray "$varname" ; local varisarray="$?"
			
			# if variables are not the same type
			isarray "$configname"
			if [[ "$varisarray" != "$?" ]] ; then
				doWrite=1
				break
			fi
			
			if [[ "$varisarray" = 0 ]] ; then
				
				# variables are arrays, so compare part by part
				
				# check for the same length
				local varlength="$(eval "echo \${#$varname[@]}")"
				if [[ "$varlength" \
						-ne "$(eval "echo \${#$configname[@]}")" ]] ; then
					doWrite=1
					break
				fi
				
				# compare each element in both arrays
				local i=0
				while [[ "$i" -lt "$varlength" ]] ; do
					if [[ "$(eval "echo \${$varname[$i]}")" \
							!= "$(eval "echo \${$configname[$i]}")" ]] ; then
						doWrite=1
						break
					fi
					i=$(($i + 1))
				done
		
				# if we had a mismatch, break out of the outer loop
				[[ "$doWrite" ]] && break
			else
				
				# variables are scalar, simple compare
				if [[ "$(eval "echo \${$varname}")" \
						!= "$(eval "echo \${$configname}")" ]] ; then
					doWrite=1
					break
				fi
			fi
		done
		
		if [[ "$doWrite" ]] ; then
			debuglog "Configuration variables have changed. Updating config.sh."
		else
			debuglog "Configuration variables have not changed. No need to update."
		fi
	else
		debuglog "Forced update."
	fi
	
	# if we need to, write out the file
	if [[ "$doWrite" ]] ; then
		
		# write out the config file
		writevars "$myConfigFile" "${appConfigVars[@]}"
	fi
	
	# return code
	[[ "$ok" ]] && return 0 || return 1
	
}


# LAUNCHAPP: launch an app by directly running its executable
#   launchapp(aPath aDoRegister [aAppDesc aResultPIDVar aArgsVar])
function launchapp {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
        
    # arguments
    local aPath="$1" ; shift
	local aDoRegister="$1" ; shift ; [[ "$aDoRegister" ]] && aDoRegister='true' || aDoRegister='false'
    local aAppDesc="$1" ; shift ; [[ "$aAppDesc" ]] || aAppDesc="${aPath##*/}"
	local aResultPIDVar="$1" ; shift
	local aArgs="$1" ; shift ; [[ "$aArgs" ]] && eval "aArgs=( \"\${$aArgs[@]}\" )"
	
	if [[ "$aDoRegister" ]] ; then
		
		# register app before launching it
		debuglog "Registering '${aPath##*/}' with Launch Services."
		local iAppUtilErr=
		try 'iAppUtilErr&=' osascript "$myScriptPath/apputil.js" "{
   \"action\": \"register\",
   \"path\": \"$(escapejson "$aPath")\"
}" ''
		
		# error is non-fatal, so just report it
		if [[ ! "$ok" ]] ; then
			errlog "Unable to register '${aPath##*/}' with Launch Services: $iAppUtilErr"
			ok=1 ; errmsg=
		fi

	fi
	
	# find app executable
	local iExec="$(echo "$aPath/Contents/MacOS/"*)"
	if [[ -f "$iExec" ]] ; then
		if [[ -x "$iExec" ]] ; then
			
			# launch the app
			"$iExec" "${aArgs[@]}" &
			local iResultPID="$!"
			local iExitCode=
			
			# check that PID is active
			sleep 1
			try '!12' kill -0 "$iResultPID" ''
			
			if [[ "$ok" ]] ; then
				debuglog "Launched $aAppDesc with PID $iResultPID."
			else
				# PID has already exited, so get result code
				wait "$iResultPID" ; iExitCode="$?"
				
				# interpret result code
				if [[ "$iExitCode" = 127 ]] ; then
					# process not found
					errmsg="Error launching $aAppDesc: process not found."
					errlog "$errmsg"
				elif [[ "$iExitCode" = 126 ]] ; then
					# executable not found
					errmsg="Error launching $aAppDesc: could not run executable."
					errlog "$errmsg"			
				elif [[ "$iExitCode" != 0 ]] ; then
					# launched but immediately quit with an error
					errmsg="Launched $aAppDesc but it quit with code $iExitCode."
					errlog "$errmsg"
				else
					# launched and immediately quit successfully
					debuglog "Launched $aAppDesc and it finished with exit code 0."
					ok=1 ; errmsg=
				fi
			fi
			
			# either assign PID result to variable, or echo it
			if [[ "$ok" ]] ; then
				if [[ "$aResultPIDVar" ]] ; then
					eval "$aResultPIDVar=\"\$iResultPID\""
				else
					echo "$iResultPID"
				fi
			fi							
		else
			# app executable is not executable
			ok= ; errmsg="Not allowed to run executable for $aAppDesc."
			errlog "$errmsg"
		fi
	else
		# app executable not found
		ok= ; errmsg="Unable to find executable for $aAppDesc."
		errlog "$errmsg"
	fi
	
	# return result code
	[[ "$ok" ]] && return 0 || return 1
}
# $$$$ export -f launchapp


# LAUNCHURLS: launch URLs in a running app engine
#  launchurls(aUrlDesc url ...)
function launchurls {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# arguments
	local aUrlDesc="$1" ; shift ; [[ "$aUrlDesc" ]] || aUrlDesc='URLs'
	
	if [[ "$debug" ]] ; then
		errlog DEBUG "Opening $aUrlDesc in running engine:"
		local curUrl=
		for curUrl in "$@" ; do
			errlog DEBUG "  $curUrl"
		done
	fi
	
	# make sure the app is open
    if waitforcondition 'app to open' 10 .5 test -L "$myProfilePath/RunningChromeVersion" ; then
		
		# launch the URLs
		try '-1' "$SSBAppPath/Contents/MacOS/${SSBEngineSourceInfo[$iExecutable]}" \
				"--user-data-dir=$myProfilePath" "$@" \
            	"Error sending $aUrlDesc to app engine."
    else
		ok= ; errmsg='App engine does not appear to be running.'
		errlog "$errmsg"
	fi
	
	[[ "$ok" ]] && return 0 || return 1
}
# $$$$ export -f launchurls
