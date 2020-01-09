#!/bin/sh
#
#  epichromeinfo.sh: utility functions for getting info on Epichrome itself
#
#  Copyright (C) 2020  David Marmor
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


# VISBETA -- if version is a beta, return 0, else return 1
function visbeta { # ( version )
    [[ "$1" =~ [bB] ]] && return 0
    return 1
}


# VCMP -- if V1 OP V2 is true, return 0, else return 1
function vcmp { # ( version1 operator version2 )

    # arguments
    local v1="$1" ; shift
    local op="$1" ; shift ; [[ "$op" ]] || op='=='
    local v2="$1" ; shift
    
    # turn operator into a numeric comparator
    case "$op" in
	'>')
	    op='-gt'
	    ;;
	'<')
	    op='-lt'
	    ;;
	'>=')
	    op='-ge'
	    ;;
	'<=')
	    op='-le'
	    ;;
	'='|'==')
	    op='-eq'
	    ;;
    esac
    
    # munge version numbers into comparable integers
    local vre='^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?$'
    local vnums=() ; local i=0
    local curv=
    for curv in "$v1" "$v2" ; do
	if [[ "$curv" =~ $vre ]] ; then

	    # munge main part of version number
	    vnums[$i]=$(( ( ${BASH_REMATCH[1]} * 1000000000 ) \
			      + ( ${BASH_REMATCH[2]} * 1000000 ) \
			      + ( ${BASH_REMATCH[3]} * 1000 ) ))
	    if [[ "${BASH_REMATCH[4]}" ]] ; then
		# beta version
		vnums[$i]=$(( ${vnums[$i]} + ${BASH_REMATCH[5]} ))
	    else
		# release version
		vnums[$i]=$(( ${vnums[$i]} + ${BASH_REMATCH[5]} + 999 ))
	    fi
	else
	    # no version
	    vnums[$i]=0
	fi
	
	i=$(( $i + 1 ))
    done
        
    # compare versions using the operator & return the result
    eval "[[ ${vnums[0]} $op ${vnums[1]} ]]"
}


# GETEPICHROMEINFO: get absolute path and version info for Epichrome
function getepichromeinfo {
    # populates the following globals (if found):
    #    epiCurrentPath -- path to version of Epichrome that corresponds to this app
    #    epiLatestVersion -- version of the latest Epichrome found
    #    epiLatestPath -- path to the latest Epichrome found
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # default global return values
    epiCurrentPath= ; epiLatestVersion= ; epiLatestPath=
    
    # use spotlight to search the system for Epichrome instances
    local instances=()
    try 'instances=(n)' /usr/bin/mdfind \
	"kMDItemCFBundleIdentifier == '${appIDRoot}.Epichrome'" \
	'error'
    if [[ ! "$ok" ]] ; then
	# ignore mdfind errors
	ok=1
	errmsg=
    fi
    
    # if spotlight fails (or is off) try hard-coded locations
    if [[ ! "${instances[*]}" ]] ; then
	instances=( ~/'Applications/Epichrome.app' \
		      '/Applications/Epichrome.app' )
    fi
    
    # check instances of Epichrome to find the current and latest
    local curInstance= ; local curVersion=
    for curInstance in "${instances[@]}" ; do
	if [[ -d "$curInstance" ]] ; then
	    
	    # get this instance's version
	    curVersionScript="$curInstance/Contents/Resources/Scripts/version.sh"
	    curVersion="$( safesource "$curInstance/Contents/Resources/Scripts/version.sh" && try echo "$epiVersion" '' )"
	    if [[ ( "$?" != 0 ) || ( ! "$curVersion" ) ]] ; then
		curVersion=0.0.0
	    fi
	    
	    if vcmp "$curVersion" '>' 0.0.0 ; then
		
		debuglog "Found Epichrome $curVersion at '$curInstance'."
		
		# see if this is newer than the current latest Epichrome
		if ( [[ ! "$epiLatestPath" ]] || \
			 vcmp "$epiLatestVersion" '<' "$curVersion" ) ; then
		    epiLatestPath="$curInstance"
		    epiLatestVersion="$curVersion"
		fi
		
		# if we haven't already found an instance of the current version, check that
		if [[ ! "$epiCurrentPath" ]] && vcmp "$curVersion" '==' "$SSBVersion" ; then
		    epiCurrentPath="$curInstance"
		fi
		
	    else
		
		# failed to get version, so assume this isn't really a version of Epichrome
		debuglog "Epichrome at '$curInstance' is not valid."
	    fi
	fi
    done
    
    # log versions found
    if [[ "$debug" ]] ; then
	[[ "$epiCurrentPath" ]] && \
	    errlog "Current version of Epichrome ($SSBVersion) found at '$epiCurrentPath'"
	[[ "$epiLatestPath" && ( "$epiLatestPath" != "$epiCurrentPath" ) ]] && \
	    errlog "Latest version of Epichrome ($epiLatestVersion) found at '$epiLatestPath'"
    fi
    
    # return 
    [[ "$ok" ]] && return 0 || return 1
}


# CHECKGITHUBVERSION: function that checks for a new version of Epichrome on GitHub
function checkgithubversion { # ( curVersion )

    [[ "$ok" ]] || return 1
    
    # set current version to compare against
    local curVersion="$1" ; shift

    # regex for pulling out version
    local versionRe='"tag_name": +"v([0-9.bB]+)",'
    
    # check github for the latest version
    local latestVersion=
    latestVersion="$(/usr/bin/curl 'https://api.github.com/repos/dmarmor/epichrome/releases/latest' 2> /dev/null)"
    
    if [[ "$?" != 0 ]] ; then

	# curl returned an error
	ok=
	errmsg="Error retrieving data."
	
    elif [[ "$latestVersion" =~ $versionRe ]] ; then

	# extract version number from regex
	latestVersion="${BASH_REMATCH[1]}"
	
	# compare versions
	if vcmp "$curVersion" '<' "$latestVersion" ; then
	    
	    # output new available version number & download URL
	    echo "$latestVersion"
	    echo 'https://github.com/dmarmor/epichrome/releases/latest'
	fi
    else

	# no version found
	ok=
	errmsg='No version information found.'
    fi
    
    # return value tells us if we had any errors
    [[ "$ok" ]] && return 0 || return 1
}
