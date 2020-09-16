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


// --- CONSTANTS ---

// app ID info (max length for CFBundleIdentifier is 30 characters)
const kBundleIDBase = 'org.epichrome.app.';
const kAppIDMaxLength = 30 - kBundleIDBase.length;
const kAppIDMinLength = 3;
const kAppIDLegalCharsRe = /[^-a-zA-Z0-9_]/g;

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
const kDotAdvanced = '⚙️';

// app info and their summary headers
const kAppInfoKeys = {
    path: 'Path',
    version: 'Version',
    displayName: 'App Name',
    shortName: 'Short Name',
    windowStyle: 'Style',
    urls: ['URL', 'Tabs'],
    registerBrowser: 'Register as Browser',
    icon: 'Icon',
    engine: 'App Engine',
    id: kDotAdvanced + ' App ID / Data Directory',
    updateAction: kDotAdvanced + ' Update Action'
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
const kUpdateActions = {
    prompt: {
        button: 'Display Prompt',
        message: 'display the default update prompt dialog',
        value: ''
    },
    auto: {
        button: 'Update Automatically',
        message: 'be automatically updated with no prompt',
        value: 'Auto'
    },
    never: {
        button: 'Never Update',
        message: 'never attempt to update itself',
        value: 'Never'
    }
};

// script paths
const kEpichromeScript = kApp.pathToResource("epichrome.sh", {
    inDirectory:"Scripts" }).toString();

// app resources
const kEpiIcon = kApp.pathToResource("droplet.icns");

// general utility
const kDay = 24 * 60 * 60 * 1000;
const kIndent = ' '.repeat(3);

// actions
const kActionCREATE = 1;
const kActionEDIT = 2;
const kActionUPDATE = 3;

// step results
const kStepResultSUCCESS = 1;
const kStepResultERROR = 2;
const kStepResultQUIT = 3;
const kStepResultSKIP = 4;


// --- GLOBAL VARIABLES ---

// Epichrome state
let gEpiLastDir = {
    create: null,
    edit: null,
    icon: null
}

// flag whether a default app directory has already been created
let gEpiDefaultAppDirCreated = false;

// the last error encountered checking GitHub
let gEpiGithubFatalError = '';

// info from core.sh
let gCoreInfo = null;

// new app defaults
let gAppInfoDefault = {
    displayName: 'My Epichrome App',
    shortName: false,
    windowStyle: kWinStyleApp,
    urls: [],
    registerBrowser: false,
    icon: true,
    engine: kEngines[0],
    updateAction: 'prompt'
};


// --- FUNCTIONS ---

// --- TOP-LEVEL HANDLERS ---

// RUN: handler for when app is run without dropped files
function run() {
    main();
}


// OPENDOCUMENTS: handler function for files dropped on the app
function openDocuments(aApps) {
    main(aApps);
}


// QUIT: handler for when app quits
function quit() {
    // write properties before quitting
    writeProperties();
}


// --- MAIN FUNCTION ---

function main(aApps=[]) {

    let myErr;

    // wrap everything in a try to catch all errors
    try {

        // APP INIT
        
        // set up data path & settings file
        gCoreInfo = {};
        try {
            ObjC.import('stdlib');
            gCoreInfo.dataPath = $.getenv('HOME') + '/Library/Application Support/Epichrome';
            gCoreInfo.settingsFile = gCoreInfo.dataPath + "/epichrome.plist";
        } catch (myErr) {
            gCoreInfo.dataPath = '';
            gCoreInfo.settingsFile = '';
        }
        
        // read in persistent properties
        readProperties();
        
        // initialize core, optionally check github for updates
        let myInitInfo = JSON.parse(shell(
            'coreDoInit=1',
            'epiAction=init',
            'epiGithubFatalError=' + (gEpiGithubFatalError ? '1' : '')
        ));
        
        // check for core errors
        if (myInitInfo.core.error) {
            throw Error(myInitInfo.core.error);
        }
        
        // make sure data path matches
        if (myInitInfo.core.dataPath != gCoreInfo.dataPath) {
            throw Error('Got unexpected Epichrome data path.');
        }
        
        // replace old core info with init info
        myInitInfo.core.settingsFile = gCoreInfo.settingsFile;
        gCoreInfo = myInitInfo.core;
        
        // init engine list
        for (let curEng of kEngines) {
            curEng.button = engineName(curEng);
        }
        
        // handle any GitHub updates found during init
        if (myInitInfo.github) {
            handleGithubUpdate(myInitInfo.github);
        }
        
        
        // HANDLE RUN BOTH WITH AND WITHOUT DROPPED APPS

        if (aApps.length == 0) {

            while (true) {
                // no dropped files, so ask user for run mode
                let myDlgResult = dialog('Would you like to create a new app, or edit existing apps?', {
                    withTitle: 'Select Action | Epichrome EPIVERSION',
                    withIcon: kEpiIcon,
                    buttons: ['Create', 'Edit', 'Quit'],
                    defaultButton: 1,
                    cancelButton: 3
                }).buttonIndex;

                if (myDlgResult == 0) {

                    // Create button

                    return runCreate();

                } else if (myDlgResult == 1) {

                    // Edit/Update button

                    // show file selection dialog
                    let aApps = fileDialog('open', gEpiLastDir, 'edit', {
                        withPrompt: 'Select any apps you want to edit or update.',
                        ofType: ["com.apple.application"],
                        multipleSelectionsAllowed: true,
                        invisibles: false
                    });
                    if (!aApps) {
                        // canceled: ask user to select action again
                        continue;
                    }

                    // if we got here, the user chose files
                    return runEdit(aApps);

                } else {
                    if (confirmQuit()) { return; }
                }
            }
        } else {

            // we have dropped apps, so go straight to edit
            return runEdit(aApps);
        }
    } catch(myErr) {
        errlog(myErr.message, 'FATAL');
        kApp.displayDialog("Fatal error: " + myErr.message, {
            withTitle: 'Error',
            withIcon: 'stop',
            buttons: ["Quit"],
            defaultButton: 1
        });
    }
}


// --- CREATE AND EDIT MODES ---

// RUNCREATE: run in create mode
function runCreate() {
    
    // create default app dir if it doesn't already exist
    
    if (!gEpiDefaultAppDirCreated) {
        
        // run epichrome.sh to create directory
        let myDefaultAppDir = shell('epiAction=defaultappdir');
        
        // handle default app dir
        if (myDefaultAppDir) {
            
            // we won't try it again, even if there was an error
            gEpiDefaultAppDirCreated = true;
            
            // set up messages
            let myDeviceNote = ['Because Epichrome is installed on a different drive from the /Applications folder, your apps will not be able to use extensions like 1Password that require a validated browser. If you want to create apps for use with 1Password, you should first move Epichrome to /Applications.'];
            
            if (myDefaultAppDir.startsWith('ERROR|')) {
                // warn the user
                let myDlgMessage = 'Unable to create Apps folder. (' + myDefaultAppDir.slice(6) + ')';
                
                // add messages based on location of Epichrome
                if (gCoreInfo.epiPath.startsWith('/Applications/Epichrome/')) {
                    // Epichrome.app is in /Applications/Epichrome
                    myDlgMessage += '\n\nIt is strongly recommended you create a subfolder under /Applications/Epichrome for your apps.';
                } else if (!gCoreInfo.wrongDevice) {
                    // Epichrome.app is in /Applications or on same volume
                    myDlgMessage += '\n\nIt is strongly recommended you create a subfolder under /Applications for your apps.';
                } else {
                    // Epichrome.app is on a different volume from /Applications
                    myDlgMessage += '\n\nAny apps you create MUST be on the same drive as Epichrome. ' + myDeviceNote;
                }
                
                // show warning
                dialog(myDlgMessage, {
                    withTitle: 'Warning',
                    withIcon: 'caution',
                    buttons: ['OK'],
                    defaultButton: 1
                });
            } else {
                
                // set default directories
                gEpiLastDir.create = myDefaultAppDir;
                if (!gEpiLastDir.edit) {
                    gEpiLastDir.edit = myDefaultAppDir;
                }
                
                // notify user of apps folder
                let myDlgMessage = 'A folder called "' + myDefaultAppDir.match('[^/]*$')[0] + '" has been created in the location where Epichrome is installed.';
                
                // add warnings based on location of Epichrome
                if (gCoreInfo.epiPath.startsWith('/Applications/')) {
                    // Epichrome.app is somewhere under /Applications
                    myDlgMessage += ' While you do not have to keep your apps there, it is strongly recommended you do.';
                } else if (!gCoreInfo.wrongDevice) {
                    // Epichrome.app is not in /Applications but on same volume
                    myDlgMessage += '\n\n' + kDotWarning + ' Because it is not a subfolder of /Applications, apps you put there will not be able to use extensions like 1Password that require a validated browser. If you want to create apps for use with 1Password, they must use the external engine and be put in a subfolder of /Applications.';
                } else {
                    // Epichrome.app is on a different volume from /Applications
                    myDlgMessage += '\n\n' + kDotWarning + ' ' + myDeviceNote;
                }
                
                // show warning
                dialog(myDlgMessage, {
                    withTitle: 'App Folder Created',
                    withIcon: kEpiIcon,
                    buttons: ['OK'],
                    defaultButton: 1
                });
            }
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


// RUNEDIT: run in edit mode
function runEdit(aApps) {

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
        let curAppFileInfo = getAppPathInfo(curAppPath);

        // initialize app object
        let curApp = {
            result: kStepResultSKIP,
        };

        try {

            // run core script to initialize
            curApp.appInfo = JSON.parse(shell(
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
        };

        // determine if the app's name matches the display name
        curApp.stepInfo.isOrigFilename =
            (curApp.appInfo.file.base.toLowerCase() == curApp.appInfo.displayName.toLowerCase());

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
            myDlgIcon = 'stop';
            if (myErrApps.length == 1) {
                myDlgMessage = 'Error reading ' + myErrApps[0].appInfo.file.name + ': ' + myErrApps[0].error;
            }
        }

        if ((myApps.length > 0) || (myErrApps.length > 1)) {
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


// --- STARTUP/SHUTDOWN FUNCTIONS ---

// READPROPERTIES: read properties user data, or initialize any not found
function readProperties() {

    let myProperties = null, myErr;
    
	// read in the property list
    if (gCoreInfo.settingsFile) {
        try {
            myProperties = kSysEvents.propertyListFiles.byName(gCoreInfo.settingsFile).contents.value();
        } catch(myErr) {
            // ignore
        }
    }
    
    // if no properties read in, we're done
    if (!myProperties) { return; }
    
    
    // SET PROPERTIES FROM THE FILE AND INITIALIZE ANY PROPERTIES NOT FOUND

    // EPICHROME SETTINGS

    // lastAppCreatePath (fall back to old lastAppPath)
	if (typeof myProperties["lastAppCreatePath"] === 'string') {
        gEpiLastDir.create = myProperties["lastAppCreatePath"];
    } else if (typeof myProperties["lastAppPath"] === 'string') {
        gEpiLastDir.create = myProperties["lastAppPath"];
    }

    // lastEditAppPath (fall back to create path)
	if (typeof myProperties["lastAppEditPath"] === 'string') {
        gEpiLastDir.edit = myProperties["lastAppEditPath"];
    } else if (gEpiLastDir.create) {
        gEpiLastDir.edit = gEpiLastDir.create;
    }
    
    // lastIconPath
    if (typeof myProperties["lastIconPath"] === 'string') {
        gEpiLastDir.icon = myProperties["lastIconPath"];
    }

    // defaultAppDirCreated
	if (typeof myProperties["defaultAppDirCreated"] === 'boolean') {
        gEpiDefaultAppDirCreated = myProperties["defaultAppDirCreated"];
    }

    // githubFatalError
	if (typeof myProperties["githubFatalError"] === 'string') {
        gEpiGithubFatalError = myProperties["githubFatalError"];
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

    // updateAction
	// if (new RegExp('^(' + Object.keys(kUpdateActions).join('|') + ')$').test(myProperties['updateAction'])) {
    //     gAppInfoDefault.updateAction = myProperties['updateAction'];
    // }
}


// HANDLEGITHUBUPDATE: handle any GitHub updates returned from core init
function handleGithubUpdate(aGithubInfo) {
    
    if (aGithubInfo.hasOwnProperty('version')) {
        
        // NEW VERSION FOUND
        
        // variables to pass back for writing info file
        let myNextVersion = '', myGithubDialogErr = '';
        
        let myErr;
        
        try {
            
            let myDlgResult;
            
            try {
                myDlgResult = dialog(aGithubInfo.message, {
                    withTitle: 'Update Available',
                    withIcon: kEpiIcon,
                    buttons:['Download', 'Remind Me Later', 'Ignore This Version'],
                    defaultButton: 1,
                    cancelButton: 2
                }).buttonIndex;
            } catch(myErr) {
                throw Error('Unable to display update dialog.');
            }
                
            if (myDlgResult == 0) {
                
                // DOWNLOAD button
                
                // open URLs
                try {
                    for (let curUrl of aGithubInfo.urls) {
                        kApp.openLocation(curUrl);
                    }
                } catch(myErr) {
                    // URL open didn't work -- still consider this version downloaded
                    errlog('Unable to open update URL. (' + myErr.message + ')');
                    try {
                        dialog('Unable to open update page on GitHub. Please try downloading this update yourself at the following URL:\n\n' + aGithubInfo.urls[1], {
                            withTitle: 'Unable To Download',
                            withIcon: 'caution',
                            buttons: ['OK'],
                            defaultButton: 1
                        });
                    } catch(myErr) {
                        // ignore errors with this dialog
                    }
                }
                
                // mark this version as downloaded
                myNextVersion = aGithubInfo.version;
                
            } else if (myDlgResult == 1) {
                
                // LATER button -- just clear next version
            } else {
                
                // IGNORE button -- mark this version as downloaded
                myNextVersion = aGithubInfo.version;
            }
        } catch(myErr) {
            myGithubDialogErr = myErr.message;
            myNextVersion = aGithubInfo.prevGithubVersion;
            errlog(myErr.message);
        }
        
        // write to GitHub info file
        let myWriteResult = shell('epiAction=githubresult',
            'epiGithubDialogErr=' + myGithubDialogErr,
            'epiCheckDate=' + aGithubInfo.checkDate,
            'epiGithubLastError=' + aGithubInfo.lastError,
            'epiNextVersion=' + myNextVersion);
        
        // if any errors are returned, handle them
        if (myWriteResult) {
            aGithubInfo = JSON.parse(myWriteResult);
        }
    }
    
    
    // HANDLE GITHUB UPDATE ERRORS
    
    if (aGithubInfo.hasOwnProperty('error')) {
        
        // if there's a warning message, display alert
        if (aGithubInfo.error) {
            dialog(aGithubInfo.error, {
                withTitle: 'Checking For Update',
                withIcon: 'caution',
                buttons: ['OK'],
                defaultButton: 1
            });
        }
        
        // if this is a fatal error, save that info
        gEpiGithubFatalError = aGithubInfo.isFatal;
        
        // flag an error
        return false;
    }
    
    // success
    return true;
}


// WRITEPROPERTIES: write properties back to plist file
function writeProperties() {
    
    // if we don't have a settings file, we're done
    if (!gCoreInfo.settingsFile) { return; }
    
    let myProperties, myErr;
    
    debuglog("Writing preferences.");
    
    try {
        // create empty plist file
        myProperties = kSysEvents.PropertyListFile({
            name: gCoreInfo.settingsFile
        }).make();

        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"lastAppCreatePath",
                value:gEpiLastDir.create
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"lastAppEditPath",
                value:gEpiLastDir.edit
            })
        );
        // fill property list with Epichrome state
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind: "string",
                name: "lastIconPath",
                value: gEpiLastDir.icon
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"boolean",
                name:"defaultAppDirCreated",
                value:gEpiDefaultAppDirCreated
            })
        );
        myProperties.propertyListItems.push(
            kSysEvents.PropertyListItem({
                kind:"string",
                name:"githubFatalError",
                value:gEpiGithubFatalError
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
        // myProperties.propertyListItems.push(
        //     kSysEvents.PropertyListItem({
        //         kind: "string",
        //         name: "updateAction",
        //         value: gAppInfoDefault.updateAction
        //     })
        // );
    } catch(myErr) {
        // ignore errors, we just won't have persistent properties
    }
}


// --- BUILD STEPS ---

// DOSTEPS: run a set of build or edit steps
function doSteps(aSteps, aInfo, aOptions={}) {
    // RUN THE STEPS TO BUILD THE APP
    
    // start on step 0
    let myNextStep = 0;
    
    // assume success
    let myResult = kStepResultSUCCESS;
    
    let myStepResult;
    
    while (true) {

        // backed out of the first step
        if (myNextStep < 0) {
            
            // if no confirm
            if (aOptions.abortSilent) {
                return kStepResultSKIP;
            }
            
            // normalize
            myNextStep = -1;

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

            // confirm back-out
            myDlgResult = dialog(myDlgMessage, {
                withTitle: myDlgTitle,
                withIcon: aInfo.stepInfo.dlgIcon,
                buttons: myDlgButtons,
                defaultButton: 2,
                cancelButton: 1
            }).buttonIndex;

            // return appropriate value
            if (myDlgResult == 0) {
                // No button -- continue with steps
                myNextStep -= myStepResult;
            } else if (myDlgResult == 1) {
                // Yes button -- end steps
                return myResult;
            } else {
                // Quit button -- send Quit result
                return kStepResultQUIT;
            }
        } else if (myNextStep >= aSteps.length) {
            
            // past the end of our steps, so we're done
            break;
        }
        
        if (myNextStep == 0) {
            if (aOptions.abortBackButton) {
                aInfo.stepInfo.backButton = aOptions.abortBackButton;
            } else {
                if (aInfo.stepInfo.isOnlyApp) {
                    aInfo.stepInfo.backButton = 'Quit';
                } else {
                    aInfo.stepInfo.backButton = 'Abort';
                }
            }
        } else {
            aInfo.stepInfo.backButton = 'Back';
        }
        
        // set step number
        aInfo.stepInfo.number = myNextStep;

        if (aInfo.stepInfo.action != kActionUPDATE) {

            // set step dialog title
            aInfo.stepInfo.numText = (aOptions.stepTitle ? aOptions.stepTitle : 'Step') + ' ' + (myNextStep + 1).toString() +
                ' of ' + aSteps.length.toString();
            aInfo.stepInfo.dlgTitle = aInfo.stepInfo.titlePrefix + ' | ' + aInfo.stepInfo.numText;
            
            // in edit mode, add status dot
            if (aInfo.stepInfo.action == kActionEDIT) {
                let myStatusDot = (aInfo.appInfoStatus.version.changed ? kDotNeedsUpdate : kDotCurrent);
                if (Object.keys(aInfo.appInfoStatus).filter(x => x != 'version').reduce((a,v) => a || aInfo.appInfoStatus[v].changed, false)) {
                    myStatusDot = kDotChanged;
                }
                aInfo.stepInfo.dlgTitle = myStatusDot + ' ' + aInfo.stepInfo.dlgTitle;
            }
        }
        
        // RUN THE NEXT STEP

        myStepResult = aSteps[myNextStep](aInfo);
        
        
        // CHECK RESULT OF STEP

        if (typeof(myStepResult) == 'number') {

            // FORWARD OR BACK: MOVE ON TO ANOTHER STEP

            // move forward, backward, or stay on the same step
            myNextStep += myStepResult;

            continue;

        } else if (typeof(myStepResult) == 'object') {

            // STEP RETURNED ERROR
            
            errlog(myStepResult.message, myStepResult.backStep ? 'ERROR' : 'FATAL');
            
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

                    // Back button
                    if (myStepResult.resetProgress) {
                        Progress.completedUnitCount = 0;
                        Progress.description = myStepResult.resetMsg;
                        Progress.additionalDescription = '';
                    }
                    myNextStep += myStepResult.backStep;
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


// STEPCREATEDISPLAYNAME: step function to get display name and app path for CREATE action
function stepCreateDisplayName(aInfo) {

    // status variable
	let myErr;

    // CHOOSE WHERE TO SAVE THE APP

    let myDlgOptions = {
        withPrompt: aInfo.stepInfo.numText + ': Select name and location for the app.',
        defaultName: aInfo.appInfo.displayName
    };

    let myTryAgain = true;
    while (myTryAgain) {

        myTryAgain = false; // assume we'll succeed

        let myAppPath;
        
        // save current last dir in case of certain warnings/errors
        let myLastDir = gEpiLastDir.create;

        // show file selection dialog
        myAppPath = fileDialog('save', gEpiLastDir, 'create', myDlgOptions);
        if (!myAppPath) {
            // canceled
            return -1;
        }

        // break down the path & canonicalize app name
        let myOldFile = aInfo.appInfo.file;
        let myOldShortName = aInfo.appInfo.shortName;
        if (!getAppPathInfo(myAppPath, aInfo.appInfo)) {
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
        
        // check for problems/warnings with this location
        let myPathCheck = JSON.parse(shell(
            'epiAction=checkpath',
            'appDir=' + aInfo.appInfo.file.dir,
            'appPath=' + aInfo.appInfo.file.path
        ));
        
        // warning dialog info
        let myWarnMessageList = [];
        let myWarnMessage = '';
        let myWarnOverride = true;
        let myWarnReplace = false;
        let myWarnOptions = {
            buttons: ['OK'],
            defaultButton: 1
        };
        
        // start building warning message
        if (!myPathCheck.canWriteDir) {
            myWarnMessageList.push("You don't have permission to write to that folder. Please choose another location for your app.");
            myWarnOverride = false;
            
            // bad location, so reset lastDir
            gEpiLastDir.create = myLastDir;
            
        } else if (myPathCheck.appExists) {
            myWarnMessageList.push('A file or folder named "' + aInfo.appInfo.file.name + '" already exists in that location.');
            if (!myPathCheck.canWriteApp) {
                myWarnMessageList[0] += 'Please choose another location or name for your app.';
                myWarnOverride = false;
            } else {
                myWarnReplace = true;
                if (!(myPathCheck.rightDevice && myPathCheck.inApplicationsFolder)) {
                    myWarnMessageList[0] += ' If you continue, it will be overwritten.';
                }
            }
        }
        
        // if we don't have an unrecoverable problem, add any other problems
        if (myWarnOverride) {
            
            // only add these location warnings if this is a new location from last time
            if (myLastDir != gEpiLastDir.create) {

                // location is on the wrong device
                if (!myPathCheck.rightDevice) {
                    myWarnMessageList.push('That location is on a different drive than Epichrome. If you create the app there, it will NOT work until you move it onto the same drive as Epichrome.');
                }
                
                // location isn't in the Applications folder
                if (!myPathCheck.inApplicationsFolder) {
                    myWarnMessageList.push('That location is not a subfolder of /Applications, so the app will not be able to use extensions like 1Password that require a validated browser.');
                }
            }
            
            // add on the final prompt & format the final message
            if (myWarnMessageList.length > 0) {
                if ((myWarnMessageList.length == 1) && myWarnReplace) {
                    myWarnMessage = myWarnMessageList[0] + ' Do you want to replace it?';
                } else {
                    if (myWarnMessageList.length > 1) {
                        myWarnMessageList.unshift('Your selected location has ' + myWarnMessageList.length.toString() + ' warnings:');
                        myWarnMessage = myWarnMessageList.join('\n\n   ' + kDotSelected + ' ');
                    } else {
                        myWarnMessage = myWarnMessageList[0];
                    }
                    myWarnMessage += '\n\nDo you want to continue anyway?';
                }
                
                // set up dialog options
                myWarnOptions.withTitle = 'Warning';
                myWarnOptions.withIcon = 'caution';
                myWarnOptions.buttons.unshift('Cancel');
            }
        } else {
            // set up dialog options for uncancelable dialog
            myWarnOptions.withTitle = 'Error';
            myWarnOptions.withIcon = 'stop';
        }
        
        // if there are any warnings, display dialog
        if (myWarnMessageList.length > 0) {
            if (dialog(myWarnMessage, myWarnOptions).buttonIndex == 0) {
                myTryAgain = true;
                
                // if we're cancelling anything other than a replace, reset lastdir
                if ((myWarnMessageList.length > 1) || !myWarnReplace) {
                    // bad location, so reset lastDir
                    gEpiLastDir.create = myLastDir;
                }
                
                // try again
                continue;
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
        myAppShortNamePrompt = 'Edit ' +  myAppShortNamePrompt;
    }

    myTryAgain = true;
    while (myTryAgain) {

        // assume success
        myTryAgain = false;
        
        myDlgResult = stepDialog(aInfo,
            myAppShortNamePrompt + aInfo.appInfoStatus.shortName.stepSummary, {
                defaultAnswer: aInfo.appInfo.shortName,
                buttons: ['OK'],
            }
        );
        
        if (myDlgResult.buttonIndex == 1) {
            // Back button
            return -1;
        }
        
        myDlgResult = myDlgResult.textReturned;
        if (myDlgResult.length > 16) {
            myTryAgain = true;
            myAppShortNamePrompt = kDotWarning + " That name is too long. Please limit the name to 16 characters or less.";
            aInfo.appInfo.shortName = myDlgResult.slice(0, 16);
        } else if (myDlgResult.length == 0) {
            myTryAgain = true;
            myAppShortNamePrompt = kDotWarning + " No name entered. Please try again.";
        }
    }
    
    // if we got here, we have a good name
    updateAppInfo(aInfo, 'shortName', myDlgResult);
    
    // create automatic ID if needed
    if (!aInfo.appInfo.id) {
        createAppID(aInfo);
    }
    
    // move on
    return 1;
}


// STEPID: step function for setting app ID
function stepID(aInfo) {

    // status variables
    let myTryAgain, myErr, myDlgResult;
    let myDlgMessage, myDlgOptions;


    // SET UP DIALOG

    // ID warnings & limits
    const myIDWarning = "It is STRONGLY recommended not to have multiple apps with the same ID. They will interfere with each other's engine and data directories, which can cause many problems including data corruption and inability to run.";
    function myIDCheckErrorWarning(aErr) {
        return 'THIS ID MAY NOT BE UNIQUE. There was an error checking for other apps on the system with the same ID. (' + aErr + ') ' + myIDWarning;
    }
    const myIDLimits = '12 characters or less with only unaccented letters, numbers, and the symbols - and _';
    
    // start building dialog message & buttons
    myDlgMessage = ' a custom app ID (' + myIDLimits + ')';
    myDlgOptions = { defaultAnswer: aInfo.appInfo.id, buttons: ['OK'] };
    
    // customize dialog message & buttons
    if (aInfo.stepInfo.action == kActionCREATE) {
        if (aInfo.stepInfo.isCustomID) {
            myDlgOptions.buttons.push('Use Default (' + aInfo.stepInfo.autoID + ')');
        } else {
            myDlgOptions.buttons.push('Keep Default (' + aInfo.stepInfo.autoID + ')');
            myDlgOptions.defaultButton = 2;
        }
        myDlgMessage = 'Enter' + myDlgMessage + '.';
    } else if (aInfo.stepInfo.action == kActionEDIT) {
        if (aInfo.stepInfo.autoID) {
            if (aInfo.stepInfo.isCustomID) {
                myDlgOptions.buttons.push('Use Default (' + aInfo.stepInfo.autoID + ')');
            } else {
                myDlgOptions.buttons.push('Keep Default (' + aInfo.stepInfo.autoID + ')');
                myDlgOptions.defaultButton = 2;
            }
        } else {
            myDlgOptions.buttons.push('Create Default');
        }
        if (aInfo.appInfoStatus.shortName.changed && (!aInfo.appInfoStatus.id.changed)) {
            myDlgMessage = kDotWarning + " The app's short name has changed, but its ID has not.\n\nYou may enter" + myDlgMessage;
        } else {
            myDlgMessage = 'Enter' + myDlgMessage;
        }
        myDlgMessage += ', or click "' + myDlgOptions.buttons[1] + '" to let Epichrome create one.';
    }

    // if (aInfo.stepInfo.autoIDError) {
    //     myDlgMessage += '\n\n' +
    //         kDotWarning + ' ' + myIDCheckErrorWarning(aInfo.stepInfo.autoIDError.message) +
    //         '\n\nUnless you know what you are doing, you should click "Choose Custom ID" and create an ID you know to be unique.';
    //     myDlgOptions.defaultButton = 2;
    // }
    
    
    // LOOP TILL WE HAVE AN ACCEPTABLE ID
    
    while (true) {
        
        // display dialog
        myDlgResult = stepDialog(aInfo, myDlgMessage + aInfo.appInfoStatus.id.stepSummary, myDlgOptions);
        
        if (myDlgResult.buttonIndex == 0) {

            // NEW CUSTOM ID CHOSEN

            // error-check new ID
            let myHasErrors = false;
            myDlgMessage = [];
            let myIDDefault = myDlgResult.textReturned;
            if (myDlgResult.textReturned.length < 1) {
                myHasErrors = true;
                myDlgMessage.push('is empty');
                myIDDefault = aInfo.appInfo.id;
            } else {
                if (kAppIDLegalCharsRe.test(myDlgResult.textReturned)) {
                    myHasErrors = true;
                    myDlgMessage.push('contains illegal characters');
                    myIDDefault = myIDDefault.replace(kAppIDLegalCharsRe, '');
                }
                if (myDlgResult.textReturned.length > kAppIDMaxLength) {
                    myHasErrors = true;
                    myDlgMessage.unshift('is too long');
                    myIDDefault = myIDDefault.slice(0, kAppIDMaxLength);
                }
            }

            // build error message and try again
            if (myHasErrors) {
                myDlgMessage = kDotWarning + ' The entered ID ' +
                    myDlgMessage.join(' and ') +
                    '.\n\nPlease enter a new ID using ' + myIDLimits + '.';
                myDlgOptions.defaultAnswer = myIDDefault;
                continue;
            }

            // if we got here, we have a legal ID

            // if we already know this ID, we're done
            if ((myDlgResult.textReturned == aInfo.appInfo.id) ||
                ((aInfo.stepInfo.action == kActionEDIT) &&
                    (myDlgResult.textReturned == aInfo.oldAppInfo.id))) {
                break;
            }

            // this is a new ID, so check for uniqueness
            let myIsUnique = appIDIsUnique(myDlgResult.textReturned);
            let myConfirmMessage = null;

            if (myIsUnique instanceof Object) {

                // we got an error checking for uniqueness
                myConfirmMessage = myIDCheckErrorWarning(myIsUnique.message) +
                    '\n\nUnless you know this ID is in fact unique, you should select another one.';
                myIsUnique = false;
            }

            if (myIsUnique) {

                // unique ID -- moving on
                break;

            } else {

                // ID is not unique (or we had an error while checking)

                // if not unique, build message prefix
                if (!myConfirmMessage) {
                    myConfirmMessage = 'THAT ID IS NOT UNIQUE. There is already an app with ID "' + myDlgResult.textReturned + '" on the system.\n\n' + myIDWarning +
                        '\n\nUnless you know what you are doing, you should select another one.';
                }

                // finish confirm message
                myConfirmMessage += ' Do you want to use this ID anyway?';

                // display confirm dialog
                if (dialog(myConfirmMessage, {
                    withTitle: 'Duplicate ID',
                    withIcon: 'caution',
                    buttons: ['Cancel', 'OK'],
                    defaultButton: 1,
                    cancelButton: 1
                }).buttonIndex == 0) {
                    // Cancel -- try again
                    myDlgMessage = 'Enter a new app ID (' + myIDLimits + ')';
                    myDlgOptions.defaultAnswer = myDlgResult.textReturned;
                    continue;
                } else {
                    // OK
                    break;
                }
            }

        } else if (myDlgResult.buttonIndex == 1) {
            // DEFAULT ID button
            createAppID(aInfo);
            return 1;
        } else {
            // Back
            return -1;
        }

        // we should never get here
        return 0;
    }
    
    // if we got here, we have chosen an ID
    updateAppInfo(aInfo, 'id', myDlgResult.textReturned);

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
        
        myDlgResult = stepDialog(aInfo, myDlgMessage + aInfo.appInfoStatus.urls.stepSummary, {
            defaultAnswer: aInfo.appInfo.urls[0],
            buttons: ['OK']
        });
        if (myDlgResult.buttonIndex == 0) {
            // OK button
            aInfo.appInfo.urls[0] = myDlgResult.textReturned;
        } else {
            // BACK button
            return -1;
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
        
        // set up dialog options
        let myDlgOptions = {
            withTitle: aInfo.stepInfo.dlgTitle,
            withIcon: aInfo.stepInfo.dlgIcon
        };
        
        // default button for the Add/Done dialog
        // set default button
        let myDefaultButton = 2;
        // if ((aInfo.stepInfo.action == kActionEDIT) && !aInfo.stepInfo.urlsAddedOrRemoved) {
        //     myDefaultButton = 2;
        // }
        
        while (true) {

            if (myCurTab > aInfo.appInfo.urls.length) {

                // we're past the end of the entered URLs, so show the Add/Done dialog
                myDlgOptions.defaultAnswer = kAppDefaultURL;
                myDlgOptions.buttons = ['Add', "Done (Don't Add)"];
                myDlgOptions.cancelButton = 3;
                
                if (myCurTab == 1) {
                    
                    // no URLs yet

                    // use Back button
                    myDlgOptions.buttons.push(aInfo.stepInfo.backButton);

                    // if we're in create mode, or if we're editing and have deleted
                    // tabs that had been in the app, default to Add
                    if ((aInfo.stepInfo.action == kActionCREATE) ||
                        (aInfo.oldAppInfo.urls.length > 0)) {
                        myDefaultButton = 1;
                    }
                } else {
                    
                    // URLs selected
                    
                    // use Previous button
                    myDlgOptions.buttons.push('Previous');
                }
                
                // set default button
                myDlgOptions.defaultButton = myDefaultButton;
                
                // show dialog
                myDlgResult = dialog(
                    tablist(aInfo.appInfo.urls, myCurTab) + aInfo.appInfoStatus.urls.stepSummary,
                    myDlgOptions);
                if (myDlgResult.buttonIndex == 0) {
                    
                    // ADD button

                    // we've just added a URL, so default to the same for next URL
                    myDefaultButton = 1;
                    
                    // add the current text to the end of the list of URLs
                    aInfo.appInfo.urls.push(myDlgResult.textReturned);
                    updateAppInfo(aInfo, 'urls');
                    myCurTab++;
                    
                } else {
                    
                    // anything other than Add, default to Don't Add next time
                    myDefaultButton = 2;
                    
                    if (myDlgResult.buttonIndex == 1) {
                        
                        // DONE (DON'T ADD) button
                        
                        // we're done, don't add the current text to the list
                        break;
                        
                    } else {
                        
                        if (myCurTab == 1) {
                            // BACK button
                            myCurTab = 0;
                            break;
                        } else {
                            // PREVIOUS button
                            myCurTab--;
                        }
                    }
                }
            } else {
                
                // we're in the middle of existing URLs, so show the Next/Remove dialog
                myDlgOptions.defaultAnswer = aInfo.appInfo.urls[myCurTab-1];
                myDlgOptions.buttons = ['Next', 'Remove'];
                myDlgOptions.defaultButton = 1;

                // if this is the first URL, use Back button, otherwise use Previous
                if (myCurTab == 1) {
                    myDlgOptions.buttons.push(aInfo.stepInfo.backButton);
                    myDlgOptions.cancelButton = 3;
                } else {
                    myDlgOptions.buttons.push('Previous');
                    delete myDlgOptions.cancelButton;
                }
                
                // show dialog
                myDlgResult = dialog(
                    tablist(aInfo.appInfo.urls, myCurTab) + aInfo.appInfoStatus.urls.stepSummary,
                    myDlgOptions);

                if (myDlgResult.buttonIndex == 0) {

                    // NEXT button
                    
                    aInfo.appInfo.urls[myCurTab - 1] = myDlgResult.textReturned;
                    myCurTab++;

                } else if (myDlgResult.buttonIndex == 1) {

                    // REMOVE button
                    
                    // mark that we've removed a URL
                    aInfo.stepInfo.urlsAddedOrRemoved = true;
                                        
                    if (myCurTab == 1) {
                        aInfo.appInfo.urls.shift();
                    } else if (myCurTab == aInfo.appInfo.urls.length) {
                        aInfo.appInfo.urls.pop();
                        myCurTab--;
                    } else {
                        aInfo.appInfo.urls.splice(myCurTab-1, 1);
                    }
                } else {

                    if (myCurTab == 1) {
                        // BACK button
                        myCurTab = 0;
                        break;
                    } else {
                        // PREVIOUS button
                        aInfo.appInfo.urls[myCurTab - 1] = myDlgResult.textReturned;
                        myCurTab--;
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

            // set up file selection dialog options
            let myDlgOptions = {
                withPrompt: 'Select an image to use as an icon.',
                ofType: ["public.jpeg", "public.png", "public.tiff", "com.apple.icns"],
                invisibles: false
            };

            // show file selection dialog
            myIconSourcePath = fileDialog('open', gEpiLastDir, 'icon', {
                withPrompt: aInfo.stepInfo.numText + ': Select an image to use as an icon.',
                ofType: ["public.jpeg", "public.png", "public.tiff", "com.apple.icns"],
                invisibles: false
            });
            if (!myIconSourcePath) {
                // canceled: ask about a custom icon again
                return 0;
            }

            // update custom icon info
            aInfo.appInfo.icon = myIconSourcePath;

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


// STEPUPDATE: step function to set updating options
function stepUpdate(aInfo) {
    
    //    function stepDialog(aInfo, aMessage, aDlgOptions) {
    
    // status variables
	let myErr;

    // set up dialog message
    let myCurAction = kUpdateActions[aInfo.appInfo.updateAction];
    let myDlgMessage = 'How should this app handle updates when a new version of Epichrome is installed?';
    let myDlgButtons = {};
    myDlgButtons[myCurAction.button] = aInfo.appInfo.updateAction;
    let myDlgOtherOptions = Object.keys(kUpdateActions).filter(x => x != aInfo.appInfo.updateAction)
    myDlgButtons['Other Options'] = myDlgOtherOptions;
    
    // display default choice dialog
    let myDlgResult = stepDialog(aInfo, myDlgMessage + aInfo.appInfoStatus.updateAction.stepSummary[0], {
        key: 'updateAction',
        buttons: myDlgButtons
    });
    
    // process dialog result
    if (myDlgResult.canceled) {
        // BACK button
        return -1;
    } else if (myDlgResult.buttonIndex == 0) {
        // <CURRENT CHOICE> button
        updateAppInfo(aInfo, 'updateAction', myDlgResult.buttonValue);

    } else {

        // OTHER OPTIONS button
        
        // build dialog message and button map
        myDlgMessage = 'Should this app ' + kUpdateActions[myDlgOtherOptions[0]].message +
            ' or ' + kUpdateActions[myDlgOtherOptions[1]].message + '?';
        myDlgButtons = myDlgOtherOptions.reduce(function(obj, val) {
            obj[kUpdateActions[val].button] = val; return obj;
        }, {});
        let myButtonMap = dialogButtonMap(aInfo, 'updateAction', myDlgButtons);
        
        // build final button list
        myDlgButtons = Object.keys(myButtonMap.map);
        myDlgButtons.push('Cancel');
        
        // display dialog
        myDlgResult = dialog(myDlgMessage + aInfo.appInfoStatus.updateAction.stepSummary[1], {
            withTitle: 'Advanced Update Options',
            withIcon: kEpiIcon,
            buttons: myDlgButtons,
            defaultButton: myButtonMap.defaultButton,
            cancelButton: 3
        }, myButtonMap.map);
        
        // process dialog result
        if (myDlgResult.canceled) {
            // CANCEL button
            return 0;
        } else {
            // other choice selected
            updateAppInfo(aInfo, 'updateAction', myDlgResult.buttonValue);
        }
    }
    
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
                Object.entries(aInfo.appInfoStatus).filter(x => x[1].buildSummary && (aInfo.stepInfo.showAdvanced || (typeof(kAppInfoKeys[x[0]]) != 'string') || !kAppInfoKeys[x[0]].startsWith(kDotAdvanced))).map(x => x[1].buildSummary).join('\n\n');
            myActionButton = 'Create';
        } else {

            myScriptAction = 'edit';

            // edit summary of app & look for changes
            let myChangedSummary = [];
            let myUnchangedSummary = [];
            for (let [curKey, curItem] of Object.entries(aInfo.appInfoStatus).filter(x => Boolean(x[1].buildSummary))) {
                if (curItem.buildSummary &&
                    (aInfo.stepInfo.showAdvanced ||
                        typeof(kAppInfoKeys[curKey]) != 'string') ||
                        !kAppInfoKeys[curKey].startsWith(kDotAdvanced)) {
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

                    // set message/button for update only
                    myAppSummary = 'This app will be updated to version ' + kVersion +
                        '. No other changes have been made.';
                    myActionButton = 'Update';

                    // change script action to update
                    myScriptAction = 'update';

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
        myDlgResult = stepDialog(aInfo, myAppSummary, {buttons: [myActionButton, kDotAdvanced + ' Advanced Settings']}).buttonIndex;
        if (myDlgResult == 1) {
            // ADVANCED button
            aInfo.stepInfo.showAdvanced = true;
            doSteps([
                stepID,
                stepUpdate
            ], aInfo, {
                abortSilent: true,
                abortBackButton: 'Back',
                stepTitle: 'Advanced Setting'
            });
            return 0;
        } else if (myDlgResult == 2) {
            // BACK button
            return -1;
        }
        
        // if we got here, user clicked the BUILD button
        
        // if there are no changes, quit
        if (!myDoBuild) {
            // go to step -1 to trigger quit dialog
            return -aInfo.stepInfo.number - 1;
        }
    } else {
        // update action
        myScriptAction = 'update';
    }


    // BUILD SCRIPT ARGUMENTS

    let myScriptArgs = [
        'epiAction=' + myScriptAction,
        'CFBundleDisplayName=' + aInfo.appInfo.displayName,
        'CFBundleName=' + aInfo.appInfo.shortName,
        'SSBIdentifier=' + aInfo.appInfo.id,
        'SSBCustomIcon=' + (aInfo.appInfo.icon ? 'Yes' : 'No'),
        'SSBRegisterBrowser=' + (aInfo.appInfo.registerBrowser ? 'Yes' : 'No'),
        'SSBEngineType=' + aInfo.appInfo.engine.type + '|' + aInfo.appInfo.engine.id,
        'SSBUpdateAction=' + kUpdateActions[aInfo.appInfo.updateAction].value
    ];
    
    // add app command line
    myScriptArgs.push('SSBCommandLine=(');
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
        
        // CREATE-specific arguments
        myScriptArgs.push('epiAppPath=' + aInfo.appInfo.file.path);
        
    } else {
        // EDIT-/UPDATE-specific arguments

        // add version argument for both edit & update
        myScriptArgs.push('SSBVersion=' + aInfo.appInfo.version);
        
        if (aInfo.stepInfo.action == kActionEDIT) {
            // old ID
            if (aInfo.appInfoStatus.id.changed) {
                myScriptArgs.push('epiOldIdentifier=' + aInfo.oldAppInfo.id);
            }
            // old engine
            if (aInfo.appInfoStatus.engine.changed) {
                myScriptArgs.push('epiOldEngine=' + aInfo.oldAppInfo.engine.type + '|' + aInfo.oldAppInfo.engine.id);
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
        myBuildMessage = ['Building', 'Build', 'Configuring', 'Created'];
    } else if (aInfo.stepInfo.action == kActionEDIT) {
        myBuildMessage = ['Saving changes to', 'Save', 'Editing', 'Saved'];
    } else {
        myBuildMessage = ['Updating', 'Update', 'Canceled', 'Updated'];
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
        Progress.description = myBuildMessage[1] + ' succeeded.';
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

        if (myErr.message.startsWith('WARN\r')) {
            Progress.completedUnitCount = 2;
            Progress.description = myBuildMessage[1] + ' succeeded with warnings.';
            Progress.additionalDescription = '';

            // collate all warnings
            let myWarnings = myErr.message.split('\r');
            myWarnings.shift();
            
            let myWarningMsg = myBuildMessage[1] + ' succeeded, but with the following warning';
            if (myWarnings.length == 1) {
                myWarningMsg += ': ' + myWarnings[0];
            } else {
                myWarningMsg += 's:\n\n' + kIndent + kDotSelected + ' ' +
                    myWarnings.join('\n' + kIndent + kDotSelected + ' ');
            }
            dialog(myWarningMsg, {
                withTitle: 'Warning',
                withIcon: 'caution',
                buttons: ['OK'],
                defaultButton: 1
            });
        } else {
            Progress.completedUnitCount = 0;
            Progress.description = myBuildMessage[1] + ' failed.';
            Progress.additionalDescription = '';

            // show error dialog & quit or go back
            return {
                message: myBuildMessage[1] + ' failed: ' + myErr.message,
                title: 'Application Not ' + myBuildMessage[3],
                backStep: -1,
                resetProgress: true,
                resetMsg: myBuildMessage[2] + myAppNameMessage
            };
        }
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

        // launch
        if (myDlgResult == "Launch Now") {
            delay(1);
            try {
                launchApp(aInfo.appInfo.file.path);
            } catch(myErr) {
                kApp.displayDialog(myErr.message + ' Please try launching from the Finder.', {
                    withTitle: 'Unable to Launch',
                    withIcon: 'caution',
                    buttons: ['OK'],
                    defaultButton: 1
                });
                myDlgResult = "Reveal in Finder";
            }
        }

        // reveal
        if (myDlgResult == "Reveal in Finder") {
            kFinder.select(Path(aInfo.appInfo.file.path));
            kFinder.activate();
        }
    }

    // we're finished! quit
    return false;
}


// --- APP INFO FUNCTIONS ---

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
            
            // PATH

            if (aInfo.stepInfo.action == kActionCREATE) {

                // set build summary only in create mode
                curStatus.buildSummary = kAppInfoKeys.path + ':\n' + kIndent + dot() +
                    (aInfo.appInfo.file ? aInfo.appInfo.file.path : '[not yet set]');
            }

        } else if (curKey == 'version') {

            // VERSION

            if ((aInfo.stepInfo.action == kActionEDIT) && curStatus.changed) {

                // set build summary only if in edit mode & we need an update
                curStatus.buildSummary = kAppInfoKeys.version + ':\n' + kIndent +
                    kDotNeedsUpdate + ' ' + aInfo.appInfo.version;
            }

        } else if ((curKey == 'displayName') || (curKey == 'shortName')) {

            // DISPLAYNAME & SHORTNAME

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

        } else if (curKey == 'id') {

            // ID
            
            // set isCustomID
            aInfo.stepInfo.isCustomID = (aInfo.appInfo.id != aInfo.stepInfo.autoID);
            
            // step summary
            if (aInfo.stepInfo.action == kActionEDIT) {
                curStatus.stepSummary = '\n\n' + kIndent + dot() + aInfo.appInfo.id;
                if (curStatus.changed) {
                    curStatus.stepSummary += '  |  Was: ' + (aInfo.oldAppInfo.id ? aInfo.oldAppInfo.id : '[no ID]');
                }
            }
            
            // build summary
            curStatus.buildSummary = kAppInfoKeys.id + ':\n' +
                kIndent + dot() + aInfo.appInfo.id + '\n' +
                kIndent + dot() + '~/Library/Application Support/Epichrome/Apps/' + aInfo.appInfo.id;

        } else if (curKey == 'urls') {
            
            // URLS
            
            if (aInfo.appInfo.windowStyle == kWinStyleApp) {
                
                // set step summary for app-style URL only
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

            // REGISTERBROWSER

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

            // ICON

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

            // ENGINE
            
            // set common summary
            let curSummary = dot() + aInfo.appInfo.engine.button;

            // no step summary needed, but we'll set one for safety
            if (aInfo.stepInfo.action == kActionEDIT) {
                curStatus.stepSummary = '\n\n' + kIndent + curSummary;
            }

            // set build summary
            curStatus.buildSummary = kAppInfoKeys.engine + ':\n' + kIndent + curSummary;

        } else if (curKey == 'updateAction') {
            
            // UPDATEACTION
            
            // need two step summaries for the two levels of dialogs
            curStatus.stepSummary = ['', ''];
            
            // step summary -- show old value only
            if (aInfo.stepInfo.action == kActionEDIT) {
                
                // create basic summary for second-level dialog
                curStatus.stepSummary[1] = '\n\n' + kIndent + dot() +
                    kUpdateActions[aInfo.appInfo.updateAction].button;
                
                if (curStatus.changed) {
                    let curWasSummary = 'Was: ' +
                        kUpdateActions[aInfo.oldAppInfo.updateAction].button;
                    curStatus.stepSummary[0] = '\n\n' + kIndent + kDotChanged + curWasSummary;
                    curStatus.stepSummary[1] += '  |  ' + curWasSummary;
                }
            }
            
            // set build summary
            curStatus.buildSummary = kAppInfoKeys[curKey] + ':\n' + kIndent + dot() +
                kUpdateActions[aInfo.appInfo.updateAction].button;
            
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


// GETPATHINFO: break down a generic path
function getPathInfo(aPath) {

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

    } else {
        myResult = null;
    }

    return myResult;
}


// GETAPPPATHINFO: break down an app path & fill in extra info
function getAppPathInfo(aPath, aAppInfo=true) {

    // get basic path info
    let myResult;
    if (aPath instanceof Object) {
        myResult = ((aPath.path && aPath.name) ? aPath : null);
    } else {
        myResult = getPathInfo(aPath);
    }
    if (!myResult) { return null; }

    // set up app-specific info
    let myMatch = myResult.name.match(/^(.+)\.app$/i);
    if (myMatch) {
        myResult.base = myMatch[1];
        myResult.extAdded = false;
    } else {
        myResult.base = myResult.name;
        myResult.extAdded = true;
    }

    // if we've been passed an appInfo object, fill it in
    if (typeof(aAppInfo) == 'object') {

        // set appInfo file
        aAppInfo.file = myResult;

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


// VCMP: compare version numbers (v1 < v2: -1, v1 == v2: 0, v1 > v2: 1)
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


// --- APP ID FUNCTIONS ---

// APPIDISUNIQUE: check if an app ID is unique on the system
function appIDIsUnique(aID) {
    let myErr;
    try {
        return findAppByID(kBundleIDBase + aID).length == 0;
    } catch (myErr) {
        return myErr;
    }
}


// CREATEAPPID: create a unique app ID based on short name
function createAppID(aInfo) {

    let myResult;

    // flag that this app has an auto ID  $$$$ DELETE?
    // aInfo.stepInfo.isCustomID = false;

    if (aInfo.stepInfo.autoID) {

        // we already created an auto ID, so just use that
        myResult = aInfo.stepInfo.autoID;

    } else {

        // first attempt: use the short name with illegal characters removed
        myResult = aInfo.appInfo.shortName.replace(kAppIDLegalCharsRe,'');
        let myBase, myIsUnique;

        // if too many characters trimmed away, start with a generic ID
        if ((myResult.length < (aInfo.appInfo.shortName.length / 2)) ||
        (myResult.length < kAppIDMinLength)) {
            myBase = 'EpiApp';
            myIsUnique = false;
        } else {

            // trim ID down to max length
            myResult = myResult.slice(0, kAppIDMaxLength);

            // check for any apps that already have this ID
            myIsUnique = appIDIsUnique(myResult);

            // if ID checks failing, we'll tack on the first random ending we try
            if (myIsUnique instanceof Object) { myIsUnique = false; }

            // if necessary, trim ID again to accommodate 3-digit random ending
            if (!myIsUnique) { myBase = myResult.slice(0, kAppIDMaxLength - 3); }
        }

        // if ID is not unique, try to uniquify it
        while (!myIsUnique) {

            // add a random 3-digit extension to the base
            myResult = myBase +
            Math.min(Math.floor(Math.random() * 1000), 999).toString().padStart(3,'0');

            myIsUnique = appIDIsUnique(myResult);
        }

        // update step info about this ID
        aInfo.stepInfo.autoID = myResult;
        aInfo.stepInfo.autoIDError = ((myIsUnique instanceof Object) ? myIsUnique : false);
    }

    // update app info with new ID
    updateAppInfo(aInfo, 'id', myResult);

}


// --- DIALOG FUNCTIONS ---

// DIALOG: show a dialog & process the result
function dialog(aMessage, aDlgOptions={}, aButtonMap=null) {

    let myResult, myErr;
    
    if (typeof(aMessage) != 'string') { aMessage = JSON.stringify(aMessage, null, 3); }
    
    try {
        // display dialog
        myResult = kApp.displayDialog(aMessage, aDlgOptions);

        // add useful info if dialog not canceled
        myResult.canceled = false;
        if (aDlgOptions.buttons) {
            myResult.buttonIndex = aDlgOptions.buttons.indexOf(myResult.buttonReturned);
        } else {
            myResult.buttonIndex = 1;
        }
        
    } catch(myErr) {
        if (myErr.errorNumber == -128) {

            // back button -- create faux object
            if (aDlgOptions.buttons && aDlgOptions.cancelButton) {
                myResult = {
                    buttonReturned: aDlgOptions.buttons[aDlgOptions.cancelButton - 1],
                    buttonIndex: aDlgOptions.cancelButton - 1,
                    canceled: true
                };
            } else {
                myResult = {
                    buttonReturned: 'Cancel',
                    buttonIndex: 0,
                    canceled: true
                };
            }
        } else {
            throw myErr;
        }
    }
    
    // handle any button map
    if (aButtonMap) {
        
        // get the map for the chosen button
        let curButton = aButtonMap[myResult.buttonReturned];
        if (curButton === undefined) {
            curButton = { name: myResult.buttonReturned, value: myResult.buttonReturned };
        }
        
        // add button name & value to result
        myResult.buttonName = curButton.name;
        myResult.buttonValue = curButton.value;
    }
    
    // return object
    return myResult;
}


// FILEDIALOG: show a file selection dialog & process the result
function fileDialog(aType, aDirObj, aDirKey, aOptions={}) {

    let myResult, myErr;

    // add default location if we have one
    if (aDirObj[aDirKey]) {
        aOptions = objCopy(aOptions);
        aOptions.defaultLocation = aDirObj[aDirKey];
    }

    // show file selection dialog
    while (true) {
        try {

            // show the chosen type of dialog
            if ((typeof(aType) == 'string') && (aType.toLowerCase() == 'save')) {
                myResult = kApp.chooseFileName(aOptions).toString();
            } else {
                myResult = kApp.chooseFile(aOptions);
            }

            // if we got here, we got a path

            // process result
            let myFileDir;
            if (myResult instanceof Array) {
                if (myResult.length > 0) {
                    myFileDir = getPathInfo(myResult[0].toString());
                } else {
                    myFileDir = null;
                }
            } else {
                // return path info
                myResult = getPathInfo(myResult.toString());
                myFileDir = myResult;
            }

            // try to set this directory as default for next time
            if (myFileDir && myFileDir.dir) {
                aDirObj[aDirKey] = myFileDir.dir;
            }

            // and return
            return myResult;

        } catch(myErr) {

            if (myErr.errorNumber == -1700) {

                // bad defaultLocation, so try again with none
                aDirObj[aDirKey] = null;
                delete aOptions.defaultLocation;
                continue;

            } else if (myErr.errorNumber == -128) {

                // canceled: return null
                return null;

            } else {

                // unknown error
                throw myErr;
            }
        }
    }
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


// STEPDIALOG: show a standard step dialog
function stepDialog(aInfo, aMessage, aDlgOptions) {

    let myButtonMap = null;
    let myErr;
    
    // copy dialog options object
    let myDlgOptions = objCopy(aDlgOptions);
    
    // if aDlgOptions is a button map, build options from that
    if (myDlgOptions.hasOwnProperty('key')) {
        
        // ensure we have a button-to-value map
        myButtonMap = dialogButtonMap(aInfo, myDlgOptions.key, myDlgOptions.buttons);
                
        // update dialog options with button map info
        myDlgOptions.buttons = Object.keys(myButtonMap.map);
        if (!myDlgOptions.hasOwnProperty('defaultButton')) {
            myDlgOptions.defaultButton = myButtonMap.defaultButton;
        }
        delete myDlgOptions.key;
        
        // we're done with everything except the map
        myButtonMap = myButtonMap.map;
    }
    
    // fill in boilerplate
    if (!myDlgOptions.withTitle) { myDlgOptions.withTitle = aInfo.stepInfo.dlgTitle; }
    if (!myDlgOptions.withIcon) { myDlgOptions.withIcon = aInfo.stepInfo.dlgIcon; }
    
    // add back button
    myDlgOptions.buttons.push(aInfo.stepInfo.backButton);
    if (!myDlgOptions.defaultButton) { myDlgOptions.defaultButton = 1; }
    if (!myDlgOptions.cancelButton) { myDlgOptions.cancelButton = myDlgOptions.buttons.length; }
    
    return dialog(aMessage, myDlgOptions, myButtonMap);
}


// DIALOGBUTTONMAP: set up a button map for a step dialog
function dialogButtonMap(aInfo, aKey, aButtonInfo) {
    
    // ensure we have a button-to-value map
    if (aButtonInfo instanceof Array) {
        // turn button array into a one-to-one dict
        aButtonInfo = aButtonInfo.reduce(function (obj,val) { obj[val] = val; return obj; }, {});
    }
    
    // build button map
    let myAppValue = aInfo.appInfo[aKey];
    let curButtonNum = 1;
    let myButtonMap = {};
    let myDefaultButton = 1;
    for (let curButtonName in aButtonInfo) {
        
        // default button title
        let curButtonTitle = curButtonName;
        let curButtonValueList = aButtonInfo[curButtonName];
        
        // convert single match value to an array
        if ((! (curButtonValueList instanceof Array)) || myAppValue instanceof Array) {
            curButtonValueList = [curButtonValueList];
        }
        
        // put a dot on the selected button
        if (curButtonValueList.reduce((acc, val) => (acc || objEquals(val, myAppValue)), false)) {
            let curDot = ((aInfo.stepInfo.action == kActionCREATE) ? kDotSelected :
                            ((objEquals(myAppValue, aInfo.oldAppInfo[aKey])) ?
                            kDotCurrent : kDotChanged));
            curButtonTitle = curDot + ' ' + curButtonName;
            myDefaultButton = curButtonNum;
        }
        
        // add this button to button map
        myButtonMap[curButtonTitle] = { name: curButtonName, value: aButtonInfo[curButtonName] };
        
        // increment button number
        curButtonNum++;
    }
    
    return {
        map: myButtonMap,
        defaultButton: myDefaultButton
    };
}


// DIALOGINFO: set up button map and other info for a step dialog  $$$ DEPRECATED -- GET RID OF THIS
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


// INDENT: indent a string
function indent(aStr, aIndent) {
    // regex that includes empty lines: /^/gm

    if (typeof aIndent != 'number') { aIndent = 1; }
    if (aIndent < 0) { return aStr; }

    // indent string
    return aStr.replace(/^(?!\s*$)/gm, kIndent.repeat(aIndent));
}


// --- LOGGING FUNCTIONS ---

// ERRLOG -- log an error message
function errlog(aMsg, aType='ERROR') {
    if (gCoreInfo.logFile) {
        shell(
            'epiAction=log',
            'epiLogType=' + aType,
            'epiLogMsg=' + aMsg);
    }
}


// DEBUGLOG -- log a debugging message
function debuglog(aMsg) {
    errlog(aMsg, 'DEBUG');
}


// HASLOGFILE: check if a log file for this run exists
function hasLogFile() {
    return kFinder.exists(Path(gCoreInfo.logFile));
}


// SHOWLOGFILE: reveal log file in the Finder
function showLogFile() {
    kFinder.select(Path(gCoreInfo.logFile));
    kFinder.activate();
}


// --- SHELL INTERACTION FUNCTIONS ---

// SHELL: execute epichrome.sh with a list of arguments
function shell(...aArgs) {
    
    // if logging has been initialized, include logging variable
    if (gCoreInfo.logFile) { aArgs.unshift('myLogFile=' + gCoreInfo.logFile); }
    
    // start with the path to epichrome.sh
    aArgs.unshift(kEpichromeScript);
    
    // run the script
    return kApp.doShellScript(shellQuote.apply(null, aArgs));
}


// SHELLQUOTE: assemble a list of arguments into a shell string
function shellQuote(...aArgs) {
    let result = [];
    for (let s of aArgs) {
        result.push("'" + s.replace(/'/g, "'\\''") + "'");
    }
    return result.join(' ');
}


// --- OBJECT UTILITY FUNCTIONS ---

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
