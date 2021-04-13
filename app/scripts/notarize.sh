#!/bin/bash
#
#  notarize.sh: notarize Epichrome
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


#	https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
#	sudo xcode-select -r
#	  # to find ProviderShortname for --asc-provider
#	xcrun altool --list-providers -u "dmarmor@gmail.com" -p "@keychain:AppleID altool notarize"
#	  # to store AppleID app password credential in keychain:
#	xcrun altool --store-password-in-keychain-item 'KEYCHAIN_ITEM' -u 'USERNAME' -p 'PASSWORD'

# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi
epipath="$mypath/.."

# ABORT function
function abort {
    [[ "$*" ]] && echo "*** $*" 1>&2
    exit 1
}

#  handle options
doprompt=
staple_only=
if [[ "$1" = '--prompt' ]] ; then
    doprompt=1
    shift
elif [[ "$1" = '--staple' ]] ; then
    staple_only=1
    shift
fi

# get version argument
version="$1"

# package file
package="epichrome-$version.pkg"

# move to app directory
cd "$epipath" || abort 'Unable to move to app directory.'

# ensure package is in place
[[ -f "$package" ]] || abort "Unable to find $package"

# get notarize credentials
credentials="$(cat private/notarize_credentials.txt)" || abort 'Unable to retrieve credentials.'
eval "credentials=( $credentials )"

if [[ ! "$staple_only" ]] ; then
    
    # DO NOTARIZATION
    
    # prompt to make sure
    if [[ "$doprompt" ]] ; then
        echo '*** This should only be done after thorough testing that the package is correct.'
        zsh -c "read \"ans?Send $package to Apple for notarization? (y/n [n]) \"; [[ \"\$ans\" = [Yy]* ]] && exit 0 || exit 2"
        result="$?"
        if [[ "$result" = 1 ]] ; then
            echo "Unable to display prompt. Assuming yes!"
        elif [[ "$result" = 2 ]] ; then
            abort "Notarization canceled."
        fi
    fi

    # send to Apple
    echo "Sending $package to Apple for notarization..."
    
    request_id="notarize-request.$(date '+%Y%m%d-%H%M%S')"
    request_file="epichrome-$version.$request_id.txt"
    xcrun altool --notarize-app \
            --primary-bundle-id 'org.epichrome.Epichrome.'"$version.$request_id" \
            "${credentials[@]}" \
            --file "$package" > "$request_file"
    result=$?
    cat "$request_file"
    [[ "$result" = 0 ]] || abort
        
    # wait a minute
    echo 'Waiting one minute before checking status...'
    sleep 60
else
    request_file="$(ls "epichrome-$version.notarize-request."*.txt 2> /dev/null | sort | tail -n 1)" || \
    abort 'Unable to find request file.'
fi


# CHECK FOR SUCCESS OR FAILURE FOR 5 MINUTES

# get RequestUUID & URL
request_uuid="$(sed -En 's/RequestUUID *= *([^ ]+) *$/\1/p' "$request_file")" || abort 'Unable to get request UUID.'
check_file="${request_file%.txt}.check.txt"
json_file="${request_file%.txt}.json"
status_re=$'(^|\n) *Status: *([a-zA-Z][a-zA-Z ]*[a-zA-Z]) *(\n|$)'

for ((i=0; i<5; i++)) ; do
    
    # check status
    echo "Checking $request_file..."
    xcrun altool --notarization-info "$request_uuid" "${credentials[@]}" > "$check_file" || \
            abort 'Error checking notarization status.'
    
    # parse check file to get status
    check_data="$(cat "$check_file")"
    check_status='unknown (unable to parse)'
    if [[ "$check_data" =~ $status_re ]] ; then
        if [[ "${BASH_REMATCH[2]}" = 'success' ]] ; then
            
            # success! staple it
            echo 'Package approved! Stapling notarization...'
            xcrun stapler staple "$package" || abort 'Stapling failed.'
            exit 0
            
        elif [[ "${BASH_REMATCH[2]}" = 'in progress' ]] ; then
            # wait a minute
            sleep 60

            continue
        else
            check_status="${BASH_REMATCH[1]}"
        fi
    fi
    
    # if we got here, we got non-success or pending status
    echo "Notarization status: $check_status" 1>&2
    
    # get JSON log
    curl --silent --show-error \
            "$(sed -En 's/^ *LogFileURL: *(.+)$/\1/p' "$check_file")" > \
            "$json_file" || abort 'Unable to get JSON log file.'
    
    abort 'Created JSON log file.'
done

# if we got here we timed out
abort 'Timed out waiting for notarization to be approved. Please try again later.'
