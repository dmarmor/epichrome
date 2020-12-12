//
//
//  libapp.js: JXA/Obj-C bridge calls to register, find & launch apps
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

    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print('Entering launchApp with:\naSpec = ' + aSpec + '\naArgs = ' + JSON.stringify(aArgs, null, 3) + '\naUrls = ' + JSON.stringify(aUrls, null, 3) + '\naOptions = ' + JSON.stringify(aOptions, null, 3)); }
    
    // prepare args for Obj-C
    aArgs = aArgs.map(x => $(x));
    
    // prepare URLs for Obj-C
    if (aUrls.length > 0) {
        aUrls = $(aUrls.map(x => $.NSURL.URLWithString($(x))));
    } else {
        aUrls = false;
    }
    
    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print('Urls mapped.'); }
    
    // if we got an ID, launch the first app with that ID
    if (aOptions.specIsID) {
        let myAppList = findAppByID(aSpec);
        if (myAppList.length < 1) {
            throw Error('No apps found with ID ' + aSpec);
        }
        aSpec = myAppList[0];

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("App path found from ID: '" + aSpec + "'."); }
    }
    
    // if we're supposed to register the app first, do that now
    if (aOptions.registerFirst) {
        registerApp(aSpec);
    }
    
    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print('App registered.'); }
    
    // prepare app spec for Obj-C
    aSpec = $.NSURL.fileURLWithPath($(aSpec));

    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print('Path converted to NSURL.'); }
    
    // name of app for errors
    let myAppName = aSpec.pathComponents.js;
    myAppName = ((myAppName.length > 0) ? '"' + myAppName[myAppName.length - 1].js + '"' : '<unknown app>');

    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print("App name parsed: '" + myAppName + "'."); }
    
    // launch info
    let myErr = undefined, myApp = undefined;

    // determine whether to use openApplicationAtURL or launchApplicationAtURL
    let myOSVersion = kApp.systemInfo().systemVersion.split('.').map(x => parseInt(x));
    let myUseOpen = ((myOSVersion.length >= 2) &&
        ((myOSVersion[0] > 10) || (myOSVersion[0] == 10) && (myOSVersion[1] >= 15)));

    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print("OS version parsed: '" + myOSVersion.join('.') + "'."); }
        
    if (myUseOpen) {

        // 10.15+

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("10.15+ so using Open."); }
        
        // set up open configuration
        let myConfig = $.NSWorkspaceOpenConfiguration.configuration;
        
        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Created configuration."); }
        
        // make sure engine doesn't fail to launch due to another similar engine
        myConfig.allowsRunningApplicationSubstitution = false;
        
        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Added running app option to config."); }
        
        // add any args
        if (aArgs.length > 0) { myConfig.arguments = $(aArgs); }

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Added args to config."); }
        
        // launch
        function myCompletionHandler(aApp, aErr) {
            myApp = aApp;
            myErr = aErr;
            
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("Completion handler set vars."); }
        }
        if (aUrls) {
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("URLs found so opening URLs."); }
            
            $.NSWorkspace.sharedWorkspace.openURLsWithApplicationAtURLConfigurationCompletionHandler(
                aUrls, aSpec, myConfig, myCompletionHandler);
        } else {
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("No URLs found so opening Application."); }
            
            $.NSWorkspace.sharedWorkspace.openApplicationAtURLConfigurationCompletionHandler(
                aSpec, myConfig, myCompletionHandler);
        }

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Open command complete."); }

        // wait for completion handler
        let myWait = 0.0;
        while ((myErr === undefined) && (myWait < 15.0)) {
            delay(0.1);
            myWait += 0.1;
        }
        if (myErr === undefined) {
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("Hit timeout."); }

            throw Error('Timed out waiting for ' + myAppName + ' to open.');
        }

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Got completion within timeout."); }

    } else {

        // 10.14-

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("10.14- so using Launch."); }
        
        // set up launch configuration
        let myConfigKeys = [], myConfigValues = [];
        if (aArgs.length > 0) {
            myConfigKeys.push($.NSWorkspaceLaunchConfigurationArguments);
            myConfigValues.push($(aArgs));
        }
        
        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Set up config keys & values."); }

        let myConfig = $.NSMutableDictionary.dictionaryWithObjectsForKeys(
            $(myConfigValues), $(myConfigKeys));
        
        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Created mutable config dictionary."); }

        // launch (error arg causes a crash, so ignore it)
        if (aUrls) {
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("URLs found so launching URLs."); }
            
            myApp = $.NSWorkspace.sharedWorkspace.openURLsWithApplicationAtURLOptionsConfigurationError(
                aUrls, aSpec, $.NSWorkspaceLaunchDefault | $.NSWorkspaceLaunchNewInstance, myConfig, null);
        } else {
            // $$$ WEIRD BUG DEBUGGING
            if (aOptions.debug) { print("No URLs found so launching Application."); }
            
            myApp = $.NSWorkspace.sharedWorkspace.launchApplicationAtURLOptionsConfigurationError(
                aSpec, $.NSWorkspaceLaunchDefault | $.NSWorkspaceLaunchNewInstance, myConfig, null);
        }

        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Launch command complete."); }

        // create generic error
        if (!myApp.js) {
            throw Error('The application ' + myAppName + ' could not be launched.');
        }
        
        // $$$ WEIRD BUG DEBUGGING
        if (aOptions.debug) { print("Launch command completed without error."); }
    }

    // throw any error encountered
    if (myErr && myErr.js) {
        throw Error(myErr.localizedDescription.js);
    }
    
    // $$$ WEIRD BUG DEBUGGING
    if (aOptions.debug) { print("launchApp completed successfully."); }
    
    // if we got here, we launched successfully
    return myApp;
}
