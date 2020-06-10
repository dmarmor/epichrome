//
//
//  main.js: A JavaScript GUI for creating Epichrome apps.
//
//  Copyright (C) 2020  David Marmor
//
//  https://github.com/dmarmor/epichrome
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.


// VERSION

const kVersion = "EPIVERSION";


// JXA SETUP
const kApp = Application.currentApplication();
kApp.includeStandardAdditions = true;
const kSysEvents = Application('System Events');
const kFinder = Application('Finder');


// CORE UTILITY FUNCTIONS

function quotedForm(s) {
    return "'" + s.replace(/'/g, "'\\''") + "'";
}


// CONSTANTS

// app defaults & settings
const kPromptNameLoc = "Select name and location for the app.";
const kAppDefaultURL = "https://www.google.com/mail/";
const kIconPrompt = "Select an image to use as an icon.";
const kIconTypes = ["public.jpeg", "public.png", "public.tiff", "com.apple.icns"];
const kEngineInfo = {
    internal: {
        id:"internal|com.brave.Browser",
        buttonName:"Built-In (Brave)"
    },
    external: {
        id:"external|com.google.Chrome",
        buttonName:"External (Google Chrome)"
    }
};

// script paths
const kEpichromeScript = quotedForm(kApp.pathToResource("epichrome.sh", {
    inDirectory:"Scripts" }).toString());

// app resources
const kEpiIcon = kApp.pathToResource("applet.icns");

// general utility
const kDay = 24 * 60 * 60 * 1000;


// GLOBAL VARIABLES

let gScriptLogVar = "";
let gDataPath = null;
let gLogFile = null;


// INITIALIZE LOGGING & DATA DIRECTORY

function initDataDir() {

    let coreOutput;
    let myErr;

    // run core.sh to initialize logging & get key paths
    try {

        // run core script to initialize
        coreOutput = kApp.doShellScript(kEpichromeScript +
            " 'coreDoInit=1' 'epiAction=init'").split("\r");

        // make sure we get 2 lines of output
        if (coreOutput.length != 2) { throw('Unexpected output.'); }

        // parse output lines
        gDataPath = coreOutput[0];
        gLogFile = coreOutput[1];
        gScriptLogVar = quotedForm("myLogFile=" + gLogFile);

        // check that the data path is writeable
        coreOutput = kApp.doShellScript("if [[ ! -w " + quotedForm(gDataPath) + " ]] ; then echo FAIL ; fi");
        if (coreOutput == 'FAIL') { throw('Application data folder is not writeable.'); }

    } catch(myErr) {
        kApp.displayDialog("Error initializing core: " + myErr, {
            withTitle: 'Error',
            withIcon: 'stop',
            buttons: ["OK"],
            defaultButton: 1
        });
        return false;
    }

    return true;
}
if (! initDataDir()) { kApp.quit(); }

// ERRLOG -- log an error message
function errlog(aMsg, aType='ERROR') {
    kApp.doShellScript(kEpichromeScript + ' ' +
        gScriptLogVar + ' ' +
        "'epiAction=log' " +
        quotedForm('epiLogType=' + aType) + ' ' +
        quotedForm('epiLogMsg=' + aMsg));
}

// DEBUGLOG -- log a debugging message
function debuglog(aMsg) {
    errlog(aMsg, 'DEBUG');
}


// SETTINGS FILE

const kSettingsFile = gDataPath + "/epichrome.plist";


// PERSISTENT PROPERTIES

// Epichrome state
let gEpiLastIconDir = "";
let gEpiLastAppDir = "";
let gEpiUpdateCheckDate = new Date(kApp.currentDate() - (1 * kDay));
let gEpiUpdateCheckVersion = "";

// app state
let gAppNameBase = "My Epichrome App";
let gAppName = false;
let gAppShortName = false;
let gAppPath = false;
let gAppDir = false;
let gAppRegisterBrowser = "No";
let gAppCustomIcon = "Yes";
let gAppIconSrc = '';
let gAppIconName = false;
let gAppStyle = "App Window";
let gAppURLs = [];
let gAppEngineType = kEngineInfo.internal.id;
let gAppEngineButton = kEngineInfo.internal.buttonName;


// FUNCTION DEFINITIONS

// WRITEPROPERTIES: write properties back to plist file
function writeProperties() {

    let myProperties, myErr;

    debuglog("Writing preferences.");

    try {
        // create empty plist file
        myProperties = kSysEvents.PropertyListFile({
            name: kSettingsFile
        }).make();

        // fill property list with Epichrome state
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind: "string",
                name: "lastIconPath",
                value: gEpiLastIconDir
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"lastAppPath",
                value:gEpiLastAppDir
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"date",
                name:"updateCheckDate",
                value:gEpiUpdateCheckDate
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"boolean",
                name:"updateCheckVersion",
                value:gEpiUpdateCheckVersion
            })
        );

        // fill property list with app state
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"appStyle",
                value:gAppStyle
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"doRegisterBrowser",
                value:gAppRegisterBrowser
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"doCustomIcon",
                value:gAppCustomIcon
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"appEngineType",
                value:gAppEngineType
            })
        );
    } catch(myErr) {
        // ignore errors, we just won't have persistent properties
    }
}


