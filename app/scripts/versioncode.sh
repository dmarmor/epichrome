#!/bin/bash

# <maj><02-min><03-bug>.<03-beta|100>.<build|10000>

if ! source src/core.sh 2> /dev/null ; then
    echo '*** Unable to load src/core.sh' 1>&2
    exit 1
fi
logNoStderr=1

# VCODE -- echo numeric code for given version (current if none given)
#   vcode([aVersion aBuildNum])
function vcode {
    
    # argument
    local aVersion="$1" ; shift ; [[ "$aVersion" ]] || aVersion="$coreVersion"
    local aBuildNum="$1" ; shift
    
    if [[ "$aVersion" =~ ^$epiVersionRe$ ]] ; then
        local iBeta="${BASH_REMATCH[5]}" ; [[ "$iBeta" ]] || iBeta='100'
        if [[ ! "$aBuildNum" ]] ; then
            aBuildNum="${BASH_REMATCH[7]}" ; [[ "$aBuildNum" ]] || aBuildNum='10000'
        fi
        printf '%d.%d.%d\n' \
                $(( (${BASH_REMATCH[1]} * 100000) + (${BASH_REMATCH[2]} * 1000) + ${BASH_REMATCH[3]} )) \
                $iBeta $aBuildNum
    else
        return 1
    fi
}

if ! vcode "$1" ; then
    echo "FAIL"
fi

cleanexit
