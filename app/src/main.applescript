(*
 *
 *  main.applescript: An AppleScript GUI for creating Epichrome apps.
 *
 *  Copyright (C) 2020  David Marmor
 *
 *  https://github.com/dmarmor/epichrome
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *)


-- VERSION

local myVersion
set myVersion to "EPIVERSION"


-- GLOBAL OBJECT

local g


-- MISC CONSTANTS
set g to {promptNameLoc:"Select name and location for the app."}
set g to g & {appDefaultURL:"https://www.google.com/mail/"}
set g to g & {iconPrompt:"Select an image to use as an icon."}
set g to g & {iconTypes:{"public.jpeg", "public.png", "public.tiff", "com.apple.icns"}}
set g to g & {engineBuiltin:{id:"internal|com.brave.Browser", buttonName:"Built-In (Brave)"}}
set g to g & {engineExternal:{id:"external|com.google.Chrome", buttonName:"External (Google Chrome)"}}


-- USEFUL UTILITY VARIABLES

local dlgResult
local errStr, errNum


-- SET UP ENVIRONMENT TO EXPORT TO SCRIPTS THAT LOAD CORE.SH

set g to g & {scriptEnv:"logNoStderr='1'"}


-- GET MY ICON FOR DIALOG BOXES

set g to g & {myIcon:path to resource "applet.icns"}


-- GET PATHS TO USEFUL RESOURCES IN THIS APP
set g to g & {coreScript:quoted form of (POSIX path of (path to resource "core.sh" in directory "Runtime/Contents/Resources/Scripts"))}
set g to g & {buildScript:quoted form of (POSIX path of (path to resource "build.sh" in directory "Scripts"))}
set g to g & {pathInfoScript:quoted form of (POSIX path of (path to resource "pathinfo.sh" in directory "Scripts"))}
set g to g & {updateCheckScript:quoted form of (POSIX path of (path to resource "updatecheck.sh" in directory "Scripts"))}


-- INITIALIZE LOGGING & DATA DIRECTORY

local coreOutput
local myDataPath
set g to g & {myLogFile:""}

-- run core.sh to initialize logging & get key paths
try
	set coreOutput to do shell script (scriptEnv of g) & " /bin/bash -c 'source '" & quoted form of (coreScript of g) & "' --inepichrome ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; else initlogfile ; echo \"$myDataPath\" ; echo \"$myLogFile\" ; fi'"
	set myDataPath to paragraph 1 of coreOutput
	set (myLogFile of g) to paragraph 2 of coreOutput
	set (scriptEnv of g) to (scriptEnv of g) & " myLogFile=" & (quoted form of (myLogFile of g))
on error errStr number errNum
	display dialog "Non-fatal error initializing log: " & errStr & " Logging will not work." with title "Warning" with icon caution buttons {"OK"} default button "OK"
end try

-- ensure we have a data directory
try
	do shell script "if [[ ! -w " & (quoted form of myDataPath) & " ]] ; then false ; fi"
on error errStr number errNum
	display dialog "Error accessing application data folder: " & errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
	return
end try


-- SETTINGS FILE

set g to g & {mySettingsFile:myDataPath & "/epichrome.plist"}


-- PERSISTENT PROPERTIES

-- Epichrome state
set g to g & {lastIconPath:"", lastAppPath:"", updateCheckDate:(current date) - (1 * days), updateCheckVersion:""}

-- app state
set g to g & {appNameBase:"My Epichrome App"}
set g to g & {appName:false}
set g to g & {appShortName:false}
set g to g & {appPath:false}
set g to g & {appDir:false}
set g to g & {appIconSrc:false}
set g to g & {appIconName:false}
set g to g & {appStyle:"App Window", appURLs:{}}
set g to g & {doRegisterBrowser:"No", doCustomIcon:"Yes"}
set g to g & {appEngineType:id of (engineBuiltin of g)}
set g to g & {appEngineButton:buttonName of (engineBuiltin of g)}


