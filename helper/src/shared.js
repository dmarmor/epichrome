/*! shared.js
(c) 2015 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/*
 *
 * shared.js: shared code for Epichrome Helper extension
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */


// SSB -- object that holds all data & methods
// ---------------------------------------------

var ssb = {};


// STARTUP/SHUTDOWN -- handle startup, shutdown & installation
// -----------------------------------------------------------

// STARTUP -- main startup function for the shared code
ssb.startup = function(pageType, callback) {
    
    // basic information about this extension
    ssb.manifest = chrome.runtime.getManifest();
    ssb.logPrefix = ssb.manifest.name + ' v' + ssb.manifest.version

    // set default options
    ssb.defaultOptions =
	{
	    optionsVersion: ssb.manifest.version,
	    ignoreAllInternalSameDomain: true,
	    rules: [
		// {pattern: '*',
		//  target: 'external',
		//  redirect: true	 
		// }
	    ],
	    redirectByDefault: false,
	    stopPropagation: false,
	    sendIncomingToMainTab: false
	};
    
    // what type of page are we running in?
    ssb.pageType = pageType;
    
    // set up code to call when options have been retrieved
    var myCallback;
    myCallback = function(success, message) {
	if (success) {	    
	    // install storage change listener
	    chrome.storage.onChanged.removeListener(ssb.handleOptionsChange);
	    chrome.storage.onChanged.addListener(ssb.handleOptionsChange);
	}
	
	// call callback
	callback(success, message);
    }
    
    // get options
    chrome.storage.local.get(null, function(items) {
	if (!chrome.runtime.lastError) {
	    
	    // set up local copy of options
	    ssb.options = items;
	    ssb.parseRules(ssb.options.rules);

	    // if we're running in the background page and options are
	    // not found, set up default options
	    if (ssb.pageType == 'background') {
		
		if ((!ssb.options) || !ssb.options.optionsVersion) {
		    
		    // no recognizable options found -- we must be installing
		    ssb.log(ssb.logPrefix,'is installing');
		    
		    // set default options
		    ssb.setOptions(ssb.defaultOptions, myCallback);
		    
		} else if (ssb.updateOptions(ssb.options)) {
		    
		    // we had to update the options, so save them
		    ssb.setOptions(ssb.options, myCallback);
		    
		} else {
		    
		    // nothing to do -- options loaded successfully
		    myCallback(true);
		}
	    } else {
		myCallback(true);
	    }
	} else {
	    myCallback(false, 'Unable to retrieve options.');
	}
    });
}


// SHUTDOWN -- get rid of the shared object
ssb.shutdown = function() {
    // remove listener for storage changes
    chrome.storage.onChanged.removeListener(ssb.handleOptionsChange);

    // destroy self
    delete window.ssb;
}


// OPTIONS -- set and update extension options
// -------------------------------------------

ssb.options = {};


// SETOPTIONS -- replace options in storage with new options
ssb.setOptions = function(newOptions, callback) {
    chrome.storage.local.clear(function() {
	
	// failed to clear storage
	if (chrome.runtime.lastError) {
	    callback('Unable to clear old options: ' +
		     chrome.runtime.lastError.message);
	    return;
	}
	
	// set default options
	chrome.storage.local.set(
	    newOptions,
	    function() {
		if (!chrome.runtime.lastError) {
		    ssb.options = ssb.clone(newOptions);
		    ssb.parseRules(ssb.options.rules);
		    
		    if (typeof callback == 'function') {
			callback(true);
		    }
		} else {
		    // failed to set default options
		    if (typeof callback == 'function') {
			callback(false,
				 'Unable to set options: ' +
				 chrome.runtime.lastError.message);
		    }
		}
	    });
    });
}


// HANDLEOPTIONSCHANGE -- when options change in storage, update local copy
ssb.handleOptionsChange = function(changes) {
    
    for (var key in changes) {
	ssb.options[key] = ssb.clone(changes[key].newValue);
	if (key == 'rules') ssb.parseRules(ssb.options.rules);
    }
}


