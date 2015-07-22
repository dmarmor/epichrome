/*! background.js
(c) 2015 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/* 
 *
 * background.js: background page for Epichrome Helper extension
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

    // a persistent listener to immediately install available updates (currently unused)
    // chrome.runtime.onUpdateAvailable.addListener(function(details) {
    // 	console.log('version',details.version,'is available -- updating extension');
    // 	chrome.runtime.reload();
    // });
    
    // start up shared code
    ssb.startup('background', function(success, message) {
	if (success) {
	    
	    ssb.log(ssb.logPrefix + ' is starting up');
	    
	    // we are active!
	    localStorage.setItem('status', JSON.stringify({ active: false, startingUp: true, message: 'Please wait...' }));

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
	    ssbBG.mainTab = undefined;
	    
	    // in 200ms, initialize all tabs
	    // (giving Chrome startup time to override)
	    if (typeof ssbBG.doInitTabs != 'number') ssbBG.doInitTabs = 1;
	    ssbBG.initTabsTimeout = setTimeout(ssbBG.initializeTabs, 200);
	    
	} else {
	    ssbBG.shutdown(message);
	}
    });
}


// SHUTDOWN -- shuts the extension down
ssbBG.shutdown = function(statusmessage) {
    
    ssb.log(ssb.logPrefix + ' is shutting down:', statusmessage);
    
    // cancel startup timeouts
    if (ssbBG.initTabsTimeout) {
	clearTimeout(ssbBG.initTabsTimeout);
	delete ssbBG.initTabsTimeout;
    }
    
    // cancel page timeouts
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
    
    delete ssbBG.initTabsTimeout;    
    
    // find all existing tabs
    ssbBG.allTabs(
	function(tab, win, scripts) {
	    
	    // try to find the "main" tab (for optionally directing incoming tabs there)
	    
	    // It's a bit of a kludge--I have no documentation that the first tab
	    // loaded on startup will always have the lowest ID, but it appears to be true.
	    // I look for the lowest tab ID that's the only tab in an app or popup window
	    // type (for some reason, Chrome currently gives the window type as 'popup' for
	    // app windows). Usually this all should only match one tab anyway.
	    if (((ssbBG.mainTab == undefined) || (ssbBG.mainTab.id > tab.id)) &&
		((win.type == 'popup') || (win.type == 'app')) &&
		(win.tabs.length == 1)) {
		ssbBG.mainTab = tab;
	    }
	    
	    // if we're not in Chrome startup, ping tab
    	    if (ssbBG.doInitTabs) {
		chrome.tabs.sendMessage(tab.id, 'ping', function(response) {
		    
		    if (response != 'ping') {
			
			ssb.debug('initTabs', 'reloading tab', tab.id);
			
			// no response, so inject content scripts
    			for(var i = 0 ; i < scripts.length; i++ ) {
    			    chrome.tabs.executeScript(
				tab.id,
				{ file: scripts[i], allFrames: true },
				function () {
				    if (chrome.runtime.lastError) {
					ssb.warn('unable to load tab '+tab.id+': '+
						 chrome.runtime.lastError.message);
				    }
				});
    			}
    		    }
    		});
	    }
	},
	ssb.manifest.content_scripts[0].js,

	// we finished initializing all tabs
	function() {
	    if (ssbBG.mainTab != undefined)
		ssb.debug('initTabs', 'main tab set to', ssbBG.mainTab,'--',ssbBG.mainTab.url);
	    else
		ssb.debug('initTabs', 'no main tab found');
	});
}


// HANDLECHROMESTARTUP -- prevent initializing tabs on Chrome startup
ssbBG.handleChromeStartup = function() {
    // Chrome is starting up, so don't initialize tabs
    ssbBG.doInitTabs = 0;
}


// HANDLEINSTALL -- let the system know we're installing
ssbBG.handleInstall = function(details) {

    // check why we got this event
    if (details.reason == 'install') {
	
	// we're actually installing
	ssb.debug('install', 'we are installing');
	
	if (ssbBG.startupComplete) {
	    ssbBG.showInstallMessage();
	} else {
	    ssbBG.isInstall = true;
	}
    }
    // here is where we could take action based on an update or a Chrome update
    // details.reason can be: "install", "update", "chrome_update", or "shared_module_update"
    // if (details.reason == 'update') details.previousVersion will be set

}

// SHOWINSTALLMESSAGE -- display a welcome message on installation
ssbBG.showInstallMessage = function() {

    ssb.debug('install', 'showing install message');

    // get current status
    var curStatus = localStorage.getItem('status');
    if (typeof curStatus == 'string') {
	try {
	    curStatus = JSON.parse(curStatus);
	} catch (err) {
	    ssb.warn('got bad extension status');
	    curStatus = null;
	}
	
	if (curStatus.active) {
	    
	    // tell options page to show install message
	    curStatus.showInstallMessage = true;
	    
	    // set new status with install indicator
	    localStorage.setItem('status', JSON.stringify(curStatus));
	    
	    // open options page
	    chrome.runtime.openOptionsPage();
	} else {
	    ssb.debug('install', 'extension has shut down, so not showing install message');
	}
    } else {
	ssb.debug('install', 'no status received, so not showing install message');
    }
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
		    if ( ! (ssb.regexpChromeScheme.test(curTab.url) ||
			    ssb.regexpChromeStore.test(curTab.url))) {
			// perform action
			action(curTab, curWindow, arg);
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
	    ssb.debug('newTab', 'tab was redirected from this app -- ignoring');
	    
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
		ssb.options.sendIncomingToMainTab &&
		(ssbBG.mainTab != undefined)) {

		// according to our options, it should be sent to main tab
		ssb.debug('newTab', 'using options -- sending to main tab');
		
		var oldTabId = tab.id;
		var thisUrl = tab.url;
		chrome.tabs.update(
		    ssbBG.mainTab.id,
		    {url: thisUrl, active: true},
		    function (myTab) {
			if (chrome.runtime.lastError) {
			    // unable to update the main tab
			    ssb.warn('unable to find main tab',ssbBG.mainTab.id,
				     '('+chrome.runtime.lastError.message+') -- leaving new tab open');
			} else {
			    // we updated the tab, so get rid of the old one & focus
			    chrome.tabs.remove(oldTabId);
			    chrome.windows.update(
				myTab.windowId,
				{focused: true},
				function () {
				    // log it if we failed to focus on the window
				    if (chrome.runtime.lastError) {
					ssb.warn('unable to focus on main window',myTab.windowId,
						 '('+chrome.runtime.lastError.message+')');
				    }
				});
			}
		    });
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


// HANDLEWINDOWSWITCH -- switch a main app window between app-style and tabs style
ssbBG.handleWindowSwitch = function() {

    if (ssbBG.mainTab) {
	chrome.tabs.get(ssbBG.mainTab.id,
			function(tab) {
			    if (chrome.runtime.lastError) {
				ssb.warn('unable to find main tab',
					 ssbBG.mainTab.id,
					 '('+chrome.runtime.lastError.message+')');
			    } else {
				chrome.windows.get(tab.windowId, function(win) {
				    if (chrome.runtime.lastError) {
					ssb.warn('unable to find main window',
						 win.id,
						 '('+chrome.runtime.lastError.message+')');
				    } else {
					chrome.windows.create({
					    tabId: ssbBG.mainTab.id,
					    type: (win.type == 'popup') ? 'normal' : 'popup',
					    left: win.left,
					    top: win.top,
					    width: win.width,
					    height: win.height
					});
				    }
				});
			    }
			});
    }
}
// chrome.windows.create({tabId:2, type:"popup"}); // that'll get it back
// update mainTab as it changes
// set up hotkey in options? (cmd-L to get to tabs, but what to get out?)
// triple-click
// context menu -- var id = chrome.contextMenus.create({title: 'Show Address Bar', contexts:'all' ???});


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
    
    // we now know we have an operating port
    ssbBG.host.isReconnect = false;
    
    ssbBG.host.canCommunicate = true;
    
    // parse response
    
    if ('url' in message) {
	ssb.debug('host','got redirect response:',message);
	
	// acknowledging a URL redirect	
	ssbBG.pages.urls[message.url].response = true;
	if (message.result != "success") {
	    ssbBG.shutdown('Redirect request failed.');
	}
    } else if ('version' in message) {
	// version is always part of a handshake request
	ssb.debug('host', 'got handshake:',message);
	
	// start building our status object
	var status = { active: true };
	
	// other info that may be part of the handshake
	if ('ssbID' in message) { status.ssbID = message.ssbID }
	if ('ssbName' in message) { status.ssbName = message.ssbName }
	if ('ssbShortName' in message) { status.ssbShortName = message.ssbShortName }
	
	// this is also how we know our connection to the host is live
	localStorage.setItem('status', JSON.stringify(status));
	
	// we're done starting up
	ssbBG.startupComplete = true;
	
	// if we're installing, now we know we can show the welcome message
	if (ssbBG.isInstall)
	    ssbBG.showInstallMessage();
	
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
    ssbBG.host.port = chrome.runtime.connectNative('org.epichrome.helper');
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

    // say hello by asking for the host's version
    ssbBG.host.port.postMessage({'version': true});
    ssb.debug('host', 'requesting handshake');
}


// BOOTSTRAP STARTUP
// -----------------

// handle new installation
chrome.runtime.onInstalled.addListener(ssbBG.handleInstall);

// handle Chrome startup
chrome.runtime.onStartup.addListener(ssbBG.handleChromeStartup);

// start the extension
ssbBG.startup();
