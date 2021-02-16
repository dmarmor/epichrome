//
//
//  reporterr.js: Function for reporting errors to GitHub.
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

const kMaxUrlLength = 8196;

const kUrlStart = 'https://github.com/dmarmor/epichrome/issues/new?title=';
const kUrlBodyTag = '&body=';
const kBodyStart = '<!-- ℹ️ Please provide as much detail as you can about how this error occurred. -->';
const kLogPre = "\n\n<!-- ℹ️ Below is a log of this run of Epichrome, which may be helpful in diagnosing this error. Please redact any paths or information you're not comfortable sharing before posting this issue. -->\n\n```\n";
const kLogPost = '\n```';


// REPORTERROR: report an error to GitHub
function reportError(aTitle, aLogFile=undefined) {
    
    let iResult, iErr;
    
    // get default log file if we have one
    if ((aLogFile === undefined) && (typeof gCoreInfo !== 'undefined') &&
            gCoreInfo && gCoreInfo.logFile) {
        aLogFile = gCoreInfo.logFile;
    }
    
    // attempt to read in log
    let iLog = '';
    if (aLogFile) {
        aLogFile = Path(aLogFile);
        try {
            iLog = kApp.read(aLogFile);
        } catch(iErr) {} // fail silently
    }
    
    // open a GitHub issue page populated with our error info
    let iUrlStart = kUrlStart + encodeURIComponent(aTitle) + kUrlBodyTag + encodeURIComponent(kBodyStart);
    let iUrl = iUrlStart;
    
    try {
        
        // add in log
        if (iLog) {
            
            // ensure URL isn't too long with log
            iUrl += encodeURIComponent(kLogPre + iLog + kLogPost);
            
            // if too long, ask for it to be manually pasted in
            if (iUrl.length >= kMaxUrlLength) {
                iUrl = iUrlStart + encodeURIComponent("\n\n<!-- ❗ The log file is too long to include in the URL. To help diagnose this error, please copy the log and paste the log in the area below. Please redact any paths or information you're not comfortable sharing before posting this issue. -->\n\n```\n[ℹ️ PASTE LOG HERE]\n```");
            }
        }
        
        // open URL
        kApp.openLocation(iUrl);
        
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
