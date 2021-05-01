//
//
//  libapp.js: JXA/Obj-C bridge calls to register, find & launch apps
//
//  Copyright (C) 2021  David Marmor
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


// OBJECTIVE-C SETUP

ObjC.import('CoreServices');
ObjC.import('AppKit');
ObjC.bindFunction('CFMakeCollectable', [ 'id', [ 'void *' ] ]);
Ref.prototype.toNS = function() { return $.CFMakeCollectable(this); }


// FUNCTIONS

// FINDAPPBYID: use launch services to find an app by its bundle ID
function findAppByID(aID) {

    // local state
    let myResult = [];
    let myErr = Ref();

    // check launch services for ID
    let myLSResult = $.LSCopyApplicationURLsForBundleIdentifier($(aID), myErr);
    myErr = myErr[0].toNS();

    // check for errors
    if (myErr.code) {
        if (myErr.code != $.kLSApplicationNotFoundErr) {

            // error
            let myErrID, myIgnore;
            try { myErrID = '"' + aID.toString() + '"'; } catch(myIgnore) { myErrID = '<unknown>'; }
            throw Error('Unable to search for apps with ID ' + myErrID + ': ' + myErr.localizedDescription.js);
            return null; // not reached
        }
    } else {

        // unwrap app list
        myLSResult = myLSResult.toNS().js;

        // create array of only app paths
        for (let curApp of myLSResult) {
            myResult.push(curApp.path.js);
        }
    }

    return myResult;
}


// REGISTERAPP: register an app with launch services
function registerApp(aPath) {

    let myUrl = $.NSURL.fileURLWithPath($(aPath));

    let myResult = $.LSRegisterURL(myUrl, true);

    if (myResult != 0) {
        throw Error('Error code ' + myResult.toString());
    }
}


// LAUNCHAPP: launch an app with arguments & URLs
function launchApp(aSpec, aArgs=[], aUrls=[], aOptions={}) {
    
    // prepare args for Obj-C
    aArgs = aArgs.map(x => $(x));
    
    // prepare URLs for Obj-C
    if (aUrls.length > 0) {
        aUrls = $(aUrls.map(x => $.NSURL.URLWithString($(x))));
    } else {
        aUrls = false;
    }
    
    // if we got an ID, launch the first app with that ID
    if (aOptions.specIsID) {
        let myAppList = findAppByID(aSpec);
        if (myAppList.length < 1) {
            throw Error('No apps found with ID ' + aSpec);
        }
        aSpec = myAppList[0];
        
    }
    
    // if we're supposed to register the app first, do that now
    if (aOptions.registerFirst) {
        registerApp(aSpec);
    }
    
    // set number of attempts before throwing an error
    let iMaxAttempts = 2;
    if (aOptions.maxAttempts) {
        iMaxAttempts = aOptions.maxAttempts;
    }
    
    // prepare app spec for Obj-C
    aSpec = $.NSURL.fileURLWithPath($(aSpec));
    
    // name of app for errors
    let myAppName = aSpec.pathComponents.js;
    myAppName = ((myAppName.length > 0) ? '"' + myAppName[myAppName.length - 1].js + '"' : '<unknown app>');
    
    // launch info
    let myLaunchErr = undefined, myApp = undefined;
    let myConfig;
    
    // determine whether to use openApplicationAtURL or launchApplicationAtURL
    let myOSVersion = kApp.systemInfo().systemVersion.split('.').map(x => parseInt(x));
    let myUseOpen = ((myOSVersion.length >= 2) &&
        ((myOSVersion[0] > 10) || (myOSVersion[0] == 10) && (myOSVersion[1] >= 15)));
    
    if (myUseOpen) {

        // setup for 10.15+

        // set up open configuration
        myConfig = $.NSWorkspaceOpenConfiguration.configuration;
        
        // make sure engine doesn't fail to launch due to another similar engine
        myConfig.allowsRunningApplicationSubstitution = false;
        
        // add any args
        if (aArgs.length > 0) { myConfig.arguments = $(aArgs); }

        // launch
        function myCompletionHandler(aApp, aErr) {
            myApp = aApp;
            myLaunchErr = aErr;
        }
    } else {
        
        // setup for 10.14-

        // set up launch configuration
        let myConfigKeys = [], myConfigValues = [];
        if (aArgs.length > 0) {
            myConfigKeys.push($.NSWorkspaceLaunchConfigurationArguments);
            myConfigValues.push($(aArgs));
        }
        
        myConfig = $.NSMutableDictionary.dictionaryWithObjectsForKeys(
            $(myConfigValues), $(myConfigKeys)
        );
    }
    
    // try to launch up to iMaxAttempts times
    let curAttempt = 1;
    while (true) {
        
        let iErr;
        try {
            
            if (myUseOpen) {
                
                // launch for 10.15+
                
                if (aUrls) {
                    $.NSWorkspace.sharedWorkspace.openURLsWithApplicationAtURLConfigurationCompletionHandler(
                        aUrls, aSpec, myConfig, myCompletionHandler
                    );
                } else {
                    $.NSWorkspace.sharedWorkspace.openApplicationAtURLConfigurationCompletionHandler(
                        aSpec, myConfig, myCompletionHandler
                    );
                }
                
                // wait for completion handler
                let myWait = 0.0;
                while ((myLaunchErr === undefined) && (myWait < 15.0)) {
                    delay(0.1);
                    myWait += 0.1;
                }
                if (myLaunchErr === undefined) {
                    throw Error('Timed out waiting for ' + myAppName + ' to open.');
                }
            } else {
                
                // launch for 10.14-
                
                // launch (error arg causes a crash, so ignore it)
                if (aUrls) {
                    myApp = $.NSWorkspace.sharedWorkspace.openURLsWithApplicationAtURLOptionsConfigurationError(
                        aUrls, aSpec, $.NSWorkspaceLaunchDefault | $.NSWorkspaceLaunchNewInstance, myConfig, null
                    );
                } else {
                    myApp = $.NSWorkspace.sharedWorkspace.launchApplicationAtURLOptionsConfigurationError(
                        aSpec, $.NSWorkspaceLaunchDefault | $.NSWorkspaceLaunchNewInstance, myConfig, null
                    );
                }
                
                // create generic error
                if (!myApp.js) {
                    throw Error('The application ' + myAppName + ' could not be launched.');
                }
            }
            
            // throw any error encountered
            if (myLaunchErr && myLaunchErr.js) {
                throw Error(myLaunchErr.localizedDescription.js);
            }
        } catch (iErr) {
            
            // this was our final attempt, so throw the error
            if (curAttempt == iMaxAttempts) {
                throw iErr;
            }
            
            // increment attempt counter and try again
            curAttempt++;
            continue;
        }
        
        // if we got here, we launched successfully
        return myApp;
    }
}
