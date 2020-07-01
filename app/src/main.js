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

// SHELLQUOTE: assemble a list of arguments into a shell string
function shellQuote(...aArgs) {
    let result = [];
    for (let s of aArgs) {
        result.push("'" + s.replace(/'/g, "'\\''") + "'");
    }
    return result.join(' ');
}


// SHELL: execute a shell script given a list of arguments
function shell(...aArgs) {
    return kApp.doShellScript(shellQuote.apply(null, aArgs));
}


// VCMP: compare version numbers
//         return -1 if v1 <  v2
//         return  0 if v1 == v2
//         return  1 if v1 >  v2
function vcmp (v1, v2) {

    // regex for pulling out version parts
    const vRe='^0*([0-9]+)\\.0*([0-9]+)\\.0*([0-9]+)(b0*([0-9]+))?(\\[0*([0-9]+)])?$';

    // array for comparable version integers
    var vStr = [];

    // munge version numbers into comparable integers
    for (const curV of [ v1, v2 ]) {

        let vmaj, vmin, vbug, vbeta, vbuild;

        const curMatch = curV.match(vRe);

        if (curMatch) {

            // extract version number parts
            vmaj   = parseInt(curMatch[1]);
            vmin   = parseInt(curMatch[2]);
            vbug   = parseInt(curMatch[3]);
            vbeta  = (curMatch[5] ? parseInt(curMatch[5]) : 1000);
            vbuild = (curMatch[7] ? parseInt(curMatch[7]) : 10000);
        } else {

            // unable to parse version number
            console.log('Unable to parse version "' + curV + '"');
            vmaj = vmin = vbug = vbeta = vbuild = 0;
        }

        // add to array
        vStr.push(vmaj.toString().padStart(3,'0')+'.'+
                  vmin.toString().padStart(3,'0')+'.'+
                  vbug.toString().padStart(3,'0')+'.'+
                  vbeta.toString().padStart(4,'0')+'.'+
                  vbuild.toString().padStart(5,'0'));
    }

    // compare version strings
    if (vStr[0] < vStr[1]) {
        return -1;
    } else if (vStr[0] > vStr[1]) {
        return 1;
    } else {
        return 0;
    }
}


// CONSTANTS

// app defaults & settings
const kPromptNameLoc = "Select name and location for the app.";
const kWinStyleApp = 'App Window';
const kWinStyleBrowser = 'Browser Tabs';
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
const kEpichromeScript = kApp.pathToResource("epichrome.sh", {
    inDirectory:"Scripts" }).toString();

// app resources
const kEpiIcon = kApp.pathToResource("droplet.icns");

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
        coreOutput = shell(kEpichromeScript,
            'coreDoInit=1',
            'epiAction=init').split("\r");

        // make sure we get 2 lines of output
        if (coreOutput.length != 2) { throw('Unexpected output.'); }

        // parse output lines
        gDataPath = coreOutput[0];
        gLogFile = coreOutput[1];
        gScriptLogVar = "myLogFile=" + gLogFile;

        // check that the data path is writeable
        coreOutput = kApp.doShellScript("if [[ ! -w " + shellQuote(gDataPath) + " ]] ; then echo FAIL ; fi");
        if (coreOutput == 'FAIL') { throw('Application data folder is not writeable.'); }

    } catch(myErr) {
        kApp.displayDialog("Error initializing core: " + myErr.message, {
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
    shell(kEpichromeScript,
        gScriptLogVar,
        'epiAction=log',
        'epiLogType=' + aType,
        'epiLogMsg=' + aMsg);
}

// DEBUGLOG -- log a debugging message
function debuglog(aMsg) {
    errlog(aMsg, 'DEBUG');
}


// SETTINGS FILE

const kSettingsFile = gDataPath + "/epichrome.plist";


// EPICHROME STATE

let gEpiLastIconDir = "";
let gEpiLastAppDir = "";
let gEpiUpdateCheckDate = new Date(kApp.currentDate() - (1 * kDay));
let gEpiUpdateCheckVersion = "";


// NEW APP DEFAULTS

let gAppInfoDefault = {
    displayName: 'My Epichrome App',
    shortName: false,
    windowStyle: kWinStyleApp,
    urls: [],
    registerBrowser: 'No',
    customIcon: 'Yes',
    engineTypeID: kEngineInfo.internal.id
};


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
                value:gAppInfoDefault.windowStyle
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"doRegisterBrowser",
                value:gAppInfoDefault.registerBrowser
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"doCustomIcon",
                value:gAppInfoDefault.customIcon
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"appEngineType",
                value:gAppInfoDefault.engineTypeID
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
    //     gAppInfoDefault.windowStyle = myProperties["appStyle"];
    // }

    let myYesNoRegex=/^(Yes|No)$/;

	// doRegisterBrowser
	if (myYesNoRegex.test(myProperties["doRegisterBrowser"])) {
        gAppInfoDefault.registerBrowser = myProperties["doRegisterBrowser"];
    }

	// doCustomIcon
	if (myYesNoRegex.test(myProperties["doCustomIcon"])) {
        gAppInfoDefault.customIcon = myProperties["doCustomIcon"];
    }

	// appEngineType
	// if (myProperties["appEngineType"]) {
    //     gAppInfoDefault.engineTypeID = myProperties["appEngineType"];
    //     if (gAppInfoDefault.engineTypeID.startsWith("external") {
    //         gAppInfoDefault.engineTypeID = kEngineInfo.external.id;
    //     } else {
    //         gAppInfoDefault.engineTypeID = kEngineInfo.internal.id;
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
            myUpdateCheckResult = shell(kEpichromeScript,
                gScriptLogVar,
                'epiAction=updatecheck',
                'epiUpdateCheckVersion=' + gEpiUpdateCheckVersion,
                'epiVersion=' + kVersion).split('\r');
        } catch(myErr) {
            myUpdateCheckResult = ["ERROR", myErr.message];
        }

        // parse update check results

        if (myUpdateCheckResult[0] == "MYVERSION") {
            // updateCheckVersion is older than the current version, so update it
            gEpiUpdateCheckVersion = kVersion;
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


// GETPATHINFO: break down an app or icon path
function getPathInfo(aPath, aAppInfo) {

    let myResult = {};

    // the input path must be fully-qualified
    let myMatch = aPath.match('^((/([^/]+/+)*[^/]+)/+)([^/]+)/*$');

    if (myMatch) {

        myResult = {

            // path: full path including item
            path: aPath,

            // dir: directory containing item
            dir: myMatch[2],

            // name: name of item (including any extension)
            name: myMatch[4]
        };

        // if we were given an appInfo object, add result to it
        if (aAppInfo) {
            aAppInfo.file = myResult;
        }

    } else {
        return null;
    }

    if (aAppInfo) {

        // remove any .app extension
        myMatch = aAppInfo.file.name.match(/^(.+)\.app$/i);
        if (myMatch) {
            aAppInfo.file.base = myMatch[1];
            aAppInfo.file.extAdded = false;
        } else {
            aAppInfo.file.base = aAppInfo.file.name;
            aAppInfo.file.extAdded = true;
        }

        // add canonical .app extension to base name
        aAppInfo.file.name = aAppInfo.file.base + '.app';


        // CREATE DISPLAY NAME & DEFAULT SHORTNAME

        // set display name from file basename
        aAppInfo.displayName = aAppInfo.file.base;

        // start short name with display name
        let myShortNameTemp;
        aAppInfo.shortName = aAppInfo.displayName;

        // too long -- remove all non-alphanumerics
        if (aAppInfo.shortName.length > 16) {
            myShortNameTemp = aAppInfo.shortName.replace(/[^0-9a-z]/gi, '');
            if (myShortNameTemp.length > 0) {
                // still some name left, so we'll use it
                aAppInfo.shortName = myShortNameTemp;
            }
        }

        // still too long -- remove all lowercase vowels
        if (aAppInfo.shortName.length > 16) {
            myShortNameTemp = aAppInfo.shortName.replace(/[aeiou]/g, '');
            if (myShortNameTemp.length > 0) {
                // still some name left, so we'll use it
                aAppInfo.shortName = myShortNameTemp;
            }
        }

        // still still too long -- truncate
        if (aAppInfo.shortName.length > 16) {
            aAppInfo.shortName = aAppInfo.shortName.slice(0, 16);
        }

        // canonicalize app path
        aAppInfo.file.path = aAppInfo.file.dir + '/' + aAppInfo.file.name;
    }

    return myResult;
}


// OPENDOCUMENTS: handler function for files dropped on the app
function openDocuments(aApps) {

    let myDlgResult;
    let myApps = [];

    for (let curAppPath of aApps) {

        // get path to app as string
        curAppPath = curAppPath.toString();

        // break down path into components
        let curAppFileInfo = getPathInfo(curAppPath);

        // app object
        let curApp = {};

        try {

            // run core script to initialize
            curApp.appInfo = JSON.parse(shell(kEpichromeScript,
                'epiAction=read',
                'epiAppPath=' + curApp
            ));

            // add in app file info
            curApp.appInfo.file = curAppFileInfo;

            // determine app window style and get URL list
            if (curApp.appInfo.commandLine[0] &&
                (curApp.appInfo.commandLine[0].startsWith('--app='))) {
                curApp.appInfo.windowStyle = kWinStyleApp;
                curApp.appInfo.urls = [ curApp.appInfo.commandLine[0].slice(6) ];
            } else {
                curApp.appInfo.windowStyle = kWinStyleBrowser;
                curApp.appInfo.urls = curApp.appInfo.commandLine;
            }
            delete curApp.appInfo.commandLine;

            // set dialog icon
            curApp.icon = (curApp.appInfo.appIconPath ?
                Path(curApp.appInfo.appIconPath) : kEpiIcon);

            //     titlePrefix: 'Editing ' + curApp.appInfo.file.base,

            // add to list of apps to process
            myApps.push(curApp);

        } catch(myErr) {
            kApp.displayDialog(myErr.message, {
                withTitle: 'Error',
                withIcon: 'stop',
                buttons: ["OK"],
                defaultButton: 1
            });
            continue;
        }
    }

    let myHasUpdates = false;
    let myAppList = [];
    for (let curApp in myApps) {

        let curAppText = curApp.appInfo.file.name;

        if (vcmp(curApp.appInfo.version, kVersion) < 0) {
            myHasUpdates = true;
            curApp.update = true;
            curAppText = kDotNeedsUpdate + ' ' + curAppText + '(' + curApp.appInfo.version + ')';
        } else {
            curAppText = kDotCurrent + ' ' + curAppText;
        }
    }

    // by default, edit apps
    let myDoEdit = true;

    // if any apps need updating, give option to only update
    if (myHasUpdates) {

        // set up dialog text & buttons depending if one or multiple apps
        let myDlgText, myBtnEdit, myBtnUpdate;
        if (myApps.length == 1) {
            myDlgText = '';
            myBtnEdit = 'Edit';
            myBtnUpdate = 'Update';
        } else {
            myDlgText = "You've selected at least one app with an older version (marked " + kDotNeedsUpdate + "). Edit and update all selected apps, or just update the " + kDotNeedsUpdate + " apps?\n\n" + myAppList.join('\n');
            myBtnEdit = 'Edit All';
            myBtnUpdate = 'Update ' + kDotNeedsUpdate;
        }

        try {
            myDlgResult = kApp.displayDialog(myDlgText, {
                withTitle: 'Choose Action',
                withIcon: kEpiIcon,
                buttons: [myBtnEdit, myBtnUpdate + kDotNeedsUpdate, "Quit"],
                defaultButton: 1,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                //  $$$$ hANDLE THIS
                freakout;
            } else {
                // some other dialog error
                throw myErr;
            }
        }

        if (myDlgResult != myBtnEdit) {
            // $$$ just run edit script with no dialogs
            myDoEdit = false;
        }
    }


    // RUN EDIT STEPS

    for (let curApp in myApps) {

        let myResult = true;

        if (myDoEdit) {
            myResult = doSteps(curApp, steps);
        }

        if (myResult) {
            // run update

        } else if (myResult == 'SKIPTHISAPP') {
            setsomestate;
            continue;
        }
    }


    // handle success or failure
    if (backedout) {
        confirmquit;
    } else {
        //show summary of success & failure
    }
}


// --- BUILD STEPS ---

// STEPDISPLAYNAME: step function to get display name and app path
function stepDisplayName(aInfo) {

    // status variables
	let myTryAgain, myErr;

    // CHOOSE WHERE TO SAVE THE APP

    myTryAgain = true;

    while (myTryAgain) {

        myTryAgain = false; // assume we'll succeed

        let myAppPath;

        // show file selection dialog
        try {
            if (gEpiLastAppDir) {
                try {
                    myAppPath = kApp.chooseFileName({
                        withPrompt: aInfo.stepInfo.numText + ': ' + kPromptNameLoc,
                        defaultName: aInfo.appInfo.displayName,
                        defaultLocation: gEpiLastAppDir
                    }).toString();
                } catch(myErr) {

                    if (myErr.errorNumber == -1700) {
                        // bad defaultLocation, so try this again
                        gEpiLastAppDir = '';
                        myTryAgain = true;
                        continue;
                    } else {
                        // hand off to enclosing try
                        throw myErr;
                    }
                }
            } else {
                myAppPath = kApp.chooseFileName({
                    withPrompt: kPromptNameLoc,
                    defaultName: aInfo.appInfo.displayName
                }).toString();
            }
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                return -1;
            } else {
                throw myErr;
            }
        }

        // break down the path & canonicalize app name
        let myOldFile = aInfo.appInfo.file;
        let myOldShortName = aInfo.appInfo.shortName;
        if (!getPathInfo(myAppPath.toString(), aInfo.appInfo)) {
            return {
                message: "Unable to parse app path.",
                title: "Error",
                backStep: false
            };
        }

        // if path hasn't changed & we already have a short name, use that
        if (myOldShortName && myOldFile &&
            (myOldFile.path == aInfo.appInfo.file.path)) {
            aInfo.appInfo.shortName = myOldShortName;
        }

        // update the last path info
        gEpiLastAppDir = aInfo.appInfo.file.dir;

        // check if we have permission to write to this directory
        if (kApp.doShellScript("if [[ -w " + shellQuote(aInfo.appInfo.file.dir) + " ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") != "Yes") {
            kApp.displayDialog("You don't have permission to write to that folder. Please choose another location for your app.", {
                withTitle: "Error",
                withIcon: 'stop',
                buttons: ["OK"],
                defaultButton: 1
            });
            myTryAgain = true;
            continue;
        } else {

            // if no ".app" extension was given, check if they accidentally
            // chose an existing app without confirming
            if (aInfo.appInfo.file.extAdded) {

                // see if an app with the given base name exists
                if (kApp.doShellScript("if [[ -e " + shellQuote(aInfo.appInfo.file.path) + " ]] ; then echo \"Yes\" ; else echo \"No\" ; fi") == "Yes") {
                    try {
                        kApp.displayDialog("A file or folder named \"" + aInfo.appInfo.file.name + "\" already exists. Do you want to replace it?", {
                            withTitle: "File Exists",
                            withIcon: 'caution',
                            buttons: ["Cancel", "Replace"],
                            defaultButton: 1,
                            cancelButton: 1
                        });
                    } catch(myErr) {
                        if (myErr.errorNumber == -128) {
                            myTryAgain = true;
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

    // if we got here, assume success and move on
    return 1;
}


// STEPSHORTNAME: step function for setting app short name
function stepShortName(aInfo) {

    // status variables
    let myTryAgain, myErr, myDlgResult;

    let myAppShortNamePrompt = "Enter the app name that should appear in the menu bar (16 characters or less).";

    myTryAgain = true;

    while (myTryAgain) {

        // assume success
        myTryAgain = false;

        try {
            myDlgResult = kApp.displayDialog(myAppShortNamePrompt, {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: kEpiIcon,
                defaultAnswer: aInfo.appInfo.shortName,
                buttons: ['OK', aInfo.stepInfo.backButton],
                defaultButton: 1,
                cancelButton: 2
            }).textReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return -1;
            } else {
                throw myErr;
            }
        }

        if (myDlgResult.length > 16) {
            myTryAgain = true;
            myAppShortNamePrompt = "That name is too long. Please limit the name to 16 characters or less.";
            aInfo.appInfo.shortName = myDlgResult.slice(0, 16);
        } else if (myDlgResult.length == 0) {
            myTryAgain = true;
            myAppShortNamePrompt = "No name entered. Please try again.";
        }
    }

    // if we got here, we have a good name
    aInfo.appInfo.shortName = myDlgResult;

    // move on
    return 1;
}


// STEPWINSTYLE: step function for setting app window style
function stepWinStyle(aInfo) {

    // status variables
	let myErr;

    try {
        aInfo.appInfo.windowStyle = kApp.displayDialog("Choose App Style:\n\nAPP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)\n\nBROWSER TABS - The app will display a full browser window with the given tabs.", {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: kEpiIcon,
            buttons: [kWinStyleApp, kWinStyleBrowser, "Back"],
            defaultButton: aInfo.appInfo.windowStyle,
            cancelButton: 3
        }).buttonReturned;

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // move on
    return 1;
}


// STEPURLS: step function for setting app URLs
function stepURLs(aInfo) {

    // status variables
    let myErr, myDlgResult;

    // initialize URL list
    if ((aInfo.appInfo.urls.length == 0) && (aInfo.appInfo.windowStyle == kWinStyleApp)) {
        aInfo.appInfo.urls.push(kAppDefaultURL);
    }

    if (aInfo.appInfo.windowStyle == kWinStyleApp) {

        // APP WINDOW STYLE

        try {
            aInfo.appInfo.urls[0] = kApp.displayDialog("Choose URL:", {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: kEpiIcon,
                defaultAnswer: aInfo.appInfo.urls[0],
                buttons: ["OK", "Back"],
                defaultButton: 1,
                cancelButton: 2
            }).textReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return -1;
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
            if (myCurTab > aInfo.appInfo.urls.length) {
                try {
                    myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab), {
                        withTitle: aInfo.stepInfo.dlgTitle,
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
                    aInfo.appInfo.urls.push(myDlgResult.textReturned);
                    myCurTab++;
                } else { // "Done (Don't Add)"
                    // we're done, don't add the current text to the list
                    break;
                }
            } else {

                let myBackButton = false;

                if (myCurTab == 1) {
                    try {
                        myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab), {
                            withTitle: aInfo.stepInfo.dlgTitle,
                            withIcon: kEpiIcon,
                            defaultAnswer: aInfo.appInfo.urls[myCurTab-1],
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
                    myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab), {
                        withTitle: aInfo.stepInfo.dlgTitle,
                        withIcon: kEpiIcon,
                        defaultAnswer: aInfo.appInfo.urls[myCurTab-1],
                        buttons: ["Next", "Remove", "Previous"],
                        defaultButton: 1
                    });
                }

                if (myBackButton || (myDlgResult.buttonReturned == "Previous")) {
                    if (myBackButton) {
                        myCurTab = 0;
                        break;
                    } else {
                        aInfo.appInfo.urls[myCurTab-1] = myDlgResult.textReturned;
                        myCurTab--;
                    }
                } else if (myDlgResult.buttonReturned == "Next") {
                    aInfo.appInfo.urls[myCurTab-1] = myDlgResult.textReturned;
                    myCurTab++;
                } else { // "Remove"
                    if (myCurTab == 1) {
                        aInfo.appInfo.urls.shift();
                    } else if (myCurTab == aInfo.appInfo.urls.length) {
                        aInfo.appInfo.urls.pop();
                        myCurTab--;
                    } else {
                        aInfo.appInfo.urls.splice(myCurTab-1, 1);
                    }
                }
            }
        }

        if (myCurTab == 0) {
            // we hit the back button
            return -1;
        }
    }

    // move on
    return 1;
}


// STEPBROWSER: step to determine if app should register as a browser
function stepBrowser(aInfo) {

    // status variables
	let myErr;

    // STEP 5: REGISTER AS BROWSER?

    try {
        aInfo.appInfo.registerBrowser = kApp.displayDialog("Register app as a browser?", {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: kEpiIcon,
            buttons: ["No", "Yes", "Back"],
            defaultButton: aInfo.appInfo.registerBrowser,
            cancelButton: 3
        }).buttonReturned;
    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // move on
    return 1;
}


// STEPICON: step function to determine custom icon
function stepIcon(aInfo) {

    // status variables
	let myErr;

    try {
        aInfo.appInfo.customIcon = kApp.displayDialog("Do you want to provide a custom icon?", {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: kEpiIcon,
            buttons: ["Yes", "No", "Back"],
            defaultButton: aInfo.appInfo.customIcon,
            cancelButton: 3
        }).buttonReturned;
    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    if (aInfo.appInfo.customIcon == "Yes") {

        // CHOOSE AN APP ICON

        let myIconSourcePath;

        // show file selection dialog
        try {
            if (gEpiLastIconDir) {
                try {
                    myIconSourcePath = kApp.chooseFile({
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
                myIconSourcePath = kApp.chooseFile({
                    withPrompt: kIconPrompt,
                    ofType: kIconTypes,
                    invisibles: false
                }).toString();
            }
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // canceled: ask about a custom icon again
                return 0;
            } else {
                throw myErr;
            }
        }

        // set up custom icon info

        // break down the path & canonicalize icon name
        aInfo.appInfo.iconSource = getPathInfo(myIconSourcePath);

        // save icon directory as default
        gEpiLastIconDir = aInfo.appInfo.iconSource.dir;

    } else {

        // no custom icon
        aInfo.appInfo.iconSource = { path: '' };

    }

    // move on
    return 1;
}


// STEPENGINE: step function to set app engine
function stepEngine(aInfo) {

    // status variables
	let myErr;

    // initialize engine choice buttons
    if (aInfo.appInfo.engineTypeID.startsWith("external")) {
        aInfo.appInfo.engineTypeButton = kEngineInfo.external.buttonName;
    } else {
        aInfo.appInfo.engineTypeButton = kEngineInfo.internal.buttonName;
    }

    try {
        aInfo.appInfo.engineTypeButton = kApp.displayDialog("Use built-in app engine, or external browser engine?\n\nNOTE: If you don't know what this question means, choose Built-In.\n\nIn almost all cases, using the built-in engine will result in a more functional app. Using an external browser engine has several disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.\n\nThe main reason to choose the external browser engine is if your app must run on a signed browser (for things like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension).", {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: kEpiIcon,
            buttons: [kEngineInfo.internal.buttonName, kEngineInfo.external.buttonName, "Back"],
            defaultButton: aInfo.appInfo.engineTypeButton,
            cancelButton: 3
        }).buttonReturned;
    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // set app engine
    if (aInfo.appInfo.engineTypeButton == kEngineInfo.external.buttonName) {
        aInfo.appInfo.engineTypeID = kEngineInfo.external.id;
    } else {
        aInfo.appInfo.engineTypeID = kEngineInfo.internal.id;
    }

    // move on
    return 1;
}


// STEPBUILD: step function to build app
function stepBuild(aInfo) {

    // status variables
    let myErr, myDlgResult;

    // create summary of the app
    let myAppSummary = "Ready to create!\n\nApp: " + aInfo.appInfo.file.name +
        "\n\nMenubar Name: " + aInfo.appInfo.shortName +
        "\n\nPath: " + aInfo.appInfo.file.dir + "\n\n";
    if (aInfo.appInfo.windowStyle == kWinStyleApp) {
        myAppSummary += "Style: App Window\n\nURL: " + aInfo.appInfo.urls[0];
    } else {
        myAppSummary += "Style: Browser Tabs\n\nTabs: ";
        if (aInfo.appInfo.urls.length == 0) {
            myAppSummary += "<none>";
        } else {

            for (let t of aInfo.appInfo.urls) {
                myAppSummary += "\n  -  " + t;
            }
        }
    }
    myAppSummary += "\n\nRegister as Browser: " + aInfo.appInfo.registerBrowser + "\n\nIcon: ";
    if (!aInfo.appInfo.iconSource) {
        myAppSummary += "<default>";
    } else {
        myAppSummary += aInfo.appInfo.iconSource.name;
    }
    myAppSummary += "\n\nApp Engine: " + aInfo.appInfo.engineTypeButton;

    // set up app command line
    let myAppCmdLine = [];
    if (aInfo.appInfo.windowStyle == kWinStyleApp) {
        myAppCmdLine.push('--app=' + aInfo.appInfo.urls[0]);
    } else if (aInfo.appInfo.urls.length > 0) {
        myAppCmdLine = aInfo.appInfo.urls;
    }

    // display summary
    try {
        kApp.displayDialog(myAppSummary, {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: kEpiIcon,
            buttons: ["Create", "Back"],
            defaultButton: 1,
            cancelButton: 2
        });
    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }


    // CREATE THE APP

    try {

        Progress.totalUnitCount = 2;
        Progress.completedUnitCount = 1;
        Progress.description = "Building app...";
        Progress.additionalDescription = "This may take up to 30 seconds. The progress bar will not advance.";

        // this somehow allows the progress bar to appear
        delay(0.1);

        shell.apply(null, Array.prototype.concat( [
            kEpichromeScript,
            gScriptLogVar,
            'epiAction=build',
            'epiAppPath=' + aInfo.appInfo.file.path,
            'CFBundleDisplayName=' + aInfo.appInfo.displayName,
            'CFBundleName=' + aInfo.appInfo.shortName,
            'SSBCustomIcon=' + aInfo.appInfo.customIcon,
            'epiIconSource=' + aInfo.appInfo.iconSource.path,
            'SSBRegisterBrowser=' + aInfo.appInfo.registerBrowser,
            'SSBEngineType=' + aInfo.appInfo.engineTypeID,
            'SSBCommandLine=(' ],
            myAppCmdLine,
            [ ')' ])
        );

        Progress.completedUnitCount = 2;
        Progress.description = "Build complete.";
        Progress.additionalDescription = "";

    } catch(myErr) {

        if (myErr.errorNumber == -128) {
            Progress.completedUnitCount = 0;
            Progress.description = "Configuring app...";
            Progress.additionalDescription = "";
            return 0;
        }

        Progress.completedUnitCount = 0;
        Progress.description = "Build failed.";
        Progress.additionalDescription = "";

        myErr = myErr.message;

        // unable to create app due to permissions
        if (myErr == "PERMISSION") {
            myErr = "Unable to write to \"" + aInfo.appInfo.file.dir + "\".";
        }

        // show error dialog & quit or go back
        return {
            message:"Creation failed: " + myErr,
            title: "Application Not Created",
            backStep: -1,
            resetProgress: true
        };
    }

    // SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH
    try {
        myDlgResult = false;
        myDlgResult = kApp.displayDialog("Created Epichrome app \"" + aInfo.appInfo.displayName + "\".\n\nIMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it.", {
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
            shell("/usr/bin/open", aInfo.appInfo.file.path);
        } catch(myErr) {
            // do I want some error reporting? /usr/bin/open is unreliable with errors
        }
    } else if (myDlgResult == "Reveal in Finder") {
        kFinder.select(Path(aInfo.appInfo.file.path));
        kFinder.activate();
    }

    // we're finished! quit
    return false;
}


// DOSTEPS: run a set of build or edit steps
function doSteps(aSteps, aInfo) {
    // RUN THE STEPS TO BUILD THE APP

    let myNextStep = 0;

    while (true) {

        // backed out of the first step
        if (myNextStep < 0) {
            return false;
        }

        if (myNextStep == 0) {
            aInfo.stepInfo.backButton = 'Quit';
        } else {
            // cap max step number
            myNextStep = Math.min(myNextStep, aSteps.length - 1);

            aInfo.stepInfo.backButton = 'Back';
        }

        // set step dialog title
        // change: 🔹🔸🔺
        aInfo.stepInfo.numText = 'Step ' + (myNextStep + 1).toString() +
            ' of ' + aSteps.length.toString();
        aInfo.stepInfo.dlgTitle = '(Epichrome EPIVERSION)   ' +
            aInfo.stepInfo.titlePrefix + ' | ' + aInfo.stepInfo.numText;


        // RUN THE NEXT STEP

        let myStepResult = aSteps[myNextStep](aInfo);


        // CHECK RESULT OF STEP

        if (typeof(myStepResult) == 'number') {

            // FORWARD OR BACK: MOVE ON TO ANOTHER STEP

            // move forward, backward, or stay on the same step
            myNextStep += myStepResult;

            continue;

        } else if (typeof(myStepResult) == 'object') {

            // ERROR: SHOW DIALOG

            // always show Quit button
            let myDlgButtons = ["Quit"];

            // show View Log option if there's a log
            if (kFinder.exists(Path(gLogFile))) {
                myDlgButtons.push("View Log & Quit");
            }

            // display dialog
            let myDlgResult;

            // if we're allowed to backstep & this isn't the first step
            if ((myStepResult.backStep !== false) && (myNextStep != 0)) {

                // show Back button too
                myDlgButtons.unshift('Back');

                // dialog with Back button
                try {
                    myDlgResult = kApp.displayDialog(myStepResult.message, {
                        withTitle: myStepResult.title,
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
                    if (myStepResult.resetProgress) {
                        Progress.completedUnitCount = 0;
                        Progress.description = "Configuring app...";
                        Progress.additionalDescription = "";
                    }
                    myNextStep += myStepResult.backStep;
                    continue;
                } else {
                    // remove Back button again
                    myDlgButtons.shift();
                }
            } else {

                // dialog with no Back button
                myDlgResult = kApp.displayDialog(myStepResult.message, {
                    withTitle: myStepResult.title,
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

        // done
        break;
    }

    return true;
}


// CONFIRMQUIT: confirm quit
function confirmQuit(aMessage='') {

    try {

        let myPrefix = (aMessage ? aMessage + ' ' : '');

        // confirm quit
        kApp.displayDialog(myPrefix + 'Are you sure you want to quit?', {
            withTitle: "Confirm",
            withIcon: kEpiIcon,
            buttons: ["No", "Yes"],
            defaultButton: 2,
            cancelButton: 1
        });

        return true;  // QUIT

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // quit not confirmed, so show welcome dialog again
            return false;
        } else {
            // some other dialog error
            throw myErr;
        }
    }
}


// RUN: handler for when app is run without dropped files
function run() {

    let myResult;

    // say hello
    try {

        kApp.displayDialog('Click OK to select a name and location for the app.', {
            withTitle: 'Create App',
            withIcon: kEpiIcon,
            buttons: ['OK', 'Quit'],
            defaultButton: 1,
            cancelButton: 2
        });

        myResult = true;

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            myResult = false;
        } else {
            // some other dialog error
            throw myErr;
        }
    }

    while (true) {

        if (!myResult) {

            // steps aborted before completion, so confirm first
            if (confirmQuit('The app has not been created.')) {
                break;
            }
        }

        // run new app build steps
        myResult = doSteps([
            stepDisplayName,
            stepShortName,
            stepWinStyle,
            stepURLs,
            stepBrowser,
            stepIcon,
            stepEngine,
            stepBuild
        ], {
            stepInfo: {
                titlePrefix: 'Create App',
                dlgIcon: kEpiIcon,
                isOnlyApp: true
            },
            appInfo: gAppInfoDefault
        });

        if (myResult) {
            // steps completed (or error), so quit
            break;
        }
    }

    // write properties before quitting
    writeProperties();
}


// --- MAIN BODY: functions that run first whether files are dropped or not ---

// read in persistent properties
readProperties();

// check GitHub for updates to Epichrome
checkForUpdate();