// READPROPERTIES: read properties user data, or initialize any not found
function readProperties() {

    let myProperties, myErr;

    debuglog("Reading preferences.");

	// read in the property list
    try {
        myProperties =  kSysEvents.propertyListFiles.byName(kSettingsFile).contents.value();
    } catch(myErr) {
        myProperties = {};
    }

	// set properties from the file, and initialize any properties not found

    // EPICHROME SETTINGS

    // lastIconPath
    if (typeof myProperties["lastIconPath"] === 'string') {
        gEpiLastIconDir = myProperties["lastIconPath"];
    }

    // lastAppPath
	if (typeof myProperties["lastAppPath"] === 'string') {
        gEpiLastAppDir = myProperties["lastAppPath"];
    }

    // updateCheckDate
	if (myProperties["updateCheckDate"] instanceof Date) {
        gEpiUpdateCheckDate = myProperties["updateCheckDate"];
    }

	// updateCheckVersion
	if (typeof myProperties["updateCheckVersion"] === 'string') {
        gEpiUpdateCheckVersion = myProperties["updateCheckVersion"];
    }


    // APP SETTINGS

    // appStyle (DON'T STORE FOR NOW)
    // if (myProperties["appStyle"]) {
    //     gAppStyle = myProperties["appStyle"];
    // }

    let myYesNoRegex=/^(Yes|No)$/;

	// doRegisterBrowser
	if (myYesNoRegex.test(myProperties["doRegisterBrowser"])) {
        gAppRegisterBrowser = myProperties["doRegisterBrowser"];
    }

	// doCustomIcon
	if (myYesNoRegex.test(myProperties["doCustomIcon"])) {
        gAppCustomIcon = myProperties["doCustomIcon"];
    }

	// appEngineType
	// if (myProperties["appEngineType"]) {
    //     gAppEngineType = myProperties["appEngineType"];
    //     if (gAppEngineType.startsWith("external") {
    //         gAppEngineType = kEngineInfo.external.id;
    //     } else {
    //         gAppEngineType = kEngineInfo.internal.id;
	// 	}
    // }
}


// CHECKFORUPDATE: check for updates to Epichrome
function checkForUpdate() {

    let curDate = kApp.currentDate();
    let myErr;

    if (gEpiUpdateCheckDate < curDate) {

        // set next update for 1 week from now
        gEpiUpdateCheckDate = new Date(curDate + (7 * kDay));

        // run the update check script
        let myUpdateCheckResult;
        try {
            myUpdateCheckResult = kApp.doShellScript(kEpichromeScript + ' ' +
                gScriptLogVar + ' ' +
                "'epiAction=updatecheck' " +
                quotedForm('myUpdateCheckVersion=' + gEpiUpdateCheckVersion) + ' ' +
                quotedForm('myVersion=' + myVersion)).split('\r');
        } catch(myErr) {
            myUpdateCheckResult = ["ERROR", myErr.toString()];
        }

        // parse update check results

        if (myUpdateCheckResult[0] == "MYVERSION") {
            // updateCheckVersion is older than the current version, so update it
            gEpiUpdateCheckVersion = myVersion;
            myUpdateCheckResult.shift();
        }

        if (myUpdateCheckResult[0] == "ERROR") {
            // update check error: fail silently, but check again in 3 days instead of 7
            gEpiUpdateCheckDate = (curDate + (3 * kDay))
        } else {
            // assume "OK" status
            myUpdateCheckResult.shift();

            if (myUpdateCheckResult.length == 1) {

                // update check found a newer version on GitHub
                let myNewVersion = myUpdateCheckResult[0];
                let myDlgResult;
                try {
                    myDlgResult = kApp.displayDialog("A new version of Epichrome (" + myNewVersion + ") is available on GitHub.", {
                        withTitle: "Update Available",
                        withIcon: kEpiIcon,
                        buttons:["Download", "Later", "Ignore This Version"],
                        defaultButton: 1,
                        cancelButton: 2
                    }).buttonReturned;
                } catch(myErr) {
                    // Later: do nothing
                    if (myErr.errorNumber == -128) {
                        myDlgResult = false;
                    } else {
                        throw myErr;
                    }
                }

                // Download or Ignore
                if (myDlgResult == "Download") {
                    kApp.openLocation("GITHUBUPDATEURL");
                } else if (myDlgResult == "Ignore This Version") {
                    gEpiUpdateCheckVersion = myNewVersion;
                }
            } // (myUpdateCheckResult.length == 1)
        } // ! (myUpdateCheckResult[0] == "ERROR")
    } // (gEpiUpdateCheckDate < curDate)
}


