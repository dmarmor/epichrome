/*! content.js
(c) 2017 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/*
*
* content.js: content script for Epichrome Runtime extension
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

// if an old version of ssbContent already exists, shut it down
if ((typeof(ssbContent) != 'undefined') && ssbContent.shutdown) {
    ssbContent.shutdown();
}

// reinitialize ssbContent
ssbContent = {};


// STARTUP/SHUTDOWN -- handle startup, shutdown & installation
// -----------------------------------------------------------

// STARTUP -- start up the content script
ssbContent.startup = function() {
    
    // run shared code
    ssb.startup('content', function(success, message) {
        
        // shared code loaded successfully
        if (success) {
            
            // open keepalive connection to background page
            ssbContent.keepalive = chrome.runtime.connect();
            if (ssbContent.keepalive) {
                
                // if we lose the keepalive, shut down this content script
                ssbContent.keepalive.onDisconnect.addListener(ssbContent.shutdown);
                
                // am I a top-level window, or an iframe?
                ssbContent.isTopLevel = (window == window.top);
                
                if (ssbContent.isTopLevel) {
                    // log startup
                    ssb.log('starting up content script');
                    
                    // $$$ testing
                    chrome.runtime.onMessage.addListener(function(msg, sender, response) {
                        console.log('GOT MESSAGE', msg, 'from', sender);
                        response('ping');
                    });
                }
                
                // // Set up listener for messages from the background script
                // ssbContent.keepalive.onMessage.addListener(ssbContent.keepaliveMessageHandler);
                
                // $$$ TESTING -- capture phase handler
                window.addEventListener('mousedown', ssbContent.interactionHandler, true);
                window.addEventListener('mouseup', ssbContent.interactionHandler, true);
                window.addEventListener('click', ssbContent.interactionHandler, true);
                window.addEventListener('keydown', ssbContent.interactionHandler, true);
                //window.addEventListener('keyup', ssbContent.interactionHandler, true);
                window.addEventListener('contextmenu', ssbContent.contextMenuStartHandler, true);
                //window.addEventListener('blur', ssbContent.interactionHandler, true);
                //window.addEventListener('mousemove', ssbContent.interactionHandler, true);
                
                // $$$ delete this
                // assume we're not the main tab
                //ssbContent.isMainTab = false;
                
                // // $$$ replace this
                // // add click and mousedown handlers for all links
                // ssbContent.updateLinkHandlers(document, true);
                
                // // $$$ delete this
                // // watch DOM mutations to attach handler on newly-created links
                // ssbContent.mutationObserver =
                //     new MutationObserver(ssbContent.handleMutation);
                
                // // $$$$ and this
                // // attach mutation observer to body node
                // if (document.body)
                //     ssbContent.mutationObserver.observe(document.body,
                // 					{ childList: true,
                // 					  subtree: true
                // 					});
            } else {
                // failed to open keepalive channel
                ssbContent.shutdown('Failed to connect to extension');
            }
        } else {
            // shared code failed to start up
            ssbContent.shutdown('extension failed to start up ('+message+')');
        }
    });
}


// $$$ TESTHANDLERS
ssbContent.contextMenuStartHandler = function(evt) {
    window.removeEventListener('mousemove', ssbContent.contextMenuEndHandler, true);
    window.addEventListener('mousemove', ssbContent.contextMenuEndHandler, true);
    
    // we do this just to store any class list for later retrieval by contextMenuEndHandler
    ssbContent.getInteractionInfo(evt.target);
}
ssbContent.contextMenuEndHandler = function(evt) {
    window.removeEventListener('mousemove', ssbContent.contextMenuEndHandler, true);
    
    // $$$ call getInteractionClasses with no arg to use last stored (which should be
    // from contextMenuStartHandler
    // $$$ have to use true to signal to use current time, not event time, as it's unreliable
    ssbContent.sendInteraction(evt, ssbContent.getInteractionInfo(), 'contextmenu', true);
}

ssbContent.lastInteraction = {
    target: undefined,
    info: undefined
};
ssbContent.getInteractionInfo = function(obj) {
    
    // determine if we should return cached interaction info
    if ((typeof obj != 'object') || (obj == ssbContent.lastInteraction.target)) {
        
        // we've already gotten info on this target or our argument isn't an object
        ssb.debug('getInteractionInfo', 'returning cached interaction', ssbContent.lastInteraction);
        
        return ssbContent.lastInteraction.info;
        
    } else {
        
        // start by looking at the target object
        var curParent = obj;
        
        // initialize info object
        var info = {
            link: undefined,
            classList: [],
        };
        
        // move up the chain looking for an <a> tag (and optionally collecting classes)
        while (curParent) {
            // see if we're nested in a link (and there isn't already a more inner link -- illegal anyway)
            if (
                !info.link &&
                curParent.tagName &&
                (typeof curParent.tagName == 'string') &&
                (curParent.tagName.toLowerCase() == 'a')
            ) {
                
                info.link = curParent;
                
                // if we're not collecting classes, we're done
                if (!ssb.options.advancedRules) break;
            }
            
            // collect classes for this object
            if (ssb.options.advancedRules) {
                
                // get current parent's class list
                info.classList = info.classList.concat(Array.from(curParent.classList));
                // curClass = curParent.className;
                // if (curClass) classList.push(curClass);
            }
            
            // move up the parent chain
            curParent = curParent.parentElement;
        }
        
        // log interaction
        if (ssb.options.advancedRules) {
            ssb.debug('getInteractionInfo', 'collected new class list', obj, info);
        } else {
            // $$$ firewall this
            ssb.debug('getInteractionInfo', 'classes not collected -- not using advanced rules', obj, info);
        }
        
        // cache for future reference
        ssbContent.lastInteraction = {
            target: obj,
            info: info
        };
        
        // return info
        return info;
    }
}

ssbContent.interactionHandler = function(evt) {
    
    if (evt.isTrusted) {
        
        ssb.debug('interaction', evt);
        
        // kill any lingering mousemove handler
        window.removeEventListener('mousemove', ssbContent.contextMenuEndHandler, true);
        
        var send = false;
        var info = undefined;
        
        
        // KEYDOWN EVENTS
        
        // $$$$ TAKE AWAY CMD-SHIFT-L
        if (evt.type == 'keydown') {
            
            if (evt.code == 'Enter') {
                
                if (evt.target) {
                    info = ssbContent.getInteractionInfo(evt.target);
                    
                    if (info.link) {
                        return ssbContent.linkHandler(evt, info);
                    } else {
                        send = true;
                    }
                } else {
                    send = true;
                }
            } else if (evt.code == 'Space') {
                send = true;
            } else if (
                (evt.code == 'KeyL') &&
                evt.metaKey && evt.shiftKey &&
                (! evt.altKey) && (! evt.ctrlKey)
            ) {
                // Command-Shift-L
                ssb.debug('hotKey', 'sending window switch message');
                ssbContent.keepalive.postMessage({type: 'windowSwitch'});
            }
        } else if (evt.target && (evt.type == 'click')) {
            info = ssbContent.getInteractionInfo(evt.target);
            
            if (info.link) {
                return ssbContent.linkHandler(evt, info);
            }
        } else // mousedown || mouseup || contextmenu
        send = true;
        
        if (send) {
            if (!info && evt.target)
            info = ssbContent.getInteractionInfo(evt.target);
            
            // send interaction
            ssbContent.sendInteraction(evt, info);
        }
    } else {
        ssb.debug('interaction', 'IGNORED -- untrusted', evt);
    }
    
    return true;
}
// ssbContent.oldLoc = undefined;
// ssbContent.beforeNavHandler = function(details) {
//     // ssbContent.oldLoc = true;
//     // window.setTimeout(function () {
//     // 	// forces DOM to recognize a location change without actually changing anything
//     // 	var oldHash = window.document.location.hash;
//     //     window.document.location.hash = 'preventNavigation' + ~~ (9999 * Math.random());
//     //     window.document.location.hash = oldHash;
//     // }, 10);
//     ssb.debug("beforeNav", JSON.parse(details));
//     return window.location.href;
// }
// $$$ DOCUMENT
ssbContent.sendInteraction = function(evt, info, type, isLate) {
    var curTime = Date.now(), message = {};
    
    message.type = 'interaction';
    if (evt) {
        message.info = {
            time: (
                isLate ?
                curTime :
                (curTime - (performance.now() - evt.timeStamp))
            ),
            type: type ? type : evt.type,
            isLate: isLate ? true : false,
            curUrl: window.location.href
        };
        
        if (typeof info == 'object') {
            message.info.isLink = info.link ? true : false;
            message.info.classList = info.classList;
        }
    } else {
        message.info = false;
    }
    
    ssb.debug(
        message.info ? message.info.type.toUpperCase() : 'CLEAR', 'at:',
        Date.now(), 'send message:', message.info, evt
    );
    
    ssbContent.keepalive.postMessage(message);
}


// SHUTDOWN -- shut down the content script
ssbContent.shutdown = function(message) {
    
    if (ssbContent.isTopLevel) {
        ssb.log(
            'shutting down' +
            ((typeof message == 'string') ? (' -- ' + message) : '')
        );
    }
    
    // turn off observer
    if (ssbContent.mutationObserver) ssbContent.mutationObserver.disconnect();
    
    // disconnect keepalive from background script (also kills onMessage handler)
    if (ssbContent.keepalive) ssbContent.keepalive.disconnect();
    
    // stop listening for global hotkeys
    document.removeEventListener('keydown', ssbContent.handleHotKey);
    
    
    // $$$ TESTHANDLER
    window.removeEventListener('mousedown', ssbContent.interactionHandler, true);
    window.removeEventListener('mouseup', ssbContent.interactionHandler, true);
    window.removeEventListener('click', ssbContent.interactionHandler, true);
    window.removeEventListener('keydown', ssbContent.interactionHandler, true);
    //window.removeEventListener('keyup', ssbContent.interactionHandler, true);
    window.removeEventListener('contextmenu', ssbContent.contextMenuStartHandler, true);
    //window.removeEventListener('blur', ssbContent.interactionHandler, true);
    window.removeEventListener('mousemove', ssbContent.contextMenuEndHandler, true);
    
    // // remove old handlers
    // ssbContent.updateLinkHandlers(document, false);
    
    // shut down shared.js
    ssb.shutdown();
    
    // kill object
    delete window.ssbContent;
}


// ADD/REMOVE LINK HANDLERS -- keep link handlers up to date
//----------------------------------------------------------

// UPDATELINKHANDLERS -- add/remove click/mousedown handlers
// ssbContent.updateLinkHandlers = function(node, add) {

//     // get a list of links
//     var links;
//     if (ssbContent.isLink(node))
// 	// this node is itself a link (which can't contain nested links)
// 	links = [node];
//     else
// 	// get an array of all links under the node
// 	links = node.querySelectorAll('a');

//     // go through all links
//     var i = links.length; while (i--) {

// 	// $$$ PUT THESE BACK OR REPLACE THEM
// 	if (add) {
// 	    // add new handlers
// 	    links[i].addEventListener('click', ssbContent.tempClickHandler);
// 	    // links[i].addEventListener('mousedown', ssbContent.clickHandler);
// 	} else {
// 	    // remove existing handlers
// 	    links[i].removeEventListener('click', ssbContent.tempClickHandler);
// 	    // links[i].removeEventListener('mousedown', ssbContent.clickHandler);
// 	}
//     }
// }


// HANDLEMUTATION -- handle an observed set of mutations
// ssbContent.handleMutation = function(mutations) {

//     // go through all mutations
//     var i = mutations.length; while (i--) {

// 	var curMut = mutations[i];
// 	if (curMut.addedNodes) {

// 	    // go through each added node
// 	    var j = curMut.addedNodes.length; while (j--) {

// 		// update link handlers for each node that's an element
// 		var curNode = curMut.addedNodes[j];
// 		if (curNode instanceof HTMLElement) {
// 		    ssbContent.updateLinkHandlers(curNode, true);
// 		}
// 	    }
// 	}
//     }
// }


// adapted from:
// http://stackoverflow.com/questions/12593035/cloning-javascript-event-object/12593036
// ssbContent.cloneEvent = function(evt, override) {

//     if (!override) {
// 	overrideObj = {};
//     }

//     function EventCloneFactory(props) {
//        for(var x in props) {
//            this[x] = props[x];
//        }
//     }

//     EventCloneFactory.prototype = evt;

//     return new EventCloneFactory(override);
// }


// CLICKHANDLER -- handle clicks on links
// ----------------------------------------------------
ssbContent.linkHandler = function(evt, info) {
    
    var topWindow = window.top;
    
    // $$$ COULD DELETE ON EVENT REWRITE?
    // make sure we haven't already handled this event
    // this can happen when a clever page delegates a click event to a link
    // nested inside it
    if (evt.timeStamp == ssbContent.lastClick) {
        ssb.debug('linkHandler', 'event timestamp',evt.timeStamp,'has already been handled');
        return true;
    }
    
    // $$$ KILL LAST INTERACTION
    ssbContent.sendInteraction();
    
    // log this click
    ssbContent.lastClick = evt.timeStamp;
    
    ssb.debug('linkHandler', 'got', evt.type, 'on', info.link, evt);
    
    // get fully-qualified URL to compare with our rules
    var href = info.link.href;
    
    // no href, so ignore this link
    if (!href) {
        ssb.debug('linkHandler', 'link has no href, so quitting');
        return true;
    }
    
    // determine if link goes to the same domain as the main page
    var sameDomain = true;
    try {
        topWindow.document.domain;
        ssb.debug('linkHandler', 'link goes to same domain as main page (able to access topWindow.document.domain)');
    } catch (err) {
        if (err.name == 'SecurityError') { //&& err.message.includes('cross-origin frame')
            sameDomain = false;
            ssb.debug('linkHandler', 'link does not go to same domain as main page');
        }
    }
    
    // // determine which type of mouse event got us here
    // if (evt.type == 'mousedown') {
    
    // 	// don't redirect yet
    // 	doRedirect = false;
    // 	message.isMousedown = true;
    
    // 	// just send a long-lasting message to log the click
    // 	ssb.debug('click', 'sending long-lasting mousedown message', evt);
    
    // } else { // it's a click, so we'll handle it fully
    
    // $$$ ONLY IF CHECKED IN OPTIONS
    if (evt.altKey) {
        if (evt.shiftKey && evt.metaKey) {
            // Opt-Cmd-Shift: open in same tab
            ssbContent.keepalive.postMessage({type: 'urlThisAppSameTab', info: href});
            ssb.debug('linkHandler', 'option-cmd-shift: force open in same tab');
        } else if (evt.shiftKey) {
            // Opt-Shift: open in new app window
            ssbContent.keepalive.postMessage({type: 'urlThisAppNewWindow', info: href});
            ssb.debug('linkHandler', 'option-shift: force open in new window');
        } else if (evt.metaKey) {
            // Opt-Cmd: open in new tab
            ssbContent.keepalive.postMessage({type: 'urlThisAppNewTab', info: href});
            ssb.debug('linkHandler', 'option-cmd: force open in new tab');
        } else {
            // Opt: open default $$$ NOT WORKING YET
            ssb.debug('linkHandler', 'option: re-dispatch for Chrome', evt);
            
            // $$$ THIS SHOULD NOT LIVE HERE ULTIMATELY
            ssbContent.keepalive.postMessage({type: 'convertTabToApp', info: Date.now()});
            
            // copy info from the original click event (but no modifier keys)
            var evtInfo = {};
            evtInfo.screenX = evt.screenX;
            evtInfo.screenY = evt.screenY;
            evtInfo.clientX = evt.clientX;
            evtInfo.clientY = evt.clientY;
            //'ctrlKey', 'shiftKey', 'altKey', 'metaKey'
            evtInfo.button = evt.button;
            evtInfo.buttons = evt.buttons;
            evtInfo.relatedTarget = evt.relatedTarget;
            evtInfo.region = evt.region;
            evtInfo.detail = evt.detail;
            evtInfo.view = evt.view;
            evtInfo.sourceCapabilities = evt.sourceCapabilities;
            evtInfo.bubbles = evt.bubbles;
            evtInfo.cancelable = evt.cancelable;
            evtInfo.scoped = evt.scoped;
            evtInfo.composed = evt.composed;
            
            // copy the click event
            var evtCopy = new MouseEvent('click', evtInfo);
            
            // this will be an untrusted event, so we'll ignore it & Chrome will handle it
            setTimeout(function() {evt.target.dispatchEvent(evtCopy);}, 0);
        }
        
        evt.preventDefault();
        evt.stopPropagation();
        
        return false;
        
    } else if (evt.shiftKey && evt.metaKey) {
        // open in default browser
        
        // request redirect from background page
        ssbContent.keepalive.postMessage({type: 'urlDefaultBrowser', info: href});
        ssb.debug('linkHandler', 'shift-cmd: force redirect', evt);
        
        evt.preventDefault();
        evt.stopPropagation();
        
        return false;
    }
    
    // get target for this link
    var target;
    
    // $$$ capture modifier keys
    if (evt.metaKey || evt.shiftKey) {
        target = 'external';
    } else {
        target = info.link.target;
        if (target) {
            target = target.toLowerCase();
        } else {
            target = '_self';
        }
        
        // normalize the target
        switch (target) {
            case '_top': {
                target = 'internal';
            }
            break;
            case '_self': {
                target = (ssbContent.isTopLevel ? 'internal' : false);
            }
            break;
            case '_parent': {
                target = (window.parent == topWindow) ? 'internal' : false;
            }
            break;
            case '_blank': {
                target = 'external';
            }
            break;
            default: {
                // if the target names a frame on this page, it's non-top-level
                var frameSelector='[name="' + target + '"]';
                target = ((sameDomain && topWindow.document.querySelector(
                    'iframe'+frameSelector+',frame'+frameSelector)) ?
                    false :
                    'external'
                );
            }
        }
    }
    
    if (!target) {
        
        // non-top-level target
        ssb.debug('linkHandler', 'sub-top-level target -- ignore');
        return true;
        
    } else if (target == 'internal') {
        
        // internal target, check global rules
        if (ssb.options.ignoreAllInternalSameDomain) {
            
            if (sameDomain) {
                // link to same domain as main page
                ssb.debug('linkHandler', 'internal link to same domain -- ignore');
                return true;
            }
        }
    }
    
    // apply rules to decide whether to redirect
    if (ssb.shouldRedirect(href, target, info.classList)) {
        
        ssb.debug(
            'linkHandler', 'requesting redirect --',
            ' url:',href,'['+target+']'
        );
        
        // request redirect from background page
        ssbContent.keepalive.postMessage({type: 'urlDefaultBrowser', info: href});
        
        // prevent the default click action
        evt.preventDefault();
        
        // if options say so, also stop propagation on the click event
        if (ssb.options.stopPropagation) {
            ssb.debug('linkHandler', 'stopping event propagation');
            evt.stopPropagation();
        }
    }
}


// HANDLERS -- miscellaneous other handlers
// ----------------------------------------

// // KEEPALIVEMESSAGEHANDLER -- handle incoming messages from the background page
// ssbContent.keepaliveMessageHandler = function(message, sender, respond) {

//     // reject any message that's not from this extension
//     if (! (sender && (sender.id == chrome.runtime.id))) {
// 	ssb.warn('ignoring message from', sender);
// 	return;
//     }

//     // // ensure the message is from the background page
//     // if (sender.tab) {
//     // 	ssb.warn('received message from another tab:', sender);
//     // 	return;
//     // }

//     // // make sure it's a well-formed message
//     // if (! message.type) {
//     // 	ssb.warn('received badly formed message:', message,'from',sender);
//     // 	return;
//     // }

//     // switch (message.type) {

//     // case 'ping':
//     // 	// respond to a ping
//     // 	ssb.debug('ping', 'got ping from extension');
//     // 	respond('ping');
//     // 	break;

//     // case 'shutdown':
// 	// the extension is shutting down
// 	ssbContent.shutdown();
// 	// break;

// 	// $$$ delete this
//     //case 'mainTab':
//     // 	ssb.debug('mainTab', 'received main tab state: '+message.state);

//     // 	// set up hotkey listener
//     // 	if (! ssbContent.isMainTab) {
//     // 	    // add global keydown handler for hotkeys
//     // 	    document.addEventListener('keydown', ssbContent.handleHotKey);
//     // 	}

//     // 	// update our state
//     // 	ssbContent.isMainTab = message.state;

//     // 	break;

//     // default:
//     // 	ssb.warn('received unknown message type', message.type);
//     // }
// }


// HANDLEHOTKEY -- handle global hot-keys
// ssbContent.handleHotKey = function(evt) {

//     // We're looking for Command-Shift-L
//     if ((evt.keyCode == 76) &&
// 	evt.metaKey && evt.shiftKey &&
// 	(! evt.altKey) && (! evt.ctrlKey)) {

// 	chrome.runtime.sendMessage({type: 'windowSwitch'});
//     }
// }


// UTILITY -- for getting info on links
// ------------------------------------

// ISLINK -- determine if a node is a link
// ssbContent.isLink = function(node) {
//     return (node && node.tagName &&
// 	    (typeof node.tagName == 'string') &&
// 	    (node.tagName.toLowerCase() == 'a'));
// }

// REGEXPABSOLUTEHREF -- regex to match any absolute URL (with scheme & domain)
// { was: '^[a-zA-Z]([-a-zA-Z0-9$_@.&!*"\'():;, %]*):'); }
ssbContent.regexpAbsoluteHref = new RegExp(':');

// // REGEXPDOMAIN -- regex that grabs the domain from a URL
// ssbContent.regexpDomain = new RegExp('://([^/]+)(/|$)');


// BOOTSTRAP STARTUP
// -----------------

ssbContent.bootstrapCount = 0;
ssbContent.bootstrap = function() {
    if (typeof ssb === 'object') {
        ssb.debug('bootstrap', 'starting up -- shared.js loaded!', (window.top == window) ? '(top frame)' : '');
        ssbContent.startup();
    } else {
        if (ssbContent.bootstrapCount < 3) { // 1.5 seconds after load attempt
            ssbContent.bootstrapCount++;
            setTimeout(ssbContent.bootstrap, 500);
            console.debug('[bootstrap]:', 'delaying startup -- shared.js not yet loaded');
        } else {
            console.debug(
                '[bootstrap]:',
                'giving up -- shared.js not loaded after 1.5 seconds',
                (window.top == window) ? '(top frame)' : ''
            );
        }
    }
}

ssbContent.bootstrap();
