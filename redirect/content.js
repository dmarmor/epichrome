//
//  content.js: content script for Mac SSB Helper extension
//
//  Copyright (C) 2015 David Marmor
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
// 


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
		}
		
		// set up click and mousedown handlers for all links
		$( 'a' ).on('click.ssbContent mousedown.ssbContent',
			    ssbContent.handleClick);
		
		// watch DOM mutations to attach handler on newly-created links
		ssbContent.mutationObserver =
		    new MutationObserver(function(mutations) {
			mutations.forEach(function(mutation) {
			    if (mutation.addedNodes) {
				for (var i = 0; i < mutation.addedNodes.length; ++i) {
				    var $links = $('a',
						   mutation.addedNodes[i]);
				    $links.off();
				    $links.on('click.ssbContent mousedown.ssbContent',
					      ssbContent.handleClick);
				}
			    }
			});
		    });

		// attach mutation observer to body node
		var bodyNode = document.querySelector('body');
		if (bodyNode)
		    ssbContent.mutationObserver.observe(bodyNode,
							{ childList: true,
							  subtree: true
							});
		
	    } else {
		ssbContent.shutdown('Failed to connect to background page');
	    }
	} else {
	    ssbContent.shutdown('Extension failed to start up.');
	}
    });
}

// SHUTDOWN -- shut down the content script
ssbContent.shutdown = function(message) {
    
    if (ssbContent.isTopLevel)
	ssb.log('shutting down content script' +
		((typeof message == 'string') ? ': ' + message : '.'));
    
    // turn off observer
    if (ssbContent.mutationObserver) ssbContent.mutationObserver.disconnect();
    
    // disconnect from background script
    if (ssbContent.port) ssbContent.port.disconnect();
    
    // stop listening for messages from background script
    chrome.runtime.onMessage.removeListener(ssbContent.handleMessage);
    
    // remove old handlers
    $('a').off();
    
    // unload jQuery
    delete window.jQuery;
    delete window.$;
    
    // shut down shared.js
    ssb.shutdown();

    // kill object
    ssbContent = undefined;
}


// HANDLECLICK -- handle clicks and mousedowns on links
// ----------------------------------------------------

ssbContent.handleClick = function(evt) {
    
    // get fully-qualified URL to compare with our rules
    var originalHref = $(this).attr('href');
    if (originalHref) {
	var absoluteHref;
	var sameDomain;
	var isAbsolute = ssbContent.regexpAbsoluteHref.test(originalHref);

	// determine if link is absolute, & if it goes to the
	// same domain as the main page
	if (isAbsolute) {
	    absoluteHref = originalHref;
	    sameDomain = (absoluteHref.match(ssbContent.regexpDomain)[1] ==
			  window.top.document.domain);
	} else {
	    absoluteHref = document.createElement('a');
	    absoluteHref.href = originalHref;
	    absoluteHref = absoluteHref.href;
	    sameDomain = true;
	}
    }
    
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
	var target = $(this).attr('target');
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
	    target = (window.parent == window.top) ? 'internal' : false;
	    break;
	case '_blank':
	    target = 'external';
	    break;
	default:
	    target = $('frame[name="' + target + '"]',
		       window.top.document).length ?
		false :
		'external';
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
		
		if ((doRedirect == undefined) && !isAbsolute) {
		    // relative link (ergo to same domain)
		    ssb.debug('click', 'relative link -- ignore');
		    doRedirect = false;
		}
	    }
	}

	// if we still haven't decide if we're redirecting, use rules
	if (doRedirect == undefined) {
	    doRedirect = ssb.shouldRedirect(absoluteHref, target);
	}
    }
    
    ssb.debug('click', 'posting message -- doRedirect =',doRedirect,
	      ' url:',absoluteHref,'['+target+']');
    
    // tell the background page about this click
    message.redirect = doRedirect;
    message.url = absoluteHref;
    ssbContent.port.postMessage(message);
    
    // if not redirecting, propagate the event
    return (! doRedirect);
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


// REGULAR EXPRESSIONS -- for getting info on URLS
// ------------------------------------------------

// matches any absolute URL (with scheme & domain)
// { was: '^[a-zA-Z]([-a-zA-Z0-9$_@.&!*"\'():;, %]*):'); }
ssbContent.regexpAbsoluteHref = new RegExp(':');

// grabs the domain from a URL
ssbContent.regexpDomain = new RegExp('://([^/]+)(/|$)');


// BOOTSTRAP STARTUP
// -----------------

ssbContent.startup();