// GETPATHINFO: break down an app or icon path and get info on it
function getPathInfo(aPath, aIsAppPath=true) {

    let myResult = {};

    // appDir: directory where app will be created
    // appBase: basename of app (without extension)
    // the argument should always be a fully-qualified path

    let myMatch = aPath.match('^/((([^/]+/+)*[^/]+)/+)?([^/]+)/*$');

    if (myMatch) {
        // directory and base
        myResult.dir = myMatch[2];
        myResult.base = myMatch[4];
    } else {
        return null;
    }

    if (aIsAppPath) {

        // remove any .app extension
        myMatch = myResult.base.match(/^(.+)\.app$/i);
        if (myMatch) {
            myResult.base = myMatch[1];
            myResult.extAdded = false;
        } else {
            myResult.extAdded = true;
        }

        // appShortName: default short name for the menubar

        myResult.shortName = myResult.base;

        let myShortNameTemp;

        // too long -- remove all non-alphanumerics
        if (myResult.shortName.length > 16) {
            myShortNameTemp = myResult.shortName.replace(/[^0-9a-z]/gi, '');
            if (myShortNameTemp.length > 0) {
                // still some name left, so we'll use it
                myResult.shortName = myShortNameTemp;
            }
        }

        // still too long -- remove all lowercase vowels
        if (myResult.shortName.length > 16) {
            myShortNameTemp = myResult.shortName.replace(/[aeiou]/g, '');
            if (myShortNameTemp.length > 0) {
                // still some name left, so we'll use it
                myResult.shortName = myShortNameTemp;
            }
        }

        // still still too long -- truncate
        if (myResult.shortName.length > 16) {
            myResult.shortName = myResult.shortName.slice(0, 16);
        }

        // appName: add canonical .app extension to base name

        myResult.name = myResult.base + '.app';

        // appPath: full path of app

        if (myResult.dir.endsWith('/')) {
            myResult.path = myResult.dir + myResult.name;
        } else {
            myResult.path = myResult.dir + '/' + myResult.name;
        }
    }

    return myResult;
}


