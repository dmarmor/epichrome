//
//
//  reporterr.js: Script to report errors to GitHub from core.sh.
//
//  Copyright (C) 2022  David Marmor
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
const kFinder = Application('Finder');
// const kSysEvents = Application('System Events');


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

        if (aArgv.length < 1) {
            throw Error('Incorrect arguments.');
        }
        
        let iResult = reportError(aArgv[0], aArgv[1]);
        if (typeof iResult === 'string') {
            throw Error(iResult);
        }
    } catch(myErr) {
        print(myErr.message, true);
        $.exit(1);
    }
}
