//
//
//  reporterr.js: Function for reporting errors to GitHub.
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


// REPORTERROR: report an error to GitHub
function reportError(aTitle, aLogFile=undefined) {
    
    let iResult, iErr;
    
    // get default log file if we have one
    if ((aLogFile === undefined) && gCoreInfo && gCoreInfo.logFile) {
        aLogFile = gCoreInfo.logFile;
    }
    
    // attempt to read in log
    let iLog = '';
    if (aLogFile) {
        aLogFile = Path(aLogFile);
        try {
            iLog = kApp.read(aLogFile);
            iLog = "\n\n[Below is a log of this run of Epichrome, which may be helpful in diagnosing this error. Please redact any paths or information you're not comfortable sharing before posting this issue.]\n\n```\n" + iLog + '\n```'
        } catch(iErr) {} // fail silently
    }
    
    // open a GitHub issue page populated with our error info
    try {
        kApp.openLocation('https://github.com/dmarmor/epichrome/issues/new?title=' +
        encodeURIComponent(aTitle) + '&body=' + encodeURIComponent('[Please provide as much detail as you can about how this error occurred.]' + iLog));
    } catch(iErr) {
        let iErrMsg = 'Unable to open GitHub issues page. (' + iErr.message + ')';
        if (typeof dialog === "function") {
            errlog(iErrMsg);
            dialog(iErrMsg + ' You will need to report this error manually.', {
                withTitle: 'Error',
                withIcon: 'stop',
                buttons: ['OK'],
                defaultButton: 1
            });
        } else {
            iResult = iErrMsg;
        }
    }
    
    if (aLogFile) {
        try {
            // reveal log file
            kFinder.select(aLogFile);
            kFinder.activate();
        } catch(iErr) {} // fail silently
    }
    
    // return any error message
    return iResult;
}
