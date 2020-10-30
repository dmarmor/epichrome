//
//
//  vcmp.js: Utility function to compare Epichrome versions.
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


// VCMP: compare version numbers (v1 < v2: -1, v1 == v2: 0, v1 > v2: 1)
//   aNumComponents: if >0, number of components to compare, starting with major version (1.2.3b4[5])
function vcmp (v1, v2, aNumComponents=0) {
    
    // regex for pulling out version parts
    const kVersionRe='^0*([0-9]+)\\.0*([0-9]+)\\.0*([0-9]+)(b0*([0-9]+))?(\\[0*([0-9]+)])?$';
    
    // normalize number of components (if <= 0 or not a number, use all)
    aNumComponents = Number(aNumComponents);
    if (!(aNumComponents > 0)) {
        aNumComponents = 10;  // safely past all components
    }
    
    // array for comparable version integers
    var vStr = [];

    // munge version numbers into comparable integers
    for (let curV of [ v1, v2 ]) {
        
        // conform current version number
        if (typeof curV == 'number') {
            curV = curV.toString();
        } else if (typeof curV != 'string') {
            curV = '';
        }
        
        let vmaj, vmin, vbug, vbeta, vbuild;

        const curMatch = curV.match(kVersionRe);

        if (curMatch) {

            // extract version number parts
            vmaj   = parseInt(curMatch[1]);
            vmin   = (aNumComponents >= 2) ? parseInt(curMatch[2]) : 0;
            vbug   = (aNumComponents >= 3) ? parseInt(curMatch[3]) : 0;
            vbeta  = (aNumComponents >= 4) ? (curMatch[5] ? parseInt(curMatch[5]) : 1000) : 0;
            vbuild = (aNumComponents >= 5) ? (curMatch[7] ? parseInt(curMatch[7]) : 10000) : 0;
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
