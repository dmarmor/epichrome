#!/bin/sh

chrome="$1" ; shift
prefix="$1" ; shift

tmpentitlementsfile=build/curentitlements.plist

for path in "$@" ; do

    relpath="${path#$prefix}"
    relpath="${relpath#/}"
    if [[ "$relpath" ]] ; then
	chromepath="$chrome/${relpath//Chromium/Google Chrome}"
    else
	chromepath="$chrome"
    fi
    
    cmdline=( --verbose=2 --force -s 'David Marmor' )

    entitlements=
    
    opts="$(codesign --display --verbose=1 "$chromepath" 2>&1)"
    if [[ "$?" != 0 ]] ; then
	if [[ "${opts%: No such file or directory}" != "$opts" ]] ; then
	    echo "'$chromepath' not found, signing with no options"
	    opts='flags=0x0(none)'
	else
	    echo "$opts" 1>&2
	    exit 1
	fi
    fi
    
    if [[ "$opts" =~ flags=0x[0-9a-z]+\(([^ ]+)\) ]] ; then
	
	opts="${BASH_REMATCH[1]}"
	
	if [[ "$opts" != 'none' ]] ; then
	    
	    cmdline+=( --options "$opts" )
	    
	    if [[ "$opts" =~ runtime ]] ; then
		
		disp="$(codesign --display --entitlements - --verbose=0 "$chromepath" 2>&1)"
		if [[ "$?" != 0 ]] ; then
		    echo "$disp" 1>&2
		    exit 1
		fi
		
		entitlements="${disp#*<?xml}"
		if [[ "$entitlements" != "$disp" ]] ; then
		    echo "<?xml$entitlements" > "$tmpentitlementsfile" || exit 1
		    /usr/libexec/PlistBuddy -c 'Delete :com.apple.application-identifier' -c 'Delete :keychain-access-groups' "$tmpentitlementsfile"
		    cmdline+=( --entitlements "$tmpentitlementsfile" )
		else
		    entitlements=
		fi
	    fi
	fi

	echo codesign "${cmdline[@]}" "$path"
	[[ "$entitlements" ]] && ( echo '--- entitlements ---' ; cat "$tmpentitlementsfile" ; echo '---' ; echo )
	codesign "${cmdline[@]}" "$path"
	result="$?"
	rm -f "$tmpentitlementsfile"
	[[ "$result" = 0 ]] || exit 1
    else
	echo "*** Can't parse code signature for '$chromepath'" 1>&2
	exit 1
    fi
done

exit 0
