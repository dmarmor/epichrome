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

safesource "${BASH_SOURCE[0]%launch.sh}filter.sh"


# CONSTANTS

epiPayloadPathBase='Payload.noindex'

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
function readjsonkeys {  # ( jsonVar key [key ...] )
	#  for each key found, sets the variable <jsonVar>_<key>

	# pull json string from first arg
	local jsonVar="$1" ; shift
	local json
	eval "json=\"\$$jsonVar\""
	
	# whitespace
	local s="[$epiWhitespace]*"
	
	# loop through each key
	local curKey curRe curMatch
	for curKey in "$@"; do
		
		# set regex for pulling out string key (groups 1-3, val is group 2)
		curRe="(\"$curKey\"$s:$s"
		curRe+='"(([^\"]|\\\\|\\")*)")'
		
		# set regex for pulling out dict key (groups 4-8, val is group 5)
		curRe+="|(\"$curKey\"$s:$s{$s"
		curRe+='(([^}"]*"([^\"]|\\\\|\\")*")*([^}"]*[^}"'"$epiWhitespace])?)$s})"
		
		# try to match
		if [[ "$json" =~ $curRe ]] ; then
			
			if [[ "${BASH_REMATCH[2]}" ]] ; then
				
				# string key: fix escaped backslashes and double-quotes
				curMatch="$(unescapejson "${BASH_REMATCH[2]}")"
			else
				
				# dict key
				curMatch="${BASH_REMATCH[5]}"
			fi
			
			# set the variable
			eval "${jsonVar}_${curKey}=$(formatscalar "$curMatch")"
		else
			
			# clear the variable
			eval "${jsonVar}_${curKey}="
		fi
	done
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
	
	# housekeeping: update list of versions to ignore for updating
	local newIgnoreList=()
	local curIgnoreVersion=
	for curIgnoreVersion in "${SSBUpdateIgnoreVersions[@]}" ; do
		if vcmp "$curIgnoreVersion" '>' "$SSBVersion" ; then
			newIgnoreList+=( "$curIgnoreVersion" )
		fi
	done
	SSBUpdateIgnoreVersions=( "${newIgnoreList[@]}" )
	
	# start with preferred install locations: the engine path & default user & global paths
	local preferred=()
	[[ -d "$SSBPayloadPath" ]] && preferred+=( "${SSBPayloadPath%/$epiPayloadPathBase/*}/Epichrome.app" )
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
	visbeta "$SSBVersion" && myVersionIsRelease=
	
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
				
			elif vcmp "$curVersion" '>=' "$SSBVersion" ; then
				
				debuglog "Found Epichrome $curVersion at '$curInstance'."
				
				# see if this is the first instance we've found of the current version
				if vcmp "$curVersion" '==' "$SSBVersion" ; then
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
		if [[ ! "$epiUpdatePath" ]] && vcmp "$epiLatestVersion" '>' "$SSBVersion" ; then
			epiUpdatePath="$epiLatestPath"
			epiUpdateVersion="$epiLatestVersion"
			epiUpdateDesc="$epiLatestDesc"
		fi
	fi
	
	# log versions found
	if [[ "$debug" ]] ; then
		[[ "$epiCurrentPath" ]] && \
			debuglog "Current version of Epichrome ($SSBVersion) found at '$epiCurrentPath'"
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
			
			# read in the new runtime
			if ! source "${epiUpdatePath}/Contents/Resources/Scripts/update.sh" ; then
				ok= ; errmsg="Unable to load update script $epiUpdateVersion."
			fi
			
			# use new runtime to update the app
			updateapp "$SSBAppPath"
			# EXITS ON SUCCESS
			
			
			# IF WE GET HERE, UPDATE FAILED -- reload my runtime
			
			# temporarily turn OK back on & reload old runtime
			oldErrmsg="$errmsg" ; errmsg=
			oldOK="$ok" ; ok=1
			source "$SSBAppPath/Contents/Resources/Scripts/core.sh" || ok=
			if [[ ! "$ok" ]] ; then
				
				# fatal error
				errmsg="Update failed and unable to reload current app. (Unable to load core script $SSBVersion)"
				return 1
			fi
			
			# restore OK state
			ok="$oldOK"
			
			# update error messages
			if [[ "$oldErrmsg" && "$errmsg" ]] ; then
				errmsg="$oldErrmsg $errmsg"
			elif [[ "$oldErrmsg" ]] ; then
				errmsg="$oldErrmsg"
			fi
			
			# alert the user to any error, but don't throw an exception
			ok=1
			[[ "$errmsg" ]] && errmsg="Unable to complete update. ($errmsg)"
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
	if ! checkpath "$myDataPath" "$appDataPathBase" ; then
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
				debuglog "Unable to get info on browser ID $browser."
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
		try /bin/rm -rf "$myProfilePath/"$allExcept \
				'Error deleting top-level files.'
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
			allExcept='!(Bookmarks|Favicons|History|Local?Extension?Settings)'
			try /bin/rm -rf "$myProfilePath/Default/"$allExcept \
					'Error deleting browser profile files.'
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
	local curExtensions=()
	local curExtDirPath=
	local curExt=
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
		curExtensions=( $allExcept )
		
		# append each one with its path
		for curExt in "${curExtensions[@]}" ; do
			
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
	curExtensions=( $(echo "$myExtensions" | \
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
	for curExt in "${curExtensions[@]}" ; do
		
		if [[ "${curExt%%|*}" = 'EPIEXTIDRELEASE' ]] ; then
			
			# don't include the Epichrome Runtime extension
			prevExtId="${curExt%%|*}"
			
		elif [[ "$prevExtID" != "${curExt%%|*}" ]] ; then
			
			# first time seeing this ID, so add id
			myExtensions+=( "$curExt" )
			prevExtID="${curExt%%|*}"
		fi
	done
	
	# important paths
	local welcomeExtGenericIcon="$SSBAppPath/Contents/$appWelcomePath/img/ext_generic_icon.png"
	local epiExtIconPath="$epiDataPath/$epiDataExtIconDir"
	
	# ensure extension icons directory exists
	if [[ "${#myExtensions[@]}" != 0 ]] ; then
		
		try /bin/mkdir -p "$epiExtIconPath" \
				'Unable to create extension icon directory.'
		if [[ ! "$ok" ]] ; then
			ok=1
			return 1
		fi
	fi
	
	
	# GET INFO ON ALL EXTENSIONS
	
	# status variables & constants
	local c
	local curExtID curExtPath curExtVersions curExtVersionPath
	local mani mani_icons mani_name mani_default_locale mani_app
	local curIconSrc biggestIcon
	local curLocale=
	local curExtLocalePath
	local curMessageID msg msg_message
	local iconRe='^([0-9]+):(.+)$'
	
	# loop through every extension
	for curExt in "${myExtensions[@]}" ; do
		
		debuglog "Adding extension ID $curExt to welcome page."
		
		# break out extension ID & path
		curExtID="${curExt%%|*}"
		curExtPath="${curExt#*|}/$curExtID"
		
		
		# PARSE EXTENSION'S MANIFEST
		
		# get extension version directories
		curExtVersions=( "$curExtPath"/* )
		if [[ ! "${curExtVersions[*]}" ]] ; then
			errlog "Unable to get version for extension $curExtID."
			myFailedExtensions+=( "$curExtID" )
			continue
		fi
		
		# get latest version path
		curExtVersionPath=
		for c in "${curExtVersions[@]}" ; do
			[[ "$c" > "$curExtVersionPath" ]] && curExtVersionPath="$c"
		done
		curExtPath="$curExtVersionPath"
		
		# read manifest
		try 'mani=' /bin/cat "$curExtPath/manifest.json" \
				"Unable to read manifest for $curExt."
		if [[ ! "$ok" ]] ; then
			myFailedExtensions+=( "$curExtID" )
			ok=1 ; errmsg=
			continue
		fi
		
		# pull out icon and name info
		readjsonkeys mani icons name default_locale app
		
		# for now, ignore apps
		[[ "$mani_app" ]] && continue
		
		
		# COPY BIGGEST ICON TO WELCOME PAGE (IF NOT FOUND)
		
		curExtIcon=( "$epiExtIconPath/$curExtID".* )
		if [[ -f "${curExtIcon[0]}" ]] ; then
			
			# there's already an icon for this ID, so use that
			curExtIcon="${curExtIcon[0]##*/}"
			
			debuglog "Found cached icon $curExtIcon."
			
		else
			
			# no icon found, so we have to copy it
			
			debuglog "No icon cached for extension $curExtID. Attempting to copy from extension."
			
			curIconSrc=
			biggestIcon=0
			if [[ "$mani_icons" ]] ; then
				# remove all newlines
				mani_icons="${mani_icons//$'\n'/}"
				
				# munge entries into parsable lines
				oldIFS="$IFS" ; IFS=$'\n'
				mani_icons=( $(echo "$mani_icons" | \
						/usr/bin/sed -E \
						's/[^"]*"([0-9]+)"[ 	]*:[ 	]*"(([^\"]|\\\\|\\")*)"[^"]*/\1:\2\'$'\n''/g' 2> "$stderrTempFile") )
				if [[ "$?" != 0 ]] ; then
					local myStderr="$(/bin/cat "$stderrTempFile")"
					[[ "$myStderr" ]] && errlog 'STDERR|sed' "$myStderr"
					errlog "Unable to parse icons for extension $curExtID."
					myFailedExtensions+=( "$curExtID" )
					continue
				fi
				IFS="$oldIFS"
				
				# find biggest icon
				for c in "${mani_icons[@]}" ; do
					if [[ "$c" =~ $iconRe ]] ; then
						if [[ "${BASH_REMATCH[1]}" -gt "$biggestIcon" ]] ; then
							biggestIcon="${BASH_REMATCH[1]}"
							curIconSrc="$(unescapejson "${BASH_REMATCH[2]}")"
						fi
					fi
				done
			fi
			
			# get full path to icon (or generic, if none found)
			if [[ ! "$curIconSrc" ]] ; then
				debuglog "No icon found for extension $curExtID."
				curIconSrc="$welcomeExtGenericIcon"
			else
				curIconSrc="$curExtPath/${curIconSrc#/}"
			fi
			
			# create welcome-page icon name
			curExtIcon="$curExtID.${curIconSrc##*.}"
			
			# copy icon to welcome page
			try /bin/cp "$curIconSrc" "$epiExtIconPath/$curExtIcon" \
					"Unable to copy icon for extension $curExtID."
			if [[ ! "$ok" ]] ; then
				myFailedExtensions+=( "$curExtID" )
				ok=1 ; errmsg=
				continue
			fi
		fi
		
		
		# GET NAME
		
		if [[ "$mani_name" =~ ^__MSG_(.+)__$ ]] ; then
			
			# get message ID
			curMessageID="${BASH_REMATCH[1]}"
			
			# set locale if not already set
			if [[ ! "$curLocale" ]] ; then
				if [[ "$LC_ALL" ]] ; then
					curLocale="$LC_ALL"
				elif [[ "$LC_MESSAGES" ]] ; then
					curLocale="$LC_MESSAGES"
				elif [[ "$LANG" ]] ; then
					curLocale="$LANG"
				else
					curLocale='en_US'
				fi
				
				# cut off any cruft
				curLocale="${curLocale%%.*}"
			fi
			
			# try to find the appropriate directory
			curExtLocalePath="$curExtPath/_locales"
			if [[ -d "$curExtLocalePath/$curLocale" ]] ; then
				curExtLocalePath="$curExtLocalePath/$curLocale"
			elif [[ -d "$curExtLocalePath/${curLocale%%_*}" ]] ; then
				curExtLocalePath="$curExtLocalePath/${curLocale%%_*}"
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
			local "msg_${curMessageID}="
			
			# read in locale messages file
			msg="$curExtLocalePath/messages.json"
			if [[ "$curExtLocalePath" && ( -f "$msg" ) ]] ; then
				try 'msg=' /bin/cat "$msg" \
						"Unable to read locale ${curExtLocalePath##*/} messages for extension $curExtID. Using ID as name."
				if [[ "$ok" ]] ; then
					
					# clear mani_name
					mani_name=
					
					# try to pull out name message
					readjsonkeys msg "$curMessageID"
					eval "msg=\"\$msg_${curMessageID}\""
					if [[ "$msg" ]] ; then
						readjsonkeys msg message
						mani_name="$msg_message"
					fi
					
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
		
		
		# SUCCESS! ADD EXTENSION OR APP TO WELCOME PAGE ARGS
		
		[[ "$result" ]] && result+='&'
		#[[ "$mani_app" ]] && result+='a=' || result+='x='
		result+="x=$(encodeurl "${curExtIcon},$mani_name")"
		
		# report success
		mySuccessfulExtensions+=( "$curExtID" )
	done	    
	
	# restore nullglob and extended glob
	shoptrestore myShoptState
	
	# write out result variable
	eval "${resultVar}=\"\$result\""
	
	# return error states
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


# ISSAMEDEVICE -- check that two paths are on the same device
function issamedevice { # ( path1 path2 )
	
	# arguments
	local path1="$1" ; shift
	local path2="$1" ; shift
	
	# get path devices
	local device1=
	local device2=
	try 'device1=' /usr/bin/stat -f '%d' "$path1" ''
	try 'device2=' /usr/bin/stat -f '%d' "$path2" ''
	
	# unable to get one or both devices
	if [[ ! "$ok" ]] ; then
		ok=1 ; errmsg=
		return 1
	fi
	
	# compare devices
	[[ "$device1" = "$device2" ]] && return 0 || return 1
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
function getbrowserinfo { # ( var [id] )
	
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


# INSTALLNMH -- install native messaging host
function installnmh {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# paths to host manifests with new and old IDs
	local nmhManifestDestPath="$myProfilePath/$nmhDirName"    
	local nmhManifestNewDest="$nmhManifestDestPath/$nmhManifestNewFile"
	local nmhManifestOldDest="$nmhManifestDestPath/$nmhManifestOldFile"
	
	# determine which manifests to update
	local updateOldManifest=
	local updateNewManifest=
	if [[ "$myStatusNewApp" || "$myStatusNewVersion" || \
			( "$SSBAppPath" != "$configSSBAppPath" ) ]] ; then
		
		# this is the first run on a new version, or app has moved, so update both
		updateOldManifest=1
		updateNewManifest=1
	else
		
		# update any that are missing
		[[ ! -e "$nmhManifestOldDest" ]] && updateOldManifest=1
		[[ ! -e "$nmhManifestNewDest" ]] && updateNewManifest=1
	fi
	
	if [[ "$updateOldManifest" || "$updateNewManifest" ]] ; then
		
		# get source NMH script path
		local hostSourcePath="$SSBAppPath/Contents/Resources/NMH"
		local hostScriptPath="$hostSourcePath/$appNMHFile"
		
		# create the install directory if necessary
		if [[ ! -d "$nmhManifestDestPath" ]] ; then
			try /bin/mkdir -p "$nmhManifestDestPath" \
					'Unable to create native messaging host folder.'
		fi
		
		# stream-edit the new manifest into place
		if [[ "$updateNewManifest" ]] ; then
			debuglog "Installing host manifest for $nmhManifestNewID."
			filterfile "$hostSourcePath/$nmhManifestNewFile" "$nmhManifestNewDest" \
					'native messaging host manifest' \
					APPHOSTPATH "$(escapejson "$hostScriptPath")"
		fi
		
		# duplicate the new manifest with the old ID
		if [[ "$updateOldManifest" ]] ; then
			debuglog "Installing host manifest for $nmhManifestOldID."
			filterfile "$nmhManifestNewDest" "$nmhManifestOldDest" \
					'old native messaging host manifest' \
					"$nmhManifestNewID" "$nmhManifestOldID"
		fi
	fi
	
	# return code
	[[ "$ok" ]] && return 0 || return 1
}


# LINKEXTERNALNMHS -- link to native message hosts from compatible browsers
function linkexternalnmhs {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# paths to NMH directories for compatible browsers
	
	# get path to destination NMH manifest directory
	local myHostDir="$myProfilePath/$nmhDirName"
	
	# list of NMH directories to search
	local myNMHBrowsers=()
	
	# favor hosts from whichever browser our engine is using
	if [[ "${SSBEngineType%%|*}" != internal ]] ; then
		
		# see if the current engine is in the list
		local curBrowser= ; local i=0
		for curBrowser in "${appExtEngineBrowsers[@]}" ; do
			if [[ "${SSBEngineType#*|}" = "$curBrowser" ]] ; then
				
				debuglog "Prioritizing ${SSBEngineType#*|} native messaging hosts."
				
				# engine found, so bump it to the end of the list (giving it top priority)
				myNMHBrowsers=( "${appExtEngineBrowsers[@]::$i}" \
						"${appExtEngineBrowsers[@]:$(($i + 1))}" \
						"$curBrowser" )
				break
			fi
			i=$(($i + 1))
		done
	fi
	
	# for internal engine, or if external engine not found, use vanilla list
	[[ "${myNMHBrowsers[*]}" ]] || myNMHBrowsers=( "${appExtEngineBrowsers[@]}" )
	
	# navigate to our host directory (report error)
	try '!1' pushd "$myHostDir" "Unable to navigate to '$myHostDir'."
	if [[ ! "$ok" ]] ; then
		ok=1 ; return 1
	fi
	
	# turn on nullglob
	local shoptState=
	shoptset shoptState nullglob
	
	# get list of host files currently installed
	hostFiles=( * )
	
	# collect errors
	local myError=
	
	# remove dead host links
	local curFile=
	for curFile in "${hostFiles[@]}" ; do
		if [[ -L "$curFile" && ! -e "$curFile" ]] ; then
			try rm -f "$curFile" "Unable to remove dead link to $curFile."
			if [[ ! "$ok" ]] ; then
				[[ "$myError" ]] && myError+=' '
				myError+="$errmsg"
				ok=1 ; errmsg=
				continue
			fi
		fi
	done
	
	# link to hosts from both directories
	local curHost=
	local curHostDir=
	local curError=
	for curHost in "${myNMHBrowsers[@]}" ; do
		
		# get only the data directory
		getbrowserinfo 'curHostDir' "$curHost"
		if [[ ! "${curHostDir[$iLibraryPath]}" ]] ; then
			curError="Unable to get data directory for browser $curHost."
			errlog "$curError"
			[[ "$myError" ]] && myError+=' '
			myError+="$curError"
			continue
		fi
		curHostDir="$userSupportPath/${curHostDir[$iLibraryPath]}/$nmhDirName"
		
		if [[ -d "$curHostDir" ]] ; then
			
			# get a list of all hosts in this directory
			try '!1' pushd "$curHostDir" "Unable to navigate to ${curHostDir}"
			if [[ ! "$ok" ]] ; then
				[[ "$myError" ]] && myError+=' '
				myError+="$errmsg"
				ok=1 ; errmsg=
				continue
			fi
			
			hostFiles=( * )
			
			try '!1' popd "Unable to navigate away from ${curHostDir}"
			if [[ ! "$ok" ]] ; then
				[[ "$myError" ]] && myError+=' '
				myError+="$errmsg"
				ok=1 ; errmsg=
				continue
			fi
			
			# link to any hosts that are not already in our directory or are
			# links to a different file -- this way if a given host is in
			# multiple NMH directories, whichever we hit last wins
			for curFile in "${hostFiles[@]}" ; do
				if [[ ( ! -e "$curFile" ) || \
						( -L "$curFile" && \
						! "$curFile" -ef "${curHostDir}/$curFile" ) ]] ; then
					
					debuglog "Linking to native messaging host at ${curHostDir}/$curFile."
					
					# symbolic link to current native messaging host
					try ln -sf "${curHostDir}/$curFile" "$curFile" \
							"Unable to link to native messaging host ${curFile}."
					if [[ ! "$ok" ]] ; then
						[[ "$myError" ]] && myError+=' '
						myError+="$errmsg"
						ok=1 ; errmsg=
						continue
					fi
				fi
			done
		fi
	done
	
	# silently return to original directory
	try '!1' popd "Unable to navigate away from '$myHostDir'."
	if [[ ! "$ok" ]] ; then
		[[ "$myError" ]] && myError+=' '
		myError+="$errmsg"
		ok=1 ; errmsg=
		continue
	fi
	
	# restore nullglob
	shoptrestore shoptState
	
	# return success or failure
	if [[ "$myError" ]] ; then
		errmsg="$myError"
		return 1
	else
		errmsg=
		return 0
	fi
}


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
#export -f checkenginepayload  $$$$ DELETE?


# SETENGINESTATE -- set the engine to the active or inactive state   $$$$ I AM HERE
# setenginestate( ON|OFF )
function setenginestate {
	
	# only operate if we're OK
	[[ "$ok" ]] || return 1
	
	# argument
	local newState="$1" ; shift
	
	# assume we're in the opposite state we're setting to
	local oldInactivePath= ; local newInactivePath=
	local newStateName=
	if [[ "$newState" = ON ]] ; then
		oldInactivePath="$myPayloadEnginePath"
		newStateName="activate"
		newInactivePath="$myPayloadLauncherPath"
	else
		oldInactivePath="$myPayloadLauncherPath"
		newStateName="deactivate"
		newInactivePath="$myPayloadEnginePath"
	fi
	
	# engine app contents
	local myContents="$SSBAppPath/Contents"
	
	# move the old payload out
	if [[ -d "$newInactivePath" ]] ; then
		ok= ; errmsg="Engine already ${newStateName}d."
	fi
	try /bin/mv "$myContents" "$newInactivePath" \
			"Unable to $newStateName engine."
	[[ "$ok" ]] || return 1
	
	# make double sure old payload is gone
	if [[ -d "$myContents" ]] ; then
		ok= ; errmsg="Unknown error moving old payload out of app."
		errlog "$errmsg"
		return 1
	fi
	
	# move the new payload in
	try /bin/mv "$oldInactivePath" "$myContents" \
			"Unable to $newStateName engine."
	
	# on error, try to restore the old payload
	if [[ ! "$ok" ]] ; then
		tryalways /bin/mv "$newInactivePath" "$myContents" \
				"Unable to restore old app state. This app may be damaged and unable to run."
		return 1
	fi
	
	# sometimes it takes a moment for the move to register  $$$$$ HANDLE THIS IN LAUNCHAPP NOW WITH LSREGISTER?
	# if ! waitforcondition \
	# 		"engine $oldInactiveError executable '${SSBEngineSourceInfo[$iExecutable]}' to appear" \
	# 		5 .5 \
	# 		test -x "$myContents/MacOS/${SSBEngineSourceInfo[$iExecutable]}" ; then
	# 	ok=
	# 	errmsg="Engine $oldInactiveError executable '${SSBEngineSourceInfo[$iExecutable]}' not found."
	# 	errlog "$errmsg"
	# 	return 1
	# fi
	
	debuglog "Engine ${newStateName}d."
	
	return 0
}
#export -f setenginestate  $$$$ NO NEED TO EXPORT?


# DELETEPAYLOAD -- delete payload directory
#  deletepayload( [mustSucceed] ) -- mustSucceed: if set, failure is considered a fatal error
function deletepayload {
	
	# argument
	local mustSucceed="$1" ; shift
	
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

		if [[ ( -e "$myPayloadLauncherPath" ) && (! -e "$myPayloadEnginePath" ) ]] ; then
			errmsg="Cannot delete payload while engine is active."
			errlog "$errmsg"
			ok=
		else
			debuglog "Deleting payload at '$SSBPayloadPath'"
			
			# delete payload
			$myTry /bin/rm -rf "$SSBPayloadPath" \
			"Unable to delete payload."
			
			# make sure payload deleted
			if [[ "$?" = 0 ]] ; then
				if ! waitforcondition 'payload to delete' 5 .5 \
				test '!' -d "$SSBPayloadPath" ; then
					errmsg="Removal of payload failed."
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
		
		# # if parent directory is empty, try to delete it too  $$$ I THINK LEAVE THIS FOR EPICHROME SCAN
		# tryalways /bin/rmdir "${SSBPayloadPath%/*}" ''
		
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
function createenginepayload {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	
	# CLEAR OUT ANY OLD PAYLOAD
	
	deletepayload MUSTSUCCEED
	
	
	# CREATE NEW ENGINE PAYLOAD
	
	try /bin/mkdir -p "$SSBPayloadPath" 'Unable to create payload path.'
	[[ "$ok" ]] || return 1
	
	debuglog "Creating ${SSBEngineType%%|*} ${SSBEngineSourceInfo[$iName]} engine payload in '$SSBPayloadPath'."
	
	if [[ "${SSBEngineType%%|*}" != internal ]] ; then
		
		# EXTERNAL ENGINE
		
		# make sure we have a source for the engine payload
		if [[ ! -d "${SSBEngineSourceInfo[$iPath]}" ]] ; then
			
			# we should already have this, so as a last ditch, ask the user to locate it
			local myExtEngineSourcePath=
			local myExtEngineName=
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
				return 1
			fi
			
			# user selected a path, so check it
			getextenginesrcinfo "$myExtEngineSourcePath"
			
			if [[ ! "${SSBEngineSourceInfo[$iPath]}" ]] ; then
				ok= ; errmsg="Selected app is not a valid instance of $myExtEngineName."
				return 1
			fi	    
		fi
		
		# make sure external browser is on the same volume as the payload
		if ! issamedevice "${SSBEngineSourceInfo[$iPath]}" "$SSBPayloadPath" ; then
			ok= ; errmsg="${SSBEngineSourceInfo[$iDisplayName]} is not on the same volume as this app."
			return 1
		fi
		
		# create Engine/Resources directory
		try /bin/mkdir -p "$myPayloadEnginePath/Resources" \
				"Unable to create ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
		
		# turn on extended glob for copying
		local shoptState=
		shoptset shoptState extglob
		
		# copy all of the external browser except Framework and Resources
		local allExcept='!(Frameworks|Resources)'
		try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/"$allExcept \
				"$myPayloadEnginePath" \
				"Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine payload."
		
		# copy Resources, except icons
		allExcept='!(*.icns)'
		try /bin/cp -PR "${SSBEngineSourceInfo[$iPath]}/Contents/Resources/"$allExcept \
				"$myPayloadEnginePath/Resources" \
				"Unable to copy ${SSBEngineSourceInfo[$iDisplayName]} app engine resources to payload."
		
		# restore extended glob
		shoptrestore shoptState
		
		# hard link to external engine browser Frameworks
		linktree "${SSBEngineSourceInfo[$iPath]}/Contents" "$myPayloadEnginePath" \
				"${SSBEngineSourceInfo[$iDisplayName]} app engine" 'payload' 'Frameworks'
		
		# filter localization files
		filterlproj "$myPayloadEnginePath/Resources" \
				"${SSBEngineSourceInfo[$iDisplayName]} app engine"
		
		# link to this app's icons
		try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
				"$myPayloadEnginePath/Resources/${SSBEngineSourceInfo[$iAppIconFile]}" \
				"Unable to copy app icon to ${SSBEngineSourceInfo[$iDisplayName]} app engine."
		try /bin/cp "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
				"$myPayloadEnginePath/Resources/${SSBEngineSourceInfo[$iDocIconFile]}" \
				"Unable to copy document icon file to ${SSBEngineSourceInfo[$iDisplayName]} app engine."
	else
		
		# INTERNAL ENGINE
		
		# make sure we have the current version of Epichrome
		if [[ ! -d "$epiCurrentPath" ]] ; then
			ok=
			errmsg="Unable to find this app's version of Epichrome ($SSBVersion)."
			if vcmp "$epiLatestVersion" '>' "$SSBVersion" ; then
				errmsg+=" The app can't be run until it's reinstalled or the app is updated."
			else
				errmsg+=" It must be reinstalled before the app can run."
			fi
			return 1
		fi
		
		# make sure Epichrome is on the same volume as the engine
		if ! issamedevice "$epiCurrentPath" "$SSBPayloadPath" ; then
			ok= ; errmsg="Epichrome is not on the same volume as this app's data directory."
			return 1
		fi
		
		# copy main payload from app
		try /bin/cp -PR "$SSBAppPath/Contents/$appEnginePath" \
				"$SSBPayloadPath" \
				'Unable to copy app engine payload.'
		
		# copy icons to payload
		safecopy "$SSBAppPath/Contents/Resources/$CFBundleIconFile" \
				"$myPayloadEnginePath/Resources/$CFBundleIconFile" \
				"engine app icon"
		safecopy "$SSBAppPath/Contents/Resources/$CFBundleTypeIconFile" \
				"$myPayloadEnginePath/Resources/$CFBundleTypeIconFile" \
				"engine document icon"
		
		# hard link large payload items from Epichrome
		linktree "$epiCurrentPath/Contents/Resources/Runtime/Engine/Link" \
				"$myPayloadEnginePath" 'app engine' 'payload'
	fi
	
	# link to engine  $$$$ GET RID OF THIS?
	if [[ "$ok" ]] ; then
		try /bin/ln -s "$SSBPayloadPath" "$myDataPath/Engine" \
				'Unable create to link to engine in data directory.'
	fi
	
	# return code
	[[ "$ok" ]] && return 0 || return 1
}


# UPDATECENTRALNMH
function updatecentralnmh {
	
	# only run if we're OK
	[[ "$ok" ]] || return 1
	
	# relevant paths
	local centralNMHPath=
	getbrowserinfo 'centralNMHPath' 'com.google.Chrome'
	centralNMHPath="$userSupportPath/${centralNMHPath[$iLibraryPath]}/$nmhDirName"
	local oldManifestPath="$centralNMHPath/$nmhManifestOldFile"
	local newManifestPath="$centralNMHPath/$nmhManifestNewFile"
	
	# Epichrome version and path to pull new manifest from
	local sourceVersion="$epiCurrentVersion"
	local sourcePath="$epiCurrentPath"
	if [[ ! "$sourceVersion" ]] ; then
		sourceVersion="$epiLatestVersion"
		sourcePath="$epiLatestPath"
	fi
	
	# assume no update
	local doUpdate=
	
	# if either is missing, update both
	if [[ ! ( ( -f "$oldManifestPath" ) && ( -f "$newManifestPath" ) ) ]] ; then
		doUpdate=1
		debuglog 'One or more manifests missing.'
	fi
	
	if [[ ! "$doUpdate" ]] ; then
		
		# regex for version and path
		local info_re='Host ('"$epiVersionRe"')".*"path": *"([^"]+)"'
		
		# read in one of the manifests
		try 'curManifest=' /bin/cat "$newManifestPath" 'Unable to read central manifest.'
		[[ "$ok" ]] || return 1
		
		# check current manifest version & path
		if [[ "$curManifest" =~ $info_re ]] ; then
			
			# bad path
			if [[ ! -e "${BASH_REMATCH[9]}" ]] ; then
				doUpdate=1
				debuglog 'Central native messaging host not found at manifest path.'
			else
				local curManifestVersion="${BASH_REMATCH[1]}"
			fi
		else
			
			# unreadable manifest
			doUpdate=1
			errlog 'Unable to parse central manifest.'
		fi
	fi
	
	# we're supposed to update but there's no Epichrome
	if [[ "$doUpdate" && ! "$sourceVersion" ]] ; then
		ok= ; errmsg='Epichrome not found.'
		errlog "$errmsg"
		return 1
	fi
	
	# manifests still look OK, so check if version is out of date
	if [[ ! "$doUpdate" ]] ; then
		if vcmp "$curManifestVersion" '<' "$SSBVersion" ; then
			doUpdate=1
			debuglog 'Central manifest version is out of date.'
		fi
	fi
	
	# if any of the above triggered an update, do it now
	if [[ "$doUpdate" ]] ; then
		
		debuglog 'Installing central native messaging host manifests.'
		
		# path to Epichrome NMH items
		local nmhScript="$sourcePath/Contents/Resources/Runtime/Contents/Resources/NMH/$appNMHFile"
		local sourceManifest="$sourcePath/Contents/Resources/Runtime/Contents/Resources/NMH/$nmhManifestNewFile"
		
		# make sure directory exists
		try /bin/mkdir -p "$centralNMHPath" \
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
		
		if ! waitforcondition 'app prefs to appear' 5 .5 \
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
			
			eval "config$varname=(\"\${$varname[@]}\") ; export config$varname"
			[[ "$debug" ]] && eval "errlog DEBUG \"$varname=( \${config$varname[*]} )\""
		else
			
			# scalar value
			
			eval "config$varname=\"\${$varname}\" ; export config$varname"
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


# LAUNCHAPP_OLD -- launch an app  $$$ OBSOLETE
# function launchapp_old {  # ( appPath execName appDesc openArgs ... )
# 
# 	# only run if OK
# 	[[ "$ok" ]] || return 1
# 
# 	# arguments
# 	local appPath="$1" ; shift
# 	local execName="$1" ; shift
# 	local appDesc="$1" ; shift
# 
# 	debuglog "Launching $appDesc."
# 
# 	if ! waitforcondition \
# 			"$appDesc executable to appear" \
# 			5 .5 \
# 			test -x "$appPath/Contents/MacOS/$execName" ; then
# 		ok=
# 		errmsg="Executable for $appDesc not found."
# 		errlog "$errmsg"
# 		return 1
# 	fi
# 
# 	# launch attempt function
# 	function launchapp_attempt {  # ( openArgs )
# 
# 		# try launching
# 		local openErr=	
# 		try 'openErr&=' /usr/bin/open -a "$appPath" "$@" ''
# 		[[ "$ok" ]] && return 0
# 
# 		# launch failed due to missing executable, so try again
# 		if [[ "$openErr" = *'executable is missing'* ]] ; then
# 			ok=1
# 			errmsg=
# 			return 1
# 		fi
# 
# 		# launch failed for some other reason, so give up
# 		errlog 'ERROR|open' "$openErr"
# 		errmsg="Error launching $appDesc."
# 		errlog "$errmsg"
# 		return 0
# 	}
# 
# 	# try to launch app
# 	waitforcondition "$appDesc to launch" 5 .5 launchapp_attempt "$@"
# 	unset -f launchapp_attempt
# 
# 	# return code
# 	[[ "$ok" ]] && return 0 || return 1
# }
# export -f launchapp_old


# LAUNCHAPP: launch an app using JXA $$$ FIX UP & PROBABLY USE ONLY FOR ENGINE??
#   launchapp(aPath aDoRegister [aAppDesc aResultPIDVar aArgsVar aUrlsVar])
function launchapp {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
        
    # arguments
    local aPath="$1" ; shift
	local aDoRegister="$1" ; shift ; [[ "$aDoRegister" ]] && aDoRegister='true' || aDoRegister='false'
    local aAppDesc="$1" ; shift ; [[ "$aAppDesc" ]] || aAppDesc="${aPath##*/}"
	local aResultPIDVar="$1" ; shift
	local aArgs="$1" ; shift ; [[ "$aArgs" ]] && eval "aArgs=( \"\${$aArgs[@]}\" )"
	local aUrls="$1" ; shift ; [[ "$aUrls" ]] && eval "aUrls=( \"\${$aUrls[@]}\" )"
    
	debuglog "Launching $aAppDesc."
	
	# launch the app
	local iResultPID=
	try 'iResultPID=' /usr/bin/osascript "$myPayloadLauncherPath/Resources/Scripts/launch.scpt" \
	        "{
	   \"action\": \"launch\",
	   \"path\": \"$(escapejson "$aPath")\",
	   \"args\": [
	      $(jsonarray $',\n      ' "${aArgs[@]}")
	   ],
	   \"urls\": [
	      $(jsonarray $',\n      ' "${aUrls[@]}")
	   ],
	   \"options\": {
	      \"registerFirst\": $aDoRegister
	   }
	}" "Unable to launch $aAppDesc."
	
	# check that PID is active
	try kill -0 "$iResultPID" "Launched $aAppDesc but process cannot be found."
	
	# either assign PID result to variable, or echo it
    if [[ "$aResultPIDVar" ]] ; then
		eval "$aResultPIDVar=\"\$iResultPID\""
	else
		echo "$iResultPID"
    fi
	
    [[ "$ok" ]] && return 0 || return 1
}
export -f launchapp
 

# LAUNCHHELPER -- launch Epichrome Helper app   $$$$ DELETE OBSOLETE
# epiHelperMode= ; epiHelperParentPID=
# export epiHelperMode epiHelperParentPID
# function launchhelper { # ( mode )
# 
# 	# only run if OK
# 	[[ "$ok" ]] || return 1
# 
# 	# argument
# 	local mode="$1" ; shift
# 
# 	# set state for helper
# 	epiHelperMode="Start$mode"
# 	epiHelperParentPID="$$"
# 
# 	if [[ "$mode" = 'Cleanup' ]] ; then
# 
# 		# cleanup mode array variables
# 		exportarray SSBEngineSourceInfo
# 	elif [[ "$mode" = 'Relaunch' ]] ; then
# 
# 		# relaunch mode array variables
# 		exportarray argsURIs argsOptions
# 	fi
# 
# 	# launch helper (args are just for identification in jobs listings)
# 	try /usr/bin/open "$SSBAppPath/Contents/$appHelperPath" --args "$mode" \
# 			'Got error launching Epichrome helper app.'
# 
# 	# open error state is unreliable, so ignore it
# 	ok=1 ; errmsg=
# 
# 	# check the process table for helper
# 	function checkforhelper {
# 		local pstable=
# 		try 'pstable=' /bin/ps -x 'Unable to list active processes.'
# 		if [[ ! "$ok" ]] ; then
# 			ok=1 ; errmsg=
# 			return 1
# 		fi
# 		if [[ "$pstable" == *"$SSBAppPath/Contents/$appHelperPath/Contents/MacOS"* ]] ; then
# 			return 0
# 		else
# 			return 1
# 		fi
# 	}
# 
# 	# give helper five seconds to launch
# 	if ! waitforcondition 'Epichrome helper to launch' 5 .5 checkforhelper ; then
# 		ok=
# 		errmsg="Epichrome helper app failed to launch."
# 		errlog "$errmsg"
# 	fi
# 	unset -f checkforhelper
# 
# 	# return code
# 	[[ "$ok" ]] && return 0 || return 1
# }
