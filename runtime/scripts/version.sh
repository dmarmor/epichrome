#!/bin/bash

# version.sh [code/bump]

# ABORT function
function abort {
    [[ "$*" ]] && echo "$*" 1>&2
    exit 1
}
# absolute path to this script
mypath="${BASH_SOURCE[0]%/*}"
if [[ "$mypath" = "${BASH_SOURCE[0]}" ]] ; then
    mypath="$(pwd)"
elif [[ "$mypath" ]] ; then
    mypath="$(cd "$mypath" ; pwd)"
fi
epipath="$mypath/.."

# path to manifest
mani="$epipath/src/manifest.json"

# sed command
versionre='^(.*"version_name": ")(.*)(".*)$'
vcodere='^(.*"version": ")(.*)(".*)$'
namere='^(.*"name": ")(.*)(".*)$'

# pull out version/name info
oldversion="$(sed -En "s/$versionre/\\2/p" "$mani")"
[[ "$oldversion" ]] || abort 'Unable to get version from manifest.'
oldvcode="$(sed -En "/$vcodere/p" "$mani")"
[[ "$oldvcode" ]] || abort 'Version code line not found in manifest.'
oldvcode="$(sed -En "s/$vcodere/\\2/p" "$mani")" || abort 'Unable to get version code from manifest.'
oldname="$(sed -En "/$namere/p" "$mani")"
[[ "$oldname" ]] || abort 'Name line not found in manifest.'
oldname="$(sed -En "s/$namere/\\2/p" "$mani")" || abort 'Unable to get name from manifest.'
namestem="${oldname% SRC*}"

# bump version if requested
if [[ "$1" = 'bump' ]] ; then
    if [[ "$oldversion" =~ ^(.*)\[([0-9])+\]$ ]] ; then
        version="${BASH_REMATCH[1]}[$((${BASH_REMATCH[2]} + 1))]"
    else
        abort 'Version does not have a build number.'
    fi
else
    version="$oldversion"
fi

# create version code
vcode="$(osascript -l JavaScript -e 'let v = "'"$version"'".match(/^([0-9]+)\.([0-9]+)\.([0-9]+)(?:b([0-9]+))?(?:\[([0-9]+)\])?$/).slice(1).map((x,i) => (x ? parseInt(x) : (i == 3 ? 100 : (i == 4 ? 99 : 0))));
v[0] + "." + v[1] + "." + v[2] + "." + ((v[3]*100) + v[4]);')"
[[ "$vcode" ]] || abort 'Unable to generate version code'

# create inplace name
name="$namestem SRC"
[[ "$version" =~ b ]] && name+=' BETA' || name+=' RELEASE'

# update manifest if anything has changed
if [[ ( "$oldversion" != "$version" ) || ( "$oldvcode" != "$vcode" ) || ( "$oldname" != "$name" ) ]] ; then
    echo "Updating manifest with new info: '$name' / $version ($vcode)..." 1>&2
    sed -i '' -E "s/$versionre/\\1$version\\3/; s/$vcodere/\\1$vcode\\3/; s/$namere/\\1$name\\3/;" "$mani" || abort 'Unable to update manifest.'
fi

# output requested version
if [[ "$1" = 'code' ]] ; then
    echo "$vcode"
else
    echo "$version"
fi
