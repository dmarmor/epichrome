#!/bin/bash

# <maj><02-min><03-bug>.<03-beta|100>.<build|10000>

vre='^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?(\[0*([0-9]+)])?$'
if [[ "$1" =~ $vre ]] ; then
    vbeta="${BASH_REMATCH[5]}" ; [[ "$vbeta" ]] || vbeta='100'
    vbuild="${BASH_REMATCH[7]}" ; [[ "$vbuild" ]] || vbuild='10000'
    printf '%d.%d.%d\n' \
	   $(( (${BASH_REMATCH[1]} * 100000) + (${BASH_REMATCH[2]} * 1000) + ${BASH_REMATCH[3]} )) \
	   $vbeta $vbuild
else
    echo "FAIL"
fi
