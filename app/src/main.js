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


// HASLOGFILE: check if a log file for this run exists
function hasLogFile() {
    return kFinder.exists(Path(gLogFile));
}


// SHOWLOGFILE: reveal log file in the Finder
function showLogFile() {
    kFinder.select(Path(gLogFile));
    kFinder.activate();
}


// ENGINENAME: generate engine name from ID
function engineName(aEngine, aCapType=true) {
    let myResult;
    if (aEngine.type == 'internal') {
        myResult = 'Built-In';
    } else {
        myResult = 'External';
    }
    if (!aCapType) { myResult = myResult.toLowerCase(); }

    if (kBrowserInfo[aEngine.id]) {
        myResult += ' (' + kBrowserInfo[aEngine.id].shortName + ')';
    }
    return myResult;
}


// SETDLGICON: set the dialog icon using app info, defaulting to Epichrome icon
function setDlgIcon(aAppInfo) {

    if (aAppInfo.iconPath) {
        let myCustomIcon = Path(aAppInfo.file.path + '/' + aAppInfo.iconPath);
        if (kFinder.exists(myCustomIcon)) {
            return myCustomIcon;
        }
    }

    // if we got here, custom icon not found
    if (kFinder.exists(kEpiIcon)) {
        return kEpiIcon;
    } else {
        // fallback default
        return 'note';
    }
}


// OBJCOPY: deep copy object
function objCopy(aObj) {

  if (aObj !== undefined) {
    return JSON.parse(JSON.stringify(aObj));
  }
}


// OBJEQUALS: deep-compare simple objects (including arrays)
function objEquals(aObj1, aObj2) {

	// identical objects
	if ( aObj1 === aObj2 ) return true;

    // if not strictly equal, both must be objects
    if (!((aObj1 instanceof Object) && (aObj2 instanceof Object))) { return false; }

    // they must have the exact same prototype chain, the closest we can do is
    // test there constructor
    if ( aObj1.constructor !== aObj2.constructor ) { return false; }

    for ( let curProp in aObj1 ) {
        if (!aObj1.hasOwnProperty(curProp) ) { continue; }

        if (!aObj2.hasOwnProperty(curProp) ) { return false; }

        if (aObj1[curProp] === aObj2[curProp] ) { continue; }

        if (typeof(aObj1[curProp] ) !== "object" ) { return false; }

        if (!objEqauls(aObj1[curProp], aObj2[curProp])) { return false; }
    }

	// if aObj2 has any properties aObj1 does not have, they're not equal
    for (let curProp in aObj2) {
	    if (aObj2.hasOwnProperty(curProp) && !aObj1.hasOwnProperty(curProp)) {
		    return false;
		}
	}

    return true;
}


// INDENT: indent a string
function indent(aStr, aIndent) {
    // regex that includes empty lines: /^/gm

    if (typeof aIndent != 'number') { aIndent = 1; }
    if (aIndent < 0) { return aStr; }

    // indent string
    return aStr.replace(/^(?!\s*$)/gm, kIndent.repeat(aIndent));
}


// DIALOGINFO: set up button map and other info for a step dialog
function dialogInfo(aInfo, aKey, aButtonBases, aValues) {

    let myResult = {
        options: {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: aInfo.stepInfo.dlgIcon,
            buttons: [],
            defaultButton: 1
        },
        buttonMap: {}
    };

    if (!aValues) { aValues = aButtonBases; }

    for (let i = 0; i < aValues.length; i++) {

        let curButton = aButtonBases[i];

        // put a dot on the selected button
        if (objEquals(aValues[i], aInfo.appInfo[aKey])) {
            let curDot = ((aInfo.stepInfo.action == kActionCREATE) ? kDotSelected :
                            ((objEquals(aInfo.appInfo[aKey], aInfo.oldAppInfo[aKey])) ?
                            kDotCurrent : kDotChanged));
            curButton = curDot + ' ' + curButton;
            myResult.options.defaultButton = i + 1;
        }

        // build custom button map with these button names
        myResult.options.buttons.push(curButton);
        myResult.buttonMap[curButton] = aValues[i];
    }

    // add back button
    if (aInfo.stepInfo.backButton) {
        myResult.options.buttons.push(aInfo.stepInfo.backButton);
        myResult.options.cancelButton = myResult.options.buttons.length;
    }

    return myResult;
}


