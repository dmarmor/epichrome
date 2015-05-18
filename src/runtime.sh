#/bin/sh
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
#
# Inspired by the chrome-ssb.sh engine at https://github.com/lhl/chrome-ssb-osx
#

# NOTE: functions in this script put any error text into the variable cmdtext
#       and return 1 on error, or 0 on success


# CONSTANTS

# app executable name
CFBundleExecutable="chromessb"

# icon names
CFBundleIconFile="app_default.icns"
customIconName="app_custom.icns"
CFBundleTypeIconFile="doc_default.icns"

# app paths -- relative to Contents directory
appInfoPlist="Info.plist"
appConfigScript="Resources/Config/config.sh"
appScriptingSdef="Resources/scripting.sdef"
appChromeLink="MacOS/Chrome"


# VARNAME: make a string into a legal variable name
function varname {
    local result="$1"

    # variable can't start with a number
    local re='^[0-9]'
    [[ "$result" =~ $re ]] && result="_$result"

    # replace all undesirable characters with _
    result="${result//[^a-zA-Z0-9_]/_}"

    echo "$result"
}


# URLNAME: make a string into a legal URL name
function urlname {
    local result="$1"

    # remove all undesirable characters
    result="${result//[^-a-zA-Z0-9_]/}"
    
    # if too long, truncate to 12 characters
    [ "${#result}" -ge 12 ] && result="${result::12}"

    [ ! "$result" ] && result="SSB"
    
    echo "$result"
}


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
    local temp="$1"
    local perm="$2"

    local permOld=
    
    if [ -e "$perm" ] ; then
	permOld=$(tempname "$perm")
	cmdtext=$(/bin/mv "$perm" "$permOld" 2>&1)
	if [ $? != 0 ] ; then
	    cmdtext="Unable to overwrite old $3."
	    return 1
	fi
    fi
    
    # move the temp file or directory to its permanent name
    cmdtext=$(/bin/mv -f "$temp" "$perm" 2>&1)
    if [ $? != 0 ] ; then
	cmdtext="Unable to create final $3."
	local ignore=$(/bin/mv "$permOld" "$perm" 2>&1)
	[ $? != 0 ] && cmdtext="$cmdtext Also unable to restore original $3."
	return 1
    fi

    # remove the old permanent file or folder if there is one
    if [ -e "$permOld" ]; then
	cmdtext=$(/bin/rm -rf "$permOld" 2>&1)
	if [ $? != 0 ] ; then
	    cmdtext="Unable to remove old $3."
	    return 1
	fi
    fi
    
    cmdtext=
    return 0
}