-- WRITEPROPERTIES: write properties back to plist file
on writeProperties(g)

	local myProperties

	tell application "System Events"

		try
			-- create empty plist file
			set myProperties to make new property list file with properties {contents:make new property list item with properties {kind:record}, name:(mySettingsFile of g)}

			-- fill property list with Epichrome state
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastIconPath", value:lastIconPath of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastAppPath", value:lastAppPath of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:date, name:"updateCheckDate", value:updateCheckDate of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"updateCheckVersion", value:updateCheckVersion of g}

			-- fill property list with app state
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"appStyle", value:appStyle of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doRegisterBrowser", value:doRegisterBrowser of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doCustomIcon", value:doCustomIcon of g}
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"appEngineType", value:appEngineType of g}
		on error errStr number errNum
			-- ignore errors, we just won't have persistent properties
		end try
	end tell
end writeProperties


-- READ PROPERTIES FROM USER DATA OR INITIALIZE THEM IF NONE FOUND

tell application "System Events"

	local myProperties

	-- read in the file
	try
		set myProperties to property list file (mySettingsFile of g)
	on error
		set myProperties to null
	end try

	-- set properties from the file & if anything went wrong, initialize any unset properties

	-- lastIconPath
	try
		set lastIconPath of g to (value of (get property list item "lastIconPath" of myProperties) as text)
	on error
		set lastIconPath of g to ""
	end try

	-- lastAppPath
	try
		set lastAppPath of g to (value of (get property list item "lastAppPath" of myProperties) as text)
	on error
		set lastAppPath of g to ""
	end try

	-- updateCheckDate
	try
		set updateCheckDate of g to (value of (get property list item "updateCheckDate" of myProperties) as date)
	on error
		set updateCheckDate of g to (current date) - (1 * days)
	end try

	-- updateCheckVersion
	try
		set updateCheckVersion of g to (value of (get property list item "updateCheckVersion" of myProperties) as string)
	on error
		set updateCheckVersion of g to ""
	end try

	-- appStyle
	-- try
	-- 	set appStyle of g to (value of (get property list item "appStyle" of myProperties) as text)
	-- on error
		set appStyle of g to "App Window"
	-- end try

	-- doRegisterBrowser
	try
		set doRegisterBrowser of g to (value of (get property list item "doRegisterBrowser" of myProperties) as text)
	on error
		set doRegisterBrowser of g to "No"
	end try

	-- doCustomIcon
	try
		set doCustomIcon of g to (value of (get property list item "doCustomIcon" of myProperties) as text)
	on error
		set doCustomIcon of g to "Yes"
	end try

	-- appEngineType
	-- try
	-- 	set appEngineType of g to (value of (get property list item "appEngineType" of myProperties) as text)
	-- 	if appEngineType of g starts with "external" then
	-- 		set appEngineType of g to (id of (engineExternal of g))
	-- 	else
	-- 		set appEngineType of g to (id of (engineBuiltin of g))
	-- 	end if
	-- on error
		set appEngineType of g to (id of (engineBuiltin of g))
	-- end try

end tell


-- BUILD REPRESENTATION OF BROWSER TABS
on tablist(tabs, tabnum)
	local ttext
	local t
	local ti

	if (count of tabs) is 0 then
		return "No tabs specified.

Click \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
	else
		set ttext to (count of tabs) as text
		if ttext is "1" then
			set ttext to ttext & " tab"
		else
			set ttext to ttext & " tabs"
		end if
		set ttext to ttext & " specified:
"

		-- add tabs themselves to the text
		set ti to 1
		repeat with t in tabs
			if ti is tabnum then
				set ttext to ttext & "
  *  [the tab you are editing]"
			else
				set ttext to ttext & "
  -  " & t
			end if
			set ti to ti + 1
		end repeat
		if ti is tabnum then
			set ttext to ttext & "
  *  [new tab will be added here]"
		end if
		return ttext
	end if
end tablist


-- CHECK FOR UPDATES TO EPICHROME

local curDate
set curDate to current date

