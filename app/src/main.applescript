(*
 * 
 *  main.applescript: An AppleScript GUI for creating Epichrome apps.
 *
 *  Copyright (C) 2020  David Marmor
 *
 *  https://github.com/dmarmor/epichrome
 *
 *  Full license at: http://www.gnu.org/licenses/ (V3,6/29/2007)
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


-- BUILD FLAGS

local debug
set debug to ""
local logPreserve
set logPreserve to ""


-- MISC CONSTANTS
local promptNameLoc
set promptNameLoc to "Select name and location for the app."
local appDefaultURL
set appDefaultURL to "https://www.google.com/mail/"
local iconPrompt
set iconPrompt to "Select an image to use as an icon."
local iconTypes
set iconTypes to {"public.jpeg", "public.png", "public.tiff", "com.apple.icns"}


-- SET UP KEY VARIABLES TO EXPORT TO SCRIPTS
local myDataPath
set myDataPath to (system attribute "HOME") & "/Library/Application Support/Epichrome"
try
	do shell script "/bin/mkdir -p " & (quoted form of myDataPath)
on error errStr number errNum
	display dialog "Error accessing application data folder: " & errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
	return
end try
local myLogApp
set myLogApp to "Epichrome"
try
	set myLogApp to myLogApp & "[" & (do shell script "/bin/sh -c \"echo $PPID\"") & "]"
end try
local myLogFile
set myLogFile to myDataPath & "/epichrome_log.txt"
local logNoStderr
set logNoStderr to "1"


-- SETTINGS FILE

local myDataFile
set myDataFile to myDataPath & "/epichrome.plist"


-- GET MY ICON FOR DIALOG BOXES
local myIcon
set myIcon to path to resource "applet.icns"


-- GET PATHS TO USEFUL RESOURCES IN THIS APP
local coreScript
set coreScript to POSIX path of (path to resource "core.sh" in directory "Runtime/Resources/Scripts")
local buildScript
set buildScript to quoted form of (POSIX path of (path to resource "build.sh" in directory "Scripts"))
local pathInfoScript
set pathInfoScript to quoted form of (POSIX path of (path to resource "pathinfo.sh" in directory "Scripts"))
local updateCheckScript
set updateCheckScript to quoted form of (POSIX path of (path to resource "updatecheck.sh" in directory "Scripts"))
local versionScript
set versionScript to quoted form of (POSIX path of (path to resource "version.sh" in directory "Scripts"))


-- ENVIRONMENT FOR SCRIPTS THAT LOAD CORE.SH

local scriptEnv
set scriptEnv to "debug=" & (quoted form of debug)
set scriptEnv to scriptEnv & " logPreserve=" & (quoted form of logPreserve)
set scriptEnv to scriptEnv & " myDataPath=" & (quoted form of myDataPath)
set scriptEnv to scriptEnv & " myLogApp=" & (quoted form of myLogApp)
set scriptEnv to scriptEnv & " myLogFile=" & (quoted form of myLogFile)
set scriptEnv to scriptEnv & " logNoStderr=" & (quoted form of logNoStderr)


-- PERSISTENT PROPERTIES

local lastIconPath
local lastAppPath
local doRegisterBrowser
local doCustomIcon
local updateCheckDate
local updateCheckVersion


-- WRITEPROPERTIES: write properties back to plist file
on writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion)
	tell application "System Events"
		
		try
			-- create enclosing folder if needed and create empty plist file
			set myProperties to make new property list file with properties {contents:make new property list item with properties {kind:record}, name:myDataFile}
			
			-- fill property list
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastIconPath", value:lastIconPath}
			make new property list item at end of property list items of contents of myProperties with properties {kind:string, name:"lastAppPath", value:lastAppPath}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doRegisterBrowser", value:doRegisterBrowser}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"doCustomIcon", value:doCustomIcon}
			make new property list item at end of property list items of contents of myProperties with properties {kind:date, name:"updateCheckDate", value:updateCheckDate}
			make new property list item at end of property list items of contents of myProperties with properties {kind:boolean, name:"updateCheckVersion", value:updateCheckVersion}
		on error errmsg number errno
			-- ignore errors, we just won't have persistent properties
		end try
	end tell
end writeProperties


-- READ PROPERTIES FROM USER DATA OR INITIALIZE THEM IF NONE FOUND