// UPDATEAPPINFO: update an app setting
function updateAppInfo(aInfo, aKey, aValue) {

    // normalize aKey
    if (!(aKey instanceof Array)) {
        aKey = [aKey.toString()];
    }

    // make sure we have necessary objects
    if (!aInfo.appInfo) { aInfo.appInfo = {}; }
    if (!aInfo.appInfoStatus) { aInfo.appInfoStatus = {}; }

    // loop through all keys
    for (let curKey of aKey) {

        let curValue = aValue;

        // path & version keys are only for summary
        if (!((curKey == 'path') || (curKey == 'version'))) {

            // get default value
            let curDefaultValue;
            if (aInfo.oldAppInfo) {
                curDefaultValue = aInfo.oldAppInfo[curKey];
            } else {
                curDefaultValue = gAppInfoDefault[curKey];
            }

            // if no value & not already a key, use default
            if ((curValue === undefined) && (!aInfo.appInfo.hasOwnProperty(curKey))) {
                curValue = curDefaultValue;
            }

            // if we now have a value, copy it into appInfo
            if (curValue !== undefined) {
                aInfo.appInfo[curKey] = objCopy(curValue);
            }
        }

        // initialize status object
        let curStatus = {};
        aInfo.appInfoStatus[curKey] = curStatus;

        // set changed status
        if (aInfo.stepInfo.action == kActionEDIT) {
            if (curKey == 'urls') {
                let myUrlSlice = (aInfo.appInfo.windowStyle == kWinStyleApp) ? 1 : undefined;
                let myOldUrlSlice = (aInfo.oldAppInfo.windowStyle == kWinStyleApp) ? 1 : undefined;
                curStatus.changed = !objEquals(aInfo.appInfo.urls.slice(0,myUrlSlice),
                                                aInfo.oldAppInfo.urls.slice(0,myOldUrlSlice));
            } else if (curKey == 'path') {
                curStatus.changed = false;
            } else if (curKey == 'version') {
                curStatus.changed = (aInfo.appInfo.version != kVersion);
            } else {
                curStatus.changed = !objEquals(aInfo.appInfo[curKey], aInfo.oldAppInfo[curKey]);
            }
        } else {
            curStatus.changed = false;
        }


        // SET SUMMARIES

        // initialize summaries
        curStatus.stepSummary = '';
        curStatus.buildSummary = '';

        // function to select dot
        function dot() {
            if (aInfo.stepInfo.action == kActionEDIT) {
                if (curStatus.changed) {
                    return kDotChanged + ' ';
                } else {
                    return kDotCurrent + ' ';
                }
            } else {
                return kDotSelected + ' ';
            }
        }

        if (curKey == 'path') {

            if (aInfo.stepInfo.action == kActionCREATE) {

                // set build summary only in create mode
                curStatus.buildSummary = kAppInfoKeys.path + ':\n' + kIndent + dot() +
                    (aInfo.appInfo.file ? aInfo.appInfo.file.path : '[not yet set]');
            }

        } else if (curKey == 'version') {

            if ((aInfo.stepInfo.action == kActionEDIT) && curStatus.changed) {

                // set build summary only if in edit mode & we need an update
                curStatus.buildSummary = kAppInfoKeys.version + ':\n' + kIndent +
                    kDotNeedsUpdate + ' ' + aInfo.appInfo.version;
            }

        } else if ((curKey == 'displayName') || (curKey == 'shortName')) {

            // step summary -- show old value only
            if (aInfo.stepInfo.action == kActionEDIT) {
                if (curStatus.changed) {
                    curStatus.stepSummary = '\n\n' + kIndent + kDotChanged + ' Was: ' + aInfo.oldAppInfo[curKey];
                } else {
                    curStatus.stepSummary = '\n\n' + kIndent + kDotCurrent + ' [not edited]';
                }
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys[curKey] + ':\n' + kIndent + dot() + aInfo.appInfo[curKey];

        } else if (curKey == 'urls') {
            if (aInfo.appInfo.windowStyle == kWinStyleApp) {

                // APP STYLE

                // set step summary
                if (aInfo.stepInfo.action == kActionEDIT) {

                    // display old value in step summary
                    if (curStatus.changed) {
                        curStatus.stepSummary = '\n\n' + kIndent + kDotChanged + ' Was: ';
                        if (aInfo.oldAppInfo.windowStyle == kWinStyleApp) {
                            // app URL summary
                            curStatus.stepSummary += aInfo.oldAppInfo.urls[0];
                        } else {
                            // browser tab summary
                            if (aInfo.oldAppInfo.urls.length == 0) {
                                curStatus.stepSummary += ' [none]';
                            } else {
                                let myUrlPrefix = '\n' + kIndent + kIndent + kDotUnselected + ' ';
                                curStatus.stepSummary += myUrlPrefix + aInfo.oldAppInfo.urls.join(myUrlPrefix);
                            }
                        }
                    } else {
                        let myUrlName = (aInfo.appInfo.windowStyle == kWinStyleApp) ? 'URL' : 'URLs';
                        curStatus.stepSummary = '\n\n' + kIndent + kDotCurrent + ' [' + myUrlName + ' not edited]';
                    }
                }
            }

            // set build summary
            if (aInfo.appInfo.windowStyle == kWinStyleApp) {
                // app-style URL summary
                curStatus.buildSummary = kAppInfoKeys.urls[0] + ':\n' + kIndent + dot() + aInfo.appInfo.urls[0];
            } else {
                // browser-style URL summary
                let myUrlPrefix = kIndent + dot();
                curStatus.buildSummary = kAppInfoKeys.urls[1] + ':\n' + myUrlPrefix;
                if (aInfo.appInfo.urls.length == 0) {
                    curStatus.buildSummary += '[none]';
                } else {
                    curStatus.buildSummary += aInfo.appInfo.urls.join('\n' + myUrlPrefix);
                }
            }
        } else if (curKey == 'registerBrowser') {

            // set common summary
            let curSummary = dot() +
                (aInfo.appInfo.registerBrowser ? 'Yes' : 'No');

            // no step summary needed, but we'll set one for safety
            if (aInfo.stepInfo.action == kActionEDIT) {
                curStatus.stepSummary = '\n\n' + kIndent + curSummary;
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys.registerBrowser + ':\n' + kIndent + curSummary;

        } else if (curKey == 'icon') {

            // set common summary
            let curSummary;
            if (aInfo.appInfo.icon) {
                curSummary = dot() +
                    ((aInfo.appInfo.icon instanceof Object) ? aInfo.appInfo.icon.name : '[existing custom]');
            } else {
                curSummary = dot() + '[default]';
            }

            // set step summary
            if (aInfo.stepInfo.action == kActionEDIT) {

                curStatus.stepSummary = '\n\n' + kIndent + curSummary;

                // display old value
                if (curStatus.changed) {
                    curStatus.stepSummary += '  |  Was: ' +
                        (aInfo.oldAppInfo.icon ? '[existing custom]' : '[default]');
                }
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys.icon + ':\n' + kIndent + curSummary;

        } else if (curKey == 'engine') {

            // set common summary
            let curSummary = dot() + aInfo.appInfo.engine.button;

            // no step summary needed, but we'll set one for safety
            if (aInfo.stepInfo.action == kActionEDIT) {
                curStatus.stepSummary = '\n\n' + kIndent + curSummary;
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys.engine + ':\n' + kIndent + curSummary;

        } else {

            // ALL OTHER KEYS

            // set common summary
            let curSummary = dot() + aInfo.appInfo[curKey];

            // set step summary
            if (aInfo.stepInfo.action == kActionEDIT) {
                curStatus.stepSummary = '\n\n' + kIndent + curSummary;
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys[curKey] + ':\n' + kIndent + curSummary;
        }
    }
}


// CONSTANTS

// app info and their summary headers
const kAppInfoKeys = {
    path: 'Path',
    version: 'Version',
    displayName: 'App Name',
    shortName: 'Short Name',
    id: 'App ID',
    windowStyle: 'Style',
    urls: ['URL', 'Tabs'],
    registerBrowser: 'Register as Browser',
    icon: 'Icon',
    engine: 'App Engine'
};

// app defaults & settings
const kWinStyleApp = 'App Window';
const kWinStyleBrowser = 'Browser Tabs';
const kAppDefaultURL = "https://www.google.com/mail/";
const kBrowserInfo = {
    'com.microsoft.edgemac': {
        shortName: 'Edge',
        displayName: 'Microsoft Edge'
    },
    'com.vivaldi.Vivaldi': {
        shortName: 'Vivaldi',
        displayName: 'Vivaldi'
    },
    'com.operasoftware.Opera': {
        shortName: 'Opera',
        displayName: 'Opera'
    },
    'com.brave.Browser': {
        shortName: 'Brave',
        displayName: 'Brave Browser'
    },
    'org.chromium.Chromium': {
        shortName: 'Chromium',
        displayName: 'Chromium'
    },
    'com.google.Chrome': {
        shortName: 'Chrome',
        displayName: 'Google Chrome'
    }
};
const kEngines = [
    {
        type: 'internal',
        id: 'com.brave.Browser'
    },
    {
        type: 'external',
        id: 'com.google.Chrome'
    }
];
for (let curEng of kEngines) {
    curEng.button = engineName(curEng);
}

// script paths
const kEpichromeScript = kApp.pathToResource("epichrome.sh", {
    inDirectory:"Scripts" }).toString();

// app resources
const kEpiIcon = kApp.pathToResource("droplet.icns");

// general utility
const kDay = 24 * 60 * 60 * 1000;
const kIndent = ' '.repeat(3);

// actions
const kActionCREATE = 0;
const kActionEDIT = 1;
const kActionUPDATE = 2;

// step results
const kStepResultSUCCESS = 0;
const kStepResultERROR = 1;
const kStepResultQUIT = 2;
const kStepResultSKIP = 3;

// status dots
const kDotSelected = '▪️'; //❇️
const kDotUnselected = '▫️';
const kDotCurrent = '🔹';
const kDotChanged = '🔸';
const kDotNeedsUpdate = '🔺';
const kDotSuccess = '✅'; // ✔️
const kDotError = '🚫';
const kDotSkip = '✖️'; // ◼️
const kDotWarning = '⚠️';

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
    registerBrowser: false,
    icon: true,
    engine: kEngines[0]
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
        let myRegisterBrowser = (gAppInfoDefault.registerBrowser ? 'Yes' : 'No');
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind: "string",
                name: "doRegisterBrowser",
                value: myRegisterBrowser
            })
        );
        let myIcon = (gAppInfoDefault.icon ? 'Yes' : 'No');
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"doCustomIcon",
                value: myIcon
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"appEngineType",
                value:gAppInfoDefault.engine.type
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"appEngineID",
                value:gAppInfoDefault.engine.id
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
        gAppInfoDefault.registerBrowser = (myProperties["doRegisterBrowser"] != 'No');
    }

	// doCustomIcon
	if (myYesNoRegex.test(myProperties["doCustomIcon"])) {
        gAppInfoDefault.icon = (myProperties["doCustomIcon"] != 'No');
    }

	// appEngineType  $$$ would need to be fixed
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
        if (typeof(aAppInfo) == 'object') {
            aAppInfo.file = myResult;
        }

    } else {
        return null;
    }

    if (aAppInfo) {

        // this is an app path, so set up extra info
        myMatch = myResult.name.match(/^(.+)\.app$/i);
        if (myMatch) {
            myResult.base = myMatch[1];
            myResult.extAdded = false;
        } else {
            myResult.base = myResult.name;
            myResult.extAdded = true;
        }
    }

    if (typeof(aAppInfo) == 'object') {

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

        // canonicalize app name & path
        aAppInfo.file.name = aAppInfo.file.base + '.app';
        aAppInfo.file.path = aAppInfo.file.dir + '/' + aAppInfo.file.name;
    }

    return myResult;
}