if (updateCheckDate of g) < curDate then
	-- set next update for 1 week from now
	set updateCheckDate of g to (curDate + (7 * days))

	-- run the update check script
	local updateCheckResult
	try
		set updateCheckResult to do shell script (scriptEnv of g) & " /bin/bash -c 'source '" & (quoted form of (updateCheckScript of g)) & "' '" & (quoted form of (quoted form of (updateCheckVersion of g))) & "' '" & (quoted form of (quoted form of myVersion)) & "' ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; fi'"
		set updateCheckResult to paragraphs of updateCheckResult
	on error errStr number errNum
		set updateCheckResult to {"ERROR", errStr}
	end try

	-- parse update check results

	if item 1 of updateCheckResult is "MYVERSION" then
		-- updateCheckVersion is older than the current version, so update it
		set updateCheckVersion of g to myVersion
		set updateCheckResult to rest of updateCheckResult
	end if

	if item 1 of updateCheckResult is "ERROR" then
		-- update check error: fail silently, but check again in 3 days instead of 7
		set updateCheckDate of g to (curDate + (3 * days))
	else
		-- assume "OK" status
		set updateCheckResult to rest of updateCheckResult

		if (count of updateCheckResult) is 1 then

			-- update check found a newer version on GitHub
			local newVersion

			set newVersion to item 1 of updateCheckResult
			try
				set dlgResult to button returned of (display dialog "A new version of Epichrome (" & newVersion & ") is available on GitHub." with title "Update Available" buttons {"Download", "Later", "Ignore This Version"} default button "Download" cancel button "Later" with icon (myIcon of g))
			on error number -128
				-- Later: do nothing
				set dlgResult to false
			end try

			-- Download or Ignore
			if dlgResult is "Download" then
				open location "GITHUBUPDATEURL"
			else if dlgResult is "Ignore This Version" then
				set updateCheckVersion of g to newVersion
			end if
		end if -- (count of updateCheckResult) is 1
	end if -- item 1 of updateCheckResult is "ERROR"
end if


-- MAIN STEP FUNCTION

