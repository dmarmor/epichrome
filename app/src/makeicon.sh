#!/bin/sh
#
#  makeicon: create an ICNS file from an image file
#
#  Copyright (C) 2020  David Marmor
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

version="2.0.3"

unset CDPATH

# temporary files
inputPNG=
compBGPNG=
outputMainIconset=
outputCompIconset=
outputMainTmp=
outputCompTmp=


# USAGE MESSAGE

prog=`basename -- $0`
function usage {
    echo \
"Usage: ${prog} [-afd] <input> [<output>]
       ${prog} -c <bg-input> <x> <y> <size> [-o <main-output>] [-afd] <input> [<composite-output>]" 1>&2
    
    if [[ ! "$1" ]] ; then
	# long usage
	echo "\

  Convert an image file to an ICNS archive, padding to a square if necessary

   -a - if <input> is an ICNS, convert it anyway, using its highest-
        resolution as the base image (if this is not specified, but an
	output filename is given with -o, the input ICNS file will
	be copied to the output filename; if no output filename is
	given, ${prog} will do nothing)
	   
   -f - do not prompt for confirmation before overwriting files

   -d - debug mode: print output from offending program on error

  Composite mode:
   
   -c - create a \"composite\" icon (such as a document icon) by
        placing a copy of <input>, scaled down so its biggest dimension
	is <size>, on top of <bg-input> with the top-left corner at
        (<x>, <y>).

   -o - when -c is in effect, this option tells ${prog} to also create a
        non-composite icon from <input> and output it to <main-output>. If
        this option is not given, only the composite will be created.

  If no <output> or <composite-output> is specified, ${prog} will attempt to
  output to a file with the same basename as <input> and the extension
  replaced with .icns.

(version $version)" 1>&2
    fi
    
    exit $1
}


# UTILITY FUNCTIONS

# ABORT: exit cleanly
function abort {
    # clean up temporary files
    
    [[ -e "$inputPNG" ]] && rm -rf -- "$inputPNG" > /dev/null 2>&1
    [[ -e "$compBGPNG" ]] && rm -rf -- "$compBGPNG" > /dev/null 2>&1
    [[ -e "$outputMainIconset" ]] && rm -rf -- "$outputMainIconset" > /dev/null 2>&1
    [[ -e "$outputCompIconset" ]] && rm -rf -- "$outputCompIconset" > /dev/null 2>&1
    [[ -e "$outputMainTmp" ]] && rm -f -- "$outputMainTmp" > /dev/null 2>&1
    [[ -e "$outputCompTmp" ]] && rm -f -- "$outputCompTmp" > /dev/null 2>&1
    [[ -e "$tempIconset" ]] && rm -rf -- "$tempIconset" > /dev/null 2>&1
    
    # on error, also print any debug messages
    if [[ "$2" != 0 ]] ; then
	[[ "$debug" && "$cmdtext" ]] && echo "$cmdtext" 1>&2
    fi
    
    # display final message
    [[ "$1" ]] && echo "$1" 1>&2
    
    # remove trap
    trap - EXIT
    
    # exit with code
    exit "$2"
}


# HANDLE EARLY TERMINATION

trap "abort 'Error: unexpected termination.' 3" EXIT