// OPENDOCUMENTS: handler function for files dropped on the app
function openDocuments(aApps) {

    let myDlgResult;
    let myApps = [];
    let myErrApps = [];
    let myAppList = [];
    let myErrAppList = [];
    let myHasUpdates = false;

    for (let curAppPath of aApps) {

        // get path to app as string
        curAppPath = curAppPath.toString();

        // break down path into components
        let curAppFileInfo = getPathInfo(curAppPath, true);

        // initialize app object
        let curApp = {
            result: kStepResultSKIP,
        };

        try {

            // run core script to initialize
            curApp.appInfo = JSON.parse(shell(kEpichromeScript,
                'epiAction=read',
                'epiAppPath=' + curAppPath
            ));

        } catch(myErr) {
            curApp.error = myErr.message;
            curApp.appInfo = {
                file: curAppFileInfo
            }
            myErrApps.push(curApp);
            myErrAppList.push(kIndent + kDotError + ' ' + curApp.appInfo.file.name + ': ' + curApp.error);
            continue;
        }

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

        // fill out engine info
        curApp.appInfo.engine.button = engineName(curApp.appInfo.engine);

        // $$$ CHECK FOR LEGAL ENGINE?

        // start stepInfo
        let myDlgIcon = setDlgIcon(curApp.appInfo);
        curApp.stepInfo = {
            action: kActionEDIT,
            titlePrefix: 'Editing "' + curApp.appInfo.displayName + '"',
            dlgIcon: myDlgIcon,
            isOnlyApp: false,
            isLastApp: false,
            isOrigFilename: (curApp.appInfo.file.base == curApp.appInfo.displayName)
        };

        // check if this app needs to be updated
        let curAppText = curApp.appInfo.file.name;
        if (vcmp(curApp.appInfo.version, kVersion) < 0) {
            myHasUpdates = true;
            curApp.update = true;
            curAppText = kIndent + kDotNeedsUpdate + ' ' + curAppText + '(' + curApp.appInfo.version + ')';
        } else {
            curApp.update = false;
            curAppText = kIndent + kDotCurrent + ' ' + curAppText;
        }

        // add to list of apps for summary
        myAppList.push(curAppText);

        // add to list of apps to process
        myApps.push(curApp);
    }

    // mark the last app
    if (myApps.length >= 1) {
        myApps[myApps.length - 1].stepInfo.isLastApp = true;
    }

    // by default, edit apps
    let myDoEdit = true;

    // set up dialog text & buttons depending if one or multiple apps
    let myDlgMessage, myDlgTitle, myBtnEdit, myBtnUpdate;
    let myDlgIcon = kEpiIcon;
    let myDlgButtons = [];

    // if any apps need updating, give option to only update
    if (myHasUpdates) {

        // set base title
        myDlgTitle = 'Choose Action';

        // set base buttons
        myBtnEdit = 'Edit';
        myBtnUpdate = 'Update';

        if (aApps.length == 1) {
            myDlgMessage = 'This app will be updated from version ' + myApps[0].appInfo.version + ' to ' + kVersion + '. Do you want to edit this app, or just update it?';
            myDlgIcon = myApps[0].stepInfo.dlgIcon;
        } else {
            myDlgMessage = "You've selected at least one app with an older version (marked " + kDotNeedsUpdate + "). Edit and update all selected apps, or just update the " + kDotNeedsUpdate + " apps?\n\n" + myAppList.join('\n');
            myBtnEdit += ' All';
            myBtnUpdate += ' ' + kDotNeedsUpdate;
        }

        // set button list
        myDlgButtons = [myBtnEdit, myBtnUpdate];

    } else if (myApps.length > 0) {

        // no updates, so only offer editing

        // set base title and button
        myDlgTitle = 'Edit';
        myBtnEdit = 'OK';

        if (aApps.length == 1) {
            myDlgMessage = 'Click OK to begin editing "' + myApps[0].appInfo.displayName + '". Any changes will not be applied until you complete the process.';
            myDlgTitle += myApps[0].stepInfo.titlePrefix.replace(/^Editing/,'');
            myDlgIcon = myApps[0].stepInfo.dlgIcon;
        } else {
            myDlgMessage = "Click OK to begin editing the selected apps. Each app's changes will be applied as soon as you complete the process for that app. The following apps will be edited:\n\n" + myAppList.join('\n');
            myDlgTitle += ' Apps';
        }

        // set button list
        myDlgButtons = [myBtnEdit];
    } else {

        // no apps remain
        myDlgMessage = 'There are no apps to process.';
    }

    // list apps with errors
    if (myErrApps.length > 0) {
        if (myApps.length == 0) {
            myDlgTitle = 'Error';
            myDlgMessage = 'Error reading ' + myErrApps[0].appInfo.file.name + ': ' + myErrApps[0].error + '.';
            myDlgIcon = 'stop';
        } else {
            myDlgMessage += '\n\n' + kDotWarning + ' ';
            if (myErrApps.length == 1) {
                myDlgMessage += 'There was an error reading the following app and it cannot be edited:\n\n';
            } else {
                myDlgMessage += 'There were errors reading the following apps and they cannot be edited:\n\n';
            }
            myDlgMessage += myErrAppList.join('\n');
        }
    }

    // add Quit button
    myDlgButtons.push('Quit');

    while (true) {
        try {
            // set up dialog options
            let myDlgOptions = {
                withTitle: myDlgTitle + ' | Epichrome EPIVERSION',
                withIcon: myDlgIcon,
                buttons: myDlgButtons,
                defaultButton: 1
            };
            if (myDlgButtons.length > 1) { myDlgOptions.cancelButton = myDlgButtons.length; }

            // display dialog
            myDlgResult = kApp.displayDialog(myDlgMessage, myDlgOptions).buttonReturned;

        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                if (confirmQuit()) { return; }
                continue;
            } else {
                // some other dialog error
                throw myErr;
            }
        }

        // special case: only a quit button
        if (myDlgResult == 'Quit') {
            // quit immediately
            return;
        } else if (myDlgResult == myBtnUpdate) {
            // updates only, no app editing
            myDoEdit = false;
        }

        break;
    }

    // build text to represent will be done (editing and/or updating)
    let myActionText = [];
    if (myDoEdit) { myActionText.push('edited'); }
    if (myHasUpdates) { myActionText.push('updated'); }
    myActionText = myActionText.join(' and ');


    // RUN EDIT/UPDATE STEPS

    // mark if this is the only app we're processing
    if ((aApps.length == 1) && (myApps.length == 1)) {
        myApps[0].stepInfo.isOnlyApp = true;
        myApps[0].stepInfo.actionText = myActionText;
    }

    for (let curApp of myApps) {

        if (myDoEdit) {

            // change appInfo to oldAppInfo
            curApp.oldAppInfo = objCopy(curApp.appInfo);

            // initialize relevant info
            updateAppInfo(curApp, Object.keys(kAppInfoKeys));

            // run edit steps
            curApp.result = doSteps([
                stepEditDisplayName,
                stepShortName,
                stepWinStyle,
                stepURLs,
                stepBrowser,
                stepIcon,
                stepEngine,
                stepBuild
            ], curApp);
        } else {

            // run update-only step
            if (curApp.update) {
                curApp.stepInfo.action = kActionUPDATE;
                curApp.result = doSteps([stepBuild], curApp);
            }
        }

        // handle result
        if (curApp.result == kStepResultQUIT) { break; }
    }

    // build summary
    if (aApps.length > 1) {

        let mySuccessText = [], myHasSuccess = false;
        let myErrorText = [], myHasError = false;
        let myAbortText = [], myHasAbort = false;

        for (let curApp of myApps) {
            if (curApp.result == kStepResultSUCCESS) {
                mySuccessText.push(kIndent + kDotSuccess + ' ' + curApp.appInfo.displayName);
                myHasSuccess = true;
            } else if (curApp.result == kStepResultERROR) {
                myErrorText.push(kIndent + kDotError + ' ' + curApp.appInfo.displayName);
                myHasError = true;
            } else if ((curApp.result == kStepResultSKIP) || (curApp.result == kStepResultQUIT)) {
                myAbortText.push(kIndent + kDotSkip + ' ' + curApp.appInfo.displayName);
                myHasAbort = true;
            }
        }

        let myDlgMessage;
        let myDlgButtons = ['Quit'];

        if (!myHasError && !myHasAbort) {
            if (myHasSuccess) {
                myDlgMessage = 'All apps were ' + myActionText + ' successfully!';
            } else {
                myDlgMessage = 'No apps were processed!';
            }
        } else {

            // if errors encountered, add log button
            if (myHasError && hasLogFile()) {
                myDlgButtons.push('View Log & Quit');
            }

            // build summary message
            myDlgMessage = [];
            if (myHasSuccess) {
                myDlgMessage.push('These apps were ' + myActionText + ' successfully:\n\n' + mySuccessText.join('\n'));
            }
            if (myHasError) {
                myDlgMessage.push('These apps encountered errors:\n\n' + myErrorText.join('\n'));
            }
            if (myHasAbort) {
                myDlgMessage.push('These apps were skipped:\n\n' + myAbortText.join('\n'));
            }
            myDlgMessage = myDlgMessage.join('\n\n');
        }

        // show summary
        let myDlgResult = kApp.displayDialog(myDlgMessage, {
            withTitle: 'Summary',
            withIcon: kEpiIcon,
            buttons: myDlgButtons,
            defaultButton: 1
        }).buttonReturned;

        if (myDlgResult != 'Quit') {
            // show log
            showLogFile();
        }
    }
}