tell application "System Events"
	
	-- read in the file
	try
		set myProperties to property list file myDataFile
	on error
		set myProperties to null
	end try
	
	-- set properties from the file & if anything went wrong, initialize any unset properties
	
	-- lastIconPath
	try
		set lastIconPath to (value of (get property list item "lastIconPath" of myProperties) as text)
	on error
		set lastIconPath to ""
	end try
	
	-- lastAppPath
	try
		set lastAppPath to (value of (get property list item "lastAppPath" of myProperties) as text)
	on error
		set lastAppPath to ""
	end try
	
	-- doRegisterBrowser
	try
		set doRegisterBrowser to (value of (get property list item "doRegisterBrowser" of myProperties) as text)
	on error
		set doRegisterBrowser to "No"
	end try
	
	-- doCustomIcon
	try
		set doCustomIcon to (value of (get property list item "doCustomIcon" of myProperties) as text)
	on error
		set doCustomIcon to "Yes"
	end try
	
	-- updateCheckDate
	try
		set updateCheckDate to (value of (get property list item "updateCheckDate" of myProperties) as date)
	on error
		set updateCheckDate to (current date) - (1 * days)
	end try
	
	-- updateCheckVersion
	try
		set updateCheckVersion to (value of (get property list item "updateCheckVersion" of myProperties) as string)
	on error
		set updateCheckVersion to ""
	end try
	
end tell


-- NUMBER OF STEPS IN THE PROCESS
local curStep
set curStep to 1
on step(curStep)
	return "Step " & curStep & " of 8"
end step


-- BUILD REPRESENTATION OF BROWSER TABS
on tablist(tabs, tabnum)
	local ttext
	if (count of tabs) is 0 then
		return "No tabs specified.

Click \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
	else
		local t
		set ttext to (count of tabs) as text
		if ttext is "1" then
			set ttext to ttext & " tab"
		else
			set ttext to ttext & " tabs"
		end if
		set ttext to ttext & " specified:
"
		
		-- add tabs themselves to the text
		local ti
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


-- INITIALIZE IMPORTANT VARIABLES
set appNameBase to "My Epichrome App"
set appURLs to {}


-- INITIALIZE LOG FILE
try
	do shell script scriptEnv & " /bin/sh -c 'source '" & quoted form of coreScript & "' && initlog'"
on error errStr number errNum
	display dialog "Non-fatal error initializing log: " & errStr & " Logging will not work." with title "Warning" with icon caution buttons {"OK"} default button "OK"
end try


-- CHECK FOR UPDATES TO EPICHROME

set curDate to current date
if updateCheckDate < curDate then
	-- set next update for 1 week from now
	set updateCheckDate to (curDate + (7 * days))
	
	-- get current version of Epichrome
	set curVersion to do shell script "source " & versionScript & " ; echo $epiVersion"
	
	-- if updateCheckVersion isn't set, or is earlier than the current version, set it to the current version
	if updateCheckVersion is "" then
		set updateCheckVersion to curVersion
	else
		try
			set updateCheckVersion to do shell script scriptEnv & " " & updateCheckScript & " " & (quoted form of updateCheckVersion) & " " & (quoted form of curVersion)
		on error errStr number errNum
			display dialog "Non-fatal error getting Epichrome version info: " & errStr with title "Warning" with icon caution buttons {"OK"} default button "OK"
			set updateCheckVersion to curVersion
		end try
	end if
	
	-- run the actual update check script
	try
		set updateCheckResult to do shell script scriptEnv & " " & updateCheckScript & " " & (quoted form of updateCheckVersion)
	on error errStr number errNum
		set updateCheckResult to false
		display dialog "Non-fatal error checking for new version of Epichrome on GitHub: " & errStr with title "Warning" with icon caution buttons {"OK"} default button "OK"
	end try
	
	-- parse update check results
	if updateCheckResult is not false then
		if updateCheckResult is not "" then
			set newVersion to paragraph 1 of updateCheckResult
			set updateURL to paragraph 2 of updateCheckResult
			try
				set dlgResult to button returned of (display dialog "A new version of Epichrome (" & newVersion & ") is available on GitHub." with title "Update Available" buttons {"Download", "Later", "Ignore This Version"} default button "Download" cancel button "Later" with icon myIcon)
			on error number -128
				-- Later: do nothing
				set dlgResult to false
			end try
			
			-- Download or Ignore
			if dlgResult is "Download" then
				open location updateURL
			else if dlgResult is "Ignore This Version" then
				set updateCheckVersion to newVersion
			end if
		end if
	end if
end if


-- BUILD THE APP

