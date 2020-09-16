//
//
//  json.js: pull out JSON keys for readjsonkeys function
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


// SHELLQUOTE: assemble a list of arguments into a shell string
function shellQuote(...aArgs) {
    let result = [];
    for (let s of aArgs) {
        result.push("'" + s.replace(/'/g, "'\\''") + "'");
    }
    return result.join(' ');
}

function run(aArgv) {
    
    let myErr;
    
    try {
        
        if (aArgv.length < 3) {
            throw Error('Incorrect arguments.');
        }
        
        // parse argument JSON
        const myObj = JSON.parse(aArgv.shift());
        const myPrefix = aArgv.shift();
        
        let myResult = [];
        
        for (let curKey of aArgv) {
            
            curKey = curKey.split('.');
            
            // start bash variable assignment
            let curResult = myPrefix + '_' + curKey.join('_') + '=';
            
            // drill down into object
            let curObj = myObj;
            for (let curSubKey of curKey) {
                curSubKey = curSubKey.toLowerCase();
                if (curObj.hasOwnProperty(curSubKey)) {
                    curObj = curObj[curSubKey];
                } else {
                    curObj = null;
                    break;
                }
            }

            // result found!
            if (curObj) {
                
                if (curObj instanceof Array) {

                    // array key
                    curResult += '( ' + shellQuote.apply(null, curObj) + ' )';

                } else if (typeof(curObj) == 'string') {
                    
                    // string key
                    curResult += shellQuote(curObj);
                } else {
                    
                    // object key
                    curResult += shellQuote(JSON.stringify(curObj));
                }
            }
            
            // add to list of results
            myResult.push(curResult);
        }
        
        return myResult.join('\n');

    } catch(myErr) {
        return 'ERROR|' + myErr.message;
    }
}
