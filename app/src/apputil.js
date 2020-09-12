//
//
//  apputil.js: launch an app, optionally with arguments and URLs
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
// const kSysEvents = Application('System Events');
// const kFinder = Application('Finder');


// OBJECTIVE-C SETUP

ObjC.import('stdlib');

function print(aStr, aToStderr=false) {
    let myStream = (aToStderr ?
        $.NSFileHandle.fileHandleWithStandardError :
        $.NSFileHandle.fileHandleWithStandardOutput);
    myStream.writeDataError($(aStr + '\n').dataUsingEncoding($.NSUTF8StringEncoding), null);
}

function run(aArgv) {

    let myErr;

    try {

        if (aArgv.length != 1) {
            throw Error('Incorrect arguments.');
        }

        let myArgs = JSON.parse(aArgv[0]);

        // action = register / launch / find
        if (myArgs.action == 'launch') {
            let myResult = launchApp(myArgs.path, myArgs.args, myArgs.urls, myArgs.options);
            return myResult.processIdentifier.toString();
        } else if (myArgs.action == 'register') {
            registerApp(myArgs.path);
        } else if (myArgs.action == 'find') {
            let myAppList = findAppByID(myArgs.id);
            return myAppList.join('\n');
        } else if (!myArgs.action) {
            throw Error('No action specified.');
        } else {
            throw Error('Unknown action "' + myArgs.action.toString() + '".');
        }

    } catch(myErr) {
        print(myErr.message, true);
        $.exit(1);
    }
}
