#!/bin/bash

myVersion="$1" ; shift
myPrefix='Ep Test'
# myPrefix="$1" ; shift ; [[ "$myPrefix" ]] ||

function errcheck {
    if [[ "$?" != 0 ]] ; then
        abort "$@"
    fi
}
function abort {
    echo "$@" 1>&2
    exit 1
}

myScriptDir="${BASH_SOURCE[0]%/*}"
if [[ "$myScriptDir" = "${BASH_SOURCE[0]}" ]] ; then
    myScriptDir='.'
elif [[ ! "$myScriptDir" ]] ; then
    myScriptDir='/'
fi

myScriptDir="$(cd "$myScriptDir" && pwd -P)"
errcheck "Unable to get path to this script."

# VCMP -- if V1 OP V2 is true, return 0, else return 1
function vcmp { # ( version1 operator version2 )

# arguments
local v1="$1" ; shift
local op="$1" ; shift ; [[ "$op" ]] || op='='
local v2="$1" ; shift

# munge version numbers into comparable integers
local vre='^0*([0-9]+)\.0*([0-9]+)\.0*([0-9]+)(b0*([0-9]+))?(\[0*([0-9]+)])?$'
local curv=
local vmaj vmin vbug vbeta vbuild
local vstr=()
for curv in "$v1" "$v2" ; do
    if [[ "$curv" =~ $vre ]] ; then
        
        # extract version number parts
        vmaj="${BASH_REMATCH[1]}"
        vmin="${BASH_REMATCH[2]}"
        vbug="${BASH_REMATCH[3]}"
        vbeta="${BASH_REMATCH[5]}" ; [[ "$vbeta" ]] || vbeta=1000
        vbuild="${BASH_REMATCH[7]}" ; [[ "$vbuild" ]] || vbuild=10000
    else
        
        # no version
        vmaj=0 ; vmin=0 ; vbug=0 ; vbeta=0 ; vbuild=0
    fi
    
    # build string
    vstr+=( "$(printf '%03d.%03d.%03d.%04d.%05d' "$vmaj" "$vmin" "$vbug" "$vbeta" "$vbuild")" )
done

# compare versions using the operator & return the result
local opre='^[<>]=$'
if [[ "$op" =~ $opre ]] ; then
    eval "[[ ( \"\${vstr[0]}\" ${op:0:1} \"\${vstr[1]}\" ) || ( \"\${vstr[0]}\" = \"\${vstr[1]}\" ) ]]"
else
    eval "[[ \"\${vstr[0]}\" $op \"\${vstr[1]}\" ]]"
fi
}


IFS=$'\n'

epichromes=( $( /usr/bin/mdfind "kMDItemCFBundleIdentifier == 'org.epichrome.Epichrome'" ) )
errcheck "Unable to run spotlight search for Epichrome."

[[ "${epichromes[*]}" ]] || abort "No Epichrome.app found."

myEpichrome=
topVersion=0
for ep in "${epichromes[@]}" ; do
    curVersion="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ep/Contents/Info.plist")"
    errcheck "Unable to get version for $ep."
    
    if [[ "$myVersion" ]] ; then
        if vcmp "$myVersion" '==' "$curVersion" ; then
            myEpichrome="$ep"
            break
        fi
    else
        if vcmp "$curVersion" '>' "$topVersion" ; then
            topVersion="$curVersion"
            myEpichrome="$ep"
        fi
    fi
done

if [[ ! "$myEpichrome" ]] ; then
    abort "No Epichrome.app found for version $myVersion."
fi

[[ "$myVersion" ]] || myVersion="$topVersion"

echo "Using Epichrome.app version $myVersion at '$myEpichrome'" 1>&2

myVExt="${myVersion%[*}"
myVNum="${myVExt//[^0-9b]/}"
myShortPrefix="${myPrefix//[^A-Za-z0-9]/}"

myID="$myShortPrefix$myVNum"
myID="${myID::12}"

myDir="$myVNum-$myID"

