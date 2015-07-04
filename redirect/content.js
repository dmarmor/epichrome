// INITIALIZE BASE OBJECT

var ssbContent = {};


// regular expressions for checking hrefs
ssbContent.regexpAbsoluteHref = new RegExp(':'); // '^[a-zA-Z]([-a-zA-Z0-9$_@.&!*"\'():;, %]*):');
ssbContent.regexpDomain = new RegExp('://([^/]+)(/|$)');

// click handler
ssbContent.handleClick = function(evt) {
    
    // get fully-qualified URL to compare with our rules
    var originalHref = $(this).attr('href');
    if (originalHref) {
	var absoluteHref;
	var sameDomain;
	var isAbsolute = ssbContent.regexpAbsoluteHref.test(originalHref);
	if (isAbsolute) {
	    absoluteHref = originalHref;
	    sameDomain = (absoluteHref.match(ssbContent.regexpDomain)[1] == window.top.document.domain);
	} else {
	    absoluteHref = document.createElement('a');
	    absoluteHref.href = originalHref;
	    absoluteHref = absoluteHref.href;
	    sameDomain = true;
	}
    }
    
    // $$$ capture modifier keys for later use
    //console.log('shift=' + evt.shiftKey + ' alt=' + evt.altKey + ' ctrl=' + evt.ctrlKey + ' meta=' + evt.metaKey);
    
    // get target for this link
    var target = $(this).attr('target');
    if (target) { target = target.toLowerCase(); } else { target = '_self'; }
    switch (target) {
    case '_top':
	target = 'internal';
	break;
    case '_self':
	target = (ssbContent.isTopLevel ? 'internal' : false);
	break;
    case '_parent':
	target = (window.parent == window.top) ? 'internal' : false;
	break;
    case '_blank':
	target = 'external';
	break;
    default:
	target = $('frame[name="' + target + '"]', window.top.document).length ? false : 'external';
    }
    
    // non-top-level target
    if (!target) {
	console.log(ssb.logPrefix + 'ignoring sub-top-level target');
	return true;
    }

    if (target == 'internal') {

	if (ssb.options.ignoreAllInternalSameDomain) {

	    // link to same domain as main page
	    if (sameDomain) {
		console.log(ssb.logPrefix + 'ignoring link to same domain');
		return true;
	    }
	    
	    // relative link (ergo to same domain)
	    if (!isAbsolute) {
		console.log(ssb.logPrefix + 'ignoring relative link');
		return true;
	    }
	}
    }
    
    if (ssb.shouldRedirect(absoluteHref, target)) {
	ssbContent.port.postMessage(absoluteHref);
	return false;
    }
    
    return true;
}


ssbContent.handleMessage = function(message, sender, respond) {
    if (! sender.tab)
	switch (message) {
	case 'ping':
	    respond('ping');
	    break;
	case 'shutdown':
	    if (ssbContent.isTopLevel)
		console.log(ssb.logPrefix + 'extension shutting down');
	    ssbContent.shutdown();
	    break;
	    
	}
}


ssbContent.startup = function() {

    // run shared code
    ssb.startup('content', function(success, message) {
	
	if (success) {

	    // open persistent connection to background page
	    ssbContent.port = chrome.runtime.connect();
	    
	    if (ssbContent.port) {
				
		// Set up listener for messages from the background script
		chrome.runtime.onMessage.addListener(ssbContent.handleMessage);
		
		// am I a top-level window, or an iframe?
		if (window != window.top) {
		    //console.log(ssb.logPrefix + 'running in iframe: ' + window.name);
		    ssbContent.isTopLevel = false;
		} else {
		    //console.log(ssb.logPrefix + 'top window: ' + window.name);
		    console.log(ssb.logPrefix + 'starting up content script');
		    ssbContent.isTopLevel = true;
		}
		
		// set up a click handler for all links
		$( 'a' ).click(ssbContent.handleClick);
		
		// observe DOM mutations to install handler on any newly-created links
		ssbContent.mutationObserver = new MutationObserver(function(mutations) {
		    mutations.forEach(function(mutation) {
			if (mutation.addedNodes) {
			    for (var i = 0; i < mutation.addedNodes.length; ++i) {
				var $links = $('a', mutation.addedNodes[i]);
				$links.unbind();
				$links.click(ssbContent.handleClick);
			    }
			}
		    });
		});
		var bodyNode = document.querySelector('body');
		if (bodyNode) ssbContent.mutationObserver.observe(bodyNode, { childList: true, subtree: true });
		
		// If we get disconnected, shut down this content script ($$$ could trigger reconnect)
		ssbContent.port.onDisconnect.addListener(ssbContent.shutdown);
		
	    } else {
		ssbContent.shutdown('Failed to connect to background page');
	    }
	} else {
	    ssbContent.shutdown('Extension failed to start up.');
	}
    });
}


ssbContent.shutdown = function(message) {
    
    if (ssbContent.isTopLevel) console.log(ssb.logPrefix + 'Shutting down content script' + (message ? ': ' + message : '.'));
    
    // turn off observer
    if (ssbContent.mutationObserver) ssbContent.mutationObserver.disconnect();
    
    // disconnect from background script
    if (ssbContent.port) ssbContent.port.disconnect();
    
    // stop listening for messages from background script
    chrome.runtime.onMessage.removeListener(ssbContent.handleMessage);
    
    // remove old handlers
    $('a').unbind();
    
    // unload jQuery
    delete window.jQuery;
    delete window.$;
    
    // shut down shared.js
    ssb.shutdown();
    
    ssbContent = undefined;
}


// START UP CONTENT SCRIPT

ssbContent.startup();