// DOSTEP: main function for all app-building steps
function doStep(aStepNum) {

    // steps
	const kStepNAMELOC   = 1;
	const kStepSHORTNAME = 2;
	const kStepWINSTYLE  = 3;
	const kStepURLS      = 4;
	const kStepBROWSER   = 5;
	const kStepICON      = 6;
	const kStepENGINE    = 7;
	const kStepBUILD     = 8;

	// dialog title for this step
	const kStepTitle = "Step " + aStepNum.toString() + " of 8 | Epichrome EPIVERSION";

	// status variables
	let tryAgain, myErr, myDlgResult;

	if (aStepNum == kStepNAMELOC) {

        // STEP 1: SELECT APPLICATION NAME & LOCATION

        while (true) {
            try {

                kApp.displayDialog("Click OK to select a name and location for the app.", {
                    withTitle: kStepTitle,
                    withIcon: kEpiIcon,
                    buttons: ["OK", "Quit"],
                    defaultButton: 1,
                    cancelButton: 2
                });

                break;  // move on

			} catch(myErr) {
                if (myErr.errorNumber == -128) {
                    try {

                        // confirm quit
                        kApp.displayDialog("The app has not been created. Are you sure you want to quit?", {
                            withTitle: "Confirm",
                            withIcon: kEpiIcon,
                            buttons: ["No", "Yes"],
                            defaultButton: 2,
                            cancelButton: 1
                        });

                        return false;  // QUIT

                    } catch(myErr) {
                        if (myErr.errorNumber == -128) {
                            // quit not confirmed, so show welcome dialog again
                            continue;
                        } else {
                            // some other dialog error
                            throw myErr;
                        }
                    }
                } else {
                    // some other dialog error
                    throw myErr;
                }
            }
        }

        // CHOOSE WHERE TO SAVE THE APP

		gAppPath = false;
		tryAgain = true;

		while (tryAgain) {

            tryAgain = false; // assume we'll succeed

			// show file selection dialog
			try {
				if (gEpiLastAppDir) {
                    try {
                        gAppPath = kApp.chooseFileName({
                            withPrompt: kPromptNameLoc,
                            defaultName: gAppNameBase,
                            defaultLocation: gEpiLastAppDir
                        }).toString();
                    } catch(myErr) {

                        if (myErr.errorNumber == -1700) {
                            // bad defaultLocation, so try this again
                            gEpiLastAppDir = '';
                            tryAgain = true;
                            continue;
                        } else {
                            // hand off to enclosing try
                            throw myErr;
                        }
                    }
                } else {
                    gAppPath = kApp.chooseFileName({
                        withPrompt: kPromptNameLoc,
                        defaultName: gAppNameBase
                    }).toString();
                }
            } catch(myErr) {
                if (myErr.errorNumber == -128) {
                    return aStepNum - 1;
                } else {
                    throw myErr;
                }
			}

			// break down the path & canonicalize app name
			let myAppInfo;
            myAppInfo = getPathInfo(gAppPath);
            if (! myAppInfo) {
				return {message:"Unable to parse app path.", title:"Error", backStep:false}
            }

            // set globals
			gAppNameBase = myAppInfo.base;
            gAppName = myAppInfo.name;
			gAppShortName = myAppInfo.shortName;
			gAppPath = myAppInfo.path;
            gAppDir = myAppInfo.dir;

			// update the last path info
			gEpiLastAppDir = myAppInfo.dir;

			// check if we have permission to write to this directory
			if (kApp.doShellScript("if [[ -w " + quotedForm(myAppInfo.dir) + " ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") != "Yes") {
                kApp.displayDialog("You don't have permission to write to that folder. Please choose another location for your app.", {
                    withTitle: "Error",
                    withIcon: 'stop',
                    buttons: ["OK"],
                    defaultButton: 1
                });
                tryAgain = true;
                continue;
			} else {
                // if no ".app" extension was given, check if they accidentally
                // chose an existing app without confirming
                if (myAppInfo.extAdded) {

                    // see if an app with the given base name exists
                    if (kApp.doShellScript("if [[ -e " + quotedForm(myAppInfo.path) + " ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") == "Yes") {
                        try {
                            kApp.displayDialog("A file or folder named \"" + myAppInfo.name + "\" already exists. Do you want to replace it?", {
                                withTitle: "File Exists",
                                withIcon: 'caution',
                                buttons: ["Cancel", "Replace"],
                                defaultButton: 1,
                                cancelButton: 1
                            });
                        } catch(myErr) {
                            if (myErr.errorNumber == -128) {
                                tryAgain = true;
                                continue;
                            } else {
                                throw myErr;
                            }
						}
                        // if we got here, user clicked "Replace"
                    }
                }
            }
		}

		// extra safety check
		// if (myResult.path == false) { return aStepNum - 1; }


	} else if (aStepNum == kStepSHORTNAME) {

        // STEP 2: SHORT APP NAME

        let myAppShortNamePrompt = "Enter the app name that should appear in the menu bar (16 characters or less).";

		tryAgain = true;

        while (tryAgain) {

            // assume success
            tryAgain = false;

			try {
                myDlgResult = kApp.displayDialog(myAppShortNamePrompt, {
                    withTitle: kStepTitle,
                    withIcon: kEpiIcon,
                    defaultAnswer: gAppShortName,
                    buttons: ["OK", "Back"],
                    defaultButton: 1,
                    cancelButton: 2
                }).textReturned;
            } catch(myErr) {
                if (myErr.errorNumber == -128) {
                    // Back button
                    return aStepNum - 1;
                } else {
                    throw myErr;
                }
            }

			if (myDlgResult.length > 16) {
                tryAgain = true;
                myAppShortNamePrompt = "That name is too long. Please limit the name to 16 characters or less.";
                gAppShortName = myDlgResult.slice(0, 16);
            } else if (myDlgResult.length == 0) {
                tryAgain = true;
                myAppShortNamePrompt = "No name entered. Please try again.";
			}
		}

		// if we got here, we have a good name
		gAppShortName = myDlgResult;


	} else if (aStepNum == kStepWINSTYLE) {

        // STEP 3: CHOOSE APP STYLE

		try {
			gAppStyle = kApp.displayDialog("Choose App Style:\n\nAPP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)\n\nBROWSER TABS - The app will display a full browser window with the given tabs.", {
                withTitle: kStepTitle,
                withIcon: kEpiIcon,
                buttons: ["App Window", "Browser Tabs", "Back"],
                defaultButton: gAppStyle,
                cancelButton: 3
            }).buttonReturned;

		} catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return aStepNum - 1;
            } else {
                throw myErr;
            }
		}


	} else if (aStepNum == kStepURLS) {

        // STEP 4: CHOOSE URLS

        // initialize URL list
		if ((gAppURLs.length == 0) && (gAppStyle == "App Window")) {
            gAppURLs.push(kAppDefaultURL);
		}

		if (gAppStyle == "App Window") {

            // APP WINDOW STYLE

			try {
				gAppURLs[0] = kApp.displayDialog("Choose URL:", {
                    withTitle: kStepTitle,
                    withIcon: kEpiIcon,
                    defaultAnswer: gAppURLs[0],
                    buttons: ["OK", "Back"],
                    defaultButton: 1,
                    cancelButton: 2
                }).textReturned;
            } catch(myErr) {
                if (myErr.errorNumber == -128) {
                    // Back button
                    return aStepNum - 1;
                } else {
                    throw myErr;
                }
            }

        } else {

            // BROWSER TABS

            // TABLIST: build representation of browser tabs
            function tablist(tabs, tabnum) {

                let ttext, ti;

                if (tabs.length == 0) {
            		return "No tabs specified.\n\nClick \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
                } else {
                    ttext = tabs.length.toString();
                    if (ttext == "1") {
            			ttext += " tab";
                    } else {
                        ttext += " tabs";
            		}
            		ttext += " specified:\n"

                    // add tabs themselves to the text
                    ti = 1;
            		for (const t of tabs) {
            			if (ti == tabnum) {
            				ttext += "\n  *  [the tab you are editing]";
            			} else {
            				ttext += "\n  -  " + t;
            			}
            			ti++;
            		}

            		if (ti == tabnum) {
            			ttext += "\n  *  [new tab will be added here]"
            		}
            		return ttext;
            	}
            }

            let myCurTab = 1

            while (true) {
                if (myCurTab > gAppURLs.length) {
                    try {
                        myDlgResult = kApp.displayDialog(tablist(gAppURLs, myCurTab), {
                            withTitle: kStepTitle,
                            withIcon: kEpiIcon,
                            defaultAnswer: kAppDefaultURL,
                            buttons: ["Add", "Done (Don't Add)", "Back"],
                            defaultButton: 1,
                            cancelButton: 3
                        });
                    } catch(myErr) {
                        if (myErr.errorNumber == -128) {
                            // Back button
                            myDlgResult = "Back";
                        } else {
                            throw myErr;
                        }
                    }

					if (myDlgResult == "Back") {
                        if (myCurTab == 1) {
                            myCurTab = 0;
							break;
						} else {
                            myCurTab--;
						}
					} else if (myDlgResult.buttonReturned == "Add") {

                        // add the current text to the end of the list of URLs
						gAppURLs.push(myDlgResult.textReturned);
						myCurTab++;
					} else { // "Done (Don't Add)"
						// we're done, don't add the current text to the list
						break;
					}
				} else {

					let myBackButton = false;

					if (myCurTab == 1) {
						try {
							myDlgResult = kApp.displayDialog(tablist(gAppURLs, myCurTab), {
                                withTitle: kStepTitle,
                                withIcon: kEpiIcon,
                                defaultAnswer: gAppURLs[myCurTab-1],
                                buttons: ["Next", "Remove", "Back"],
                                defaultButton: 1,
                                cancelButton: 3
                            });
                        } catch(myErr) {
                            if (myErr.errorNumber == -128) {
                                // Back button
                                myBackButton = true;
                            } else {
                                throw myErr;
                            }
                        }
					} else {
						myDlgResult = kApp.displayDialog(tablist(gAppURLs, myCurTab), {
                            withTitle: kStepTitle,
                            withIcon: kEpiIcon,
                            defaultAnswer: gAppURLs[myCurTab-1],
                            buttons: ["Next", "Remove", "Previous"],
                            defaultButton: 1
                        });
					}

					if (myBackButton || (myDlgResult.buttonReturned == "Previous")) {
                        if (myBackButton) {
                            myCurTab = 0;
							break;
						} else {
							gAppURLs[myCurTab-1] = myDlgResult.textReturned;
							myCurTab--;
                        }
                    } else if (myDlgResult.buttonReturned == "Next") {
						gAppURLs[myCurTab-1] = myDlgResult.textReturned;
						myCurTab++;
					} else { // "Remove"
						if (myCurTab == 1) {
							gAppURLs.shift();
						} else if (myCurTab == gAppURLs.length) {
                            gAppURLs.pop();
							myCurTab--;
						} else {
							gAppURLs.splice(myCurTab-1, 1);
                        }
                    }
                }
            }

			if (myCurTab == 0) {
				// we hit the back button
				return aStepNum - 1;
            }
		}


    } else if (aStepNum == kStepBROWSER) {

		// STEP 5: REGISTER AS BROWSER?

		try {
            gAppRegisterBrowser = kApp.displayDialog("Register app as a browser?", {
                withTitle: kStepTitle,
                withIcon: kEpiIcon,
                buttons: ["No", "Yes", "Back"],
                defaultButton: gAppRegisterBrowser,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return aStepNum - 1;
            } else {
                throw myErr;
            }
        }


    } else if (aStepNum == kStepICON) {

        // STEP 6: SELECT ICON FILE

		try {
            gAppCustomIcon = kApp.displayDialog("Do you want to provide a custom icon?", {
                withTitle: kStepTitle,
                withIcon: kEpiIcon,
                buttons: ["Yes", "No", "Back"],
                defaultButton: gAppCustomIcon,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return aStepNum - 1;
            } else {
                throw myErr;
            }
        }

        if (gAppCustomIcon == "Yes") {

            // CHOOSE AN APP ICON

            // show file selection dialog
			try {
				if (gEpiLastIconDir) {
                    try {
                        gAppIconSrc = kApp.chooseFile({
                            withPrompt: kIconPrompt,
                            ofType: kIconTypes,
                            invisibles: false,
                            defaultLocation: gEpiLastIconDir
                        }).toString();
                    } catch(myErr) {
                        if (myErr.errorNumber == -1700) {
                            // bad defaultLocation, so try this again with none
                            gEpiLastIconDir = '';
                        } else {
                            throw myErr;
                        }
                    }
                }
                if (! gEpiLastIconDir) {
                    gAppIconSrc = kApp.chooseFile({
                        withPrompt: kIconPrompt,
                        ofType: kIconTypes,
                        invisibles: false
                    }).toString();
                }
            } catch(myErr) {
                if (myErr.errorNumber == -128) {
                    // canceled: ask about a custom icon again
                    return aStepNum;
                } else {
                    throw myErr;
                }
            }

			// set up custom icon info

			// break down the path & canonicalize icon name
            let myIconPathInfo = getPathInfo(gAppIconSrc, false);

			gEpiLastIconDir = myIconPathInfo.dir;
			gAppIconName = myIconPathInfo.base;

        } else {
            // no custom icon
            gAppIconSrc = '';
        }


    } else if (aStepNum == kStepENGINE) {

        // STEP 7: SELECT ENGINE

        // initialize engine choice buttons
		if (gAppEngineType.startsWith("external")) {
            gAppEngineButton = kEngineInfo.external.buttonName;
		} else {
            gAppEngineButton = kEngineInfo.internal.buttonName;
        }

        try {
            gAppEngineButton = kApp.displayDialog("Use built-in app engine, or external browser engine?\n\nNOTE: If you don't know what this question means, choose Built-In.\n\nIn almost all cases, using the built-in engine will result in a more functional app. Using an external browser engine has several disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.\n\nThe main reason to choose the external browser engine is if your app must run on a signed browser (for things like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension).", {
                withTitle: kStepTitle,
                withIcon: kEpiIcon,
                buttons: [kEngineInfo.internal.buttonName, kEngineInfo.external.buttonName, "Back"],
                defaultButton: gAppEngineButton,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return aStepNum - 1;
            } else {
                throw myErr;
            }
        }

		// set app engine
		if (gAppEngineButton == kEngineInfo.external.buttonName) {
            gAppEngineType = kEngineInfo.external.id;
		} else {
            gAppEngineType = kEngineInfo.internal.id;
        }


    } else if (aStepNum == kStepBUILD) {

        // STEP 8: CREATE APPLICATION

        // create summary of the app
        let myAppSummary = "Ready to create!\n\nApp: " + gAppName +
            "\n\nMenubar Name: " + gAppShortName +
            "\n\nPath: " + gAppDir + "\n\n";
        if (gAppStyle == "App Window") {
            myAppSummary += "Style: App Window\n\nURL: " + gAppURLs[0];
		} else {
			myAppSummary += "Style: Browser Tabs\n\nTabs: ";
			if (gAppURLs.length == 0) {
				myAppSummary += "<none>";
			} else {

				for (let t of gAppURLs) {
					myAppSummary += "\n  -  " + t;
                }
            }
        }
        myAppSummary += "\n\nRegister as Browser: " + gAppRegisterBrowser + "\n\nIcon: ";
		if (!gAppIconSrc) {
			myAppSummary += "<default>";
		} else {
			myAppSummary += gAppIconName;
		}
		myAppSummary += "\n\nApp Engine: " + gAppEngineButton;

		// set up app command line
		let myAppCmdLine = "";
		if (gAppStyle == "App Window") {
			myAppCmdLine = quotedForm("--app=" + gAppURLs[0]);
		} else if (gAppURLs.length > 0) {
            for (let t of gAppURLs) {
                myAppCmdLine += " " + quotedForm(t);
            }
        }

		// display summary
        try {
            kApp.displayDialog(myAppSummary, {
                withTitle: kStepTitle,
                withIcon: kEpiIcon,
                buttons: ["Create", "Back"],
                defaultButton: 1,
                cancelButton: 2
            });
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return aStepNum - 1;
            } else {
                throw myErr;
            }
        }


        // CREATE THE APP

        Progress.totalUnitCount = 2;
        Progress.completedUnitCount = 1;
        Progress.description = "Building app...";
        Progress.additionalDescription = "This may take up to 30 seconds. The progress bar will not advance.";

        // this somehow allows the progress bar to appear
        delay(0.1);

        try {
            kApp.doShellScript(kEpichromeScript + ' ' +
                gScriptLogVar + ' ' +
                "'epiAction=build' " +
                quotedForm('myAppPath=' + gAppPath) + ' ' +
                quotedForm('CFBundleDisplayName=' + gAppNameBase) + ' ' +
                quotedForm('CFBundleName=' + gAppShortName) + ' ' +
                quotedForm('SSBCustomIcon=' + gAppCustomIcon) + ' ' +
                quotedForm('myIconSource=' + gAppIconSrc) + ' ' +
                quotedForm('SSBRegisterBrowser=' + gAppRegisterBrowser) + ' ' +
                quotedForm('SSBEngineType=' + gAppEngineType) + ' ' +
                "'SSBCommandLine=('" + myAppCmdLine + "')'");

                Progress.completedUnitCount = 2;
                Progress.description = "Build complete.";
                Progress.additionalDescription = "";

        } catch(myErr) {

            if (myErr.errorNumber == -128) {
                // progress bar Stop button
                // Progress.completedUnitCount = 0;
                // Progress.description = "Build canceled.";
                // Progress.additionalDescription = "";
                //
                // myDlgResult = kApp.displayDialog("Build canceled.", {
                //     withTitle: "Application Not Created",
                //     withIcon: kEpiIcon,
                //     buttons: ["Back", "Quit"],
                //     defaultButton: 1
                // }).buttonReturned;
                // if (myDlgResult == "Back") {
                    Progress.completedUnitCount = 0;
                    Progress.description = "Configuring app...";
                    Progress.additionalDescription = "";
                    return aStepNum;
                // } else {
                //     return false;
                // }
            }

            Progress.completedUnitCount = 0;
            Progress.description = "Build failed.";
            Progress.additionalDescription = "";

            myErr = myErr.message;

            // unable to create app due to permissions
            if (myErr == "PERMISSION") {
                myErr = "Unable to write to \"" + gAppDir + "\".";
            }

			// show error dialog & quit or go back
			return {
                message:"Creation failed: " + myErr,
                title: "Application Not Created",
                backStep: aStepNum - 1,
                resetProgress: true
            };
        }

        // SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
        try {
            myDlgResult = false;
            myDlgResult = kApp.displayDialog("Created Epichrome app \"" + gAppNameBase + "\".\n\nIMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it.", {
                withTitle: "Success!",
                withIcon: kEpiIcon,
                buttons: ["Launch Now", "Reveal in Finder", "Quit"],
                defaultButton: 1,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            // if (myErr.errorNumber == -128) {
            //     // Back button
            //     return false; // quit
            // } else {
            //     throw myErr;
            // }
        }

        // launch or reveal
        if (myDlgResult == "Launch Now") {
            delay(1);
            try {
                kApp.doShellScript("/usr/bin/open " + quotedForm(gAppPath));
            } catch(myErr) {
                // do I want some error reporting? /usr/bin/open is unreliable with errors
            }
        } else if (myDlgResult == "Reveal in Finder") {
            kFinder.select(Path(gAppPath));
            kFinder.activate();
		}

        return false;  // quit
    } else {

        // UNKNOWN STEP
        return {
            message:"Encountered unknown step " + aStepNum.toString() +
                ". Please post an issue on GitHub.",
            title: "Fatal Error",
            backStep: false
        };
    }

	// if we got here, assume success and move on
    return aStepNum + 1;
}


// --- MAIN BODY ---

// read in persistent properties
readProperties();

// check GitHub for updates to Epichrome
checkForUpdate();


// RUN THE STEPS TO BUILD THE APP

let myNextStep = 1;

while (true) {

    // ensure minimum step number
    if (myNextStep < 1) { myNextStep = 1; }

	// RUN THE NEXT STEP

	myNextStep = doStep(myNextStep);


    // CHECK RESULT OF STEP

    if (typeof(myNextStep) == 'number') {

        // FORWARD OR BACK: MOVE ON TO ANOTHER STEP

        continue;

    } else if (typeof(myNextStep) == 'object') {

		// ERROR: SHOW DIALOG

        // always show Quit button
        let myDlgButtons = ["Quit"];

        // show View Log option if there's a log
        if (kFinder.exists(Path(gLogFile))) {
			myDlgButtons.push("View Log & Quit");
		}

        // display dialog
        let myDlgResult;

        if (myNextStep.backStep !== false) {

            // show Back button too
            myDlgButtons.unshift("Back");

            // dialog with Back button
            try {
                myDlgResult = kApp.displayDialog(myNextStep.message, {
                    withTitle: myNextStep.title,
                    withIcon: 'stop',
                    buttons: myDlgButtons,
                    defaultButton: 1
                }).buttonReturned;
            } catch(myErr) {
                if (myErr.errorNumber == -128) {
                    // Back button
                    myDlgResult = myDlgButtons[0];
                } else {
                    throw myErr;
                }
            }

            // handle dialog result
            if (myDlgResult == myDlgButtons[0]) {
                if (myNextStep.resetProgress) {
                    Progress.completedUnitCount = 0;
                    Progress.description = "Configuring app...";
                    Progress.additionalDescription = "";
                }
                myNextStep = myNextStep.backStep;
                continue;
            } else {
                // remove Back button again
                myDlgButtons.shift();
            }
        } else {

            // dialog with no Back button
            myDlgResult = kApp.displayDialog(myNextStep.message, {
                withTitle: myNextStep.title,
                withIcon: 'stop',
                buttons: myDlgButtons,
                defaultButton: 1
            }).buttonReturned;
        }

        // if user didn't click Quit, then try to show the log
        if (myDlgResult != myDlgResult.slice(-1)) {
            kFinder.select(Path(gLogFile));
            kFinder.activate();
        }
    }

    // QUIT

    writeProperties();
    break; // QUIT
}
