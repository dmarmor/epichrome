#!/bin/sh
#
#  makeicon: create an ICNS file from a square image file
#
#  Copyright (C) 2015  David Marmor
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
#  Based on a script found at http://stackoverflow.com/questions/12306223/how-to-manually-create-icns-files-using-iconutil
#  in an answer by Henry posted 12/20/2013 at 12:24
#

version="1.1"

unset CDPATH


# USAGE MESSAGE

prog=`basename -- $0`
function usage {
    echo \
	"Usage: ${prog} [-afd] <input> [<output>]" 1>&2
    
    if [[ ! "$1" ]] ; then
	# long usage
	echo "\

  Convert an image file to an ICNS archive, cropping to a square if necessary

   -a - if <input> is an ICNS, convert it anyway, using its highest-
        resolution as the base image
   
   -f - do not prompt for confirmation before overwriting files

   -d - debug mode: print output from offending program on error

(version $version)" 1>&2
    fi
    
    exit $1
}


# UTILITY FUNCTIONS

# ABORT: exit cleanly
iset_exists=
converted_exists=
output_exists=
function abort {
    [[ "$iset_exists" ]] && rm -rf "$iset"
    [[ "$converted_exists" ]] && rm -f "$converted"
    [[ "$output_exists" ]] && rm -rf "$output"
    
    [[ "$debug" ]] && echo "$cmdtext" 1>&2
    [[ "$1" ]] && echo "$1" 1>&2
    
    exit "$2"
}


# HANDLE EARLY TERMINATION

trap "abort 'Error: unexpected termination.' 5" SIGHUP SIGINT SIGTERM


# CHECKERROR: check for an error & abort if necessary
function checkerror {
    local result="$?"
    local nl='
'
    local errtext=
    local iserr=
    
    # extract error text from sips or iconutil if any
    if [[ "$cmdtext" =~ ((E)|(:e)|(${nl}e))rror:\ ([^$nl]*)$nl ]] ; then
	iserr=yes
	errtext="${BASH_REMATCH[5]}"
	[[ "$errtext" ]] && errtext=" ($errtext)"
    fi

    # check if we need to abort
    [[ ( "$result" != 0 ) || "$iserr" ]] && abort "${1}${errtext}" "$2"
}


# CONFIRM: confirm action (unless -f flag is in effect)
function confirm {
    if [ ! $force ] ; then
	read -p "${1}? (y/n [n]) " -r  # -n 1 to just read a letter & go
	#echo 1>&2 # move to a new line
	if ! [[ $REPLY =~ ^[Yy]$ ]] ; then
	    return 0
	fi
    fi
    return 1
}

# DELETE: possibly delete an existing file/directory after possibly prompting
function confirmdelete {  # FILE DON'T-CONFIRM? DON'T-DELETE?
    if [[ -e "$1" ]] ; then

	# prompt unless we're not supposed to
	if [[ ! "$2" ]] ; then
	    confirm "Overwrite $1"
	    [[ "$?" != 1 ]] && abort "" 0
	fi

	# remove unless we're not supposed to
	if [[ ! "$3" ]] ; then
	    cmdtext=$(rm -rf "$1" 2>&1)
	    [[ $? != 0 ]] && abort "Error: unable to overwrite $1." 1
	fi
    fi
}

# TEMPNAME: internal version of mktemp
function tempname {
    # approximately equivalent to result=$(/usr/bin/mktemp "${appPath}.XXXXX" 2>&1)
    result="${1}.${RANDOM}${2}"
    while [[ -e "$result" ]] ; do
	result="${result}.${RANDOM}${2}"
    done

    echo "$result"
}


# COMMAND-LINE OPTIONS AND USAGE

# read arguments
convertIcns=
force=
debug=
help=
while getopts :afdh opt; do
    if [[ "$?" != 0 ]] ; then echo usage 2 ; fi
    case $opt in
	a)
	    convertIcns=1
            ;;
	f)
	    force=1
	    ;;
	d)
	    debug=1
	    ;;
	h)
	    usage # print long usage and quit
	    ;;
	'?')
	    echo "${prog}: illegal option -$OPTARG" 1>&2
	    usage 1
	    ;;
    esac
