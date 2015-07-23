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

	    // find the main tab if any (for optionally directing incoming tabs there
	    // and for switching its window between popup and normal)
	    ssbBG.mainTab = undefined;
	    ssbBG.allTabs(
		function(tab, win) {
		    // It's a bit of a kludge--I have no documentation that the first tab
		    // loaded on startup will always have the lowest ID, but it appears to be true.
		    // I look for the lowest tab ID that's the only tab in an app or popup window
		    // type (for some reason, Chrome currently gives the window type as 'popup' for
		    // app windows). Usually this all should only match one tab anyway.
		    if (((ssbBG.mainTab == undefined) || (ssbBG.mainTab.id > tab.id)) &&
			((win.type == 'popup') || (win.type == 'app')) &&
			(win.tabs.length == 1)) {
			ssbBG.mainTab = { id: tab.id };
		    }
		}, undefined,
		function() {

		    // done finding main tab -- proceed with startup
		    if (ssbBG.mainTab != undefined) {
			ssb.debug('initTabs', 'main tab set to', ssbBG.mainTab,'--',ssbBG.mainTab.url);

			// initialize the context menu
			ssbBG.updateContextMenu();
			ssbBG.setContextMenuListeners(true);
			
		    } else {
			ssb.debug('initTabs', 'no main tab found');
		    }
		    
		    // set up listener for keepalive connections
		    chrome.runtime.onConnect.addListener(ssbBG.handleKeepaliveConnect);
		    
		    // set up listener for handling messages from content scripts
		    chrome.runtime.onMessage.addListener(ssbBG.pages.handleMessage);
		    
		    // connect to host for the first time
		    ssbBG.host.canCommunicate = false;
		    ssbBG.host.connect();
		    
		    // handle new tabs
		    chrome.tabs.onCreated.addListener(ssbBG.handleNewTab);
		    chrome.webNavigation.onCreatedNavigationTarget.addListener(ssbBG.handleNewNavTarget);
		    
		    // in 200ms, initialize all tabs
		    // (giving Chrome startup time to override)
		    if (typeof ssbBG.doInitTabs != 'boolean') ssbBG.doInitTabs = true;
		    ssbBG.initTabsTimeout = setTimeout(ssbBG.initializeTabs, 200);
		});
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
	chrome.tabs.sendMessage(tab.id, {type: 'shutdown'});
    }, null, function() {
	
	// shut myself down
	if (ssbBG.host.port) ssbBG.host.port.disconnect();
	
	// clear context menu
	ssbBG.setContextMenuListeners(false);
	ssbBG.removeContextMenu();
	
	// remove listeners
	chrome.tabs.onCreated.removeListener(ssbBG.handleNewTab);
	chrome.webNavigation.onCreatedNavigationTarget.removeListener(ssbBG.handleNewNavTarget);
	chrome.runtime.onConnect.removeListener(ssbBG.handleKeepaliveConnect);
	chrome.runtime.onMessage.removeListener(ssbBG.pages.handleMessage);
	
	// set status in local storage
	localStorage.setItem('status',
			     JSON.stringify({ active: false,
					      message: statusmessage,
					      nohost: (! ssbBG.host.canCommunicate)
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
    
    // if we're not in Chrome startup, find all existing tabs
    if (ssbBG.doInitTabs) {
	ssbBG.allTabs(
	    function(tab, win, scripts) {
		
		// ping tab
		chrome.tabs.sendMessage(tab.id, {type: 'ping'}, function(response) {
		    
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
	    },
	    ssb.manifest.content_scripts[0].js);
    }
}


// HANDLECHROMESTARTUP -- prevent initializing tabs on Chrome startup
ssbBG.handleChromeStartup = function() {
    // Chrome is starting up, so don't initialize tabs
    ssbBG.doInitTabs = false;
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


// HANDLEKEEPALIVECONNECT -- set up a keepalive connection with a page
ssbBG.handleKeepaliveConnect = function(port) {

    // don't connect to any port that's not from this ID
    if (! (port.sender && (port.sender.id == chrome.runtime.id))) {
	ssb.warn('rejecting connection attempt from',port.sender);
	port.disconnect();
	return;
    }
    
    // accept the connection
    ssb.debug('keepalive', 'connected to', port.sender);

    // if this is the main tab and we haven't already, anoint it
    if (ssbBG.mainTab && (port.sender.tab.id == ssbBG.mainTab.id)) {
	// only anoint the frame that connected
	ssb.debug('mainTab', 'anointing tab '+port.sender.tab.id+', frame '+port.sender.frameId);
	chrome.tabs.sendMessage(port.sender.tab.id,
				{type: 'mainTab', state: 'popup'},
				{frameId: port.sender.frameId});
    }
}


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
	    ssbBG.pages.handleMessage({type: 'url', redirect: true, url: tab.url}, {id: chrome.runtime.id});
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


// HANDLENEWNAVTARGET -- handle a newly-created navigation target (catches a few
//                       edge cases handleNewTab misses)
ssbBG.handleNewNavTarget = function(details) {
    
    ssb.debug('webNav', 'createdNavTarget:',details);

    // try to find the tab
    chrome.tabs.get(details.tabId, function(tab) {
	if (chrome.runtime.lastError) {
	    ssb.debug('webNav', 'tab has already closed -- ignoring');
	    return;
	}
	
	// handle the tab
	ssbBG.handleNewTab(tab);
    });
}


// PAGES -- object for handling communication with web pages
// ---------------------------------------------------------

ssbBG.pages = {};


// PAGES.HANDLEMESSAGE -- handle incoming messages from content scripts
ssbBG.pages.handleMessage = function(message, sender) {
    
    // reject any message that's not from this extension
    if (! (sender && (sender.id == chrome.runtime.id))) {
	ssb.warn('ignoring message from',sender);
	return;
    }
    
    ssb.debug('pagemessage','got message:',message);

    // make sure it's a well-formed message
    if (! message.type) {
	ssb.warn('received badly formed message:', message,'from',sender);
	return false;
    }

    // parse the message
    switch (message.type) {
	
    case 'url':
	// URL message
	
	// hold onto this URL for a few seconds so we don't try to
	// close any new tab or send it to the main page
	
	// clear any old entry for this URL and start over
	var curRedirect;
	if (ssbBG.pages.urls[message.url]) {
	    curRedirect = ssbBG.pages.urls[message.url];
    	    if (curRedirect.timeout) {
		ssb.debug('pagemessage', 'clearing old timeout for',message.url);
		clearTimeout(curRedirect.timeout);
	    }
	}
	curRedirect = ssbBG.pages.urls[message.url] = { redirect: message.redirect };
	
	// figure out delay for the timeout based on what we're doing
	var delay = (message.redirect ? 4000 : (message.isMousedown ? 10000 : 2000));
	
	ssb.debug('pagemessage', 'adding entry with delay',delay,'for',message.url);
	
	// set a timeout to get rid of this redirect
	curRedirect.timeout = setTimeout(function(url) {
	    
	    // remove this redirect
	    var myRedirect = ssbBG.pages.urls[url];
	    ssb.debug('pagemessage', 'timed out', myRedirect);
	    if (myRedirect.redirect && ! myRedirect.response) {
		ssb.warn('no response to redirect request for '+url);
	    }
	    delete ssbBG.pages.urls[url];
	}, delay, message.url);
	
	// if we're redirecting, send the message to the native host now
	if (message.redirect) {
	    // send message
	    ssbBG.host.port.postMessage({"url": message.url});
	    ssb.debug('host', 'requesting redirect for url', message.url);
	}
	break;

    case 'windowSwitch':
	ssbBG.handleWindowSwitch();
	break;
	
    // case 'ping':
    // 	respond('ping');
    // 	break;
	
    default:
	ssb.warn('received unknown message type:', message.type,'from',sender);
    }

    return false;
}


// HOST -- object for communicating with native messaging host
// ---------------------------------------------------------

ssbBG.host = {};


// HOST.RECEIVEMESSAGE -- handler for messages from native host
ssbBG.host.receiveMessage = function(message) {

    ssb.debug('host', 'got message from host', message);
    
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
	if ('ssbID' in message) { status.ssbID = message.ssbID; }
	if ('ssbName' in message) { status.ssbName = message.ssbName; }
	if ('ssbShortName' in message) { status.ssbShortName = message.ssbShortName; }
	
	// add in whether we have a main tab
	if (ssbBG.mainTab) { status.mainTab = true; }
	
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
	    if (ssbBG.host.canCommunicate)
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


// WINDOW SWITCHING -- functions for switching the main
//                     window between app and tab style
// ----------------------------------------------------

// HANDLEWINDOWSWITCH -- switch a main app window between app-style and tabs style
ssbBG.handleWindowSwitch = function() {
    
    if (ssbBG.mainTab) {
	// find the main tab
	chrome.tabs.get(ssbBG.mainTab.id,
			function(tab) {
			    if (chrome.runtime.lastError) {
				
				// main tab not found
				ssb.warn('unable to find main tab',
					 ssbBG.mainTab.id,
					 '('+chrome.runtime.lastError.message+')');
			    } else {

				// find the main tab's window
				chrome.windows.get(tab.windowId, function(win) {
				    if (chrome.runtime.lastError) {

					// window not found
					ssb.warn('unable to find main window',
						 win.id,
						 '('+chrome.runtime.lastError.message+')');
				    } else {

					ssb.debug('windowSwitch', 'switching main window from '+win.type);

					// turn off tab/window activation listeners
					ssbBG.setContextMenuListeners(false);
					
					// switch the window style (experimenting shows that
					// you have to drop 22 pixels from height when coming
					// back from normal to popup, not sure why)
					chrome.windows.create({
					    tabId: ssbBG.mainTab.id,
					    type: (win.type == 'popup') ? 'normal' : 'popup',
					    left: win.left,
					    top: win.top,
					    width: win.width,
					    height: (win.type == 'popup') ? win.height : (win.height - 22)
					}, function(newWin) {
					    // tell the main tab about its new state
					    chrome.tabs.sendMessage(ssbBG.mainTab.id, {type: 'mainTab', state: newWin.type});
					    
					    // update context menu
					    ssbBG.updateContextMenu();
					    
					    // turn listeners back on
					    ssbBG.setContextMenuListeners(true);
					});
				    }
				});
			    }
			});
    }
}


// UPDATECONTEXTMENU -- update context menu when the active tab changes
ssbBG.updateContextMenu = function() {
    
    // first remove the context menu in case it already exists    
    ssbBG.removeContextMenu();
    
    // find the new active tab
    if (ssbBG.mainTab) {
	chrome.tabs.query({active: true, lastFocusedWindow: true}, function(tabs) {
	    if (tabs && (tabs.length == 1) && (tabs[0].id == ssbBG.mainTab.id)) {
		
		// the main tab is in front -- add the context menu back
		
		// get the main tab's window
		chrome.windows.get(tabs[0].windowId, function(win) {
		    
		    // create the context menu
		    chrome.contextMenus.create(
			{
			    id: 'windowSwitch',
			    title: ((win.type == 'popup') ? 'Show' : 'Hide') + ' Address Bar',
			    contexts: ['all']
			},
			function() {
			    if (chrome.runtime.lastError) {
				ssb.debug('contextMenu', "couldn't create:", chrome.runtime.lastError.message);
			    }
			});

		    // add listener for context menu
		    chrome.contextMenus.onClicked.addListener(ssbBG.handleWindowSwitch);
		});
		
	    }
	});
    }
}


// REMOVECONTEXTMENU -- remove the context menu
ssbBG.removeContextMenu = function() {

    // remove click listener
    chrome.contextMenus.onClicked.removeListener(ssbBG.handleWindowSwitch);

    // remove the menu
    chrome.contextMenus.remove('windowSwitch', function() {
	if (chrome.runtime.lastError) {
	    //ssb.debug('contextMenu', "couldn't remove:",chrome.runtime.lastError.message);
	}
    });
}


// SETCONTEXTMENULISTENERS -- add or remove context menu change listeners
ssbBG.setContextMenuListeners = function(add) {
    if (add) {
	chrome.tabs.onActivated.addListener(ssbBG.updateContextMenu);
	chrome.windows.onFocusChanged.addListener(ssbBG.updateContextMenu);
    } else {
	chrome.tabs.onActivated.removeListener(ssbBG.updateContextMenu);
	chrome.windows.onFocusChanged.removeListener(ssbBG.updateContextMenu);
    }
}


// BOOTSTRAP STARTUP
// -----------------

// handle new installation
chrome.runtime.onInstalled.addListener(ssbBG.handleInstall);

// handle Chrome startup
chrome.runtime.onStartup.addListener(ssbBG.handleChromeStartup);

// start the extension
ssbBG.startup();
