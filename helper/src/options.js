/*! options.js
(c) 2015 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/*
 *
 * options.js: options page code for Epichrome Helper extension
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


// SSBOPTIONS -- object that holds all data & methods
// --------------------------------------------------

var ssbOptions = {};

// DOC -- options page document elements
ssbOptions.doc = {};

// CONTAINER -- container div for all other elements
ssbOptions.doc.container = document.getElementById('container');

// FORM -- form elements
ssbOptions.doc.form = {};
ssbOptions.doc.form.all = document.getElementById('options_form');
ssbOptions.doc.form.rules = document.getElementById('rules');
ssbOptions.doc.form.add_rule_list = document.getElementById('add_rule_list');
ssbOptions.doc.form.add_button = document.getElementById('add_button');
ssbOptions.doc.form.save_button = document.getElementById('save_button');
ssbOptions.doc.form.reset_button = document.getElementById('reset_button');
ssbOptions.doc.form.import_button = document.getElementById('import_button');
ssbOptions.doc.form.import_options = document.getElementById('import_options');
ssbOptions.doc.form.export_button = document.getElementById('export_button');
ssbOptions.doc.form.export_options = document.getElementById('export_options');
ssbOptions.doc.form.message = {};
ssbOptions.doc.form.message.box = document.getElementById('message_box');
ssbOptions.doc.form.message.spinner = document.getElementById('message_spinner');
ssbOptions.doc.form.message.text = document.getElementById('message_text');

// DIALOG -- dialog box elements
ssbOptions.doc.dialog = {};
ssbOptions.doc.dialog.overlay = document.getElementById('overlay');
ssbOptions.doc.dialog.box = document.getElementById('dialog_box');
ssbOptions.doc.dialog.title = document.getElementById('dialog_title');
ssbOptions.doc.dialog.content = document.getElementById('dialog_content');
ssbOptions.doc.dialog.button1 = document.getElementById('dialog_button1');
ssbOptions.doc.dialog.button2 = document.getElementById('dialog_button2');
ssbOptions.doc.dialog.button3 = document.getElementById('dialog_button3');
ssbOptions.doc.dialog.text_content = document.getElementById('text_content');
ssbOptions.doc.dialog.install_content = document.getElementById('install_content');
ssbOptions.doc.dialog.shutdown_content = document.getElementById('shutdown_content');


// STARTUP -- start up and populate the options window
// ---------------------------------------------------

ssbOptions.startup = function() {

    // start up shared code
    ssb.startup('options', function(success, message) {
	
	if (success) {
	    
	    // get prototype rule entry & remove from DOM
	    ssbOptions.rulePrototype = ssbOptions.doc.form.rules.children[0];
	    ssbOptions.rulePrototype.parentNode.removeChild(
		ssbOptions.rulePrototype);
	    
	    // remove all dialog content sections from DOM
	    ssbOptions.doc.dialog.text_content.parentNode.removeChild(
		ssbOptions.doc.dialog.text_content);
	    ssbOptions.doc.dialog.install_content.parentNode.removeChild(
		ssbOptions.doc.dialog.install_content);
	    ssbOptions.doc.dialog.shutdown_content.parentNode.removeChild(
		ssbOptions.doc.dialog.shutdown_content);
	    
	    // set up jquery for options form
	    ssbOptions.jqForm = $( "#options_form" );
	    
	    // make rules list sortable by drag-and-drop
	    ssbOptions.jqRules = $( "#rules" );
	    ssbOptions.jqRules.sortable({
		axis: 'y',
		handle: '.drag-handle',
		tolerance: 'pointer'
	    });
	    
	    // handle clicks on per-row add-after and delete buttons
	    ssbOptions.jqRules.on('click', '.delete-button',
				  ssbOptions.deleteRule);
	    ssbOptions.jqRules.on('click', '.add-after-button',
				  ssbOptions.addRule);
	    
	    // handle clicks on empty-rules add button
	    ssbOptions.doc.form.add_button.addEventListener(
		'click', ssbOptions.addRule);
	    
	    // keyboard handlers for rules fields
	    ssbOptions.jqRules.on('keydown', '.keydown',
				  ssbOptions.handleRuleKeydown);
	    
	    // initialize save button to be disabled
	    ssbOptions.setSaveButtonState(false);
	    
	    // save and reset buttons
	    ssbOptions.doc.form.save_button.addEventListener(
		'click', ssbOptions.doSave);
	    ssbOptions.doc.form.reset_button.addEventListener(
		'click', ssbOptions.doResetToDefault);

	    // import button
	    ssbOptions.doc.form.import_options.addEventListener(
		'change', ssbOptions.doImport);
	    ssbOptions.doc.form.import_button.addEventListener(
		'click',
		function() { ssbOptions.doc.form.import_options.click(); });
	    
	    // export button
	    ssbOptions.doc.form.export_button.addEventListener(
		'click', ssbOptions.doExport);
	    
	    // listen for changes to extension status
	    window.addEventListener('storage',
				    ssbOptions.checkExtensionStatus);
	    
	    // get extension status now
	    ssbOptions.checkExtensionStatus();
	    
	    // populate the page from saved options
	    ssbOptions.populate(ssb.options);
	    
	    // focus on the first rule, if any
	    ssbOptions.focusOnPattern(0);
	    
	} else {
	    // display error dialog
	    ssbOptions.dialog.run(message, 'Error');
	}
    });
}


// FORM/OPTIONS INTERFACE -- moving data between the form & saved options
// ----------------------------------------------------------------------

// POPULATE -- populate options form from a given set of options
ssbOptions.populate = function(items) {    
    ssbOptions.formItem(ssbOptions.doc.form.all, items);
}


// SETOPTIONS -- set extension options from a given set of new options
ssbOptions.setOptions = function(workingMessage, failPrefix, newOptions) {

    if (!newOptions)
	newOptions = ssbOptions.formItem(ssbOptions.doc.form.all);
    
    // turn on working spinner
    ssbOptions.setWorkingMessage(workingMessage);
    
    // save current state of the form to storage
    ssb.setOptions(
	newOptions,
	function(success, message) {
	    
	    // on completion, turn off working spinner
	    ssbOptions.setWorkingMessage();
	    
	    if (success) {
		// save succeeded, so disable the save button
		ssbOptions.setSaveButtonState(false);
	    } else {
		// failed
		ssbOptions.dialog.run(failPrefix + ' ' + message, 'Warning');
	    }
	});
}


// FORMITEM - get and set option fields to and from the form
ssbOptions.formItem = function(item, newValue, append) {
    
    var result = undefined,
	optionName = item.classList.item(0),
	
	// determine if we're getting or setting
	doSet = (newValue !== undefined),

	// counters
	i, j;

    // match the current item's option name
    switch(optionName) {
	
    case 'optionsVersion':
	// this is not settable in the form, so do nothing on set
	if (!doSet) result = ssb.manifest.version;
	break;

    case 'ignoreAllInternalSameDomain':
    case 'sendIncomingToMainTab':
    case 'stopPropagation':
	// handle checkbox elements
	if (doSet)
	    item.checked = newValue;
	else
	    result = item.checked;
	break;
	
    case 'redirectByDefault':
    case 'redirect':
	// handle true-false drop-down menu elements
	if (doSet)
	    item.value = ((newValue === true) ? 'true' : 'false');
	else
	    result = (item.value == 'true');
	break;

    case 'pattern':
    case 'target':
	// handle miscellaneous straight translations
	if (doSet)
	    item.value = newValue;
	else
	    result = item.value;
	break;

    case 'rule':
    case 'options_form':
	// handle a set of options recursively
	
	if (doSet) {
	    // recursively set all subkeys in this object
	    var curProp, key;
	    for (key in newValue) {
		if (newValue.hasOwnProperty(key)) {
		    curProp = item.getElementsByClassName(key);
		    if (curProp && curProp.length)
			ssbOptions.formItem(curProp[0], newValue[key]);
		}
	    }
	} else {
	    result = {};
	    
	    var curItem, curValue;

	    // get all suboptions of this item
	    var subItems = item.getElementsByClassName('sub.'+optionName);

	    // recursively build object from subkeys
	    var subItemsLength = subItems.length;
	    for (i = 0; i < subItemsLength; i++) {
		curItem = subItems[i];
		curValue = ssbOptions.formItem(subItems[i]);
		if (curValue !== undefined)
		    result[curItem.classList.item(0)] = curValue;
	    }
	}
	break;
	
    case 'rules':
	// array of rules
	
	if (doSet) {
	    
	    var oldNumRules;
	    if (!append) {
		// we're overwriting rules
		oldNumRules = item.children.length;
	    } else {
		// we're appending rules: abuse oldNumRules so we immediately
		// start adding new rules entries (and the deleting loop will
		// never run)
		oldNumRules = 0;
	    }
	    
	    // loop through all new rules
	    var newValueLength = newValue.length;
	    for (i = 0; i < newValueLength; i++) {
		if (i >= oldNumRules) {
		    // new rules list is longer than the old one, so add an entry
		    item.appendChild(ssbOptions.rulePrototype.cloneNode(true));
		}
		
		// fill in the current entry recursively
		ssbOptions.formItem(item.children[i], newValue[i]);
	    }
	    
	    // if new rules list is shorter than old, delete extra entries
	    var curRule;
	    for (j = oldNumRules - 1; j >= i; j--) {
		curRule = item.children[j];
		curRule.parentNode.removeChild(curRule);
	    }

	    // show or hide add button
	    ssbOptions.setAddButtonState();
	    
	} else {
	    
	    // recurse to build array of rules
	    result = [];
	    i = item.children.length; while (i--)
		result.unshift(ssbOptions.formItem(item.children[i]));
	}
	break;
	
    default:
	// unknown ID -- abort
	ssb.warn('formItem got unknown option', optionName);
	result = undefined;
    }
    
    return result;
}


// RULES -- add and delete rule rows, and handle moving between rules
// ------------------------------------------------------------------

// ADDRULE -- add a rule to the list
ssbOptions.addRule = function(evt) {
    
    var thisRule, nextRule;
    
    if (evt && evt.currentTarget.classList.contains('add-after-button')) {
	
	// we were called by a rule-row add-after button, so find which rule
	thisRule = evt.currentTarget;
	while (thisRule && ! thisRule.classList.contains('rule'))
	    thisRule = thisRule.parentNode;
	
	// somehow we got called somewhere other than in a rule
	if (!thisRule) {
	    ssb.warn('bad call to addRule');
	    return;
	}
	
	// find the rule after this one (or none if we're last)
	nextRule = thisRule.nextSibling;
	
    } else {
	
	// we were called by the button that appears when no rules exist,
	// so insert new rule at the end
	nextRule = null;
    }
    
    // add a new copy of the prototype rule
    var newRule = ssbOptions.rulePrototype.cloneNode(true);
    ssbOptions.doc.form.rules.insertBefore(newRule, nextRule);
    
    // give focus to the pattern & select all text
    ssbOptions.focusOnPattern(newRule);

    // update button states
    ssbOptions.setAddButtonState();
    ssbOptions.setSaveButtonState(true);
}


// DELETERULE -- delete a rule from the list
ssbOptions.deleteRule = function(evt) {
    
    // find the rule we were called from
    var thisRule = evt.target;
    while (thisRule && ! thisRule.classList.contains('rule'))
	thisRule = thisRule.parentNode;

    if (thisRule) {
	
	// remove this row from the rules list
	thisRule.parentNode.removeChild(thisRule);
	
	// update button states
	ssbOptions.setAddButtonState();
	ssbOptions.setSaveButtonState(true);
    }
}


// HANDLERULEKEYDOWN -- move between rule rows or create a new rule at the end
ssbOptions.handleRuleKeydown = function(evt) {
    
    // we're only interested in the Enter key
    if (evt.which == 13) {

	// find the rule we were called from
	var thisRule = evt.target;
	while (thisRule && ! thisRule.classList.contains('rule'))
	    thisRule = thisRule.parentNode;
	
	// get the index of this rule
	var myIndex = $('li').index(thisRule);
	
	if (evt.shiftKey) {
	    // move up a row
	    if (myIndex > 0) {
		ssbOptions.focusOnPattern(myIndex - 1);
	    }
	} else {
	    // move down a row
	    if (myIndex < (ssbOptions.doc.form.rules.children.length - 1)) {
		// there's another row after this one
		ssbOptions.focusOnPattern(myIndex + 1);
	    } else {
		// we were on the last row, so add a new rule
		ssbOptions.addRule();
	    }
	}
    }
}


// FOCUSPATTERN -- move between rule rows or create a new rule at the end
ssbOptions.focusOnPattern = function(rule) {
    
    // if we were passed an index, turn it into a rule element
    if ((typeof rule == 'number') && ssbOptions.doc.form.rules.children) {
	rule = ssbOptions.doc.form.rules.children[rule];
    }

    if (typeof rule == 'object') {
	// find the pattern field, focus on it and select the text
	var pattern = rule.getElementsByClassName('pattern')[0];
	pattern.focus();
	pattern.select();
    }
}


// BUTTONS -- handle actions for the main button row
// -------------------------------------------------

// DOSAVE -- save options to chrome.storage.local
ssbOptions.doSave = function() {
    ssbOptions.setOptions('Saving...', 'Failed to save options.');
}


// DORESETTODEFAULT -- reset all options to default values
ssbOptions.doResetToDefault = function() {

    // open a dialog to confirm
    ssbOptions.dialog.run(
	'This will overwrite all your options and rules. Are you sure you want to continue?',
	'Confirm',
	function(success) {

	    // only act if the user confirmed
	    if (success) {

		// populate the form with default options
		ssbOptions.populate(ssb.defaultOptions);
		
		// save default options to storage
		ssbOptions.setOptions('Resetting...', 'Reset failed.',
				      ssb.defaultOptions);
	    }
	});
}


// DOIMPORT -- import settings from a file
ssbOptions.doImport = function(evt) {
    
    // turn on working spinner
    ssbOptions.setWorkingMessage('Importing...');

    // set up a FileReader
    var file = evt.target.files[0]; // this is a FileList object
    var reader = new FileReader();

    // set up handlers and then load the file
    
    // handle successful file load
    reader.onload = function(loadevent) {

	// reset the import file field
	ssbOptions.doc.form.import_options.value = '';

	// parse the options
	try {
	    var newOptions = JSON.parse(loadevent.target.result);
	} catch(err) {
	    // parse failed
	    
	    // end working message
	    ssbOptions.setWorkingMessage();

	    // open an alert
	    ssbOptions.dialog.run(
		'Unable to parse "' + file.name + '": ' + err.message,
		'Error');
	    return;
	}
	
	// end working message
	ssbOptions.setWorkingMessage();
	
	// here's where we'd handle updating from previous options version
	ssb.updateOptions(newOptions);
	//delete newOptions.optionsVersion;

	// allow user to choose how to bring in the new options
	ssbOptions.dialog.run(
	    ('You can use the settings and rules in the file to ' +
	     'replace your current settings and rules, or only ' +
	     'add the rules to your current ones.'),
	    'Choose Action',
	    function(action) {
		
		// cancel == 0
		if (action) {		    
		    if (action == 1) {
			// replace all options
			ssbOptions.populate(newOptions);
		    } else {
			// add rules to end of rules list
			ssbOptions.formItem(ssbOptions.doc.form.rules,
					    newOptions.rules, true);
		    }
		    
		    // enable save button
		    ssbOptions.setSaveButtonState(true);
		}
	    },
	    [['Replace', 1], ['Add', 2], ['Cancel', 0]]);
    }
    
    // handle abort on file load
    reader.onabort = function() {
	ssbOptions.setWorkingMessage();	
	ssbOptions.dialog.run('Import of "' + file.name + '" was aborted.', 'Alert');
    }

    // handle error on file load
    reader.onerror = function() {
	ssbOptions.setWorkingMessage();	
	ssbOptions.dialog.run('Error importing "' + file.name + '".', 'Alert');
    }
    
    // handlers are set, so read in the file
    reader.readAsText(file);
}


// DOEXPORT -- export settings to a file
ssbOptions.doExport = function() {

    // make sure options have been saved before exporting
    if (ssbOptions.doc.form.save_button.disabled) {
	
	// set working message
	ssbOptions.setWorkingMessage('Exporting...');
	
	// get options from storage
	chrome.storage.local.get(
	    null,
	    function(items) {
		
		// now that we have the options, create a JSON file

		// create the default filename
		var date = new Date();
		var filename = (ssbOptions.status.ssbName ? ssbOptions.status.ssbName : 'Epichrome Helper');
		ssbOptions.doc.form.export_options.download =
		    filename + ' Settings ' +
		    date.getFullYear() + '-' +
		    ('0' + date.getMonth()).slice(-2) + '-' +
		    ('0' + date.getDate()).slice(-2) + '.json';

		// create a live file
		ssbOptions.doc.form.export_options.href =
		    URL.createObjectURL(new Blob([JSON.stringify(items)],
						 {type: 'application/json'}));

		// simulate a click on the export object
		ssbOptions.doc.form.export_options.click();
		
		// end working message
		ssbOptions.setWorkingMessage();
	    });
    } else {
	// options haven't been saved yet, so we can't export
	ssbOptions.dialog.run('Please save options before exporting.',
			      'Unable to Export');
    }
}


// FORM STATE -- set the state of various options form elements
// ------------------------------------------------------------

// CHECKEXTENSIONSTATUS -- activate or deactivate page based on extension status
ssbOptions.checkExtensionStatus = function() {

    // get current status
    var curStatus = localStorage.getItem('status');

    if (curStatus == null) {
	// no status has been set, so set a fake one
	curStatus = { active: false, startingUp: true, message: 'Please wait...' };
	
	//localStorage.setItem('status', JSON.stringify(curStatus));
    } else {
	// parse the extension status
	try {
	    curStatus = JSON.parse(curStatus);
	} catch(err) {
	    // failed to parse status, so set it
	    ssb.warn('error parsing status: ' + err.message);
	    curStatus = { active: false, message: "Badly formed status." };
	    localStorage.setItem('status', curStatus);
	}
	
	if (curStatus.active === true)
	    
	    // ping the extension to make sure we're still connected
	    chrome.runtime.sendMessage('ping', function(response) {
		if (! response) {
		    // not connected, so set status
		    curStatus = { active: false,
				  message: ('Disconnected from extension: ' +
					    chrome.runtime.lastError)
				};
		    localStorage.setItem('status', curStatus);
		}
	    });
    }
    
    // save this status
    ssbOptions.status = curStatus;
    
    // now check final extension status
    if (curStatus.active === true) {

	// we are live, so activate options page
	ssbOptions.doc.dialog.overlay.style.display = 'none';
	
	// check if we're installing
	if (curStatus.showInstallMessage) {
	    
	    // show install dialog
	    ssbOptions.dialog.run(
		null,
		'Welcome to your Epichrome app!',
		function () {
		    // remove install message from status
		    delete curStatus.showInstallMessage;
		    localStorage.setItem('status', JSON.stringify(curStatus));
		},
		'Get Started',
		ssbOptions.doc.dialog.install_content);
	}	
    } else {
	
	// extension isn't active, so show shutdown box
	var shutdownBox = ssbOptions.doc.dialog.shutdown_content;
	var shutdownTitle;
	
	if (curStatus.startingUp) {
	    // we're starting up, so don't show error or help messages
	    shutdownBox.querySelector('#shutdown_help').style.display = 'none';
	    shutdownBox.querySelector('#nohost_message').style.display = 'none';
	    shutdownTitle = 'The extension is starting up';
	} else {
	    // real shutdown, so show the shutdown help
	    shutdownBox.querySelector('#shutdown_help').style.display = 'none';
	    shutdownTitle = 'The extension has shut down';
	    
	    // if we never connected to the host, show extra information
	    if (curStatus.nohost) {
		shutdownBox.querySelector('#nohost_message').style.display = 'block';
		shutdownBox.querySelector('#nohost_help').style.display = 'inline';
		shutdownBox.querySelector('#host_help').style.display = 'none';
	    }
	}
	
	// show the dialog
	ssbOptions.dialog.run(
	    (curStatus.message ? curStatus.message : ''),
	    shutdownTitle,
	    undefined,
	    0,
	    shutdownBox);
    }
}


// SETSAVEBUTTONSTATE -- enable or disable the save button
ssbOptions.setSaveButtonState = function(enabled) {
    
    var disabled;
    
    // if called by event handler, we're always enabling
    if (typeof enabled == 'object') {
	var disabled = false;
    } else {
	disabled = ! enabled;
    }
    
    // only act if button state isn't already set
    if (! ssbOptions.doc.form.save_button.disabled != (! disabled)) {
	
	// enable or disable the button
	ssbOptions.doc.form.save_button.disabled = disabled;
	ssbOptions.doc.form.save_button.style.cursor =
	    (disabled ? 'auto' : 'pointer');
	
	if (disabled) {
	    
	    // we just disabled the save button -- add enabling handlers
	    ssbOptions.jqRules.on('sortupdate.ssbSave',
				  ssbOptions.setSaveButtonState);
	    ssbOptions.jqForm.on('change.ssbSave', '.change',
				 ssbOptions.setSaveButtonState);
	    ssbOptions.jqForm.on('click.ssbSave', '.click',
				 ssbOptions.setSaveButtonState);
	    ssbOptions.jqForm.on('input.ssbSave', '.input',
				 ssbOptions.setSaveButtonState);
	    
	    // remove any warning message (in practice, it's already been cleared by setWorkingMessage()
	    ssbOptions.setWarningMessage();
	    
	} else {
	    
	    // we just enabled the save button -- remove enabling handlers
	    ssbOptions.jqRules.unbind('.ssbSave');
	    ssbOptions.jqForm.unbind('.ssbSave');

	    // add an unsaved elements warning message
	    ssbOptions.setWarningMessage('Changes not yet saved');
	}
    }
}


// SETADDBUTTONSTATE -- show or hide the empty-list add-rule button
ssbOptions.setAddButtonState = function() {
    // if there are no rules, show the button; otherwise hide it
    ssbOptions.doc.form.add_rule_list.style.display =
	(ssbOptions.doc.form.rules.children.length > 0 ? 'none' : 'block');
}


// SETWORKINGMESSAGE -- show or hide a working message with spinner
ssbOptions.setWorkingMessage = function(message) {
    if (message) {
	// set the message and show it
	ssbOptions.doc.form.message.text.innerHTML = message;
	ssbOptions.doc.form.message.box.classList.remove('warning');
	ssbOptions.doc.form.message.box.style.display = 'inline-block';
    } else {
	// no message, so hide
	ssbOptions.doc.form.message.text.innerHTML = '';
	ssbOptions.doc.form.message.box.style.display = 'none';	
    }
}


// SETWARNINGMESSAGE -- show or hide a warning message
ssbOptions.setWarningMessage = function(message) {
    if (message) {
	// set the message and show it
	ssbOptions.doc.form.message.text.innerHTML = message;
	ssbOptions.doc.form.message.box.classList.add('warning');
	ssbOptions.doc.form.message.box.style.display = 'inline-block';
    } else {
	// no message, so hide
	ssbOptions.doc.form.message.text.innerHTML = '';
	ssbOptions.doc.form.message.box.style.display = 'none';	
    }
}


// DIALOG -- object to create and run various types of dialog box
// --------------------------------------------------------------

ssbOptions.dialog = {};


// DIALOG.HANDLEBUTTON -- object to hold the custom handler for dialog buttons
ssbOptions.dialog.handleButton = null;


// DIALOG.RUN -- show a dialog, alert or buttonless modal window
ssbOptions.dialog.run = function(message, title, callback,
				 buttons, contentElement) {
    
    // set up default contentElement if necessary
    if (! contentElement) contentElement = ssbOptions.doc.dialog.text_content;
    
    // set up default buttons if necessary
    if ((typeof callback != 'function') && (buttons == undefined)) {
	// default when called with no callback is an alert
	buttons = 1;
    } else if (buttons == undefined) {
	// default when called with a callback is a yes/no dialog
	buttons = 2;
    }

    // if a number was passed, set up default buttons
    if (typeof buttons == 'number') {
	switch (buttons) {
	case 0:
	    buttons = [ ];
	    break;
	case 1:
	    // alert
	    buttons = [ [ 'OK', true ] ];
	    break;
	case 2:
	    // dialog
	    buttons = [ [ 'Yes', true ], [ 'No', false ] ];
	    break;
	default:
	    // 3-option dialog
	    buttons = [ [ 'Yes', 1 ], [ 'No', 2 ], [ 'Cancel', 0 ] ];
	}
    } else if (typeof buttons == 'string') {
	// one button with a custom name
	buttons = [ [ buttons, true ] ];
    }
    
    // set up object keyed on button values
    var  buttonValues = {};
    var i = buttons.length; while (i--)
	buttonValues[buttons[i][0]] = buttons[i][1];
    
    // set up button handler for this dialog
    ssbOptions.dialog.handleButton = function(evt) {
	// hide the dialog box
	ssbOptions.doc.dialog.overlay.style.display = 'none';
	
	// remove button listeners
	ssbOptions.doc.dialog.button1.removeEventListener(
	    'click', ssbOptions.dialog.handleButton);
	ssbOptions.doc.dialog.button2.removeEventListener(
	    'click', ssbOptions.dialog.handleButton);
	ssbOptions.doc.dialog.button3.removeEventListener(
	    'click', ssbOptions.dialog.handleButton);
	
	// if there's a callback, call it
	if (typeof callback == 'function')
	    callback(buttonValues ?
		     buttonValues[evt.target.textContent] :
		     undefined);
    }
    
    // set dialog title
    ssbOptions.doc.dialog.title.innerHTML = title;
    
    // clear out the dialog box content
    var content = ssbOptions.doc.dialog.content;
    while (content.firstChild) {
	content.removeChild(content.firstChild);
    }

    // put content element into dialog box
    ssbOptions.doc.dialog.content.appendChild(contentElement);
    
    // if message is a string, set up a default object
    if (typeof message == 'string') message = { 'message': message }
    
    // go through the message object and fill in fields in the content element
    for (var key in message) {
	if (message.hasOwnProperty(key)) {
	    var curElement = contentElement.getElementsByClassName(key);
	    if (curElement && curElement.length) {
		curElement[0].innerHTML = message[key];
	    }
	}
    }
    
    // set up buttons
    var curButton;
    i = 3; while (i--) {
	// get ID of current button
	curButton = 'button' + (i+1);
	
	if (buttons[i]) {
	    // fill in this button and show it
	    ssbOptions.doc.dialog[curButton].textContent = buttons[i][0];
	    ssbOptions.doc.dialog[curButton].style.display = 'inline-block';

	    // add click listener
	    ssbOptions.doc.dialog[curButton].addEventListener(
		'click', ssbOptions.dialog.handleButton);
	} else {
	    // hide this button
	    ssbOptions.doc.dialog[curButton].style.display = 'none';
	}
    }
    
    // set the overlay dimensions
    var formrect = ssbOptions.doc.form.all.getBoundingClientRect();
    ssbOptions.doc.dialog.overlay.style.width = formrect.width+'px';
    ssbOptions.doc.dialog.overlay.style.height = formrect.height+'px';

    // display the dialog
    ssbOptions.doc.dialog.overlay.style.display = 'block';

    // center the dialog (vertical center looked shitty, so doing vertical position in CSS)
    // var boxrect = ssbOptions.doc.dialog.box.getBoundingClientRect();
    // console.log('top was:',ssbOptions.doc.dialog.box.style.top);
    // var top = ((formrect.height-boxrect.height)/2);
    // if (top < 0) top = 0;
    // var left = ((formrect.width-boxrect.width)/2);
    // if (left < 0) left = 0;
    // ssbOptions.doc.dialog.box.style.top = top+'px';
    // ssbOptions.doc.dialog.box.style.left = left+'px';
    // console.log('top is:',ssbOptions.doc.dialog.box.style.top);
}


// BOOTSTRAP STARTUP -- set startup to run when content has loaded
// ---------------------------------------------------------------

document.addEventListener('DOMContentLoaded', ssbOptions.startup);
