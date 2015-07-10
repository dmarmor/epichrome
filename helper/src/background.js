/*! background.js
(c) 2015 David Marmor
https://github.com/dmarmor/osx-chrome-ssb-gui
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/* 
 *
 * background.js: background page for Mac SSB Helper extension
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


// SSBBG -- object that holds all data & methods
// ---------------------------------------------

var ssbBG = {};


// STARTUP/SHUTDOWN -- handle startup, shutdown & installation
// -----------------------------------------------------------

// STARTUP -- main startup function for the extension
ssbBG.startup = function() {    
    // start up shared code
    ssb.startup('background', function(success, message) {
	if (success) {
	    
	    ssb.log(ssb.logPrefix + ' is starting up');
	    
	    // we are active!
	    localStorage.setItem('status', JSON.stringify({ active: true }));
	    
	    // initialize pages.urls
	    ssbBG.pages.urls = {};
	    
	    // status change listener (we don't need to do anything)
	    //window.addEventListener('storage', function() { ssb.debug('storage', 'got a status change!'); });
	    
	    // set up listener for when pages connect to us
	    chrome.runtime.onConnect.addListener(ssbBG.pages.handleConnect);
	    
	    // set up listener for handling pings
	    chrome.runtime.onMessage.addListener(ssbBG.handlePing);
	    
	    // connect to host for the first time
	    ssbBG.host.canCommunicate = false;
	    ssbBG.host.connect();
	    
	    // handle new tabs
	    chrome.tabs.onCreated.addListener(ssbBG.handleNewTab);

	    // we don't yet know which is the main tab
	    ssbBG.mainTabId = undefined;
	    
	    // in 200ms, initialize all tabs
	    // (giving Chrome startup time to override)
	    if (typeof ssbBG.doInitTabs != 'number') ssbBG.doInitTabs = 1;
	    ssbBG.startupTimeout = setTimeout(ssbBG.initializeTabs, 200);
	} else {
	    ssbBG.shutdown(message);
	}
    });
}


// SHUTDOWN -- shuts the extension down
ssbBG.shutdown = function(statusmessage) {
    
    // cancel outstanding timeouts
    if (ssbBG.pages.urls)
	Object.keys(ssbBG.pages.urls).forEach(
	    function(key) {
		ssb.debug('shutdown', 'clearing timeout for ' + key);
		clearTimeout(ssbBG.pages.urls[key].timeout);
	    });
    
    // tell all tabs to shut down
    ssbBG.allTabs(function(tab) {
	ssb.debug('shutdown', 'shutting down tab', tab.id);
	chrome.tabs.sendMessage(tab.id, 'shutdown');
    }, null, function() {
	
	// shut myself down
	if (ssbBG.host.port) ssbBG.host.port.disconnect();
	
	// remove listeners
	chrome.tabs.onCreated.removeListener(ssbBG.handleNewTab);
	chrome.runtime.onConnect.removeListener(ssbBG.pages.handleConnect);
	chrome.runtime.onMessage.removeListener(ssbBG.handlePing);
	
	// set status in local storage
	localStorage.setItem('status',
			     JSON.stringify({ active: false,
					      message: statusmessage,
					      nohost: (! ssbBG.canCommunicate)
					    }));
	
	// open options page
	chrome.runtime.openOptionsPage();
	// shut down shared.js
	ssb.shutdown();
	
	// kill myself
	delete window.ssbBG;
    });
}


// INITIALIZETABS -- reload content scripts for every open tab &
//                   identify the "main" tab (by lowest ID)
ssbBG.initializeTabs = function() {
    
    // find all existing tabs
    ssbBG.allTabs(function(tab, scripts) {

	// store the smallest tab ID for handling incoming tabs (this is a bit
	// of a kludge--I have no documentation that tab ID always start small
	// on startup, but they appear to pretty reliably; also, generally at
	// this point in loading, in an app-style scenario there should only be
	// one tab open, so it should be moot)
	if ((ssbBG.mainTabId == undefined) ||
	    (ssbBG.mainTabId > tab.id)) {
	    ssbBG.mainTabId = tab.id;
	    ssb.debug('initTabs', 'setting main tab to', ssbBG.mainTabId);
	}
	
	// if we're not in Chrome startup, ping tab
    	if (ssbBG.doInitTabs) {
	    chrome.tabs.sendMessage(tab.id, 'ping', function(response) {
		
		if (response != 'ping') {
		    
		    ssb.debug('initTabs', 'reloading tab', tab.id);
		    
		    // no response, so inject content scripts
    		    for(var i = 0 ; i < scripts.length; i++ ) {
    			chrome.tabs.executeScript(tab.id, { file: scripts[i], allFrames: true });
    		    }
    		}
    	    });
	}
    }, ssb.manifest.content_scripts[0].js);
}


// HANDLECHROMESTARTUP -- prevent initializing tabs on Chrome startup
ssbBG.handleChromeStartup = function() {
    // Chrome is starting up, so don't initialize tabs
    ssbBG.doInitTabs = 0;
}


// HANDLEINSTALL -- display a welcome message on installation
ssbBG.handleInstall = function() {

    // get current status
    var curStatus = localStorage.getItem('status');
    if (typeof curStatus == 'string') {
	try {
	    curStatus = JSON.parse(curStatus);
	} catch (err) {
	    ssb.warn('got bad extension status--resetting');
	    curStatus = null;
	}
    }
    
    // set new status with install indicator
    localStorage.setItem('status',
			 JSON.stringify({ active: curStatus.active,
					  message: curStatus.message,
					  showInstallMessage: true }));
    
    // open options page
    chrome.runtime.openOptionsPage();
}


// ALLTABS -- utility function to run a function on every open tab
ssbBG.allTabs = function(action, arg, finished) {
    chrome.windows.getAll(
	{ populate: true },
	function (windows) {
	    var curWindow;
	    for(var i = 0 ; i < windows.length; i++ ) {
		curWindow = windows[i];
		var curTab;
		for(var j = 0 ; j < curWindow.tabs.length; j++ ) {
		    // Skip chrome://
		    var curTab = curWindow.tabs[j];
		    if( ! ssb.regexpChromeScheme.test(curTab.url)) {			
			// perform action
			action(curTab, arg);
		    }
		}
	    }

	    // callback to let us know we've exited
	    if (finished) finished();
	});
}


// HANDLERS -- event and message handlers
// ----------------------------------------------------

// HANDLENEWTAB -- process a newly-opened tab
ssbBG.handleNewTab = function(tab) {
    
    ssb.debug('newTab', 'tab created ( id =',tab.id,'openerId =',tab.openerTabId,')');
    
    if (!tab.url || (tab.url == 'chrome://newtab/')) {

	// blank tab
	ssb.debug('newTab', 'tab is empty -- ignoring');
	
    } else if (!ssb.regexpChromeScheme.test(tab.url)) {
	
	// incoming or nav tab
	ssb.debug('newTab', 'tab has url',tab.url);
	
	if (!tab.openerTabId && ssbBG.pages.urls[tab.url] &&
	    ssbBG.pages.urls[tab.url].redirect) {

	    // tab redirected from here apparently landed here again, so we
	    // ignore it to avoid an endless redirection loop
	    ssb.debug('newTab', 'tab was redirected from this SSB -- ignoring');
	    
	} else if (ssb.shouldRedirect(tab.url, 'external')) {

	    // according to the rules, this URL should be redirected
	    ssb.debug('newTab', 'using rules -- redirecting');
	    
	    // simulate a message from a page to send the redirect
	    ssbBG.pages.handleMessage({redirect: true, url: tab.url});
	    chrome.tabs.remove(tab.id);
	    
	} else {

	    // according to the rules, this URL should be kept
	    ssb.debug('newTab', 'using rules -- keeping');
	    
	    // if it's truly an incoming tab (we didn't create it through any
	    // kind of click), we might send it to the main tab
	    if (! ssbBG.pages.urls[tab.url] &&
		ssb.options.sendIncomingToMainTab) {

		// according to our options, it should be sent to main tab
		ssb.debug('newTab', 'using options -- sending to main tab');
		
		var thisTabId = tab.id;
		var thisUrl = tab.url;
		try {
		    chrome.tabs.get(
			ssbBG.mainTabId,
			function(mainTab) {
			    chrome.tabs.remove(thisTabId);
			    chrome.tabs.update(mainTab.id,
					       {url: thisUrl, active: true});
			    chrome.windows.update(mainTab.windowId,
						  {focused: true});
			});
		} catch(err) {
		    ssb.warn('unable to find main tab',ssbBG.mainTabId,' -- leaving new tab open');
		}
	    } else {
		// either it's an actual redirect, or our options don't call
		// for redirecting to the main tab
		ssb.debug('newTab', 'leaving new tab open');
	    }
	}
    }
}


// HANDLEPING -- handle incoming one-time pings from pages
ssbBG.handlePing = function(message, sender, respond) {
    switch (message) {
    case 'ping':
	respond('ping');
	break;
    default:
	ssb.warn('ping handler received unknown message:', message,'from',sender);
    }
}


// PAGES -- object for handling communication with web pages
// ---------------------------------------------------------

ssbBG.pages = {};


// PAGES.HANDLECONNECT -- set up a connection with a page
ssbBG.pages.handleConnect = function(port) {
    port.onMessage.addListener(ssbBG.pages.handleMessage);
}


// PAGES.HANDLEMESSAGE -- handle an incoming message from a page
ssbBG.pages.handleMessage = function(message) {
    ssb.debug('pageMessage','got message:',message);
    
    // hold onto this URL for a few seconds so we don't try to
    // close any new tab or send it to the main page
    
    // clear any old entry for this URL and start over
    var curRedirect;
    if (ssbBG.pages.urls[message.url]) {
	curRedirect = ssbBG.pages.urls[message.url];
    	if (curRedirect.timeout) {
	    ssb.debug('pageMessage', 'clearing old timeout for',message.url);
	    clearTimeout(curRedirect.timeout);
	}
    }
    curRedirect = ssbBG.pages.urls[message.url] = { redirect: message.redirect };
    
    // figure out delay for the timeout based on what we're doing
    var delay = (message.redirect ? 4000 : (message.isMousedown ? 10000 : 2000));
    
    ssb.debug('pageMessage', 'adding entry with delay',delay,'for',message.url);
    
    // set a timeout to get rid of this redirect
    curRedirect.timeout = setTimeout(function(url) {
	// remove this redirect
	ssb.debug('pageMessage', 'timing out',url);
	delete ssbBG.pages.urls[url];
    }, delay, message.url);
    
    // if we're redirecting, send the message now
    if (message.redirect) {
	// send message
	ssbBG.host.port.postMessage({"url": message.url});
	ssb.debug('host', 'requesting redirect for url', message.url);
    }
}


// HOST -- object for communicating with native messaging host
// ---------------------------------------------------------

ssbBG.host = {};


// HOST.RECEIVEMESSAGE -- handler for messages from native host
ssbBG.host.receiveMessage = function(message) {

    ssb.debug('host','got message:',message);
    
    // we now know we have an operating port
    ssbBG.host.isReconnect = false;
    
    ssbBG.host.canCommunicate = true;
    
    // parse response
    
    if ('url' in message) {
	// acknowledging a URL redirect
	ssbBG.pages.urls[message.url].response = true;
	if (message.result != "success") {
	    ssbBG.shutdown('Redirect request failed.');
	}
    } else if ('version' in message) {
	// acknowledging a version request
	ssb.debug('host', 'host is version '+message.version);
    } else {
	// unknown response from host
	ssbBG.shutdown('Redirect request returned unknown response.');
    }
}


// HOST.CONNECT -- connect to native host
ssbBG.host.connect = function(isReconnect) {
    // disconnect any existing connection
    if (ssbBG.host.port) ssbBG.host.port.disconnect();
    
    ssb.debug('host', (isReconnect ? 're' : '') + 'connecting...');
    
    // connect to host
    ssbBG.host.port = chrome.runtime.connectNative('com.dmarmor.ssb.helper');
    ssbBG.host.isReconnect = isReconnect;

    // handle disconnect from the host
    ssbBG.host.port.onDisconnect.addListener(function () {

	if (ssbBG.host.isReconnect) {
	    // second connection attempt, so disconnect is an error
	    var message;
	    if (ssbBG.canCommunicate)
		message = 'Disconnected from redirect host';
	    else
		message = 'Unable to reach redirect host';
	    ssbBG.shutdown(message);
	} else {
	    // we had a good connection or this was our first try, so retry
	    ssbBG.host.connect(true);
	}
    });

    // handle messages from the host
    ssbBG.host.port.onMessage.addListener(ssbBG.host.receiveMessage);

    // say hello by asking for the host's version (we'll just ignore the response for now)
    ssbBG.host.port.postMessage({"version": true});
    ssb.debug('host', 'requesting version');
}


// BOOTSTRAP STARTUP
// -----------------

// handle new installation
chrome.runtime.onInstalled.addListener(ssbBG.handleInstall);

// handle Chrome startup
chrome.runtime.onStartup.addListener(ssbBG.handleChromeStartup);

// start the extension
ssbBG.startup();