repeat
	-- STEP 1: SELECT APPLICATION NAME & LOCATION
	repeat
		try
			display dialog "Click OK to select a name and location for the app." with title step(curStep) with icon myIcon buttons {"OK", "Quit"} default button "OK" cancel button "Quit"
			exit repeat
		on error number -128
			try
				display dialog "The app has not been created. Are you sure you want to quit?" with title "Confirm" with icon myIcon buttons {"No", "Yes"} default button "Yes" cancel button "No"
				writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion)
				return -- QUIT
			on error number -128
			end try
		end try
	end repeat
	
	
	-- APPLICATION FILE SAVE DIALOGUE
	repeat
		-- CHOOSE WHERE TO SAVE THE APP
		
		set appPath to false
		set tryAgain to true
		
		repeat while tryAgain
			set tryAgain to false -- assume we'll succeed
			
			-- show file selection dialog
			try
				set lastAppPathAlias to (lastAppPath as alias)
			on error
				set lastAppPathAlias to ""
			end try
			try
				if lastAppPathAlias is not "" then
					set appPath to (choose file name with prompt promptNameLoc default name appNameBase default location lastAppPathAlias) as text
				else
					set appPath to (choose file name with prompt promptNameLoc default name appNameBase) as text
				end if
			on error number -128
				exit repeat
			end try
			
			-- break down the path & canonicalize app name
			try
				set appInfo to do shell script pathInfoScript & " app " & quoted form of (POSIX path of appPath)
			on error errStr number errNum
				display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
				writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion)
				return -- QUIT
			end try
			
			set appDir to (paragraph 1 of appInfo)
			set appNameBase to (paragraph 2 of appInfo)
			set appShortName to (paragraph 3 of appInfo)
			set appName to (paragraph 4 of appInfo)
			set appPath to (paragraph 5 of appInfo)
			set appExtAdded to (paragraph 6 of appInfo)
			
			-- update the last path info
			set lastAppPath to (((POSIX file appDir) as alias) as text)
			
			
			-- check if we have permission to write to this directory
			if (do shell script "#!/bin/sh
if [[ -w \"" & appDir & "\" ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") is not "Yes" then
				display dialog "You don't have permission to write to that folder. Please choose another location for your app." with title "Error" with icon stop buttons {"OK"} default button "OK"
				set tryAgain to true
			else
				-- if no ".app" extension was given, check if they accidentally chose an existing app without confirming
				if appExtAdded is "TRUE" then
					-- see if an app with the given base name exists
					tell application "Finder"
						set appExists to false
						try
							if exists ((POSIX file appPath) as alias) then set appExists to true
						end try
					end tell
					if appExists then
						try
							display dialog "A file or folder named \"" & appName & "\" already exists. Do you want to replace it?" with icon caution buttons {"Cancel", "Replace"} default button "Cancel" cancel button "Cancel" with title "File Exists"
						on error number -128
							set tryAgain to true
						end try
					end if
				end if
			end if
		end repeat
		
		if appPath is false then
			exit repeat
		end if
		
		set curStep to curStep + 1
		
		repeat
			
			-- STEP 2: SHORT APP NAME
			
			set appShortNamePrompt to "Enter the app name that should appear in the menu bar (16 characters or less)."
			
			set tryAgain to true
			
			repeat while tryAgain
				set tryAgain to false
				set appShortNameCanceled to false
				set appShortNamePrev to appShortName
				try
					set appShortName to text returned of (display dialog appShortNamePrompt with title step(curStep) with icon myIcon default answer appShortName buttons {"OK", "Back"} default button "OK" cancel button "Back")
				on error number -128 -- Back button
					set appShortNameCanceled to true
					set curStep to curStep - 1
					exit repeat
				end try
				
				if (count of appShortName) > 16 then
					set tryAgain to true
					set appShortNamePrompt to "That name is too long. Please limit the name to 16 characters or less."
					set appShortName to ((characters 1 thru 16 of appShortName) as text)
				else if (count of appShortName) < 1 then
					set tryAgain to true
					set appShortNamePrompt to "No name entered. Please try again."
					set appShortName to appShortNamePrev
				end if
			end repeat
			
			if appShortNameCanceled then
				exit repeat
			end if
			
			-- STEP 3: CHOOSE APP STYLE
			set curStep to curStep + 1
			
			repeat
				try
					set appStyle to button returned of (display dialog "Choose App Style:

APP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)

BROWSER TABS - The app will display a full browser window with the given tabs." with title step(curStep) with icon myIcon buttons {"App Window", "Browser Tabs", "Back"} default button "App Window" cancel button "Back")
					
				on error number -128 -- Back button
					set curStep to curStep - 1
					exit repeat
				end try
				
				-- STEP 4: CHOOSE URLS
				set curStep to curStep + 1
				
				-- initialize URL list
				if (appURLs is {}) and (appStyle is "App Window") then
					set appURLs to {appDefaultURL}
				end if
				
				repeat
					if appStyle is "App Window" then
						-- APP WINDOW STYLE
						try
							set (item 1 of appURLs) to text returned of (display dialog "Choose URL:" with title step(curStep) with icon myIcon default answer (item 1 of appURLs) buttons {"OK", "Back"} default button "OK" cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try
					else
						-- BROWSER TABS
						set curTab to 1
						repeat
							if curTab > (count of appURLs) then
								try
									set dlgResult to display dialog tablist(appURLs, curTab) with title step(curStep) with icon myIcon default answer appDefaultURL buttons {"Add", "Done (Don't Add)", "Back"} default button "Add" cancel button "Back"
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
									set (end of appURLs) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Done (Don't Add)"
									-- we're done, don't add the current text to the list
									exit repeat
								end if
							else
								set backButton to 0
								if curTab is 1 then
									try
										set dlgResult to display dialog tablist(appURLs, curTab) with title step(curStep) with icon myIcon default answer (item curTab of appURLs) buttons {"Next", "Remove", "Back"} default button "Next" cancel button "Back"
									on error number -128
										set backButton to 1
									end try
								else
									set dlgResult to display dialog tablist(appURLs, curTab) with title step(curStep) with icon myIcon default answer (item curTab of appURLs) buttons {"Next", "Remove", "Previous"} default button "Next"
								end if
								
								if (backButton is 1) or ((button returned of dlgResult) is "Previous") then
									if backButton is 1 then
										set curTab to 0
										exit repeat
									else
										set (item curTab of appURLs) to text returned of dlgResult
										set curTab to curTab - 1
									end if
								else if (button returned of dlgResult) is "Next" then
									set (item curTab of appURLs) to text returned of dlgResult
									set curTab to curTab + 1
								else -- "Remove"
									if curTab is 1 then
										set appURLs to rest of appURLs
									else if curTab is (count of appURLs) then
										set appURLs to (items 1 thru -2 of appURLs)
										set curTab to curTab - 1
									else
										set appURLs to ((items 1 thru (curTab - 1) of appURLs)) & ((items (curTab + 1) thru -1 of appURLs))
									end if
								end if
							end if
						end repeat
						
						if curTab is 0 then
							-- we hit the back button
							set curStep to curStep - 1
							exit repeat
						end if
					end if
					
					-- STEP 5: REGISTER AS BROWSER?
					set curStep to curStep + 1
					
					repeat
						try
							set doRegisterBrowser to button returned of (display dialog "Register app as a browser?" with title step(curStep) with icon myIcon buttons {"No", "Yes", "Back"} default button doRegisterBrowser cancel button "Back")
						on error number -128 -- Back button
							set curStep to curStep - 1
							exit repeat
						end try
						
						-- STEP 6: SELECT ICON FILE
						set curStep to curStep + 1
						
						repeat
							try
								set doCustomIcon to button returned of (display dialog "Do you want to provide a custom icon?" with title step(curStep) with icon myIcon buttons {"Yes", "No", "Back"} default button doCustomIcon cancel button "Back")
							on error number -128 -- Back button
								set curStep to curStep - 1
								exit repeat
							end try
							
							repeat
								if doCustomIcon is "Yes" then
									
									-- CHOOSE AN APP ICON
									
									-- show file selection dialog
									try
										set lastIconPathAlias to (lastIconPath as alias)
									on error
										set lastIconPathAlias to ""
									end try
									try
										if lastIconPathAlias is not "" then
											
											set appIconSrc to choose file with prompt iconPrompt of type iconTypes default location lastIconPathAlias without invisibles
										else
											set appIconSrc to choose file with prompt iconPrompt of type iconTypes without invisibles
										end if
										
									on error number -128
										exit repeat
									end try
									
									-- get icon path info
									set appIconSrc to (POSIX path of appIconSrc)
									-- break down the path & canonicalize icon name
									try
										set appInfo to do shell script pathInfoScript & " icon " & quoted form of appIconSrc
									on error errStr number errNum
										display dialog errStr with title "Error" with icon stop buttons {"OK"} default button "OK"
										writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion)
										return -- QUIT
									end try
									
									set lastIconPath to (((POSIX file (paragraph 1 of appInfo)) as alias) as text)
									set appIconName to (paragraph 2 of appInfo)
									
								else
									set appIconSrc to ""
								end if
								
								-- STEP 7: SELECT ENGINE
								set curStep to curStep + 1
								
								repeat
									try
										set appEngineType to button returned of (display dialog "Use Chromium app engine?

NOTE: If you don't know what this question means, choose Chromium.

In almost all cases, using a Chromium engine will result in a more functional app. Using Google Chrome as its engine has MANY disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.

The only reason to choose Google Chrome is if your app must run on a signed browser (mainly needed for extensions like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension)." with title step(curStep) with icon myIcon buttons {"Chromium", "Google Chrome", "Back"} default button "Chromium" cancel button "Back")
									on error number -128 -- Back button
										set curStep to curStep - 1
										exit repeat
									end try
									
									-- STEP 8: CREATE APPLICATION
									set curStep to curStep + 1
									
									-- create summary of the app
									set appSummary to "Ready to create!

App: " & appName & "

Menubar Name: " & appShortName & "

Path: " & appDir & "

"
									if appStyle is "App Window" then
										set appSummary to appSummary & "Style: App Window

URL: " & (item 1 of appURLs)
									else
										set appSummary to appSummary & "Style: Browser Tabs

Tabs: "
										if (count of appURLs) is 0 then
											set appSummary to appSummary & "<none>"
										else
											repeat with t in appURLs
												set appSummary to appSummary & "
  -  " & t
											end repeat
										end if
									end if
									set appSummary to appSummary & "
								
Register as Browser: " & doRegisterBrowser & "

Icon: "
									if appIconSrc is "" then
										set appSummary to appSummary & "<default>"
									else
										set appSummary to appSummary & appIconName
									end if
									
									set appSummary to appSummary & "
								
App Engine: "
									set appSummary to appSummary & appEngineType
									
									-- set up Chrome command line
									set appCmdLine to ""
									if appStyle is "App Window" then
										set appCmdLine to quoted form of ("--app=" & (item 1 of appURLs))
									else if (count of appURLs) > 0 then
										repeat with t in appURLs
											set appCmdLine to appCmdLine & " " & quoted form of t
										end repeat
									end if
									
									repeat
										try
											display dialog appSummary with title step(curStep) with icon myIcon buttons {"Create", "Back"} default button "Create" cancel button "Back"
										on error number -128 -- Back button
											set curStep to curStep - 1
											exit repeat
										end try
										
										
										-- CREATE THE APP
										
										repeat
											set creationSuccess to false
											try
												do shell script scriptEnv & " " & buildScript & " " & (quoted form of appPath) & " " & (quoted form of appNameBase) & " " & (quoted form of appShortName) & " " & (quoted form of appIconSrc) & " " & (quoted form of doRegisterBrowser) & " " & (quoted form of appEngineType) & " " & appCmdLine
												set creationSuccess to true
											on error errStr number errNum
												
												-- unable to create app due to permissions
												if errStr is "PERMISSION" then
													set errStr to "Unable to write to \"" & appDir & "\"."
												end if
												
												if not creationSuccess then
													try
														set dlgButtons to {"Quit", "Back"}
														try
															((POSIX file myLogFile) as alias)
															copy "View Log & Quit" to end of dlgButtons
														end try
														set dlgResult to button returned of (display dialog "Creation failed: " & errStr with icon stop buttons dlgButtons default button "Quit" cancel button "Back" with title "Application Not Created")
														if dlgResult is "View Log & Quit" then
															tell application "Finder" to reveal ((POSIX file myLogFile) as alias)
															tell application "Finder" to activate
														end if
														writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion) -- Quit button
														return -- QUIT
													on error number -128 -- Back button
														exit repeat
													end try
												end if
											end try
											
											-- SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
											try
												set dlgResult to button returned of (display dialog "Created Epichrome app \"" & appNameBase & "\".

IMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it." with title "Success!" buttons {"Launch Now", "Reveal in Finder", "Quit"} default button "Launch Now" cancel button "Quit" with icon myIcon)
											on error number -128
												writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion) -- "Quit" button
												return -- QUIT
											end try
											
											-- launch or reveal
											if dlgResult is "Launch Now" then
												delay 1
												try
													do shell script "open " & quoted form of (POSIX path of appPath)
													--tell application appName to activate
												on error
													writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion)
													return -- QUIT
												end try
											else
												--if (button returned of dlgResult) is "Reveal in Finder" then
												tell application "Finder" to reveal ((POSIX file appPath) as alias)
												tell application "Finder" to activate
											end if
											
											writeProperties(myDataFile, lastIconPath, lastAppPath, doRegisterBrowser, doCustomIcon, updateCheckDate, updateCheckVersion) -- We're done!
											return -- QUIT
											
										end repeat
										
									end repeat
									
								end repeat
								
								exit repeat -- We always kick back to the question of whether to use a custom icon
							end repeat
							
						end repeat
						
					end repeat
					
				end repeat
				
			end repeat
			
		end repeat
		
		exit repeat -- always kick back to the first dialogue (instead of the file save dialog)
		
	end repeat
	
end repeat