mkdir "./$myDir" ; errcheck "Unable to create test directory."
cd -P "./$myDir" ; errcheck "Unable to move to test directory."
myTestPath="$(pwd -P)" ; errcheck "Unable to get full path."

# handle old versions of Epichrome
oldEpi=
if vcmp "$myVersion" '<=' '2.3.2' ; then
    oldEpi=1
elif vcmp "$myVersion" '<' '2.4.0b1[001]' ; then
    epiAppPathVar=myAppPath
    epiIconSourceVar=myIconSource
else
    epiAppPathVar=epiAppPath
    epiIconSourceVar=epiIconSource
fi

if [[ "$oldEpi" ]] ; then
    paths=( $( logNoStderr=1 source "$myEpichrome/Contents/Resources/Runtime/Contents/Resources/Scripts/core.sh" --inepichrome ; \
    if [[ ! "$ok" ]] ; then \
    echo "$errmsg" 1>&2 ; exit 1 ; \
else \
    initlogfile ; echo "$myDataPath" ; echo "$myLogFile" ; \
fi ) )
else
    epiScript="$myEpichrome/Contents/Resources/Scripts/epichrome.sh"
    paths=( $( "$epiScript" 'coreDoInit=1' 'epiAction=init' ) )
fi
errcheck "Unable to initialize Epichrome."
myLogFile="${paths[1]}"

for engine in 'Brave' 'Chrome' ; do
    for style in 'App' 'Tabs' 'Empty' ; do
        
        CFBundleDisplayName="$myPrefix $myVExt $engine $style"
        
        myAppPath="$myTestPath/$CFBundleDisplayName.app"
        
        echo "Building '$CFBundleDisplayName'..."
        
        if [[ "$engine" = 'Brave' ]] ; then
            ec='b'
            SSBEngineType='internal|com.brave.Browser'
        else
            ec='c'
            SSBEngineType='external|com.google.Chrome'
        fi
        
        if [[ "$style" = 'App' ]] ; then
            sc='a'
            SSBRegisterBrowser='No'
            myAppCmdLine=( '--app=https://github.com/login' )
        elif [[ "$style" = 'Tabs' ]] ; then
            sc='t'
            SSBRegisterBrowser='Yes'
            myAppCmdLine=( 'https://github.com/login' \
            'https://www.google.com/' \
            'https://www.wikipedia.org/' )
        else
            sc='e'
            SSBRegisterBrowser='Yes'
            myAppCmdLine=( )
        fi
        
        if [[ "$oldEpi" ]] ; then
            logNoStderr=1 myLogFile="$myLogFile" "$myEpichrome/Contents/Resources/Scripts/build.sh" \
            "$myAppPath" \
            "$CFBundleDisplayName" \
            "$myID" \
            "$myScriptDir/icons/${engine}_$style.icns" \
            "$SSBRegisterBrowser" \
            "$SSBEngineType" \
            "${myAppCmdLine[@]}"
        else
            "$epiScript" "myLogFile=$myLogFile" 'epiAction=build' \
            "$epiAppPathVar=$myAppPath" \
            "epiUpdateMessage=Building test app \"${myAppPath##*/}\"" \
            "CFBundleDisplayName=$CFBundleDisplayName" \
            "CFBundleName=$myID" \
            "SSBIdentifier=$myID" \
            "SSBCustomIcon=Yes" \
            "$epiIconSourceVar=$myScriptDir/icons/${engine}_$style.icns" \
            "SSBRegisterBrowser=$SSBRegisterBrowser" \
            "SSBEngineType=$SSBEngineType" \
            'SSBCommandLine=(' \
            "${myAppCmdLine[@]}" ')'
        fi
        errcheck "Error building '$CFBundleDisplayName'."
        
        sleep 0.5
        
        /usr/bin/open "$myAppPath"
        
        read -p "Hit enter when app has quit and you're ready to archive: "
        
        "$myScriptDir/savestate.sh" . "$ec$sc"
        errcheck "Unable to save state for '$CFBundleDisplayName'."
        
        "$myScriptDir/archive.sh" . "$ec$sc"
        errcheck "Unable to archive '$CFBundleDisplayName'."
    done
done
