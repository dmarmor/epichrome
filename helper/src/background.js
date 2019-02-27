/*! background.js
(c) 2017 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/* 
 *
 * background.js: background page for Epichrome Runtime extension
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

ssbBG = {};

// $$$ TESTING
ssbBG.isChromeStartup = false;

// HANDLECHROMESTARTUP -- prevent initializing tabs on Chrome startup
ssbBG.handleChromeStartup = function() {
    // Chrome is starting up, so don't initialize tabs
    ssbBG.isChromeStartup = true;
    
    ssb.debug('startup', 'Chrome starting up');
}

// handle Chrome startup
chrome.runtime.onStartup.addListener(ssbBG.handleChromeStartup);


// $$$ DOCUMENT
ssbBG.events = {
    interaction: undefined,
    newTab: undefined
}

//ssbBG.lastWebNav = undefined;


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
	    localStorage.setItem('status',
				 JSON.stringify(
				     {
					 active: false,
					 startingUp: true,
					 message: 'Please wait...'
				     }));

	    // $$$ get rid of this?
	    // initialize pages.urls
	    // ssbBG.pages.urls = {};
	    
	    // status change listener (we don't need to do anything)
	    //window.addEventListener('storage', function() { ssb.debug('storage', 'got a status change!'); });
	    
	    // create context menus
	    ssbBG.contextMenuCreate(undefined, 'epichrome', 'Epichrome');
	    ssbBG.contextMenuCreate('epichrome', 'urlDefaultBrowser',
				    'Open in Default Browser (⌘⇧-click)', ['link']);
	    ssbBG.contextMenuCreate('epichrome', 'separator1',
				    undefined, ['link'], 'separator');
	    ssbBG.contextMenuCreate('epichrome', 'urlThisAppNewWindow',
				    'Open in New App Window (X⇧-click)', ['link']);
	    ssbBG.contextMenuCreate('epichrome', 'urlThisAppNewTab',
				    'Open in New Tab (X⌘-click)', ['link']);
	    ssbBG.contextMenuCreate('epichrome', 'urlThisAppSameTab',
				    'Open in Same Window (X⌘⇧-click)', ['link']);
	    ssbBG.contextMenuCreate('epichrome', 'separator2',
				    undefined, ['link'], 'separator');
	    ssbBG.contextMenuCreate('epichrome', 'windowSwitch',
				    'Show/Hide Address Bar (⌘⇧L)');
	    ssbBG.contextMenuCreate('epichrome', 'separator3',
				    undefined, ['link'], 'separator');
	    ssbBG.contextMenuCreate('epichrome', 'options',
				    'Options...');
	    
	    // set initial context menu text
	    //ssbBG.focusChangeHandler();
	    
	    // set up handlers for context menu
	    chrome.contextMenus.onClicked.addListener(ssbBG.contextMenuHandler);
	    // chrome.tabs.onActivated.addListener(ssbBG.focusChangeHandler);
	    // chrome.windows.onFocusChanged.addListener(ssbBG.focusChangeHandler);

	    
	    // } else {
	    // 	ssb.debug('initTabs', 'no main tab found');
	    // }
	    
	    // set up handler for keepalive connections
	    chrome.runtime.onConnect.addListener(ssbBG.handleKeepaliveConnect);
	    
	    // connect to host for the first time
	    ssbBG.host.canCommunicate = false;
	    ssbBG.host.connect();
	    
	    // set up handlers for tab changes
	    chrome.tabs.onCreated.addListener(ssbBG.tabCreatedHandler);

	    // set up handlers for webNavigation events
	    chrome.webNavigation.onCreatedNavigationTarget.addListener(ssbBG.navTargetCreatedHandler);
	    
	    // $$$ set up handlers for webRequest events
	    chrome.webRequest.onBeforeRequest.addListener(ssbBG.beforeRequestHandler,
							  {urls: ["<all_urls>"],
							   types: ["main_frame"]},
							  ["blocking"]);
	    
	    // give Chrome startup 500ms to register, then if we're not in Chrome startup,
	    // give content scripts 1000ms to register, or reload them
	    setTimeout(function() {
		if (!ssbBG.isChromeStartup) {
		    setTimeout(function() {
			ssb.debug('initTabs', 'reloading all tabs -- not in Chrome startup');
			
			ssbBG.allTabs(
			    function(tab, win, scripts) {
				
				ssb.debug('initTabs', 'sending ping to tab', tab.id);
				
				// not in startup, so fire up tabs
				chrome.tabs.sendMessage(tab.id, 'ping', function(response) {
		    		    
				    if (response != 'ping') {
					ssb.debug('initTabs', 'reloading tab', tab.id);
					
					// inject all content scripts
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
				    } else {
					ssb.debug('initTabs', 'NOT reloading tab', tab.id,'-- got ping');
				    }
				});
			    },
			    ssb.manifest.content_scripts[0].js);
		    }, 1000);
		} else {
		    ssb.debug('initTabs', 'NOT reloading tabs -- in Chrome startup');
		}
	    }, 500);
	} else {
	    ssbBG.shutdown(message);
	}
    });
}


// SHUTDOWN -- shuts the extension down
ssbBG.shutdown = function(statusmessage) {
    
    ssb.log(ssb.logPrefix + ' is shutting down:', statusmessage);
    
    // // $$$ KILL THIS cancel page timeouts
    // if (ssbBG.pages.urls)
    // 	Object.keys(ssbBG.pages.urls).forEach(
    // 	    function(key) {
    // 		ssb.debug('shutdown', 'clearing timeout for ' + key);
    // 		clearTimeout(ssbBG.pages.urls[key].timeout);
    // 	    });
    
    // $$$ OBSOLETE? tell all tabs to shut down
    // ssbBG.allTabs(function(tab) {
    // 	ssb.debug('shutdown', 'shutting down tab', tab.id);
    // 	chrome.tabs.sendMessage(tab.id, {type: 'shutdown'});
    // }, null, function() {
	
    // shut myself down
    if (ssbBG.host.port) ssbBG.host.port.disconnect();
    
    // clear context menu
    // chrome.tabs.onActivated.removeListener(ssbBG.focusChangeHandler);
    // chrome.windows.onFocusChanged.removeListener(ssbBG.focusChangeHandler);
    chrome.contextMenus.onClicked.removeListener(ssbBG.contextMenuHandler);
    chrome.contextMenus.removeAll();
    
    // remove listeners
    chrome.tabs.onCreated.removeListener(ssbBG.tabCreatedHandler);
    chrome.webNavigation.onCreatedNavigationTarget.removeListener(ssbBG.navTargetCreatedHandler);
    chrome.webRequest.onBeforeRequest.removeListener(ssbBG.beforeRequestHandler);
    
    chrome.runtime.onConnect.removeListener(ssbBG.handleKeepaliveConnect);
    
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
    
    // });
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
    
    ssb.debug('keepalive',
	      'connected to tab', port.sender.tab.id,
	      'frame', port.sender.frameId, port.sender);

    // set up handler for messages from content scripts
    port.onMessage.addListener(ssbBG.keepaliveMessageHandler);
}


// $$$ GET RID OF recal parameter
// TABCREATEDHANDLER -- process a newly-opened tab
ssbBG.tabCreatedHandler = function(tab) {
    
    /// $$$ NEW CODE -- DOCUMENT
    var eventTime = Date.now();
    
    // check if we've been ordered to convert this tab to an app-style window
    if (ssbBG.events.convertTabToApp) {
	var convertToNewTab = eventTime - ssbBG.events.convertTabToApp;
	if ((convertToNewTab >= 0) && (convertToNewTab < 200)) {
	    ssb.debug('newTab', 'CONVERT', '('+convertToNewTab+')', tab);
	    ssbBG.actionHandler('windowSwitch', tab, 'popup');
	} else {
	    ssb.debug('newTab', 'ignore convert order -- too old', '('+convertToNewTab+')', tab);
	}
	
	// either way, delete this convert request
	ssbBG.events.convertTabToApp = undefined;
	
    // check if tab opened directly after interaction
    } else if (tab.url && (tab.url != 'chrome://newtab/')) { // && (tab.url != 'about:blank')
	
	if (!ssb.regexpChromeScheme.test(tab.url)) {
	    
	    if (ssbBG.events.interaction) {
		var interactToNewTab = eventTime - ssbBG.events.interaction.time;
		
		if ((interactToNewTab >= 0) && (interactToNewTab < 200)) {
		    
		    // $$$ KILL
		    ssb.debug('newTab', 'CAPTURE', tab.url, '('+interactToNewTab+')', tab);
		    
		    // determine if we should redirect this tab
		    ssbBG.redirectNewTab(tab.id, tab.url);
		    
		    // we've officially used up this user interaction
		    ssbBG.events.interaction = undefined;
		    
		    return;
		}
	    }
	    
    	    // $$$ has URL but not captured
    	    ssbBG.events.newTab = { tab: tab, time: eventTime, hasUrl: true };

	    // $$$ KILL THIS
    	    if (!ssbBG.events.interaction)
		ssb.debug('newTab', 'LOG -- no user interaction');
	    else // if (interactToNewTab out of range)
		ssb.debug('newTab', 'LOG -- interaction time mismatch', eventTime, interactToNewTab, tab);
    	} else {
	    
    	    // else -- chrome:// page, so ignore

	    // $$$ KILL THIS
	    ssb.debug('newTab', 'IGNORE -- tab for chrome:// page', tab);
	}
    } else {
    	// blank tab -- log
    	ssbBG.events.newTab = { tab: tab, time: eventTime, hasUrl: false };
    	ssb.debug('newTab', 'LOG -- empty tab', tab);
    }
}


// NAVTARGETCREATEDHANDLER -- handle a newly-created navigation target
ssbBG.navTargetCreatedHandler = function(details) {
    
    // $$$ TESTING
    if (!ssb.regexpChromeScheme.test(details.url) &&
	ssbBG.events.interaction &&
	ssbBG.events.newTab && !ssbBG.events.newTab.hasUrl &&
       	(details.sourceTabId == ssbBG.events.interaction.tabId) &&
	(details.tabId == ssbBG.events.newTab.tab.id)) {
	
	var interactToNewTab = ssbBG.events.newTab.time - ssbBG.events.interaction.time;
	var newTabToWebNav = Math.abs(details.timeStamp - ssbBG.events.newTab.time);
	
	if ((interactToNewTab >= 0) && (interactToNewTab < 200) &&
	    (newTabToWebNav < 200)) {

	    if (details.url == 'about:blank') {

		// this probably came from a Javascript that hasn't populated the tab yet
		ssbBG.events.navTarget = {
		    details: details,
		    interaction: ssbBG.events.interaction
		};
				
		ssb.debug('navTarget', 'LOG -- target URL is about:blank', details);
	    } else {
		
		// debug
		ssb.debug('navTarget', 'CAPTURE (', interactToNewTab, '+', newTabToWebNav, ')',
			  details);
		
		// determine if we should redirect this tab
		ssbBG.redirectNewTab(details.tabId, details.url);
	    }

	    // $$$ KILL NEWTAB EVENT I THINK (MAYBE NOT INTERACTION TO HANDLE MULTIPLES)
	    ssbBG.events.newTab = undefined;
	    
	} else {
	    // $$$ KILL THIS
	    ssb.debug('navTarget', 'IGNORE -- bad interaction/newTab times (',
		      interactToNewTab, '/', newTabToWebNav, ')', details);
	}
    } else {
	// $$$ KILL THIS
	if (ssb.regexpChromeScheme.test(details.url))
	    ssb.debug('navTarget', 'IGNORE -- chrome:// URL', details);
	else if (!ssbBG.events.interaction)
	    ssb.debug('navTarget', 'IGNORE -- no interaction found', details);
	else if (!ssbBG.events.newTab)
	    ssb.debug('navTarget', 'IGNORE -- no newTab found', details);
	else if (ssbBG.events.newTab.hasUrl)
	    ssb.debug('navTarget', 'IGNORE -- newTab already has URL',
		      ssbBG.events.newTab, details);
	else if (details.sourceTabId != ssbBG.events.interaction.tabId)
	    ssb.debug('navTarget', 'IGNORE -- navTarget sourceTabId not interaction tab (',
		      details.sourceTabId, '/', ssbBG.events.interaction.tabId, ')',
		      details);
	else // if (details.tabId == ssbBG.events.newTab.tab.id)
	    ssb.debug('navTarget', 'IGNORE -- navTarget not in same tab as newTab (',
		      details.sourceTabId, '/', ssbBG.events.interaction.tabId, ')',
		      details);
    }
}

// $$$ BEFOREREQUESTHANDLER -- handle navigation starting
ssbBG.beforeRequestHandler = function(details) {

    // by default don't interfere with request
    var result = undefined;
    
    // $$$$ document
    if (ssbBG.lastWebRequest && (details.requestId == ssbBG.lastWebRequest.requestId)) {
	ssb.debug('beforeRequest', 'IGNORE -- request already handled', details);
    } else {
	
	// this is now the last request
	ssbBG.lastWebRequest = details;
	
	if ((details.method == 'GET') && !ssb.regexpChromeScheme.test(details.url)) {

	    var handled = false;
	    
	    if (ssbBG.events.navTarget) {
		var navTargetToRequest = details.timeStamp - ssbBG.events.navTarget.details.timeStamp;
		
		if ((navTargetToRequest >= 0) && (navTargetToRequest < 500)) {
		    
		    if (details.tabId == ssbBG.events.navTarget.details.tabId) {

			ssb.debug('beforeRequest', 'CAPTURE late navTarget', details, ssbBG.events.navTarget);
			
			// determine if we should redirect this tab
			ssbBG.redirectNewTab(details.tabId, details.url,
					     ssbBG.events.navTarget.interaction);
			
			handled = true;			
		    } else {
			// $$$ debug
			ssb.debug('beforeRequest', 'IGNORE late navTarget -- different tab from target (',
				  details.tabId, '/', ssbBG.events.navTarget.tabId, ')', details);
		    }
		    
		} else {
		    // this navTarget is too old
		    killNavTarget = true;
		    
		    ssb.debug('beforeRequest', 'IGNORE late navTarget -- too late',
			      navTargetToRequest, details, ssbBG.events.navTarget);
		}
				
		// possibly kill this navTarget
		if (handled || killNavTarget || !ssbBG.events.interaction ||
		    (ssbBG.events.interaction.time > ssbBG.events.navTarget.details.timeStamp)) {
		    
		    ssbBG.events.navTarget = undefined;

		    // $$$ debug
		    if (!handled && !killNavTarget) {
			if (!ssbBG.events.interaction)
			    ssb.debug('beforeRequest', 'KILL late navTarget -- no interaction found', details);
			else // if interaction time > navTarget time
			    ssb.debug('beforeRequest', 'KILL late navTarget -- interaction after navTarget', details);
		    }
		}
	    } else {
		ssb.debug('beforeRequest', 'IGNORE late navTarget -- no target found', details);
	    }

	    // not handled as late navTarget, try handling as interaction result
	    if (!handled) {
		if (ssbBG.events.interaction &&
		    (details.tabId == ssbBG.events.interaction.tabId)) {
		
		    var interactToRequest = details.timeStamp - ssbBG.events.interaction.time;
		    
		    if ((interactToRequest >= 0) && (interactToRequest < 200)) {
			
			ssb.debug('beforeRequest', 'CAPTURE', '('+interactToRequest+')', details);
			
			// run rules here
			if (ssb.shouldRedirect(details.url, 'internal', ssbBG.events.interaction.classList)) {
			    ssbBG.host.port.postMessage({'url': details.url});
			    result = { redirectUrl: ssbBG.events.interaction.curUrl };
			}
			
			// kill interaction event
			ssbBG.events.interaction = undefined;
		    } else {
			// $$$$ KILL THIS
			ssb.debug('beforeRequest', 'IGNORE -- bad interaction time',
				  '('+interactToRequest+')', details);
		    }
		} else {
		    if (!ssbBG.events.interaction)
			ssb.debug('beforeRequest', 'IGNORE -- no interaction found', details);
		    else // if (details.tabId != ssbBG.events.interaction.tabId)
			ssb.debug('beforeRequest', 'IGNORE -- different tab from interaction (',
				  details.tabId, '/', ssbBG.events.interaction.tabId, ')', details);
		}
	    }
	} else {
	    // $$$ KILL THIS
	    if (details.method != 'GET')
		ssb.debug('beforeRequest', 'IGNORE -- non-GET request', details);
	    else // if (!ssb.regexpChromeScheme.test(details.url))
		ssb.debug('beforeRequest', 'IGNORE -- chrome:// URL', details.url, details);
	}
    }
    
    return result;
}



// $$$ DOCUMENT
ssbBG.redirectNewTab = function(tabId, url, interaction) {

    if (!interaction) interaction = ssbBG.events.interaction;
    
    if (ssb.shouldRedirect(url, 'external', interaction.classList)) {
	// send the redirect
	ssbBG.host.port.postMessage({'url': url});
	chrome.tabs.remove(tabId);
	
	// refocus tab that created this tab
	chrome.windows.update(interaction.windowId, { focused: true });
	chrome.tabs.update(interaction.tabId, { active: true });
	
	return true;
    }
    
    return false;
}





// ACTIONHANDLER -- main dispatcher to handle action messages
ssbBG.actionHandler = function(action, tab, info) {

    ssb.debug('actionHandler', 'got request:', action, tab, info);
    
    switch (action) {
	
    case 'windowSwitch':
	chrome.tabs.get(tab.id, function(curTab) {
	    
	    if (!chrome.runtime.lastError) {
		
		// find the tab's window
		chrome.windows.get(curTab.windowId, function(win) {
		    if (!chrome.runtime.lastError) {
			
			var newType = undefined;
			
			if (info && (info != win.type)) {
			    newType = info;
			} else {
			    newType = (win.type == 'popup') ? 'normal' : 'popup';
			}

			if (newType) {
			    ssb.debug('setWindowType', 'setting window', win.id, 'to', newType);
			    
			    // switch the window style
			    chrome.windows.create(
				{
				    tabId: curTab.id,
				    type: newType,
				    left: win.left,
				    top: win.top,
				    width: win.width,
				    height: win.height
				},
				function() {
				    if (chrome.runtime.lastError) {
					// window not found
					ssb.warn('unable to set window type for tab',
						 curTab.id,
						 '('+chrome.runtime.lastError.message+')');
				    }
				});
			} else {
			    ssb.debug('setWindowType', 'ignoring -- window is already', win.type);
			}
		    } else {
			// window not found
			ssb.warn('unable to find window for tab',
				 tab.id,
				 '('+chrome.runtime.lastError.message+')');
		    }
		});
	    } else {
		// tab not found
		ssb.warn('unable to find tab', tab.id,
			 '('+chrome.runtime.lastError.message+')');
	    }
	});
	break;
	
    case 'urlDefaultBrowser':
	// open the URL in the default browser
	ssbBG.host.port.postMessage({'url': info});
	break;
	
    case 'urlThisAppNewWindow':
	// open the URL in a new app-style window
	chrome.windows.create({ url: info, type: 'popup' });
	break;

    case 'urlThisAppNewTab':
	// open the URL in a new Chrome-style tab
	chrome.tabs.create({ url: info });
	break;
	
    case 'urlThisAppSameTab':
	// open the URL in the same tab even if it would usually open in a new one
	chrome.tabs.update(tab.id, { url: info });
	break;
	
    case 'convertTabToApp':
	// expect a tab to open & tell it to convert to an app-style window
	ssbBG.events.convertTabToApp = info;
	ssb.debug('convertTabToApp', 'convert next new tab after', info);
	break;
	
	// $$$ DOCUMENT
    case 'interaction':
	// clear any old interaction
	ssbBG.events.interaction = undefined;
	
	if (info) {
	    info.tabId = tab.id;
	    info.windowId = tab.windowId;
	    
	    if (info.isLate) {
		if (ssbBG.events.newTab && ssbBG.events.newTab.hasUrl) {
		    
		    var newTabToInteract = info.time - ssbBG.events.newTab.time;
		    
		    if ((newTabToInteract >= 0) && (newTabToInteract < 200)) {
			// check if late interaction is directly after tab opened
			// $$$ this captures ONLY tabs opened through the context menu
			
			// $$$ FIX THIS determine if we should redirect
			ssb.debug('interaction',
				  'CAPTURE new tab with url from context menu click',
				  '('+newTabToInteract+')');

			// redirect or not
			ssbBG.redirectNewTab(ssbBG.events.newTab.tab.id,
					     ssbBG.events.newTab.tab.url,
					     info);
			
		    } else {
			// $$$ KILL THIS ELSE
			ssb.debug('interaction',
				  'IGNORE context menu/new tab too far apart',
				  '('+newTabToInteract+')');
		    }
		} else {
		    // $$$ KILL THIS ELSE
		    ssb.debug('interaction',
			      'IGNORE -- context menu/new tab mismatch',
			      info, ssbBG.events.newTab);
		}
	    } else {
		ssbBG.events.interaction = info;
		ssb.debug('interaction', 'LOG', info.type,
			  'at', '-' + (Date.now() - info.time), info);
	    }
	} else {
	    ssb.debug('interaction', 'CLEAR');
	}
	break;
	
    default:
	ssb.warn('received unknown action', action, 'from', tab);
    }
}


// $$$$  HANDLEMESSAGE -- handle incoming messages from content scripts
ssbBG.keepaliveMessageHandler = function(message, port) {
    
    // make sure it's a well-formed message
    if (! message.type) {
	ssb.warn('received badly formed message:', message,'from', port.sender);
	return false;
    }

    // send to action handler
    ssbBG.actionHandler(message.type, port.sender.tab, message.info);
    
    return false;
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

	// $$$ obsolete -- remove and fix options page
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


// $$$ CLEAN UP ORDER/NAMING/COMMENTS
// WINDOW SWITCHING -- functions for switching the main
//                     window between app and tab style
// ----------------------------------------------------
ssbBG.contextMenuCreate = function(parent, id, title, contexts, type) {
    chrome.contextMenus.create(
	{
	    parentId: parent,
	    type: type,
	    id: id,
	    title: title,
	    contexts: (contexts ? contexts : ['all'])
	},
	function() {
	    if (chrome.runtime.lastError) {
		ssb.warn('Error creating context menu item "'+title+'":',
			 chrome.runtime.lastError.message);
	    }
	});
}


// $$$ fix documentation
// contextMenuHandler -- switch a window between app-style and tabs style
ssbBG.contextMenuHandler = function(info, tab) {

    if (info.menuItemId == 'options') {
	chrome.tabs.create({ url: 'chrome-extension://' + chrome.runtime.id + '/options.html'})
    } else {
	ssbBG.actionHandler(info.menuItemId, tab, info.linkUrl);
    }
}


// REGEXPS
// -----------------

// REGEXPSTRINGIFY
ssbBG.regexpEscapeStringify = new RegExp("['\\\\]", 'g');


// BOOTSTRAP STARTUP
// -----------------

// handle new installation
chrome.runtime.onInstalled.addListener(ssbBG.handleInstall);

// start the extension
ssbBG.bootstrap = function() {
    if (typeof ssb === 'object') {
	ssb.debug('bootstrap', 'starting up -- shared.js loaded!');
	ssbBG.startup();
    } else {
	console.debug('[bootstrap]:', 'delaying startup -- shared.js not yet loaded');
	setTimeout(ssbBG.bootstrap, 500);
    }
}

ssbBG.bootstrap();