# APPPATHS: create app bundle path variables given a prefix - or use my prefix if none given
function apppaths {

    local app=

    # GET PATH TO THE APP BUNDLE
    
    if [ "$1" ] ; then
	
	# just use the argument we've been passed

	app="$1"
    else
	
	# find app bundle this script is inside

	# get path to this script
	app=$(cd "$(dirname "$0")"; pwd)
	if [ $? != 0 ] ; then
	    cmdtext="Unable to determine app path."
	    return 1
	fi
	
	# find the containing app bundle
	if [[ "$app" =~ \.[aA][pP][pP](/.*)$ ]] ; then
	    local len=$(( ${#app} - ${#BASH_REMATCH[1]} ))
	    app=${app:0:$len}
	else
	    cmdtext="Current script is not inside an app ($app)."
	    return 1
	fi
    fi


    # FILL OUT APP PATHS

    appContentsDir="${app}/Contents"
    
    appInfoPlist="${appContentsDir}/Info.plist"
    
    appMacOSDir="${appContentsDir}/MacOS"
    
    appResourcesDir="${appContentsDir}/Resources"
    appScriptsDir="${appResourcesDir}/Scripts"
    appConfigDir="${appResourcesDir}/Config"
    appConfigScript="${appConfigDir}/config.sh"
    appScriptingSdef="${appResourcesDir}/scripting.sdef"
    
    appChromeLink="${appMacOSDir}/Chrome"
    
    cmdtext=
    return 0
}

# MCSSBINFO: find absolute paths to and info on relevant MakeChromeSSB items
function mcssbinfo {
    # default values
    mcssbVersion="$SSBVersion"
    mcssbRuntimeDir=
    mcssbUpdateScript=
    mcssbMakeIconScript=

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

    # get path to runtime stuff
    mcssbRuntimeDir="${mcssbPath}/Contents/Resources/Runtime"
    if [ ! -d "$mcssbRuntimeDir" ] ; then
	cmdtext="Unable to find runtime directory."
	return 2
    fi

    mcssbUpdateScript="${mcssbPath}/Contents/Resources/Scripts/update.sh"
    if [ ! -x "$mcssbUpdateScript" ] ; then
	cmdtext="Unable to load update script."
	return 2
    fi
    
    mcssbMakeIconScript="${myScriptsDir}/makeicon.sh"
    if [ ! -x "$mcssbMakeIconScript" ] ; then
	cmdtext="Unable to load icon conversion utility."
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
    local vls=($(unset CLICOLOR ; /bin/ls "${chromePath}/Contents/Versions" 2>&1))
    if [ \( $? != 0 \) -o \( "${#vls[@]}" -lt 1 \) ] ; then
	cmdtext="Unable to retrieve Chrome version information."
	return 1
    fi
    chromeVersion="${vls[$((${#vls[@]}-1))]}"
    
    cmdtext=
    return 0
}


# LINKCHROME: link to absolute path to Google Chrome executable inside its app bundle
function linkchrome {

    # find Chrome paths if necessary
    [ ! "$chromePath" ] && chromeinfo
    
    # make the new link in a temporary location
    local tmpChromeLink=$(tempname "$appChromeLink")
    
    # create temporary link
    cmdtext=$(/bin/ln -s "$chromeExec" "$tmpChromeLink" 2>&1)
    if [ "$?" != "0" ] ; then
	cmdtext="Unable to create link to Chrome executable."
	return 1
    fi
    
    # overwrite permanent link
    permanent "$tmpChromeLink" "$appChromeLink" "Chrome executable link"
    if [ $? != 0 ] ; then
	/bin/rm -f "$tmpChromeLink" > /dev/null 2>&1
	return 1
    fi
    
    cmdtext=
    return 0
}


# WRITECONFIG: write out config.sh file
function writeconfig {

    local configvars=( CFBundleDisplayName \
			   CFBundleName \
			   CFBundleIconFile \
			   SSBVersion \
			   SSBChromePath \
			   SSBChromeVersion \
			   SSBRegisterBrowser \
			   SSBCommandLine )
    
    local re='^declare -a'
    local var=
    local value=
    local arr=()
    local i

    # make temporary config file
    local tmpAppConfigScript=$(tempname "$appConfigScript")

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
		    value="${value} \"$i\""
		done
		value="${value} )"
	    else
		value="$(eval "echo \"\\\"\$$var\\\"\"")"
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
	permanent "$tmpAppConfigScript" "$appConfigScript" "config file"
	[ $? != 0 ] && result=1
    else
	# error earlier trying to write the temp config file
	cmdtext="Unable to write config file."
    fi
    
    # if we failed, delete the temp file
    if [ $result != 0 ] ; then
	if [ -e "$tmpAppConfigScript" ] ; then
	    /bin/rm -f "$tmpAppConfigScript" > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to remove temporary config file."
	fi
    fi

    return $result
}


# WRITEPLIST_MAKEKEYRE: assemble key value array into a regular expression
function writeplist_makekeyre {
    local result=
    for k in "${@}" ; do
	[ "$result" ] && result="${result}|"
	result="${result}${k}"
    done
    result="^(${result})$"
    echo "$result"
}


# WRITEPLIST: write out new Info.plist file
function writeplist {

    # ensure Chrome's Info.plist file is where we think it is
    if [ ! -f "$chromeInfoPlist" ] ; then
	cmdtext="Unable to find Google Chrome Info.plist file."
	return 1
    fi
    
    # set up added necessary Info.plist variables
    local CFBundleIdentifier="com.google.Chrome.$(urlname "${CFBundleName}")"
    local CFBundleVersion="$mcssbVersion"            # MakeChromeSSB version
    local CFBundleShortVersionString="$mcssbVersion" # MakeChromeSSB version

    # create name for temp Info.plist file
    local tmpInfoPlist=$(tempname "$appInfoPlist")
    
    local IFS=''
    local re_key="<key>(.*)</key>"
    local re_string="(^.*<string>)(.*)(</string>.*$)"
    local state=
    local printline=

    
    # SET UP ALL KEYS WE'LL BE CHANGING OR DELETING
    
    # keys to change in the Info.plist file
    local re_states=$(writeplist_makekeyre CFBundleDisplayName \
					   CFBundleExecutable \
					   CFBundleIconFile \
					   CFBundleIdentifier \
					   CFBundleName \
					   CFBundleShortVersionString \
					   CFBundleVersion \
					   CFBundleTypeIconFile )
    
    # keys to delete from the Info.plist file
    local re_delete=( CFBundleSignature \
			  SCMRevision \
			  DTSDKBuild \
			  DTSDKName \
			  DTXcode \
			  DTXcodeBuild \
			  KSChannelID-32bit \
			  KSChannelID-32bit-full \
			  KSChannelID-full \
			  KSProductID \
			  KSUpdateURL \
			  KSVersion )
    
    # if we're not registering as a browser, delete these keys too
    if [ "$SSBRegisterBrowser" != "Yes" ] ; then
	re_delete+=( NSPrincipalClass NSUserActivityTypes )
	eval "$(varname NSUserActivityTypes)=3"  # delete 3 lines
    fi
    
    # make the regular expression
    re_delete=$(writeplist_makekeyre "${re_delete[@]}")

    
    # READ AND FILTER CHROME'S INFO.PLIST FILE INTO OUR TEMP FILE

    local result=0
    cmdtext=
    
    while read -r line ; do
	if [ $? != 0 ] ; then
	    cmdtext="Error reading Google Chrome Info.plist file."
	    break
	fi
	
	if [ ! "$state" ] ; then
	    if [[ "$line" =~ $re_key ]] ; then
		key="${BASH_REMATCH[1]}"
		if [[ "$key" =~ $re_states ]] ; then
		    state="${BASH_REMATCH[1]}"
		    printline="$line"
		elif [[ "$key" =~ $re_delete ]] ; then
		    state="__DELETE"
		    
		    # set number of further lines to delete (default 1)
		    eval numlines="\$$(varname $key)"
		    [ ! "$numlines" ] && numlines=1
		    
		    # don't print this line
		    printline=
		else
		    printline="$line"
		fi
	    else
		printline="$line"
	    fi
	else
	    if [ "$state" = "__DELETE" ] ; then
		printline=
		
		# decrement line deletion count
		numlines=$(($numlines - 1))
		[ $numlines -lt 1 ] && state=  # we're done
	    else
		if [[ "$line" =~ $re_string ]] ; then
		    # special case: store Chrome's version number
		    if [ "$state" = "CFBundleShortVersionString" ] ; then
			if [ "$chromeVersion" -a \( "$chromeVersion" != "${BASH_REMATCH[2]}" \) ] ; then
			    cmdtext="Chrome version in Info.plist (${BASH_REMATCH[2]}) doesn't match Versions directory ($chromeVersion)."
			    break
			else
			    chromeVersion="${BASH_REMATCH[2]}"
			fi
		    fi

		    # replace string with our value
		    eval replace="\$$state"
		    if [ ! "$replace" ] ; then
			cmdtext="Internal error (unknown state \"$state\")"
			break
		    fi
		    printline="${BASH_REMATCH[1]}${replace}${BASH_REMATCH[3]}"
		else
		    cmdtext="Unable to parse Chrome Info.plist (expecting XML <string> tag)."
		    break
		fi
		state=
	    fi
	fi
	
	if [ "$printline" ] ; then
	    printf "%s\n" "$printline" >> ${tmpInfoPlist}
	    if [ $? != 0 ] ; then
		cmdtext="Error writing Info.plist."
		break
	    fi
	fi
    done < "$chromeInfoPlist"

    [ "$cmdtext" ] && result=1

    # move temp file to permanent location
    if [ $result = 0 ] ; then
	permanent "$tmpInfoPlist" "$appInfoPlist" "Info.plist"
	[ $? != 0 ] && result=1
    fi
    
    # if we failed, delete the temp file
    if [ $result != 0 ] ; then
	if [ -e "$tmpInfoPlist" ] ; then
	    /bin/rm -f "$tmpInfoPlist" > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to remove temporary Info.plist."
	fi
    fi
    
    return $result
}


# COPYCHROMERESOURCES: copy Google Chrome resources directory and update localization strings

# function copychromeresources {
#     local IFS=''

#     while read -r line ; do
# 	if [ $? != 0 ] ; then
# 	    cmdtext="Error reading XXXX localization file."
# 	    break
# 	fi

# 	if [[ "$line" =~ ^([^\"]*CFBundleDisplayName[^\"]*\")(.*)(\";[^\"]*)$ ]] ; then
# 	    line="${BASH_REMATCH[1]}${CFBundleDisplayName}${BASH_REMATCH[3]}"
# 	fi

# 	echo "$line"
# 	#printf "%s\n" "$line"
	
#     done < "$1"
# }



function copyscriptingsdef {
    # temporary scripting.sdef file
    local tmpScriptingSdef=$(tempname "$appScriptingSdef")

    # copy Chrome scripting.sdef to temp file
    cmdtext=$(/bin/cp -p "$chromeScriptingSdef" "$tmpScriptingSdef")
    if [ $? != 0 ] ; then
	cmdtext="Unable to copy Chrome scripting.sdef file."
	return 1
    fi
    
    # replace any existing file with temp file
    permanent "$tmpScriptingSdef" "$appScriptingSdef" "scripting.sdef"
    if [ $? != 0 ] ; then
	if [ -e "$tmpScriptingSdef" ] ; then
	    /bin/rm -f "$tmpScriptingSdef" > /dev/null 2>&1
	    [ $? != 0 ] && cmdtext="$cmdtext Also unable to remove temporary scripting.sdef file."
	fi
	return 1
    fi

    return 0
}
