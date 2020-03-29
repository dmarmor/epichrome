#!/bin/sh

shopt -s nullglob

# simulation mode
simulate=
if [[ "$1" = '-p' ]] ; then
    simulate=1
    shift
fi

# directory
dir_arg=
if [[ "${1::2}" != '--' ]] ; then
    # args
    dir_arg="${1%/}" ; shift
fi

# validate and move to dir
[[ "$dir_arg" ]] || dir_arg='.'
if [[ ! -d "$dir_arg" ]] ; then
    echo "Directory '$dir_arg' not found."
    exit 1
fi
cd "$dir_arg"
dir="$(pwd)"

# set up useful info
id="${dir#*-}"
lib=~/"Library/Application Support/Epichrome/Apps"
app=( *.app )
if [[ "${#app[@]}" -lt 1 ]] ; then
    echo "No app found in '$dir_arg'."
    exit 1
elif [[ "${#app[@]}" -gt 1 ]] ; then
    echo "Multiple apps found in '$dir_arg'."
    exit 1
fi
app="${app[0]}"

# get command line
eval "$(sed -En '/^SSBCommandLine/p' "$app/Contents/Resources/script")"
if [[ ! "${SSBCommandLine+x}" ]] ; then
    echo "Unable to app read command line."
    exit 1
fi

# make sure payload is in place
engdir=~/"Scratch/Epichrome/EpichromeEngines.noindex/$id"
if [[ -d "$engdir/Payload" ]] ; then
    if [[ -d "$engdir/Placeholder" ]] ; then
	rm -rf "$engdir/Placeholder"
    fi
    if ! ( mv "$engdir/$app/Contents" "$engdir/Placeholder" && \
	       mv "$engdir/Payload" "$engdir/$app/Contents" ) ; then
	echo "Failed to activate engine."
	exit 1
    fi
fi

# find engine executable
exc=( ~/"Scratch/Epichrome/EpichromeEngines.noindex/$id/$app/Contents/MacOS"/* )
exc="${exc[0]}"
if [[ ! -x "$exc" ]] ; then
    echo "No engine executable found in ~/Scratch/Epichrome/EpichromeEngines.noindex/$id/$app/Contents/MacOS."
    exit 1
fi

# run engine

if [[ "$simulate" ]] ; then
    echo "'$exc'" "'--user-data-dir=$lib/$id/UserData'" "$@" "${SSBCommandLine[@]}"
else
    "$exc" "--user-data-dir=$lib/$id/UserData" "$@" "${SSBCommandLine[@]}"
fi
