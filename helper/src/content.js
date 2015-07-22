/*! content.js
(c) 2015 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/*
 * 
 * content.js: content script for Epichrome Helper extension
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


// SSBCONTENT -- object that holds all data & methods
// --------------------------------------------------

var ssbContent = {};


// STARTUP/SHUTDOWN -- handle startup, shutdown & installation
// -----------------------------------------------------------

// STARTUP -- start up the content script
ssbContent.startup = function() {
    
    // run shared code
    ssb.startup('content', function(success, message) {

	// shared code loaded successfully
	if (success) {
	    
	    // open persistent connection to background page
	    ssbContent.port = chrome.runtime.connect();
	    
	    if (ssbContent.port) {
		
		// if we get disconnected, shut down this content script
		ssbContent.port.onDisconnect.addListener(ssbContent.shutdown);
		
		// Set up listener for messages from the background script
		chrome.runtime.onMessage.addListener(ssbContent.handleMessage);
		
		// am I a top-level window, or an iframe?
		if (window != window.top) {
		    ssbContent.isTopLevel = false;
		} else {
		    ssb.log('starting up content script');
		    ssbContent.isTopLevel = true;

		    // add global keydown handler for hotkeys
		    document.addEventListener('keydown', ssbContent.handleHotKey);

		    //$$$ REMOVE THIS ON SHUTDOWN!!!
		}

		// add click and mousedown handlers for all links
		ssbContent.updateLinkHandlers(document, true);
				
		// watch DOM mutations to attach handler on newly-created links
		ssbContent.mutationObserver =
		    new MutationObserver(ssbContent.handleMutation);
		
		// attach mutation observer to body node
		if (document.body)
		    ssbContent.mutationObserver.observe(document.body,
							{ childList: true,
							  subtree: true
							});
		
	    } else {
		ssbContent.shutdown('Failed to connect to background page');
	    }
	} else {
	    ssbContent.shutdown('extension failed to start up ('+message+')');
	}
    });
}

// SHUTDOWN -- shut down the content script
ssbContent.shutdown = function(message) {
    
    if (ssbContent.isTopLevel)
	ssb.log('shutting down content script' +
		((typeof message == 'string') ? (': ' + message) : '.'));
    
    // turn off observer
    if (ssbContent.mutationObserver) ssbContent.mutationObserver.disconnect();
    
    // disconnect from background script
    if (ssbContent.port) ssbContent.port.disconnect();

    // stop listening for global hotkeys
    if (ssbContent.isTopLevel)
	document.removeEventListener('keydown', ssbContent.handleHotKey);
    
    // stop listening for messages from background script
    chrome.runtime.onMessage.removeListener(ssbContent.handleMessage);
    
    // remove old handlers
    ssbContent.updateLinkHandlers(document, false);
    
    // shut down shared.js
    ssb.shutdown();

    // kill object
    delete window.ssbContent;
}


// ADD/REMOVE LINK HANDLERS -- keep link handlers up to date
//----------------------------------------------------------

// UPDATELINKHANDLERS -- add/remove click/mousedown handlers
ssbContent.updateLinkHandlers = function(node, add) {

    // get a list of links
    var links;
    if (ssbContent.isLink(node))
	// this node is itself a link (which can't contain nested links)
	links = [node];
    else
	// get an array of all links under the node
	links = node.querySelectorAll('a');
    
    // go through all links
    var i = links.length; while (i--) {

	links[i].removeEventListener('click', ssbContent.handleClick);
	links[i].removeEventListener('mousedown', ssbContent.handleClick);
	    
	if (add) {
	    // optionally add new handlers
	    links[i].addEventListener('click', ssbContent.handleClick);
	    links[i].addEventListener('mousedown', ssbContent.handleClick);
	}
    }
}


// HANDLEMUTATION -- handle an observed set of mutations
ssbContent.handleMutation = function(mutations) {
    
    // go through all mutations
    var i = mutations.length; while (i--) {
	
	var curMut = mutations[i];
	if (curMut.addedNodes) {
	    
	    // go through each added node
	    var j = curMut.addedNodes.length; while (j--) {
		
		// update link handlers for each node that's an element
		var curNode = curMut.addedNodes[j];
		if (curNode instanceof HTMLElement) {
		    ssbContent.updateLinkHandlers(curNode, true);
		}
	    }
	}
    }
}


// HANDLECLICK -- handle clicks and mousedowns on links
// ----------------------------------------------------

ssbContent.handleClick = function(evt) {
    
    var topWindow = window.top;
    var link = evt.currentTarget;
    
    // make sure we haven't already handled this event
    // this can happen when a clever page delegates a click event to a link
    // nested inside it
    if (evt.timeStamp == ssbContent.lastClick) {
	ssb.debug('click', 'event timestamp',evt.timeStamp,'has already been handled');
	return true;
    }

    // log this click
    ssbContent.lastClick = evt.timeStamp;
    
    ssb.debug('click', 'got '+evt.type+' event on:', link);
    if (evt.target != evt.currentTarget)
	ssb.debug('click', 'delegated from:', evt.target);
    
    // make sure we're actually a link
    if (! ssbContent.isLink(link)) {
	ssb.warn('non-link received link event');
	return true;
    }
    
    // get fully-qualified URL to compare with our rules
    var href = link.href;

    // no href, so ignore this link
    if (!href) {
	ssb.debug('click', 'link has no href, so quitting');
	return true;
    }
    
    // determine if link goes to the same domain as the main page
    var sameDomain = (href.match(ssbContent.regexpDomain)[1] ==
		      topWindow.document.domain);
    
    // $$$ future development: capture modifier keys
    // ssb.log('shift =', evt.shiftKey, 'alt =', evt.altKey,
    //         'ctrl =', evt.ctrlKey, 'meta =', evt.metaKey);
    
    // we don't yet know if we're redirecting this
    var doRedirect = undefined;
    var message = {};
    
    // determine which type of mouse event got us here
    if (evt.type == 'mousedown') {

	// don't redirect yet
	doRedirect = false;
	message.isMousedown = true;
	
	// just send a long-lasting message to log the click
	ssb.debug('click', 'sending long-lasting mousedown message', evt);
	
    } else { // it's a click, so we'll handle it fully
	
	// get target for this link
	var target = link.target;
	if (target) {
	    target = target.toLowerCase();
	} else {
	    target = '_self';
	}

	// normalize the target
	switch (target) {
	case '_top':
	    target = 'internal';
	    break;
	case '_self':
	    target = (ssbContent.isTopLevel ? 'internal' : false);
	    break;
	case '_parent':
	    target = (window.parent == topWindow) ? 'internal' : false;
	    break;
	case '_blank':
	    target = 'external';
	    break;
	default:
	    // if the target names a frame on this page, it's non-top-level
	    var frameSelector='[name="' + target + '"]';
	    target =
		(topWindow.document.querySelector('iframe'+frameSelector+
						  ',frame'+frameSelector) ?
		 false :
		 'external');
	}
	
	if (!target) {
	    
	    // non-top-level target
	    ssb.debug('click', 'sub-top-level target -- ignore');
	    doRedirect = false;
	    
	} else if (target == 'internal') {

	    // internal target, check global rules
	    if (ssb.options.ignoreAllInternalSameDomain) {
		
		if (sameDomain) {
		    // link to same domain as main page
		    ssb.debug('click', 'link to same domain -- ignore');
		    doRedirect = false;
		}
	    }
	}

	// if we still haven't decide if we're redirecting, use rules
	if (doRedirect == undefined) {
	    doRedirect = ssb.shouldRedirect(href, target);
	}
    }
    
    ssb.debug('click', 'posting message -- doRedirect =',doRedirect,
	      ' url:',href,'['+target+']');
    
    // tell the background page about this click
    message.redirect = doRedirect;
    message.url = href;
    ssbContent.port.postMessage(message);
    
    // if redirecting, prevent the default click action
    if (doRedirect) {
	ssb.debug('click', 'preventing default action');
	evt.preventDefault();

	// if options say so, also stop propagation on the click event
	if (ssb.options.stopPropagation) {
	    ssb.debug('click', 'stopping event propagation');
	    evt.stopPropagation();
	}
    }
}


// HANDLEMESSAGE -- handle incoming one-time messages from the background page
// ---------------------------------------------------------------------------

ssbContent.handleMessage = function(message, sender, respond) {

    // ensure the message is from the background page
    if (! sender.tab)
	switch (message) {
	    
	case 'ping':
	    // respond to a ping
	    respond('ping');
	    break;
	    
	case 'shutdown':
	    // the extension is shutting down
	    ssbContent.shutdown();
	    break;
	}
}


// HANDLEHOTKEY -- handle global hot-keys
ssbContent.handleHotKey = function(evt) {
    if ((evt.keyCode == 76) &&
	evt.metaKey &&
	(! evt.shiftKey) && (! evt.altKey) && (! evt.ctrlKey)) {
	
	// Command-L
	console.log('got command-L');
    } else if ((evt.keyCode == 76) &&
	       evt.metaKey && evt.shiftKey &&
	       (! evt.altKey) && (! evt.ctrlKey)) {
	
	// Command-Shift-L
	console.log('got command-shift-L');
    } else {
	console.log('got key '+evt.keyCode);
    }    
}


// UTILITY -- for getting info on links
// ------------------------------------

// ISLINK -- determine if a node is a link
ssbContent.isLink = function(node) {
    return (node && node.tagName &&
	    (typeof node.tagName == 'string') &&
	    (node.tagName.toLowerCase() == 'a'));
}

// REGEXPABSOLUTEHREF -- regex to match any absolute URL (with scheme & domain)
// { was: '^[a-zA-Z]([-a-zA-Z0-9$_@.&!*"\'():;, %]*):'); }
ssbContent.regexpAbsoluteHref = new RegExp(':');

// REGEXPDOMAIN -- regex that grabs the domain from a URL
ssbContent.regexpDomain = new RegExp('://([^/]+)(/|$)');


// BOOTSTRAP STARTUP
// -----------------

ssbContent.startup();
