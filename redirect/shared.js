
// BASE SHARED OBJECT

var ssb = {};


// SET UP BASIC SHARED VARIABLES

ssb.manifest = chrome.runtime.getManifest();
ssb.logPrefix = ssb.manifest.name + ' v' + ssb.manifest.version + ': '


// DEFAULT OPTIONS

ssb.defaultOptions = {
    optionsVersion: ssb.manifest.version,
    ignoreAllInternalSameDomain: true,
    redirectByDefault: false,
    rules: [
	{pattern: '*',
	 target: 'external',
	 redirect: true	 
	}
    ]
}


// DEFINE SHARED FUNCTIONS

// match only patterns that contain a scheme header or start with a wildcard
ssb.regexpHasScheme = new RegExp(/^(\*|([^\/]+:))/);

// match special characters (except already-escaped *)
ssb.regexpEscape = new RegExp(/([.+?^=!:${}()|\[\]\/]|\\(?!\*))/g);

// match multiple non-escaped stars in a row
ssb.regexpCollapseStars = new RegExp(/((?:^|[^\\])(?:\\{2})*)(?:\*+)/g);

//ssb.regexpPlus = new RegExp(/(^|[^a-z0-9])\*([^a-z0-9])/gi);

// transform non-escaped *
ssb.regexpStar = new RegExp(/\[\*\]/g);


ssb.parseRules = function(rules) {
    if ((ssb.pageType != 'options') && rules)
	for (rule of rules) {
	    rule.regexp = rule.pattern;
	    if (! rule.regexp) rule.regexp = '*';
	    
	    var noscheme = (! ssb.regexpHasScheme.test(rule.regexp));
	    
	    rule.regexp = rule.regexp.replace(ssb.regexpEscape, '\\$1');
	    rule.regexp = rule.regexp.replace(ssb.regexpCollapseStars, '$1[*]');
	    rule.regexp = rule.regexp.replace(ssb.regexpStar, '.*');
	    if (noscheme) {
		rule.regexp = '[^/]+:(?://)?' + rule.regexp;
	    }
	    rule.regexp = '^' + rule.regexp + '$';
	    
	    rule.regexp = new RegExp(rule.regexp, 'i');
	}
}


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


ssb.setOptions = function(newOptions, callback) {
    chrome.storage.local.clear(function() {
	
	// failed to clear storage
	if (chrome.runtime.lastError) {
	    callback('Unable to clear old options: ' + chrome.runtime.lastError.message);
	    return;
	}
	
	// set default options
	chrome.storage.local.set(
	    newOptions,
	    function() {
		if (!chrome.runtime.lastError) {
		    ssb.options = ssb.clone(newOptions);
		    ssb.parseRules(ssb.options.rules);
		    
		    callback(true);
		} else {
		    // failed to set default options
		    callback(false, 'Unable to set options: ' + chrome.runtime.lastError.message);
		}
	    });
    });
}


ssb.handleStorageChange = function(changes, area) {
    
    for (key in changes) {
	ssb.options[key] = ssb.clone(changes[key].newValue);
	if (key == 'rules') ssb.parseRules(ssb.options.rules);
    }
}

ssb.regexpChromeScheme = new RegExp('^chrome([-a-zA-Z0-9.+]*):', 'i');

ssb.shouldRedirect = function(url, target) {

    // always ignore chrome schemes
    if (ssb.regexpChromeScheme.test(url)) { return false; }
    
    // iterate through rules until one matches
    var index = 0
    if (ssb.options.rules)
	for (rule of ssb.options.rules) {
	    if (((rule.target == 'both') || (target == rule.target)) &&
		rule.regexp.test(url)) {
		console.log(ssb.logPrefix +
			    (rule.redirect ? 'redirecting' : 'ignoring') +
			    ' based on rule ' +
			    index + ': ' + url + ' [' + target + ']');
		return rule.redirect;
	    }
	    index++;
	}
    
    // default action
    console.log(ssb.logPrefix +
		(ssb.options.redirectByDefault ? 'redirecting' : 'ignoring') +
		' based on default action: ' + url + ' [' + target + ']');
    return ssb.options.redirectByDefault;
}

ssb.shutdown = function() {
    chrome.storage.onChanged.removeListener(ssb.handleStorageChange);
    ssb = undefined;
}

ssb.startup = function(pageType, callback) {

    // what type of page are we running in?
    ssb.pageType = pageType;
    
    // if this is the background page, check if we need to set options
    var versionCheck = ((ssb.pageType == 'background') ? { optionsVersion: false } : null);
    
    // set up code to call on completion of getting options
    var myCallback;
//    if (ssb.pageType != 'options') {
	myCallback = function(success, message) {
	    if (success) {	    
		// install storage change listener
		chrome.storage.onChanged.removeListener(ssb.handleStorageChange);
		chrome.storage.onChanged.addListener(ssb.handleStorageChange);
	    }
	    
	    // call callback
	    callback(success, message);
	}
    // } else {
    // 	myCallback = callback;
    // }

    // get options & optionally set defaults if necessary
    chrome.storage.local.get(versionCheck, function(items) {
	if (!chrome.runtime.lastError) {
	    
	    // set up local copy of options
	    ssb.options = items;
	    ssb.parseRules(ssb.options.rules);
	    
	    if (ssb.pageType == 'background') {
		var rewriteOptions = false;
		if ((!items) || !items.optionsVersion) {
		    // no recognizable options found -- we must be installing
		    console.log(ssb.logPrefix + 'installing');
		    
		    // set default options
		    ssb.setOptions(ssb.defaultOptions, myCallback);
		    
		} else if (items.optionsVersion != ssb.manifest.version) {
		    // options are for an older version -- we must be updating
		    console.log(ssb.logPrefix + 'updating from version ' + items.optionsVersion);

		    ssb.options.optionsVersion = ssb.manifest.version;
		    
		    // for now, just set the current version in the options
		    chrome.storage.local.set(
			{ optionsVersion: ssb.manifest.version },
			function() {
			    if (! chrome.runtime.lastError) {
				// success
				myCallback(true);
			    } else {
				myCallback(false, 'Unable to update options: ' + chrome.runtime.lastError);
			    }
			});
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