done

shift $((OPTIND - 1))


# input and output files

input="$1" ; shift
[[ ! "$input" ]] && usage 1

output="$1" ; shift
[[ ! "$output" ]] && output="${input%.*}.icns"

# confirm output file should be deleted if it already exists (but don't delete)
confirmdelete "$output" "" 1

# set path for temporary iconset
iset="${output%.icns}.iconset"

# make sure input file exists
[[ -e "$input" ]] || abort "Error: image file does not exist." 2

# get file format from sips
cmdtext=$(sips -g format "$input" 2>&1)
checkerror "Error: not a recognized image format." 2
format=${format#*format: }

# possibly exit if already an ICNS
if [[ "$format" = "icns" ]] ; then
    [[ ! "$convertIcns" ]] && abort "Error: input file is already ICNS." 3
fi

# # abort on image with no alpha channel (iconutil seems to require this)
# alpha=$(sips --getProperty hasAlpha "$input" 2>&1)
# [[ "$?" != "0" ]] && abort "Error: unable to get image alpha property." 2
# [[ "${alpha#*hasAlpha: }" != "yes" ]] && abort "Error: image does not have an alpha channel." 2

# get image dimensions
cmdtext=$(sips -g pixelWidth "$input" 2>&1)
checkerror "Error: unable to get image width." 2
w=${cmdtext#*pixelWidth: }

cmdtext=$(sips -g pixelHeight "$input" 2>&1)
checkerror "Error: unable to get image height." 2
h=${cmdtext#*pixelHeight: }

# problems with the image dimensions
[[ ( "$h" -lt "16" ) || ( "$w" -lt "16" ) ]] && abort "Error: image is less than 16x16." 2

# if not a square PNG, convert to a square PNG
converted=
convert_args=()
if [[ "$h" -ne "$w" ]] ; then
    min=$(( $h > $w ? $w : $h ))
    convert_args=( -c "$min" "$min" )
fi
[[ "$format" != "png" ]] && convert_args=( "${convert_args[@]}" -s format png )

if [[ "${#convert_args[@]}" -gt 0 ]] ; then
    converted=$(tempname "${output}" ".png")
    
    cmdtext=$(sips "${convert_args[@]}" "$input" --out "$converted" 2>&1)
    checkerror "Error: unable to convert image to a square PNG." 2
    converted_exists=1
    
    input="$converted"
fi


# create iconset directory

confirmdelete "$iset"

cmdtext=$(mkdir "$iset" 2>&1)
[[ "$?" != "0" ]] && abort "Error: unable to create temporary iconset directory." 1
iset_exists=1

# create sized images

sizes=(512 256 128 32 16)

for cursize in ${sizes[@]} ; do
    nm="$iset/icon_${cursize}x${cursize}"
    dblnm="${nm}@2x.png"
    nm="${nm}.png"
    dbl=$(($cursize * 2))
    
    if [[ "$h" -eq "$dbl" ]] ; then
	cp "$input" "$dblnm"
    elif [[ "$h" -gt "$dbl" ]] ; then
	cmdtext=$(sips -z $dbl $dbl "$input" --out "$dblnm" 2>&1)
	checkerror "Error: unable to create image size ${dbl}x${dbl}." 2
    fi
    
    if [[ "$h" -eq "$cursize" ]] ; then
	cp "$input" "$nm"
    elif [[ "$h" -gt "$cursize" ]] ; then
	cmdtext=$(sips -z $cursize $cursize "$input" --out "$nm" 2>&1)
	checkerror "Error: unable to create image size ${cursize}x${cursize}." 2
    fi
done

confirmdelete "$output" 1  # delete without prompting

cmdtext=$(iconutil -c icns -o "$output" "$iset" 2>&1)
checkerror "Error: unable to convert iconset to ICNS file." 4

abort "" 0
