(*
 * Interface & error-checking for the chrome-ssb.sh engine from https://github.com/lhl/chrome-ssb-osx
 *
 * Tested on Mac OS X 10.10.1
 *
 * Creative Commons 2014
 *)

set myIcon to path to resource "applet.icns"

-- FIND chrome-ssb.sh IN THE SSB
set chromeSSBScript to quoted form of (POSIX path of (path to resource "chrome-ssb.sh" in directory "Scripts"))
set lastPathScript to quoted form of (POSIX path of (path to resource "lastpath.sh" in directory "Scripts"))

set lastIconPath to do shell script lastPathScript & " get icon"
set lastSSBPath to do shell script lastPathScript & " get ssb"

-- CHOOSE THE URL
set ssbURL to the text returned of (display dialog "" with title "Choose URL" default answer "https://www.google.com/mail/" buttons {"Quit", "OK"} default button "OK" cancel button "Quit" with icon myIcon)

-- CHOOSE THE APP ICON
try
	set iconPrompt to "Select an image to use as an icon, or Cancel for none."
	set iconTypes to {"public.jpeg", "public.png", "public.tiff", "com.apple.icns"}
	try
		set lastIconPath to (lastIconPath as alias)
		set ssbIconSrc to choose file with prompt iconPrompt of type iconTypes default location lastIconPath without invisibles
	on error
		set ssbIconSrc to choose file with prompt iconPrompt of type iconTypes without invisibles
	end try
	
on error number -128
	set ssbIconSrc to ""
end try

-- if an icon was selected, update the last path info
if ssbIconSrc is not "" then
	set ssbIconSrc to (the POSIX path of ssbIconSrc)
	set lastIconPath to do shell script "dirname " & quoted form of ssbIconSrc
	set lastIconPath to quoted form of (((POSIX file lastIconPath) as alias) as text)
	do shell script lastPathScript & " set icon " & lastIconPath
end if


-- CHOOSE WHERE TO SAVE THE SSB

set ssbDefaultName to "Chrome SSB"
set ssbPrompt to "Select an image to use as an icon, or Cancel for none."

set tryAgain to true
repeat while tryAgain
	set tryAgain to false -- assume we'll succeed
	
	-- show file selection dialog
	try
		set lastSSBPath to (lastSSBPath as alias)
		set ssbPath to (choose file name with prompt ssbPrompt default name ssbDefaultName default location lastSSBPath) as text
	on error
		set ssbPath to (choose file name with prompt ssbPrompt default name ssbDefaultName) as text
	end try
	
	
	set ssbPathPosix to POSIX path of ssbPath
	set ssbDir to do shell script "dirname " & quoted form of ssbPathPosix
	set ssbName to do shell script "basename " & quoted form of ssbPathPosix
	
	-- update the last path info
	set lastSSBPath to quoted form of (((POSIX file ssbDir) as alias) as text)
	do shell script lastPathScript & " set ssb " & lastSSBPath
	
	-- if no ".app" extension given, check if they accidentally chose an existing app without confirming
	if ssbPath does not end with ".app" and ssbPath does not end with ".app:" then
		set ssbPath to ssbPath & ".app"
		set ssbName to ssbName & ".app"
		
		-- see if an app with the given base name exists
		tell application "Finder"
			set appExists to false
			if exists ssbPath then set appExists to true
		end tell
		if appExists then
			try
				display dialog "A file or folder named Ò" & ssbName & "Ó already exists. Do you want to replace it?" with icon caution buttons {"Cancel", "Replace"} default button "Cancel" cancel button "Cancel" with title "File Exists"
			on error number -128
				set tryAgain to true
				set ssbDefaultName to ssbName
			end try
		end if
	end if
	
	-- get the SSB basename for the script
	set ssbBase to do shell script "x=" & quoted form of ssbName & " ; echo ${x%.app}"
	
	if length of ssbBase > 12 then
		display dialog "The name Ò" & ssbBase & "Ó is too long. The application name canÕt be more than 12 characters long." with icon stop buttons {"OK"} default button "OK" with title "Name Too Long"
		set tryAgain to true
		set ssbDefaultName to ((characters 1 thru 12 of ssbBase) as string)
	end if
end repeat
try
	-- try to trash old application
	tell application "Finder" to move ssbPath to trash
end try

-- CREATE THE SSB
set myResult to do shell script Â
	"cd " & quoted form of ssbDir & " ; " & Â
	"( " & Â
	"echo " & quoted form of ssbBase & " ; " & Â
	"echo " & quoted form of ssbURL & " ; " & Â
	"echo " & quoted form of ssbIconSrc & Â
	" ) | " & Â
	chromeSSBScript & " > /dev/null ; " & Â
	"echo $?"
if myResult is equal to "0" then
	set dlgResult to display dialog "Created Chrome SSB \"" & ssbBase & "\"" with title "Success!" buttons {"Reveal in Finder", "OK", "Launch Now"} default button "Launch Now" cancel button "OK" with icon myIcon
else
	display dialog "Creation failed with the error: " & myResult with icon stop buttons {"OK"} default button "OK" with title "Application Not Created"
	return
end if

-- if we got here, the user wants to launch the new SSB
if (button returned of dlgResult) is "Launch Now" then
	delay 1
	try
		tell application ssbName to activate
	on error
		return
	end try
else
	--if (button returned of dlgResult) is "Reveal in Finder" then
	tell application "Finder" to reveal ssbPath
	tell application "Finder" to activate
end if