// --- BUILD STEPS ---

// STEPCREATEDISPLAYNAME: step function to get display name and app path for CREATE action
function stepCreateDisplayName(aInfo) {

    // status variables
	let myTryAgain, myErr;

    // CHOOSE WHERE TO SAVE THE APP

    myTryAgain = true;

    const myPromptNameLoc = 'Select name and location for the app.';

    let myDlgOptions = {
        withPrompt: aInfo.stepInfo.numText + ': ' + myPromptNameLoc,
        defaultName: aInfo.appInfo.displayName
    };
    if (gEpiLastAppDir) { myDlgOptions.defaultLocation = gEpiLastAppDir; }

    while (myTryAgain) {

        myTryAgain = false; // assume we'll succeed

        let myAppPath;

        // show file selection dialog
        try {
            myAppPath = kApp.chooseFileName(myDlgOptions).toString();
        } catch(myErr) {

            if (myErr.errorNumber == -128) {

                // cancel button
                return -1;

            } else if (myErr.errorNumber == -1700) {

                // bad defaultLocation, so try this again with no default
                gEpiLastAppDir = '';
                delete myDlgOptions.defaultLocation;
                myTryAgain = true;
                continue;

            } else {
                // hand off to enclosing try
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

    // if we got here, we have a good path and display name
    updateAppInfo(aInfo, ['path', 'displayName']);

    // move on
    return 1;
}


// STEPEDITDISPLAYNAME: step function to get display name and app path for CREATE action
function stepEditDisplayName(aInfo) {

    // status variables
    let myErr, myDlgResult;

    let myDlgMessage = 'Edit the name of the app.';

    if (aInfo.stepInfo.isOrigFilename) {
        myDlgMessage += '\n\n' + kDotWarning + ' Warning: Changing this will also rename the app file.';
    }

    try {
        myDlgResult = kApp.displayDialog(myDlgMessage + aInfo.appInfoStatus.displayName.stepSummary, {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: aInfo.stepInfo.dlgIcon,
            defaultAnswer: aInfo.appInfo.displayName,
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

    // if display name changed and this would result in renaming the app, confirm
    if (aInfo.stepInfo.isOrigFilename &&
        (aInfo.appInfo.displayName == aInfo.oldAppInfo.displayName) &&
        (myDlgResult != aInfo.oldAppInfo.displayName)) {

        let myConfResult;

        try {
            myConfResult = kApp.displayDialog("Are you sure you want to change the app's name? This will rename the app file:\n\n" + kIndent + kDotUnselected + " Old name: " + aInfo.oldAppInfo.file.name + "\n" + kIndent + kDotSelected + " New name: " + myDlgResult + ".app", {
                withTitle: 'Confirm Rename App',
                withIcon: 'caution',
                buttons: ['Cancel', 'OK'],
                defaultButton: 1
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                myConfResult = 'Cancel';
            } else {
                throw myErr;
            }
        }

        if (myConfResult != 'OK') {
            // repeat this step
            return 0;
        }

        // update path for new display name
        aInfo.appInfo.file.base = myDlgResult;
        aInfo.appInfo.file.name = myDlgResult + '.app';
        aInfo.appInfo.file.path = aInfo.appInfo.file.dir + '/' + aInfo.appInfo.file.name;
        updateAppInfo(aInfo, 'path');
    }

    // if we got here, set the display name
    updateAppInfo(aInfo, 'displayName', myDlgResult);

    // move on
    return 1;
}


// STEPSHORTNAME: step function for setting app short name
function stepShortName(aInfo) {

    // status variables
    let myTryAgain, myErr, myDlgResult;

    let myAppShortNamePrompt = 'the short app name that will appear in the menu bar (16 characters or less).';

    if (aInfo.stepInfo.action == kActionCREATE) {
        myAppShortNamePrompt = 'Enter ' +  myAppShortNamePrompt;
    } else {
        // edit prompt
        myAppShortNamePrompt = 'Edit ' +  myAppShortNamePrompt + '\n\n' + kDotWarning + " Warning: Changing this will also change the app's ID and rename its data directory.";
    }

    myTryAgain = true;
    while (myTryAgain) {

        // assume success
        myTryAgain = false;

        try {
            myDlgResult = kApp.displayDialog(myAppShortNamePrompt + aInfo.appInfoStatus.shortName.stepSummary, {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: aInfo.stepInfo.dlgIcon,
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
            myAppShortNamePrompt = kDotWarning + " That name is too long. Please limit the name to 16 characters or less.";
            aInfo.appInfo.shortName = myDlgResult.slice(0, 16);
        } else if (myDlgResult.length == 0) {
            myTryAgain = true;
            myAppShortNamePrompt = kDotWarning + " No name entered. Please try again.";
        }
    }

    // if short name changed, confirm
    if ((aInfo.stepInfo.action == kActionEDIT) &&
        (aInfo.appInfo.shortName == aInfo.oldAppInfo.shortName) &&
        (myDlgResult != aInfo.oldAppInfo.shortName)) {

        let myConfResult;

        try {
            myConfResult = kApp.displayDialog("Are you sure you want to change the app's short name? This will change the app's ID and rename its data directory.", {
                withTitle: 'Confirm Change App ID',
                withIcon: 'caution',
                buttons: ['Cancel', 'OK'],
                defaultButton: 1
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                myConfResult = 'Cancel';
            } else {
                throw myErr;
            }
        }

        if (myConfResult != 'OK') {
            // repeat this step
            return 0;
        }
    }

    // if we got here, we have a good name
    updateAppInfo(aInfo, 'shortName', myDlgResult);

    // move on
    return 1;
}


// STEPWINSTYLE: step function for setting app window style
function stepWinStyle(aInfo) {

    // status variables
	let myErr;

    // set up dialog message

    let myDlgMessage = "App Style:\n\nAPP WINDOW - The app will display an app-style window with the given URL. (This is ordinarily what you'll want.)\n\nBROWSER TABS - The app will display a full browser window with the given tabs.";

    if (aInfo.stepInfo.action == kActionCREATE) {
        myDlgMessage = 'Choose ' +  myDlgMessage;
    } else {
        myDlgMessage = 'Edit ' +  myDlgMessage;
    }

    // set up dialog info
    let myDlgInfo = dialogInfo(aInfo, 'windowStyle', [kWinStyleApp, kWinStyleBrowser]);

    try {

        // display dialog
        updateAppInfo(aInfo, 'windowStyle',
            myDlgInfo.buttonMap[kApp.displayDialog(myDlgMessage, myDlgInfo.options).buttonReturned]);

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // update URLs too for next step
    updateAppInfo(aInfo, 'urls');

    // move on
    return 1;
}


// STEPURLS: step function for setting app URLs
function stepURLs(aInfo) {

    // status variables
    let myErr, myDlgResult;

    if (aInfo.appInfo.windowStyle == kWinStyleApp) {

        // APP WINDOW STYLE

        // set up dialog prompt

        let myDlgMessage = 'URL:';

        if (aInfo.stepInfo.action == kActionCREATE) {

            // create prompt
            myDlgMessage = 'Choose ' +  myDlgMessage;

            // initialize URL list
            if (aInfo.appInfo.urls.length == 0) {
                aInfo.appInfo.urls.push(kAppDefaultURL);
            }

        } else {

            // edit prompt
            myDlgMessage = 'Edit ' +  myDlgMessage;
        }

        try {
            aInfo.appInfo.urls[0] = kApp.displayDialog(myDlgMessage + aInfo.appInfoStatus.urls.stepSummary, {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: aInfo.stepInfo.dlgIcon,
                defaultAnswer: aInfo.appInfo.urls[0],
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

        // update summaries
        updateAppInfo(aInfo, 'urls');

    } else {

        // BROWSER TABS

        // TABLIST: build representation of browser tabs
        function tablist(tabs, tabnum) {

            let ttext, ti;

            if (tabs.length == 0) {
                return kIndent + kDotSelected + " [no tabs specified]\n\nClick \"Add\" to add a tab. If you click \"Done (Don't Add)\" now, the app will determine which tabs to open on startup using its preferences, just as Chrome would."
            } else {
                if (tabs.length == 1) {
                    ttext = "One tab specified:";
                } else {
                    ttext = tabs.length.toString() + ' tabs specified:';
                }

                // add tabs themselves to the text
                ti = 1;
                for (const t of tabs) {
                    if (ti == tabnum) {
                        ttext += '\n' + kIndent + kDotSelected + '  [the tab you are editing]';
                    } else {
                        ttext += '\n' + kIndent + kDotUnselected + '  ' + t;
                    }
                    ti++;
                }

                if (ti == tabnum) {
                    ttext += '\n' + kIndent + kDotSelected + '  [new tab will be added here]';
                }

                return ttext;
            }
        }

        // set up dialog prompt

        let myCurTab = 1

        while (true) {

            if (myCurTab > aInfo.appInfo.urls.length) {

                // set default button
                let myDefaultButton = 1;
                if ((aInfo.stepInfo.action == kActionEDIT) && !aInfo.appInfoStatus.urls.changed) {
                    // user did not edit tabs, so default to Don't Add
                    myDefaultButton = 2;
                }

                try {
                    myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab) +
                            aInfo.appInfoStatus.urls.stepSummary, {
                        withTitle: aInfo.stepInfo.dlgTitle,
                        withIcon: aInfo.stepInfo.dlgIcon,
                        defaultAnswer: kAppDefaultURL,
                        buttons: ["Add", "Done (Don't Add)", aInfo.stepInfo.backButton],
                        defaultButton: myDefaultButton,
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
                    updateAppInfo(aInfo, 'urls');
                    myCurTab++;

                } else { // "Done (Don't Add)"
                    // we're done, don't add the current text to the list
                    break;
                }
            } else {

                let myBackButton = false;

                if (myCurTab == 1) {
                    try {
                        myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab) +
                                aInfo.appInfoStatus.urls.stepSummary, {
                            withTitle: aInfo.stepInfo.dlgTitle,
                            withIcon: aInfo.stepInfo.dlgIcon,
                            defaultAnswer: aInfo.appInfo.urls[myCurTab-1],
                            buttons: ['Next', 'Remove', aInfo.stepInfo.backButton],
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
                    myDlgResult = kApp.displayDialog(tablist(aInfo.appInfo.urls, myCurTab) +
                            aInfo.appInfoStatus.urls.stepSummary, {
                        withTitle: aInfo.stepInfo.dlgTitle,
                        withIcon: aInfo.stepInfo.dlgIcon,
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
                        aInfo.appInfo.urls[myCurTab - 1] = myDlgResult.textReturned;
                        myCurTab--;
                    }
                } else if (myDlgResult.buttonReturned == "Next") {
                    aInfo.appInfo.urls[myCurTab - 1] = myDlgResult.textReturned;
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

                // update step summary
                updateAppInfo(aInfo, 'urls');
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

    // set up dialog message

    let myDlgMessage = 'Register app as a browser?';

    let myDlgInfo = dialogInfo(aInfo, 'registerBrowser', ['Yes', 'No'], [true, false]);
    let myDlgResult;

    try {
        // display dialog
        updateAppInfo(aInfo, 'registerBrowser',
            myDlgInfo.buttonMap[kApp.displayDialog(myDlgMessage, myDlgInfo.options).buttonReturned]);

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

    // set up dialog message

    let myDlgMessage = 'Do you want to provide a custom icon?';
    let myDlgResult;

    let myDlgInfo = dialogInfo(aInfo, 'icon', ['Yes', 'No'], [aInfo.appInfo.icon ? aInfo.appInfo.icon : true, false]);

    try {

        // display step dialog
        myDlgResult = kApp.displayDialog(myDlgMessage + aInfo.appInfoStatus.icon.stepSummary,
            myDlgInfo.options).buttonReturned;

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // if editing & icon choice changed from custom to default, confirm whether to remove icon
    if ((aInfo.stepInfo.action == kActionEDIT) &&
        (aInfo.appInfo.icon && aInfo.oldAppInfo.icon) &&
        !myDlgInfo.buttonMap[myDlgResult]) {

        let myDlgResult;

        try {
            myDlgResult = kApp.displayDialog("Are you sure you want to remove this app's custom icon and replace it with the default Epichrome icon?", {
                withTitle: 'Confirm Icon Change',
                withIcon: 'caution',
                buttons: ['Cancel', 'OK'],
                defaultButton: 1
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                myDlgResult = 'Cancel';
            } else {
                throw myErr;
            }
        }

        if (myDlgResult != 'OK') {
            // repeat this step
            return 0;
        }
    }

    if (myDlgInfo.buttonMap[myDlgResult]) {

        let myChooseIcon = true;

        // if we haven't changed the check if user wants to change current custom icon
        if ((aInfo.stepInfo.action == kActionEDIT) && aInfo.oldAppInfo.icon &&
            (!(aInfo.appInfo.icon instanceof Object))) {

            myChooseIcon = (kApp.displayDialog("Do you want to replace the app's current icon" + (aInfo.stepInfo.dlgIcon != kEpiIcon ? ' (shown in this dialog box)' : '') + '?', {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: aInfo.stepInfo.dlgIcon,
                buttons: ['Keep', 'Replace'],
                defaultButton: 1
            }).buttonReturned == 'Replace');
        }

        if (myChooseIcon) {

            // CHOOSE AN APP ICON

            let myIconSourcePath;

            const myIconPrompt = 'Select an image to use as an icon.';
            const myIconTypes = ["public.jpeg", "public.png", "public.tiff", "com.apple.icns"];

            // show file selection dialog
            try {

                if (gEpiLastIconDir) {
                    try {
                        myIconSourcePath = kApp.chooseFile({
                            withPrompt: myIconPrompt,
                            ofType: myIconTypes,
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
                        withPrompt: myIconPrompt,
                        ofType: myIconTypes,
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
            aInfo.appInfo.icon = getPathInfo(myIconSourcePath);

            // save icon directory as default
            gEpiLastIconDir = aInfo.appInfo.icon.dir;

        } else {
            // don't change custom icon
            aInfo.appInfo.icon = true;
        }
    } else {

        // default icon
        aInfo.appInfo.icon = false;
    }

    // update summaries
    updateAppInfo(aInfo, 'icon');

    // move on
    return 1;
}


// STEPENGINE: step function to set app engine
function stepEngine(aInfo) {

    // status variables
	let myErr;

    // dialog message
    let myDlgMessage;

    // initialize engine choice buttons
    let myDefaultButton = 1;

    // name buttons based on which engine app is selected
    let myDlgInfo = dialogInfo(aInfo, 'engine', kEngines.map(x => x.button), kEngines);

    if (aInfo.stepInfo.action == kActionCREATE) {

        myDlgMessage = "Use built-in app engine, or external browser engine?\n\n";

        myDlgMessage += kDotWarning + " NOTE: If you don't know what this question means, choose Built-In.\n\n";

        myDlgMessage += "In almost all cases, using the built-in engine will result in a more functional app. Using an external browser engine has several disadvantages, including unreliable link routing, possible loss of custom icon/app name, inability to give each app individual access to the camera and microphone, and difficulty reliably using AppleScript or Keyboard Maestro with the app.\n\n";

        myDlgMessage += "The main reason to choose the external browser engine is if your app must run on a signed browser (for things like the 1Password desktop extension--it is NOT needed for the 1PasswordX extension).";
    } else {

        // edit message
        myDlgMessage = 'Edit app engine choice.\n\n';

        myDlgMessage += kDotWarning + " NOTE: If you don't know what this question means, choose Keep.\n\n";

        myDlgMessage += "Switching an existing app's engine will log you out of any existing sessions in the app, you will lose any saved passwords, and you will need to reinstall all your extensions. (The first time you run the updated app, it will open the Chrome Web Store page for each extension you had installed to give you a chance to reinstall them. Once reinstalled, any extension settings should reappear.)\n\n";

        myDlgMessage += "The built-in engine has many advantages, including more reliable link routing, preventing intermittent loss of custom icon/app name, ability to give the app individual access to camera and microphone, and more reliable interaction with AppleScript and Keyboard Maestro.\n\n";

        myDlgMessage += "The main advantage of the external engine is if your app must run on a signed browser (mainly needed for extensions like the 1Password desktop extension--it is not needed for the 1PasswordX extension).";
    }

    let myDlgResult;

    try {

        // display dialog
        myDlgResult = kApp.displayDialog(myDlgMessage, myDlgInfo.options).buttonReturned;

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            // Back button
            return -1;
        } else {
            throw myErr;
        }
    }

    // if engine change chosen during editing, confirm
    if ((aInfo.stepInfo.action == kActionEDIT) &&
        objEquals(aInfo.appInfo.engine, aInfo.oldAppInfo.engine) &&
        !objEquals(myDlgInfo.buttonMap[myDlgResult], aInfo.oldAppInfo.engine)) {

        let myConfResult;

        try {
            myConfResult = kApp.displayDialog("Are you sure you want to switch engines?\n\nIMPORTANT: You will be logged out of all existing sessions, lose all saved passwords, and will need to reinstall all extensions. If you want to save or export anything, you must do it BEFORE continuing with this change.", {
                withTitle: 'Confirm Engine Change',
                withIcon: 'caution',
                buttons: ['Cancel', 'OK'],
                defaultButton: 1
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                myConfResult = 'Cancel';
            } else {
                throw myErr;
            }
        }

        if (myConfResult != 'OK') {

            // repeat this step
            return 0;
        }
    }

    // set app engine
    updateAppInfo(aInfo, 'engine', myDlgInfo.buttonMap[myDlgResult]);

    // move on
    return 1;
}


// STEPBUILD: step function to build app
function stepBuild(aInfo) {

    // status variables
    let myErr;

    let myScriptAction;

    if (aInfo.stepInfo.action != kActionUPDATE) {

        let myDlgResult, myAppSummary, myActionButton;
        let myDoBuild = true;

        if (aInfo.stepInfo.action == kActionCREATE) {

            myScriptAction = 'build';

            // create summary of the app
            myAppSummary = 'Ready to create!\n\n' +
                Object.keys(aInfo.appInfoStatus).filter(x => x != 'version').map(x => aInfo.appInfoStatus[x].buildSummary).join('\n\n');
            myActionButton = 'Create';
        } else {

            myScriptAction = 'edit';

            // edit summary of app & look for changes
            let myChangedSummary = [];
            let myUnchangedSummary = [];
            for (let curItem of Object.values(aInfo.appInfoStatus)) {
                if (curItem.buildSummary) {
                    if (curItem.changed) {
                        myChangedSummary.push(curItem.buildSummary);
                    } else {
                        myUnchangedSummary.push(curItem.buildSummary);
                    }
                }
            }

            // set up dialog message and action
            if (myChangedSummary.length == 0) {
                myDoBuild = false;
                myAppSummary = 'No changes have been made to this app.';
                myActionButton = (aInfo.stepInfo.isOnlyApp ? 'Quit' : 'Skip');
            } else {
                if (aInfo.appInfoStatus.version.changed && (myChangedSummary.length == 1)) {
                    myAppSummary = 'This app will be updated to version ' + kVersion +
                        '. No other changes have been made.';
                    myActionButton = 'Update';
                } else {
                    let myHasUnchanged = (myUnchangedSummary.length > 0);

                    myAppSummary = 'Ready to save changes!\n\n' +
                        (myHasUnchanged ? 'CHANGED:\n\n' : '') +
                        indent(myChangedSummary.join('\n\n'), myHasUnchanged ? 1 : 0);
                    if (myHasUnchanged) {
                        myAppSummary += '\n\nUNCHANGED:\n\n' +
                            indent(myUnchangedSummary.join('\n\n'));
                    }
                    myActionButton = 'Save Changes';
                    if (aInfo.appInfoStatus.version.changed) {
                        myActionButton += ' & Update';
                    }
                }
            }
        }

        // display summary
        try {
            kApp.displayDialog(myAppSummary, {
                withTitle: aInfo.stepInfo.dlgTitle,
                withIcon: aInfo.stepInfo.dlgIcon,
                buttons: [myActionButton, aInfo.stepInfo.backButton],
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

        // if there are no changes, quit
        if (!myDoBuild) {
            // go to step -1 to trigger quit dialog
            return -aInfo.stepInfo.number - 1;
        }
    } else {
        myScriptAction = 'edit';
    }


    // BUILD/UPDATE SCRIPT ARGUMENTS

    let myScriptArgs = [
        kEpichromeScript,
        gScriptLogVar,
        'epiAction=' + myScriptAction,
        'CFBundleDisplayName=' + aInfo.appInfo.displayName,
        'CFBundleName=' + aInfo.appInfo.shortName,
        'SSBCustomIcon=' + (aInfo.appInfo.icon ? 'Yes' : 'No'),
        'SSBRegisterBrowser=' + (aInfo.appInfo.registerBrowser ? 'Yes' : 'No'),
        'SSBEngineType=' + aInfo.appInfo.engine.type + '|' + aInfo.appInfo.engine.id,
        'SSBCommandLine=(' ];

    // add app command line
    if (aInfo.appInfo.windowStyle == kWinStyleApp) {
        myScriptArgs.push('--app=' + aInfo.appInfo.urls[0]);
    } else if (aInfo.appInfo.urls.length > 0) {
        myScriptArgs.push.apply(myScriptArgs, aInfo.appInfo.urls);
    }
    myScriptArgs.push(')');

    // add icon source if necessary
    if (aInfo.appInfo.icon instanceof Object) {
        myScriptArgs.push('epiIconSource=' + aInfo.appInfo.icon.path);
    }

    // action-specific arguments
    if (aInfo.stepInfo.action == kActionCREATE) {
        // create-specific arguments
        myScriptArgs.push('epiAppPath=' + aInfo.appInfo.file.path);
    } else {
        // edit-/update-specific arguments

        // app ID
        myScriptArgs.push('SSBIdentifier=' + aInfo.appInfo.id);

        if (aInfo.stepInfo.action == kActionEDIT) {
            // old ID
            if (aInfo.appInfoStatus.id.changed) {
                myScriptArgs.push('epiOldIdentifier=' + aInfo.oldAppInfo.id);
            }

            // app path
            myScriptArgs.push('epiAppPath=' + aInfo.oldAppInfo.file.path);
            if (aInfo.stepInfo.isOrigFilename && aInfo.appInfoStatus.displayName.changed) {
                myScriptArgs.push('epiNewAppPath=' + aInfo.appInfo.file.path);
            }
        } else {
            // app path for update
            myScriptArgs.push('epiAppPath=' + aInfo.appInfo.file.path);
        }
    }


    // CREATE/UPDATE THE APP

    let myBuildMessage;
    if (aInfo.stepInfo.action == kActionCREATE) {
        myBuildMessage = ['Building', 'Build', 'Configuring'];
    } else if (aInfo.stepInfo.action == kActionEDIT) {
        myBuildMessage = ['Saving changes to', 'Save', 'Editing'];
    } else {
        myBuildMessage = ['Updating', 'Update', 'Canceled'];
    }
    let myAppNameMessage = ' "' + aInfo.appInfo.displayName + '"...';
    try {

        Progress.totalUnitCount = 2;
        Progress.completedUnitCount = 1;
        Progress.description = myBuildMessage[0] + myAppNameMessage;
        Progress.additionalDescription = 'This may take up to 30 seconds. The progress bar will not advance.';

        // this somehow allows the progress bar to appear
        delay(0.1);

        // run the build/update script
        shell.apply(null, myScriptArgs);

        Progress.completedUnitCount = 2;
        Progress.description = myBuildMessage[1] + ' complete.';
        Progress.additionalDescription = '';

    } catch(myErr) {

        if (myErr.errorNumber == -128) {
            Progress.completedUnitCount = 0;
            Progress.description = myBuildMessage[2] + myAppNameMessage;
            Progress.additionalDescription = '';
            if (aInfo.stepInfo.action == kActionUPDATE) {
                return -1;
            } else {
                return 0;
            }
        }

        Progress.completedUnitCount = 0;
        Progress.description = myBuildMessage[1] + ' failed.';
        Progress.additionalDescription = '';

        // show error dialog & quit or go back
        return {
            message: "Creation failed: " + myErr.message,
            title: "Application Not Created",
            backStep: -1,
            resetProgress: true,
            resetMsg: myBuildMessage[2] + myAppNameMessage
        };
    }

    // SUCCESS! GIVE OPTION TO REVEAL OR LAUNCH

    if (aInfo.stepInfo.isOnlyApp) {

        let myDlgMessage = 'app "' + aInfo.appInfo.displayName + '".';
        if (aInfo.stepInfo.action == kActionCREATE) {
            myDlgMessage = 'Created Epichrome ' + myDlgMessage + '\n\nIMPORTANT NOTE: A companion extension, Epichrome Helper, will automatically install when the app is first launched, but will be DISABLED by default. The first time you run, a welcome page will show you how to enable it.';
        } else if (aInfo.stepInfo.action == kActionEDIT) {
            myDlgMessage = 'Saved changes to ' + myDlgMessage;
        } else {
            myDlgMessage = 'Updated ' + myDlgMessage;
        }

        try {
            // reset dialog icon as app may have moved
            let myDlgIcon = setDlgIcon(aInfo.appInfo);

            myDlgResult = false;
            myDlgResult = kApp.displayDialog(myDlgMessage, {
                withTitle: "Success!",
                withIcon: myDlgIcon,
                buttons: ["Launch Now", "Reveal in Finder", "Quit"],
                defaultButton: 1,
                cancelButton: 3
            }).buttonReturned;
        } catch(myErr) {
            if (myErr.errorNumber == -128) {
                // Back button
                return false; // quit
            } else {
                throw myErr;
            }
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
    }

    // we're finished! quit
    return false;
}


// DOSTEPS: run a set of build or edit steps
function doSteps(aSteps, aInfo, aNextStep=0) {
    // RUN THE STEPS TO BUILD THE APP

    let myResult = kStepResultSUCCESS;

    // if we start out on step -1, make sure a nonconfirm goes to step 0
    let myStepResult = -1;

    while (true) {

        // backed out of the first step
        if (aNextStep < 0) {

            // normalize
            aNextStep = -1;

            let myDlgButtons = ['No', 'Yes'];
            let myDlgMessage = 'Are you sure you want to ';
            let myDlgTitle = 'Confirm ';
            let myResult = kStepResultQUIT;

            if (aInfo.stepInfo.action == kActionCREATE) {
                myDlgMessage = 'The app has not been created. ' + myDlgMessage + 'quit?';
                myDlgTitle += 'Quit';
            } else {

                if (aInfo.stepInfo.action == kActionEDIT) {
                    myDlgMessage = 'You have not finished editing "' + aInfo.appInfo.displayName + '". Your changes have not been saved' + (aInfo.update ? ' and the app will not be updated. ' : '. ') + myDlgMessage;
                } else {
                    myDlgMessage = 'You canceled the update of "' + aInfo.appInfo.displayName + '". The app has not been updated.' + myDlgMessage;
                }

                if (aInfo.stepInfo.isLastApp) {
                    myDlgMessage += 'quit?';
                    myDlgTitle += 'Quit';
                } else {
                    myDlgMessage += 'skip this app?';
                    myDlgTitle += 'Skip';
                    myDlgButtons.push('Quit');
                    myResult = kStepResultSKIP;
                }
            }

            let myDlgResult;

            try {

                // confirm back-out
                myDlgResult = kApp.displayDialog(myDlgMessage, {
                    withTitle: myDlgTitle,
                    withIcon: aInfo.stepInfo.dlgIcon,
                    buttons: myDlgButtons,
                    defaultButton: 2,
                    cancelButton: 1
                }).buttonReturned;
            } catch(myErr) {
                if (myErr.errorNumber == -128) {

                    // quit not confirmed, so continue with steps
                    aNextStep -= myStepResult;

                } else {
                    // some other dialog error
                    throw myErr;
                }
            }

            // return appropriate value
            if (myDlgResult == 'Yes') {
                return myResult;
            } else if (myDlgResult == 'Quit') {
                return kStepResultQUIT;
            } else {
                // should never get here
                aNextStep -= myStepResult;
            }
        }

        if (aNextStep == 0) {
            if (aInfo.stepInfo.isOnlyApp) {
                aInfo.stepInfo.backButton = 'Quit';
            } else {
                aInfo.stepInfo.backButton = 'Abort';
            }
        } else {
            // cap max step number
            aNextStep = Math.min(aNextStep, aSteps.length - 1);

            aInfo.stepInfo.backButton = 'Back';
        }

        // set step number
        aInfo.stepInfo.number = aNextStep;

        // set step dialog title
        aInfo.stepInfo.numText = 'Step ' + (aNextStep + 1).toString() +
            ' of ' + aSteps.length.toString();
        aInfo.stepInfo.dlgTitle = aInfo.stepInfo.titlePrefix + ' | ' + aInfo.stepInfo.numText;


        // RUN THE NEXT STEP

        myStepResult = aSteps[aNextStep](aInfo);


        // CHECK RESULT OF STEP

        if (typeof(myStepResult) == 'number') {

            // FORWARD OR BACK: MOVE ON TO ANOTHER STEP

            // move forward, backward, or stay on the same step
            aNextStep += myStepResult;

            continue;

        } else if (typeof(myStepResult) == 'object') {

            // STEP RETURNED ERROR

            myResult = kStepResultERROR;

            // always show exit button
            let myExitButton, myDlgButtons;
            let myViewLogButton = false;

            if (aInfo.stepInfo.isOnlyApp) {
                myExitButton = 'Quit';

                myDlgButtons = [myExitButton];

                // show View Log option if there's a log
                if (hasLogFile()) {
                    myViewLogButton = 'View Log & ' + myExitButton;
                    myDlgButtons.push(myViewLogButton);
                }
            } else {
                myExitButton = 'Abort';
                myDlgButtons = [myExitButton];
            }

            // display dialog
            let myDlgResult;

            // if we're allowed to backstep & this isn't the first step
            if ((myStepResult.backStep !== false) && (aNextStep != 0)) {

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

                    // Back button
                    if (myStepResult.resetProgress) {
                        Progress.completedUnitCount = 0;
                        Progress.description = myStepResult.resetMsg;
                        Progress.additionalDescription = '';
                    }
                    aNextStep += myStepResult.backStep;
                    continue;
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

            // if user clicked 'View Log & Quit', then try to show the log
            if (myDlgResult == myViewLogButton) {
                showLogFile();
            }
        }

        // done
        break;
    }

    return myResult;
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

    // say hello
    try {

        kApp.displayDialog('Click OK to select a name and location for the app.', {
            withTitle: 'Create App | Epichrome EPIVERSION',
            withIcon: kEpiIcon,
            buttons: ['OK', 'Quit'],
            defaultButton: 1,
            cancelButton: 2
        });

    } catch(myErr) {
        if (myErr.errorNumber == -128) {
            if (confirmQuit()) { return; }
        } else {
            // some other dialog error
            throw myErr;
        }
    }

    // initialize app info from defaults
    let myInfo = {
        stepInfo: {
            action: kActionCREATE,
            titlePrefix: 'Create App',
            dlgIcon: kEpiIcon,
            isOnlyApp: true,
        },
        appInfo: gAppInfoDefault
    };
    updateAppInfo(myInfo, Object.keys(kAppInfoKeys));

    // run new app build steps
    doSteps([
        stepCreateDisplayName,
        stepShortName,
        stepWinStyle,
        stepURLs,
        stepBrowser,
        stepIcon,
        stepEngine,
        stepBuild
    ], myInfo);
}


// QUIT: handler for when app quits
function quit() {
    // write properties before quitting
    writeProperties();
}

// --- MAIN BODY: functions that run first whether files are dropped or not ---

// read in persistent properties
readProperties();

// check GitHub for updates to Epichrome
checkForUpdate();
