var ssbBG = {};

ssbBG.host = {};
ssbBG.host.sendUrl = function(url, sender) {
    // log the redirect, so if it ends up back here, we won't accidentally kill it
    var curRedirect = ssbBG.redirects[url] = { sent: true };
    
    // time out the redirect after a few seconds
    curRedirect.timeout = setTimeout(function(url) {
	var redirect = ssbBG.redirects[url];
	if (redirect && (! redirect.response))
	    ssbBG.shutdown('Redirect request timed out.');
	
	// remove this redirect
	delete ssbBG.redirects[url];
	
    }, 4000, url);
    
    // send message
    ssbBG.host.port.postMessage({"url": url});
    console.log("sent url redirect: " + url);
}

ssbBG.host.receiveMessage = function(message) {

    console.log('got response back',message);
    // we now know we have an operating port
    ssbBG.host.isReconnect = false;

    // parse response
    if ('url' in message) {
	ssbBG.redirects[message.url].response = true;
	if (message.result != "success") {
	    ssbBG.shutdown('Redirect request failed.');
	}
    } else {
	// unknown response from host
	ssbBG.shutdown('Redirect request returned unknown response.');
    }
}


ssbBG.host.connect = function(isReconnect) {
    // disconnect any existing connection
    if (ssbBG.host.port) ssbBG.host.port.disconnect();
    
    console.log(ssb.logPrefix + 'connecting to redirect host');
    
    // connect to host
    ssbBG.host.port = chrome.runtime.connectNative('com.dmarmor.ssb.redirect');
    ssbBG.host.isReconnect = isReconnect;

    // handle disconnect from the host
    ssbBG.host.port.onDisconnect.addListener(function () {
	var logmsg = ssb.logPrefix + 'disconnected from redirect host';

	if (ssbBG.host.isReconnect) {
	    // second connection attempt, so disconnect is an error
	    ssbBG.shutdown('Disconnected from redirect host');
	} else {
	    // we had a good connection or this was our first try, so retry
	    ssbBG.host.connect(true);
	}
    });
    
    // handle messages from the host
    ssbBG.host.port.onMessage.addListener(ssbBG.host.receiveMessage);
}


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


ssbBG.handlePing = function(message, sender, respond) {
    switch (message) {
    case 'ping':
	respond('ping');
	break;
    default:
	console.log(ssb.logPrefix + 'received unknown message:', message, sender);
    }
}


ssbBG.handleConnect = function(port) {
    port.onMessage.addListener(ssbBG.host.sendUrl);
}


ssbBG.handleChromeStartup = function() {
    // Chrome is starting up, so don't ping tabs yet
    if (ssbBG.startupTimeout)
	clearTimeout(ssbBG.startupTimeout);
}


ssbBG.pingTabs = function() {
    
    // ping all existing tabs & if dead, inject content scripts
    ssbBG.allTabs(function(tab, scripts) {
	
	// ping tab
    	chrome.tabs.sendMessage(tab.id, 'ping', function(response) {
	    
	    if (response != 'ping') {
		
		console.log(ssb.logPrefix + 'updating tab ' + tab.id);

		// no response, so inject content scripts
    		for(var i = 0 ; i < scripts.length; i++ ) {
    		    chrome.tabs.executeScript(tab.id, { file: scripts[i], allFrames: true });
    		}
    	    }
    	});
    }, ssb.manifest.content_scripts[0].js);
}


ssbBG.checkStatus = function() {
    console.log('got a status change!', localStorage.getItem('status'));
}


ssbBG.startup = function() {
    console.log(ssb.logPrefix + 'starting up');
    
    // start up shared code
    ssb.startup('background', function(success, message) {
	if (success) {
	    // we are active!
	    localStorage.setItem('status', JSON.stringify({ active: true }));
	    
	    // initialize redirects
	    ssbBG.redirects = {};
	    
	    // status change listener
	    window.addEventListener('storage', ssbBG.checkStatus);
	    
	    // set up listener for when pages connect to us
	    chrome.runtime.onConnect.addListener(ssbBG.handleConnect);
	    
	    // set up listener for handling pings
	    chrome.runtime.onMessage.addListener(ssbBG.handlePing);
	    
	    // connect to host
	    ssbBG.host.connect();
	    
	    // handle new tabs
	    chrome.tabs.onCreated.addListener(ssbBG.handleNewTab);
	    
	    // handle Chrome startup
	    chrome.runtime.onStartup.addListener(ssbBG.handleChromeStartup);
	    
	    // in 200ms, ping all tabs (unless canceled by Chrome startup)
	    ssbBG.startupTimeout = setTimeout(ssbBG.pingTabs, 200);
	} else {
	    ssbBG.shutdown(message);
	}
    });
}


ssbBG.shutdown = function(statusmessage) {

    // cancel outstanding timeouts
    if (ssbBG.redirects)
	Object.keys(ssbBG.redirects).forEach(
	    function(key, index) {
		console.log('clearing timeout for ' +key);
		clearTimeout(ssbBG.redirects[key].timeout);
	    });
    
    // tell all tabs to shut down
    ssbBG.allTabs(function(tab) {
	console.log(ssb.logPrefix + 'shutting down tab ' + tab.id);
	chrome.tabs.sendMessage(tab.id, 'shutdown');
    }, null, function() {
	
	// shut myself down
	if (ssbBG.host.port) ssbBG.host.port.disconnect();
	
	// remove listeners
	chrome.tabs.onCreated.removeListener(ssbBG.handleNewTab);
	chrome.runtime.onConnect.removeListener(ssbBG.handleConnect);
	chrome.runtime.onMessage.removeListener(ssbBG.handlePing);
	
	// set status in local storage
	localStorage.setItem('status', JSON.stringify({ active: false, message: statusmessage }));
	
	// open options page
	chrome.runtime.openOptionsPage();
	// shut down shared.js
	ssb.shutdown();
	
	// kill myself
	ssbBG = undefined;
    });
}


ssbBG.handleNewTab = function(tab) {
    if (!tab.url || (tab.url == 'chrome://newtab/')) {
	// blank tab
	console.log("Empty tab created -- ignore: " + tab.id + " openerTabId = " + tab.openerTabId);
    } else {
	console.log("Nav/incoming tab created: " + tab.id + " openerTabId = " + tab.openerTabId + " url = '" + tab.url + "'");
	
	if (!tab.openerTabId && ssbBG.redirects[tab.url]) {
	    console.log("  -- this tab came from me! let's get out of here");
	} else if (ssb.shouldRedirect(tab.url, 'external')) {
	    ssbHostSendUrl(tab.url);
	    chrome.tabs.remove(tab.id);
	} else
	    console.log('  -- passed rules, keeping it');
    }
}

ssbBG.startup();