// UPDATEOPTIONS -- if necessary, update options to current version
ssb.updateOptions = function(options) {
    var result = false;
    
    if (options.optionsVersion != ssb.manifest.version) {
	
	// options are for an older version
	ssb.debug('options', 'updating options from version',
		  options.optionsVersion,
		  'to version',
		  ssb.manifest.version);

	// pre-1.1.0 options: add stopPropagation
	if (ssb.compareVersions(options.optionsVersion, '1.1.0') < 0) {
	    options.stopPropagation = ssb.defaultOptions.stopPropagation;
	}

	// update optionsVersion
	options.optionsVersion = ssb.manifest.version;
	
	result = true;
    }

    return result;
}


// RULES -- functions & data for processing URL-handling rules
// -----------------------------------------------------------

// SHOULDREDIRECT -- return true if a URL should be redirected
ssb.shouldRedirect = function(url, target) {
    
    // always ignore chrome schemes
    if (ssb.regexpChromeScheme.test(url)) { return false; }
    
    // iterate through rules until one matches
    var index = 0
    if (ssb.options.rules) {
	var rulesLength = ssb.options.rules.length;
	for (var i = 0; i < rulesLength; i++) {
	    var rule = ssb.options.rules[i];
	    if (((rule.target == 'both') || (target == rule.target)) &&
		rule.regexp.test(url)) {
		ssb.debug('rules',
			  (rule.redirect ? 'redirecting' : 'ignoring') +
			  ' based on rule',
			  index,'--', url, '[' + target + ']');
		return rule.redirect;
	    }
	    index++;
	}
    }
    
    // default action
    ssb.debug('rules',
	      (ssb.options.redirectByDefault ? 'redirecting' : 'ignoring') +
	      ' based on default action --', url, '[' + target + ']');
    return ssb.options.redirectByDefault;
}


// PARSERULES -- parse pseudo-regexp patterns into real regexes
ssb.parseRules = function(rules) {

    // if we're running in the options page, never parse
    if ((ssb.pageType != 'options') && rules)
	
	var i = rules.length; while (i--) {
	    var rule = rules[i];
	    
	    // create new regexp
	    rule.regexp = rule.pattern;
	    if (! rule.regexp) rule.regexp = '*';

	    // determine if this pattern has a scheme (e.g. http://)
	    var noscheme = (! ssb.regexpHasScheme.test(rule.regexp));

	    // escape any special characters
	    rule.regexp = rule.regexp.replace(ssb.regexpEscape, '\\$1');

	    // collapse multiple * (e.g. ***) into a single *
	    rule.regexp =
		rule.regexp.replace(ssb.regexpCollapseStars, '$1[*]');

	    // replace * with .*
	    rule.regexp = rule.regexp.replace(ssb.regexpStar, '.*');
	    
	    // if no scheme in pattern, prepend one that matches any scheme
	    if (noscheme) {
		rule.regexp = '[^/]+:(?://)?' + rule.regexp;
	    }

	    // make sure regexp only matches entire url
	    rule.regexp = '^' + rule.regexp + '$';

	    // create the regexp
	    rule.regexp = new RegExp(rule.regexp, 'i');
	}
}


// RULE REGEXPS -- regexps for converting rule patterns into regexps

// match only patterns that contain a scheme header or start with a wildcard
ssb.regexpHasScheme = new RegExp(/^(\*|([^\/]+:))/);

// match special characters (except already-escaped *)
ssb.regexpEscape = new RegExp(/([.+?^=!:${}()|\[\]\/]|\\(?!\*))/g);

// match multiple non-escaped stars in a row
ssb.regexpCollapseStars = new RegExp(/((?:^|[^\\])(?:\\{2})*)(?:\*+)/g);