# CHECKERROR: check for an error & abort if necessary
function checkerror {
    local result="$?"
    local nl='
'
    local errtext=
    local iserr=
    
    # extract error text from sips or iconutil if any
    if [[ "$cmdtext" =~ ((E)|(:e)|(${nl}e))rror( [0-9]+)?:\ ([^$nl]*)$nl ]] ; then
	iserr=yes
	errtext="${BASH_REMATCH[6]}"
	[[ "$errtext" ]] && errtext=" ($errtext)"
    fi

    # check if we need to abort
    [[ ( "$result" != 0 ) || "$iserr" ]] && abort "${1}${errtext}" "$2"
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


# PERMANENT: move temporary file or directory to permanent location safely
function permanent {
    
    local temp="$1"
    local perm="$2"
    
    # MOVE OLD FILE OUT OF THE WAY, MOVE TEMP FILE TO PERMANENT NAME, DELETE OLD FILE
    
    # rename any existing permanent file to temp name for later removal
    local permOld=
    if [[ -e "$perm" ]] ; then
	permOld=$(tempname "$perm")
	cmdtext=$(/bin/mv -- "$perm" "$permOld" 2>&1)
	[[ "$?" != 0 ]] && abort "Unable to move old $perm." 2
    fi
    
    # rename temp file to its permanent name
    cmdtext=$(/bin/mv -f -- "$temp" "$perm" 2>&1)
    if [[ "$?" != 0 ]] ; then
	
	local errmsg="Unable to move $perm into place."
	
	# try to move old permanent file back
	if [[ -e "$permOld" ]] ; then
	    cmdtext="$cmdtext
"$(/bin/mv -- "$permOld" "$perm" 2>&1)
	    [[ "$?" != 0 ]] && errmsg="${errmsg}. Also unable to restore old file (now in $permOld)."
	fi
	
	abort "$errmsg" 2
    fi
    
    # remove the old file if there is one
    if [[ -e "$permOld" ]]; then
	cmdtext=$(/bin/rm -f -- "$permOld" 2>&1)
	[[ "$?" != 0 ]] && echo "Warning: Unable to delete old $perm (now $permOld)." 1>&2
    fi
    
    # if we got here, we succeeded
    return 0
}


# COMMAND-LINE OPTIONS AND USAGE

# read arguments
convertIcns=
force=
debug=
composite=
input=
outputMain=
outputComp=
help=
while getopts :afdc:o:h opt; do
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
	c)
            # check that we have enough arguments (plus at least the input file)
            if [[ $((OPTIND+3)) -gt $# ]] ; then
		echo "${prog}: -c requires 4 arguments" 1>&2
                usage 1
            fi
	    
	    # we're doing a composite icon
	    composite=1
	    
	    # get arguments
	    compBG="$OPTARG"
            eval "compX=\$$((OPTIND))"
            eval "compY=\$$((OPTIND+1))"
            eval "compSize=\$$((OPTIND+2))"

	    # make sure none of the arguments was the delimiter
	    if [[ ( "$compBG" = '--' ) || ( "$compX" = '--' ) || \
		      ( "$compY" = '--' ) || ( "$compSize" = '--' ) ]] ; then
		echo "${prog}: -c requires 4 arguments" 1>&2
                usage 1
	    fi

            # shift getopts index
            OPTIND=$((OPTIND+3))
	    
	    # sanity-check arguments
	    
	    # make sure compBG file exists
	    [[ -e "$compBG" ]] || abort "Error: composite background file $compBG does not exist." 2
	    
	    # get compBG file format from sips
	    cmdtext=$(sips -g format "$compBG" 2>&1)
	    checkerror "Error: failed to parse composite background image." 2
	    compBGFormat=${cmdtext#*format: }
	    
	    #floatre='^(([0-9]+(.[0-9]*)?)|(.[0-9]+))$'
	    intre='^[0-9]+$'
	    
	    if [[ ( ! "$compX" =~ $intre ) || ( ! "$compY" =~ $intre ) ]] ; then
		echo "${prog}: X & Y coordinates passed to -c must be a non-negative integer" 1>&2
		usage 1
	    fi
	    if [[ ( ! "$compSize" =~ $intre ) || ( "$compSize" -lt 1 ) ]] ; then
		echo "${prog}: size passed to -c must be a positive integer" 1>&2
		usage 1
	    fi
	    ;;
	o)
	    # we're also outputting a non-composite icon in composite mode
	    outputMain="$OPTARG"
	    
	    # make sure the argument wasn't the delimiter
	    if [[ "$outputMain" = '--' || ! "$outputMain" ]] ; then
		echo "${prog}: -o requires an argument" 1>&2
                usage 1
	    fi
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
[[ "$1" == "--" ]] && shift

# make sure we didn't get -o without -c
if [[ "$outputMain" && ! "$composite" ]] ; then
    echo "${prog}: -o only allowed with -c" 1>&2
    usage 1
fi


# GET INPUT AND OUTPUT FILES

# input filename
input="$1" ; shift
[[ ! "$input" ]] && usage 1

# ensure input filename doesn't start with a - (will confuse sips)
[[ "$input" =~ ^- ]] && input="./$input"

# make sure input file exists
[[ -e "$input" ]] || abort "Error: input file $input does not exist." 2

# get output filename or auto-create it
if [[ $# = 0 ]] ; then
    # no output specified, so autocreate
    
    # strip off any extension
    input_base="$input"
    if [[ "$input_base" =~ [^/](\.[^./]*)$ ]] ; then
	input_base="${input_base:0:$((${#input_base} - ${#BASH_REMATCH[1]}))}"
    fi
    
    # create output filename
    outputArg="${input_base}.icns"
else
    # output filename specified
    outputArg="$1" ; shift
    [[ ! "$outputArg" ]] && usage 1

    # ensure output filename doesn't start with a -
    [[ "$outputArg" =~ ^- ]] && outputArg="./$outputArg"

    # warn if extra arguments are present
    [[ $# -ne 0 ]] && echo "${prog}: Warning: ignoring extra command-line arguments ($@)" 1>&2
fi

# assign the output argument to the right output file (main or composite)
if [[ "$composite" ]] ; then
    outputComp="$outputArg"
else
    outputMain="$outputArg"
fi


# GET INFO ON THE INPUT FILE & DETERMINE ACTION

# get file format from sips
cmdtext=$(sips -g format "$input" 2>&1)
checkerror "Error: failed to parse image." 2
inputFormat=${cmdtext#*format: }

# choose what to do based on input format & options

if [[ ! "$outputMain" ]] ; then
    mainAction=
elif [[ ( "$inputFormat" = "icns" ) && ( ! "$convertIcns" ) ]] ; then
    # if output is the same file as input, we do nothing
    if [[ "$input" -ef "$outputMain" ]] ; then
	# if we're not creating a composite, we're done
	[[ ! "$composite" ]] && abort "Warning: input and output file are the same, nothing to do." 0
	mainAction=
    else
	mainAction=copy
    fi
else
    # we are doing a main output & we have to convert the image
    mainAction=convert
fi


# CONFIRM THAT ANY EXISTING OUTPUT FILE(S) SHOULD BE OVERWRITTEN

if [[ ! "$force" ]] ; then
    existing=
    existingPrefix=
    existingConcat=
    if [[ -e "$outputMain" ]] ; then
	existing="$outputMain"
	existingPrefix="BOTH "
	existingConcat=" and "
    fi
    if [[ "$composite" && -e "$outputComp" ]] ; then
	existing="${existingPrefix}${existing}${existingConcat}$outputComp"
    fi
    
    # confirm overwrite(s)
    if [[ "$existing" ]] ; then
	read -p "Overwrite ${existing}? (y/n [n]) " -r  # -n 1 to just read a letter & go
	#echo 1>&2 # move to a new line
	[[ $REPLY =~ ^[Yy]$ ]] || abort '' 0
    fi
fi


# BUILD MAIN AND/OR COMPOSITE ICONSETS

if [[ ( "$mainAction" = convert ) || "$composite" ]] ; then
    
    # if input not already a PNG, convert to PNG
    if [[ "$inputFormat" != "png" ]] ; then
	inputPNG=$(tempname "$input" ".png")

	# if input is an icon, use iconutil to get the biggest PNG
	if [[ "$inputFormat" = 'icns' ]] ; then
	    
	    tempIconset="$(tempname "${input}_convert" ".iconset")"
	    
	    cmdtext="$(/usr/bin/iconutil -c iconset -o "$tempIconset" "$input" 2>&1)"
	    checkerror "Error: unable to convert icon file to iconset." 2
	    
	    # pull out the biggest PNG
	    f=
	    curMax=()
	    curSize=
	    iconRe='icon_([0-9]+)x[0-9]+(@2x)?\.png$'
	    for f in "$tempIconset"/* ; do
		if [[ "$f" =~ $iconRe ]] ; then
		    
		    # get actual size of this image
		    curSize="${BASH_REMATCH[1]}"
		    [[ "${BASH_REMATCH[2]}" ]] && curSize=$(($curSize * 2))
		    
		    # see if this image is biggest so far
		    if [[ (! "${curMax[0]}" ) || \
			      ( "$curSize" -gt "${curMax[0]}" ) ]] ; then
			curMax=( "$curSize" "$f" )
		    fi
		fi
	    done
	    
	    # if we found a suitable image, use it
	    if [[ -f "${curMax[1]}" ]] ; then
		cmdtext="$(/bin/mv "${curMax[1]}" "$inputPNG" 2>&1)"
		checkerror "Error: unable to extract PNG image from icon." 2
	    else
		abort "Error: unable to find PNG image in icon." 2
	    fi
	else
	    cmdtext=$(sips -s format png "$input" --out "$inputPNG" 2>&1)
	    checkerror "Error: unable to convert image to PNG." 2
	fi
	
	phpargs=("$inputPNG")
    else
	phpargs=("$input")
    fi
    
    # we're converting the main image
    if [[ "$mainAction" = convert ]] ; then
	
	# create main iconset directory
	outputMainIconset=$(tempname "${outputMain}" ".iconset")
	cmdtext=$(/bin/mkdir -- "$outputMainIconset" 2>&1)
	[[ "$?" != "0" ]] && abort "Error: unable to create temporary iconset for $outputMain." 1
	
	# update PHP args
	phpargs=("${phpargs[@]}" "$outputMainIconset")
    fi
    
    # we're outputting a composite
    if [[ "$composite" ]] ; then
	
	# if compBG isn't already a PNG, convert to PNG
	if [[ "$compBGFormat" != "png" ]] ; then
	    compBGPNG=$(tempname "$compBG" ".png")
	    
	    cmdtext=$(sips -s format png "$compBG" --out "$compBGPNG" 2>&1)
	    checkerror "Error: unable to convert composite background image to PNG." 2

	    phpargs=("${phpargs[@]}" "$compBGPNG")
	else
	    phpargs=("${phpargs[@]}" "$compBG")
	fi
	
	# create comp iconset directory
	outputCompIconset=$(tempname "${outputComp}" ".iconset")
	cmdtext=$(/bin/mkdir -- "$outputCompIconset" 2>&1)
	[[ "$?" != "0" ]] && abort "Error: unable to create temporary iconset for $outputComp." 1
	
	# update PHP args
	phpargs=("${phpargs[@]}" "$outputCompIconset" "$compX" "$compY" "$compSize")
    fi

    phpcode='<?php // main.png ?main.iconset ?(base.png comp.iconset X Y size)

// READPNG -- read in a PNG file
function readPNG($filename) {
  // read image
  $result = imagecreatefrompng($filename);
  if (!$result) {
    printf(":CONVERTERR:Unable to open PNG for image processing.\n");
    exit(1);
  }
  
  // convert to true color (no indexing)  
  if (! imageistruecolor($result)) {
    if (!imagepalettetotruecolor($result)) {
      printf(":CONVERTERR:Unable to convert image to true color.\n");
      exit(1);
    }
  }
  
  // turn on alpha blending
  if (!imagealphablending($result, true)) {
    printf(":CONVERTERR:Unable to turn on alpha blending.\n");
    exit(1);
  }
  
  return $result;
}


// CREATETRANSPARENT -- create a transparent image
function createTransparent($w, $h) {
  $result = imagecreatetruecolor($w, $h);
  if (!$result) {
    printf(":CONVERTERR:Unable to create empty image.\n");
    exit(1);
  }
  
  if (!imagealphablending($result, true)) {
    printf(":CONVERTERR:Unable to turn on alpha blending.\n");
    exit(1);
  }
  
  $transparent = imagecolorallocatealpha($result, 0,0,0,127);
  if ($transparent === FALSE) {
    printf(":CONVERTERR:Unable to allocate alpha color.\n");
    exit(1);
  }
  
  if (!imagefill($result, 0, 0, $transparent)) {
    printf(":CONVERTERR:Unable to fill image.\n");
    exit(1);
  }
  
  return $result;
}


// SAVEPNG -- save out a PNG file
function savePNG($image, $filename) {
  
  // set up to save alpha channel
  if (!imagealphablending($image, false)) {
    printf(":CONVERTERR:Unable to turn off alpha blending.\n");
    exit(1);
  }
  
  if (!imagesavealpha($image, true)) {
    printf(":CONVERTERR:Unable to save alpha channel.\n");
    exit(1);
  }
  
  //  Save the image
  if (!imagepng($image, $filename)) {
    printf(":CONVERTERR:Unable to save PNG file.\n");
    exit(1);
  }
}


// SAVEICONSET -- save out iconset directory
function saveIconset($image, $dirname) {
  // this assumes a properly square image
  $firstSize = 1024;
  $lastSize = 16;

  // get image dimensions
  $w = imagesx($image);
  $h = imagesy($image);
  if (($w === FALSE) || ($h === FALSE)) {
    printf(":CONVERTERR:Unable to get image dimensions.\n");
    exit(1);
  }
  
  $size = max($w, $h);
  
  // get biggest icon size
  $curSize = $firstSize;

  while ($curSize >= $lastSize) {
    // get next size down
    $nextSize = $curSize / 2;
    
    // we output this size if: image width is greater than current icon size;
    // this is the last icon size; or
    // image width is closer to current icon size than next one down
    if (($size >= $curSize) ||
	($curSize == $lastSize) ||
	(($size - $nextSize) > ($curSize - $size))) {

      // get scale factor
      $scale = $curSize / $size;
      $scaledW = round($scale * $w);
      $scaledH = round($scale * $h);
      // create transparent image
      $curImage = createTransparent($curSize, $curSize);
      
      // scale original image to center of square
      if (!imagecopyresampled($curImage, $image,
			      ($curSize - $scaledW) / 2.0,
			      ($curSize - $scaledH) / 2.0,
			      0, 0, $scaledW, $scaledH, $w, $h)) {
	printf(":CONVERTERR:Unable to scale image for iconset.\n");
	exit(1);
      }
      
      // output as curSize
      if ($curSize != $firstSize) {
	savePNG($curImage, sprintf("%s/icon_%dx%d.png", $dirname, $curSize, $curSize));
      }
      
      // output as nextSize x2
      if ($curSize != $lastSize) {
	savePNG($curImage, sprintf("%s/icon_%dx%d@2x.png", $dirname, $nextSize, $nextSize));
      }
      
      // destroy the image
      if (!imagedestroy($curImage)) {
	printf(":CONVERTERR:Unable to destroy image resource.\n");
	exit(1);
      }
    }
    
    $curSize = $nextSize;
  }
}


// MAIN FUNCTIONALITY

// read in main image
$main = readPNG($argv[1]); // read main

// handle different argument scenarios
$makeMain = (count($argv) != 7);
if ($makeMain) {
  $mainIconset = $argv[2];
  $baseStart = 3;
} else {
  $baseStart = 2;
}

// read composite (if any)
$makeComp = (count($argv) > 3);
if ($makeComp) {
  $comp = readPNG($argv[$baseStart]);
  $compIconset = $argv[$baseStart + 1];
  $compX = intval($argv[$baseStart + 2]);
  $compY = intval($argv[$baseStart + 3]);
  $compSize = intval($argv[$baseStart + 4]);
}


// SAVE OUT MAIN ICON

if ($makeMain) {
  saveIconset($main, $mainIconset);
}


// SAVE OUT COMPOSITE ICON

if ($makeComp) {
  
  // get front image dimensions
  $mainW = imagesx($main);
  $mainH = imagesy($main);
  if (($mainW === FALSE) || ($mainH === FALSE)) {
    printf(":CONVERTERR:Unable to get image dimensions.\n");
    exit(1);
  }
  
  $mainSize = max($mainW, $mainH);
  
  // get scaling factor
  $scale = $compSize / $mainSize;
  $scaledW = $scale * $mainW;
  $scaledH = $scale * $mainH;
  
  // composite main onto base
  if (!imagecopyresampled($comp, $main,
			  $compX + (($compSize - $scaledW) / 2.0),
			  $compY + (($compSize - $scaledH) / 2.0),
			  0, 0, $scaledW, $scaledH, $mainW, $mainH)) {
    printf(":CONVERTERR:Unable to composite images.\n");
    exit(1);
  }
  
  // write out iconset
  saveIconset($comp, $compIconset);
}

?>'
    
    # run PHP
    cmdtext=$(echo "$phpcode" | /usr/bin/php -- "${phpargs[@]}" 2>&1)
    if [[ "$?" != 0 ]] ; then
	errtext="${cmdtext#*:CONVERTERR:}"
	cmdtext="${cmdtext%:CONVERTERR:*}"
	abort "Error: unable to create iconsets. ($errtext)" 2
    fi    

fi


# CREATE OR COPY FINAL MAIN ICON (IF NEEDED)

if [[ -d "$outputMainIconset" ]] ; then
    outputMainTmp=$(tempname "$outputMain" '.icns')
    cmdtext=$(iconutil -c icns -o "$outputMainTmp" "$outputMainIconset" 2>&1)
    checkerror "Error: unable to convert iconset to ICNS file." 4
elif [[ "$mainAction" = copy ]] ; then
    # copy input (already ICNS) to output
    outputMainTmp=$(tempname "$outputMain" '.icns')
    cmdtext=$(/bin/cp -- "$input" "$outputMainTmp" 2>&1)
    [[ "$?" != 0 ]] && abort "Unable to copy $input." 2
fi

# if we created a main icon, move temp output to its permanent home
[[ "$outputMainTmp" ]] && permanent "$outputMainTmp" "$outputMain"


# CREATE FINAL COMPOSITE ICON (IF NEEDED)

if [[ -d "$outputCompIconset" ]] ; then
    outputCompTmp=$(tempname "$outputComp" '.icns')
    cmdtext=$(iconutil -c icns -o "$outputCompTmp" "$outputCompIconset" 2>&1)
    checkerror "Error: unable to convert iconset to ICNS file." 4
fi
# if we created a composite icon, move temp output to its permanent home
[[ "$outputCompTmp" ]] && permanent "$outputCompTmp" "$outputComp"


# if we got here, we succeeded; clean up & quit
abort "" 0