on doStep(stepNum, g)

	-- steps
	local stepNAMELOC, stepSHORTNAME, stepWINSTYLE, stepURLS, stepBROWSER, stepICON, stepENGINE, stepBUILD
	set stepNAMELOC   to 1
	set stepSHORTNAME to 2
	set stepWINSTYLE  to 3
	set stepURLS      to 4
	set stepBROWSER   to 5
	set stepICON      to 6
	set stepENGINE    to 7
	set stepBUILD     to 8

	-- dialog title for this step
	local stepTitle
	set stepTitle to "Step " & stepNum & " of 8 | Epichrome EPIVERSION"

	-- status variables
	local tryAgain

	-- dialog button result
	local dlgResult

	if stepNum is stepNAMELOC then

		-- STEP 1: SELECT APPLICATION NAME & LOCATION

		repeat
			try
				display dialog "Click OK to select a name and location for the app." with title stepTitle with icon (myIcon of g) buttons {"OK", "Quit"} default button "OK" cancel button "Quit"
				exit repeat  -- move on
			on error number -128
				try
					display dialog "The app has not been created. Are you sure you want to quit?" with title "Confirm" with icon (myIcon of g) buttons {"No", "Yes"} default button "Yes" cancel button "No"
					return false  -- QUIT
				on error number -128
					-- quit not confirmed, so show welcome dialog again
				end try
			end try
		end repeat

		-- CHOOSE WHERE TO SAVE THE APP

		set (appPath of g) to false
		set tryAgain to true

		repeat while tryAgain

			set tryAgain to false -- assume we'll succeed

			-- get path to last created app
			local lastAppPathAlias
			try
				set lastAppPathAlias to ((lastAppPath of g) as alias)
			on error
				set lastAppPathAlias to ""
			end try

			-- show file selection dialog
			try
				if lastAppPathAlias is not "" then
					set (appPath of g) to (choose file name with prompt (promptNameLoc of g) default name (appNameBase of g) default location lastAppPathAlias) as text
				else
					set (appPath of g) to (choose file name with prompt (promptNameLoc of g) default name (appNameBase of g)) as text
				end if
			on error number -128
				return nextStep - 1
			end try

			-- break down the path & canonicalize app name
			local appInfo
			try
				set appInfo to do shell script (pathInfoScript of g) & " app " & quoted form of (POSIX path of (appPath of g))
			on error errStr number errNum
				return {message:errStr, title:"Error", backStep:false}
			end try

			set (appDir of g) to (paragraph 1 of appInfo)
			set (appNameBase of g) to (paragraph 2 of appInfo)
			set (appShortName of g) to (paragraph 3 of appInfo)
			set (appName of g) to (paragraph 4 of appInfo)
			set (appPath of g) to (paragraph 5 of appInfo)
			local appExtAdded
			set appExtAdded to (paragraph 6 of appInfo)

			-- update the last path info
			set lastAppPath of g to (((POSIX file (appDir of g)) as alias) as text)

			-- check if we have permission to write to this directory
			if (do shell script "#!/bin/bash
			if [[ -w \"" & (appDir of g) & "\" ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") is not "Yes" then
				display dialog "You don't have permission to write to that folder. Please choose another location for your app." with title "Error" with icon stop buttons {"OK"} default button "OK"
				set tryAgain to true
			else
				-- if no ".app" extension was given, check if they accidentally chose an existing app without confirming
				if appExtAdded is "TRUE" then
					-- see if an app with the given base name exists
					local appExists
					set appExists to false
					tell application "Finder"
						try
							if exists ((POSIX file (appPath of g)) as alias) then set appExists to true
						end try
					end tell
					if appExists then
						try
							display dialog "A file or folder named \"" & (appName of g) & "\" already exists. Do you want to replace it?" with icon caution buttons {"Cancel", "Replace"} default button "Cancel" cancel button "Cancel" with title "File Exists"
						on error number -128
							set tryAgain to true
						end try
					end if
				end if
			end if
		end repeat

		-- extra safety check
		-- if (appPath of g) is false then return stepNum - 1


	else if stepNum is stepSHORTNAME then

		-- STEP 2: SHORT APP NAME

		local appShortNamePrompt
		set appShortNamePrompt to "Enter the app name that should appear in the menu bar (16 characters or less)."

		set tryAgain to true

		repeat while tryAgain
			set tryAgain to false
			try
				set dlgResult to text returned of (display dialog appShortNamePrompt with title stepTitle with icon (myIcon of g) default answer (appShortName of g) buttons {"OK", "Back"} default button "OK" cancel button "Back")
			on error number -128 -- Back button
				return stepNum - 1
			end try

			if (count of dlgResult) > 16 then
				set tryAgain to true
				set appShortNamePrompt to "That name is too long. Please limit the name to 16 characters or less."
				set (appShortName of g) to ((characters 1 thru 16 of dlgResult) as text)
			else if (count of dlgResult) < 1 then
				set tryAgain to true
				set appShortNamePrompt to "No name entered. Please try again."
			end if
		end repeat

		-- if we got here, we have a good name
		set (appShortName of g) to dlgResult


	else if stepNum is stepWINSTYLE then

		-- STEP 3: CHOOSE APP STYLE

		try
			set (appStyle of g) to button returned of (display dialog "Choose App Style:

APP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)

BROWSER TABS - The app will display a full browser window with the given tabs." with title stepTitle with icon (myIcon of g) buttons {"App Window", "Browser Tabs", "Back"} default button (appStyle of g) cancel button "Back")

		on error number -128 -- Back button
			return stepNum - 1
		end try


	else if stepNum is stepURLS then

		-- STEP 4: CHOOSE URLS

		-- initialize URL list
		if ((appURLs of g) is {}) and ((appStyle of g) is "App Window") then
			set (appURLs of g) to {appDefaultURL of g}
		end if

		if appStyle of g is "App Window" then

			-- APP WINDOW STYLE

			try
				set (item 1 of (appURLs of g)) to text returned of (display dialog "Choose URL:" with title stepTitle with icon (myIcon of g) default answer (item 1 of (appURLs of g)) buttons {"OK", "Back"} default button "OK" cancel button "Back")
			on error number -128 -- Back button
				return stepNum - 1
			end try

		else
			-- BROWSER TABS
			local curTab
			set curTab to 1

			repeat
				if curTab > (count of (appURLs of g)) then
					try
						set dlgResult to display dialog tablist(appURLs of g, curTab) with title stepTitle with icon (myIcon of g) default answer (appDefaultURL of g) buttons {"Add", "Done (Don't Add)", "Back"} default button "Add" cancel button "Back"
					on error number -128 -- Back button
						set dlgResult to "Back"
					end try

					if dlgResult is "Back" then
						if curTab is 1 then
							set curTab to 0
							exit repeat
						else
							set curTab to curTab - 1
						end if
					else if (button returned of dlgResult) is "Add" then
						-- add the current text to the end of the list of URLs
						set (end of (appURLs of g)) to text returned of dlgResult
						set curTab to curTab + 1
					else -- "Done (Don't Add)"
						-- we're done, don't add the current text to the list
						exit repeat
					end if
				else
					local backButton
					set backButton to 0
					if curTab is 1 then
						try
							set dlgResult to display dialog tablist(appURLs of g, curTab) with title stepTitle with icon (myIcon of g) default answer (item curTab of (appURLs of g)) buttons {"Next", "Remove", "Back"} default button "Next" cancel button "Back"
						on error number -128
							set backButton to 1
						end try
					else
						set dlgResult to display dialog tablist(appURLs of g, curTab) with title stepTitle with icon (myIcon of g) default answer (item curTab of (appURLs of g)) buttons {"Next", "Remove", "Previous"} default button "Next"
					end if

					if (backButton is 1) or ((button returned of dlgResult) is "Previous") then
						if backButton is 1 then
							set curTab to 0
							exit repeat
						else
							set (item curTab of (appURLs of g)) to text returned of dlgResult
							set curTab to curTab - 1
						end if
					else if (button returned of dlgResult) is "Next" then
						set (item curTab of (appURLs of g)) to text returned of dlgResult
						set curTab to curTab + 1
					else -- "Remove"
						if curTab is 1 then
							set appURLs of g to rest of (appURLs of g)
						else if curTab is (count of (appURLs of g)) then
							set appURLs of g to (items 1 thru -2 of (appURLs of g))
							set curTab to curTab - 1
						else
							set appURLs of g to ((items 1 thru (curTab - 1) of (appURLs of g))) & ((items (curTab + 1) thru -1 of (appURLs of g)))
						end if
					end if
				end if
			end repeat

			if curTab is 0 then
				-- we hit the back button
				return stepNum - 1
			end if

		end if


	else if stepNum is stepBROWSER then

		-- STEP 5: REGISTER AS BROWSER?

		try
			set (doRegisterBrowser of g) to button returned of (display dialog "Register app as a browser?" with title stepTitle with icon (myIcon of g) buttons {"No", "Yes", "Back"} default button (doRegisterBrowser of g) cancel button "Back")
		on error number -128 -- Back button
			return stepNum - 1
		end try


	else if stepNum is stepICON then

		-- STEP 6: SELECT ICON FILE

		try
			set doCustomIcon of g to button returned of (display dialog "Do you want to provide a custom icon?" with title stepTitle with icon (myIcon of g) buttons {"Yes", "No", "Back"} default button (doCustomIcon of g) cancel button "Back")
		on error number -128 -- Back button
			return stepNum - 1
		end try

		if doCustomIcon of g is "Yes" then

			-- CHOOSE AN APP ICON

			-- show file selection dialog
			local lastIconPathAlias
			try
				set lastIconPathAlias to ((lastIconPath of g) as alias)
			on error
				set lastIconPathAlias to ""
			end try

			try
				if lastIconPathAlias is not "" then

					set (appIconSrc of g) to choose file with prompt (iconPrompt of g) of type (iconTypes of g) default location lastIconPathAlias without invisibles
				else
					set (appIconSrc of g) to choose file with prompt (iconPrompt of g) of type (iconTypes of g) without invisibles
				end if

			on error number -128
				return stepNum  -- canceled: ask about a custom icon again
			end try

			-- set up custom icon info

			-- get icon path info
			set (appIconSrc of g) to (POSIX path of (appIconSrc of g))

			-- break down the path & canonicalize icon name
			try
				set appInfo to do shell script (pathInfoScript of g) & " icon " & quoted form of (appIconSrc of g)
			on error errStr number errNum
				display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
				return false -- QUIT
			end try

			set lastIconPath of g to (((POSIX file (paragraph 1 of appInfo)) as alias) as text)
			set (appIconName of g) to (paragraph 2 of appInfo)

		else
			-- no custom icon
			set (appIconSrc of g) to ""
		end if


	else if stepNum is stepENGINE then

		-- STEP 7: SELECT ENGINE

		-- initialize engine choice buttons
		if (appEngineType of g) starts with "external" then
			set (appEngineButton of g) to buttonName of (engineExternal of g)
		else
			set (appEngineButton of g) to buttonName of (engineBuiltin of g)
		end if

		try
			set (appEngineButton of g) to button returned of (display dialog "Use built-in app engine, or external browser engine?

NOTE: If you don't know what this question means, choose Built-In.

In almost all cases, using the built-in engine will result in a more functional app. Using an external browser engine has several disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.

The main reason to choose the external browser engine is if your app must run on a signed browser (for things like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension)." with title stepTitle with icon (myIcon of g) buttons {buttonName of (engineBuiltin of g), buttonName of (engineExternal of g), "Back"} default button (appEngineButton of g) cancel button "Back")
		on error number -128 -- Back button
			return stepNum - 1
		end try

		-- set app engine
		if (appEngineButton of g) is (buttonName of (engineExternal of g)) then
			set (appEngineType of g) to (id of (engineExternal of g))
		else
			set (appEngineType of g) to (id of (engineBuiltin of g))
		end if


	else if stepNum is stepBUILD then

		-- STEP 8: CREATE APPLICATION

		-- create summary of the app
		local appSummary
		set appSummary to "Ready to create!

App: " & (appName of g) & "

Menubar Name: " & (appShortName of g) & "

Path: " & (appDir of g) & "

"
		if appStyle of g is "App Window" then
			set appSummary to appSummary & "Style: App Window

URL: " & (item 1 of (appURLs of g))
		else
			set appSummary to appSummary & "Style: Browser Tabs

Tabs: "
			if (count of (appURLs of g)) is 0 then
				set appSummary to appSummary & "<none>"
			else
				local t
				repeat with t in (appURLs of g)
					set appSummary to appSummary & "
  -  " & t
				end repeat
			end if
		end if
		set appSummary to appSummary & "

Register as Browser: " & doRegisterBrowser of g & "

Icon: "
		if (appIconSrc of g) is "" then
			set appSummary to appSummary & "<default>"
		else
			set appSummary to appSummary & (appIconName of g)
		end if

		set appSummary to appSummary & "

App Engine: "
		set appSummary to appSummary & (appEngineButton of g)

		-- set up Chrome command line
		local appCmdLine
		set appCmdLine to ""
		if appStyle of g is "App Window" then
			set appCmdLine to quoted form of ("--app=" & (item 1 of (appURLs of g)))
		else if (count of (appURLs of g)) > 0 then
			repeat with t in (appURLs of g)
				set appCmdLine to appCmdLine & " " & quoted form of t
			end repeat
		end if

		-- display summary
		try
			display dialog appSummary with title stepTitle with icon (myIcon of g) buttons {"Create", "Back"} default button "Create" cancel button "Back"
		on error number -128 -- Back button
			return stepNum - 1
		end try


		-- CREATE THE APP

		try
			do shell script (scriptEnv of g) & " /bin/bash -c 'source '" & (quoted form of (buildScript of g)) & "' '" & (quoted form of (quoted form of (appPath of g))) & "' '" & (quoted form of (quoted form of (appNameBase of g))) & "' '" & (quoted form of (quoted form of (appShortName of g))) & "' '" & (quoted form of (quoted form of (appIconSrc of g))) & "' '" & (quoted form of (quoted form of (doRegisterBrowser of g))) & "' '" & (quoted form of (quoted form of (appEngineType of g))) & "' '" & (quoted form of appCmdLine) & "' ; if [[ ! \"$ok\" ]] ; then echo \"$errmsg\" 1>&2 ; exit 1 ; fi'"
		on error errStr number errNum

			-- unable to create app due to permissions
			if errStr is "PERMISSION" then
				set errStr to "Unable to write to \"" & (appDir of g) & "\"."
			end if

			-- show error dialog & quit or go back
			return {message:"Creation failed: " & errStr, title:"Application Not Created", backStep:stepNum - 1}

		end try

		-- SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
		try
			set dlgResult to false
			set dlgResult to button returned of (display dialog "Created Epichrome app \"" & appNameBase of g & "\".

IMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it." with title "Success!" buttons {"Launch Now", "Reveal in Finder", "Quit"} default button "Launch Now" cancel button "Quit" with icon (myIcon of g))
			-- on error number -128
			-- 	return false  -- quit
		end try

		-- launch or reveal
		if dlgResult is "Launch Now" then
			delay 1
			try
				do shell script "/usr/bin/open " & quoted form of (POSIX path of (appPath of g))
				-- do I want some error reporting? /usr/bin/open is unreliable with errors
			end try
		else if dlgResult is "Reveal in Finder" then
			tell application "Finder" to reveal ((POSIX file (appPath of g)) as alias)
			tell application "Finder" to activate
		end if

		return false  -- quit
	else

		-- UNKNOWN STEP
		return {message:"Encountered unknown step " & (stepNum as text) & ". Please post an issue on GitHub.", title:"Fatal Error", backStep:false}

	end if

	-- if we got here, assume success and move on
	return stepNum + 1

end doStep


-- RUN THE STEPS TO BUILD THE APP

local nextStep
set nextStep to 1
repeat

	-- RUN THE NEXT STEP

	set nextStep to doStep(nextStep, g)


	-- CHECK RESULT OF STEP

	if class of nextStep is record then

		-- SHOW ERROR DIALOG

		local dlgButtons

		-- set up buttons
		set dlgButtons to {"Quit"}
		if (class of (backStep of nextStep) is integer) then copy "Back" to end of dlgButtons

		try
			((POSIX file (myLogFile of g)) as alias)
			copy "View Log & Quit" to end of dlgButtons
		end try

		try
			-- display dialog
			if (class of (backStep of nextStep) is integer) then
				-- dialog with Back button
				set dlgResult to button returned of (display dialog (message of nextStep) with icon stop buttons dlgButtons default button (item 1 of dlgButtons) cancel button (item 2 of dlgButtons) with title (title of nextStep))
			else
				-- dialog with no Back button
				set dlgResult to button returned of (display dialog (message of nextStep) with icon stop buttons dlgButtons default button (item 1 of dlgButtons) with title (title of nextStep))
			end if

			-- handle dialog result
			if dlgResult is "View Log & Quit" then
				tell application "Finder" to reveal ((POSIX file (myLogFile of g)) as alias)
				tell application "Finder" to activate
			end if

			-- quit
			set nextStep to false

		on error number -128 -- Back button
			set nextStep to (backStep of nextStep)
		end try
	end if

	if class of nextStep is not integer then

		-- QUIT

		writeProperties(g)
		return -- QUIT

	else if nextStep < 1 then
		-- minimum step is 1
		set nextStep to 1
	end if

end repeat