// transform non-escaped *
ssb.regexpStar = new RegExp(/\[\*\]/g);


// UTILITY REGEXPS -- useful regexps for other parts of the extension

// match various Chrome-reserved URLs
ssb.regexpChromeScheme = new RegExp('^chrome([-a-zA-Z0-9.+]*):', 'i');
ssb.regexpChromeStore = new RegExp('^http(s?)://chrome\\.google\\.com/webstore', 'i');


// UTILITY -- useful utility functions
// -----------------------------------

// CLONE -- clone an object
ssb.clone = function(obj) {
    // simple data
    if ((obj == null) ||
	(typeof obj != "object"))
	return obj;

    // recursively copy object
    var copy = obj.constructor();
    for (var key in obj) {
        if (obj.hasOwnProperty(key))
	    copy[key] = ssb.clone(obj[key]);
    }
    
    return copy;
}

// EQUAL -- return true if two objects have recursively identical properties
ssb.equal = function(obj1, obj2) {
    
    // simple data
    if ((obj1 == null) ||
	(typeof obj1 != "object"))
	return (obj1 === obj2);

    // compare object property list lengths
    if ((typeof obj2 != 'object') ||
	(Object.getOwnPropertyNames(obj1).length !=
	 Object.getOwnPropertyNames(obj2).length)) { return false; }
    
    // recursively compare objects
    for (var key in obj1)
        if (! (obj1.hasOwnProperty(key) &&
	       obj2.hasOwnProperty(key) &&
	       ssb.equal(obj1[key], obj2[key])))
	    return false;
    
    return true;
}


// COMPAREVERSIONS -- compare two version numbers, return -1 if v1 < v2;
//                    0 if v1 == v2, 1 if v1 > v2
ssb.compareVersions = function(v1, v2) {
    // break up version numbers
    v1 = v1.split('.'); v2 = v2.split('.');
    var len = ((v1.length > v2.length) ? v1.length : v2.length);
    var result = 0;
    
    // loop through all elements
    for (var i = 0; i < len; i++) {
	
	// get and validate the current number
	curV1 = ((i < v1.length) ? parseInt(v1[i]) : 0);
	curV2 = ((i < v2.length) ? parseInt(v2[i]) : 0);
	if (! (curV1 >= 0)) curV1 = 0;
	if (! (curV2 >= 0)) curV2 = 0;

	// compare
	if (curV1 < curV2) {
	    result = -1;
	    break;
	} else if (curV1 > curV2) {
	    result = 1;
	    break;
	}
    }

    return result;
}


// LOGGING -- logging & debugging functions
// ----------------------------------------

// DEBUGGROUPS -- which groups should actually display debugging messages

// DEBUG -- display a debugging message if it's in displayed groups
if (typeof RELEASE != 'undefined') {
    ssb.debug = function() {}
    delete window.RELEASE;
} else {
    // ssb.debugGroups = ['shutdown', 'newTab'];
    ssb.debug = function(group) {
	if (!ssb.debugGroups || (ssb.debugGroups.indexOf(group) >= 0)) {
	    var args = Array.apply(null, arguments);
	    args[0] =
		((ssb.pageType == 'content') ? ssb.logPrefix + ' ' : '') +
		'[' + group + ']:';
	    console.debug.apply(console, args);
	}
    }
}

// LOG/WARN/ERROR -- display various levels of log message
ssb.log = function() { ssb.logInternal('log', arguments); }
ssb.warn = function() { ssb.logInternal('warn', arguments); }
ssb.error = function() { ssb.logInternal('error', arguments); }

// LOGINTERNAL -- handle all log/warn/error requests
ssb.logInternal = function(logtype, args) {
    
    // convert arguments to a proper array
    args = Array.apply(null, args);

    // if this is a content page, prepend log prefix
    if (ssb.pageType == 'content')
	args.unshift(ssb.logPrefix + ':');

    // display the message
    console[logtype].apply(console, args);
}
