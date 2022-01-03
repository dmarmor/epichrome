/*! options.js
(c) 2022 David Marmor
https://github.com/dmarmor/epichrome
http://www.gnu.org/licenses/ (GPL V3,6/29/2007) */
/*
*
* options.js: options page code for Epichrome Runtime extension
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

// ISSAVED -- current saved/unsaved state
ssbOptions.isSaved = undefined;

// DOC -- options page document elements
ssbOptions.doc = {};

// BODY -- main body of page
ssbOptions.doc.body = document.getElementById('body');

// WORKING -- working status bar
ssbOptions.doc.working = document.getElementById('working');

// BUTTON BAR -- floating bar of buttons/dialog elements
ssbOptions.doc.button_bar = document.getElementById('button_bar');

ssbOptions.doc.import_button = document.getElementById('import_button');
ssbOptions.doc.import_options = document.getElementById('import_options');
ssbOptions.doc.export_button = document.getElementById('export_button');
ssbOptions.doc.export_options = document.getElementById('export_options');
ssbOptions.doc.reset_button = document.getElementById('reset_button');

ssbOptions.doc.save_button = document.getElementById('save_button');
ssbOptions.doc.revert_button = document.getElementById('revert_button');

// DIALOG -- dialog bar elements
ssbOptions.doc.dialog = {};
ssbOptions.doc.dialog.bar = document.getElementById('dialog_bar');
ssbOptions.doc.dialog.title = document.getElementById('dialog_title');
ssbOptions.doc.dialog.text_content = document.getElementById('text_content');
ssbOptions.doc.dialog.button1 = document.getElementById('dialog_button1');
ssbOptions.doc.dialog.button2 = document.getElementById('dialog_button2');
ssbOptions.doc.dialog.button3 = document.getElementById('dialog_button3');

// OVERLAY -- overlay for deactivating the form
ssbOptions.doc.overlay = document.getElementById('overlay');

// FORM -- form elements
ssbOptions.doc.form = {};
ssbOptions.doc.form.all = document.getElementById('options_form');
ssbOptions.doc.form.rules = document.getElementById('rules');
ssbOptions.doc.form.add_rule_list = document.getElementById('add_rule_list');
ssbOptions.doc.form.add_button = document.getElementById('add_button');
ssbOptions.doc.form.main_tab_options = document.getElementById('main_tab_options');


// STARTUP -- start up and populate the options window
// ---------------------------------------------------

ssbOptions.startup = function() {
    
    // get prototype rule entry & remove from DOM
    ssbOptions.rulePrototype = ssbOptions.doc.form.rules.children[0];
    ssbOptions.rulePrototype.parentNode.removeChild(ssbOptions.rulePrototype);
    
    // start up shared code
    ssb.startup('options', function(success, message) {
        
        if (success) {
            
            // open keepalive connection to background page
            ssbOptions.keepalive = chrome.runtime.connect({name: 'options'});
            
            if (ssbOptions.keepalive) {
                
                // if we lose the keepalive, shut down
                ssbOptions.keepalive.onDisconnect.addListener( function() {
                    ssbOptions.shutdown('Not connected to extension', 'Error');
                });
                
                // set up jquery for options form
                ssbOptions.jqForm = $( "#options_form" );
                
                // display or hide advanced rules
                ssbOptions.jqForm.on(
                    'change.advanced', '.advancedRules',
                    ssbOptions.setAdvancedStatus
                );
                
                // make rules list sortable by drag-and-drop
                ssbOptions.jqRules = $( "#rules" );
                ssbOptions.jqRules.sortable({
                    axis: 'y',
                    handle: '.drag-handle',
                    tolerance: 'pointer'
                });
                
                // handle clicks on per-row add-after and delete buttons
                ssbOptions.jqRules.on('click', '.delete-button', ssbOptions.deleteRule);
                ssbOptions.jqRules.on('click', '.add-after-button', ssbOptions.addRule);
                
                // handle clicks on empty-rules add button
                ssbOptions.doc.form.add_button.addEventListener('click', ssbOptions.addRule);
                
                // keyboard handlers for rules fields
                ssbOptions.jqRules.on('keydown', '.keydown', ssbOptions.handleRuleKeydown);
                
                // save and revert buttons
                ssbOptions.doc.save_button.addEventListener('click', ssbOptions.doSave);
                ssbOptions.doc.revert_button.addEventListener('click', ssbOptions.doRevert);
                
                // import button
                ssbOptions.doc.import_options.addEventListener('change', ssbOptions.doImport);
                ssbOptions.doc.import_button.addEventListener('click', function() {
                    ssbOptions.doc.import_options.click();
                });
                
                // export button
                ssbOptions.doc.export_button.addEventListener('click', ssbOptions.doExport);
                
                // reset to default button
                ssbOptions.doc.reset_button.addEventListener('click', ssbOptions.doResetToDefault);
                
                // listen for changes to extension status
                window.addEventListener('storage', ssbOptions.checkExtensionStatus);
                
                // get extension status now
                ssbOptions.checkExtensionStatus();
                
                // populate the page from saved options
                // (this also initializes form state to "saved")
                ssbOptions.doRevert();
                
                // focus on the first rule, if any
                ssbOptions.focusOnPattern(0);
                
                // FOR TESTING SHUTDOWN DIALOG:
                //ssbOptions.shutdown('Test extension shutdown', 'Test');
                //ssbOptions.shutdown({message: 'Test no host found', nohost: true}, 'Test');
                
            } else {
                // display error dialog
                ssbOptions.shutdown('Unable to connect to extension', 'Error');
            }
        } else {
            // display error dialog
            ssbOptions.shutdown(message, 'Error');
        }
    });
}


// SHUTDOWN -- shut the options page down
ssbOptions.shutdown = function(message, title) {
    
    // remove extension status listener
    window.removeEventListener('storage', ssbOptions.checkExtensionStatus);
    
    // show shutdown dialog
    
    // normalize message object
    if (! message) {
        
        // no message
        message = { 'message': '' };
    } else if (typeof message == 'string') {
        
        // if message is a string, set up a default object
        message = { 'message': message }
    }
    
    // show the dialog (if we never connected to the host, show extra information)
    ssbOptions.dialog.run(
        message.message, title, undefined, 0,
        'shutdown' + (message.nohost ? ' nohost' : '')
    );
}


// FORM/OPTIONS INTERFACE -- moving data between the form & saved options
// ----------------------------------------------------------------------

// POPULATE -- populate options form from a given set of options
ssbOptions.populate = function(items) {
    ssbOptions.formItem(ssbOptions.doc.form.all, items);
}


// SETOPTIONS -- set extension options from a given set of new options
ssbOptions.setOptions = function(failPrefix, newOptions) {
    
    // turn on working bar
    ssbOptions.setWorkingStatus(true);
    
    if (!newOptions) {
        newOptions = ssbOptions.formItem(ssbOptions.doc.form.all);
    }
    
    // FOR TESTING WORKING BAR (PART 1):
    //setTimeout(function(){
    
    // save current state of the form to storage
    ssb.setOptions(newOptions, function(success, message) {
        
        // turn off working bar
        ssbOptions.setWorkingStatus(false);
        
        if (success) {
            // save succeeded, all changes are now saved
            ssbOptions.setSavedStatus(true);
        } else {
            // failed
            ssbOptions.dialog.run(failPrefix + ' ' + message, 'Warning');
        }
    });
    
    // FOR TESTING WORKING BAR (PART 2):
    //}, 3000);
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
        
        case 'optionsVersion': {
            
            // this is not settable in the form, so do nothing on set
            if (!doSet) {
                result = ssb.manifest.version;
            }
        }
        break;
        
        case 'advancedRules': {
            // special case -- display or hide advanced rules
            if (doSet) {
                ssbOptions.setAdvancedStatus(newValue);
            }
        }
        // fall through to generic checkbox code
        
        case 'ignoreAllInternalSameDomain':
        case 'sendIncomingToMainTab':
        case 'stopPropagation': {
            // handle checkbox elements
            if (doSet) {
                item.checked = newValue;
            } else {
                result = item.checked;
            }
        }
        break;
        
        case 'redirectByDefault':
        case 'redirect': {
            // handle true-false drop-down menu elements
            if (doSet) {
                item.value = ((newValue === true) ? 'true' : 'false');
            } else {
                result = (item.value == 'true');
            }
        }
        break;
        
        case 'pattern':
        case 'classPattern':
        case 'target': {
            // handle miscellaneous straight translations
            if (doSet) {
                item.value = newValue;
            } else {
                result = item.value;
            }
        }
        break;
        
        case 'rule':
        case 'options': {
            // handle a set of options recursively
            
            if (doSet) {
                // recursively set all subkeys in this object
                var curProp, key;
                for (key in newValue) {
                    if (newValue.hasOwnProperty(key)) {
                        curProp = item.getElementsByClassName(key);
                        if (curProp && curProp.length) {
                            ssbOptions.formItem(curProp[0], newValue[key]);
                        }
                    }
                }
            } else {
                result = {};
                
                var curItem, curValue;
                
                // get all suboptions of this item
                var subItems = item.getElementsByClassName('sub-'+optionName);
                
                // recursively build object from subkeys
                var subItemsLength = subItems.length;
                for (i = 0; i < subItemsLength; i++) {
                    curItem = subItems[i];
                    curValue = ssbOptions.formItem(curItem);
                    if (curValue !== undefined) {
                        result[curItem.classList.item(0)] = curValue;
                    }
                }
            }
        }
        break;
        
        case 'rules': {
            // array of rules
            
            if (doSet) {
                
                // if we're overwriting rules, delete old ones first
                if (!append) {
                    while (item.firstChild) {
                        item.removeChild(item.firstChild);
                    }
                }
                
                // add and recursively fill in new rules
                var newValueLength = newValue.length;
                for (i = 0; i < newValueLength; i++) {
                    newRule = item.appendChild(ssbOptions.rulePrototype.cloneNode(true));
                    ssbOptions.formItem(newRule, newValue[i]);
                }
                
                // show or hide add button
                ssbOptions.setAddButtonState();
                
            } else {
                
                // recurse to build array of rules
                result = [];
                i = item.children.length; while (i--)
                result.unshift(ssbOptions.formItem(item.children[i]));
            }
        }
        break;
        
        default: {
            // unknown ID -- abort
            ssb.warn('formItem got unknown option', optionName);
            result = undefined;
        }
    }
    
    return result;
}


// RULES -- add and delete rule rows, and handle moving between rules
// ------------------------------------------------------------------

// SETADVANCEDSTATUS -- show or hide advanced rules
ssbOptions.setAdvancedStatus = function(enabled) {
    // if we're called from event handler, get the new status
    if (typeof enabled == 'object') {
        enabled = enabled.target.checked;
    }
    
    // show or hide advanced rules
    if (enabled) {
        ssbOptions.doc.form.all.classList.add('advanced');
    } else {
        ssbOptions.doc.form.all.classList.remove('advanced');
    }
}


// ADDRULE -- add a rule to the list
ssbOptions.addRule = function(evt) {
    
    var thisRule, nextRule;
    
    if (evt && evt.currentTarget.classList.contains('add-after-button')) {
        
        // we were called by a rule-row add-after button, so find which rule
        thisRule = evt.currentTarget;
        while (thisRule && ! thisRule.classList.contains('rule')) {
            thisRule = thisRule.parentNode;
        }
        
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
    ssbOptions.setSavedStatus(false);
}


// DELETERULE -- delete a rule from the list
ssbOptions.deleteRule = function(evt) {
    
    // find the rule we were called from
    var thisRule = evt.target;
    while (thisRule && ! thisRule.classList.contains('rule')) {
        thisRule = thisRule.parentNode;
    }
    
    if (thisRule) {
        
        // remove this row from the rules list
        thisRule.parentNode.removeChild(thisRule);
        
        // update button states
        ssbOptions.setAddButtonState();
        ssbOptions.setSavedStatus(false);
    }
}


// HANDLERULEKEYDOWN -- move between rule rows or create a new rule at the end
ssbOptions.handleRuleKeydown = function(evt) {
    
    // we're only interested in the Enter key
    if (evt.which == 13) {
        
        // find the rule we were called from
        var thisRule = evt.target;
        while (thisRule && ! thisRule.classList.contains('rule')) {
            thisRule = thisRule.parentNode;
        }
        
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
    ssbOptions.setOptions('Failed to save options.');
}


// DOREVERT -- revert to last saved options from chrome.storage.local
ssbOptions.doRevert = function() {
    // populate the page from saved options
    ssbOptions.populate(ssb.options);
    
    // set form state to saved
    ssbOptions.setSavedStatus(true);
}


// DORESETTODEFAULT -- reset all options to default values
ssbOptions.doResetToDefault = function() {
    
    // open a dialog to confirm
    ssbOptions.dialog.run(
        'This will overwrite all your options and rules. Are you sure you want to continue?',
        'Confirm', function(success) {
            
            // only act if the user confirmed
            if (success) {
                
                // populate the form with default options
                ssbOptions.populate(ssb.defaultOptions);
                
                // save default options to storage
                ssbOptions.setOptions(
                    'Reset failed.',
                    ssb.defaultOptions
                );
            }
        }
    );
}


// DOIMPORT -- import settings from a file
ssbOptions.doImport = function(evt) {
    
    // turn on working bar
    ssbOptions.setWorkingStatus(true);
    
    // set up a FileReader
    var file = evt.target.files[0]; // this is a FileList object
    var reader = new FileReader();
    
    // set up handlers and then load the file
    
    // handle successful file load
    reader.onload = function(loadevent) {
        
        // FOR TESTING WORKING BAR (PART 1):
        //setTimeout(function(){
        
        // reset the import file field
        ssbOptions.doc.import_options.value = '';
        
        // parse the options
        try {
            var newOptions = JSON.parse(loadevent.target.result);
        } catch(err) {
            // parse failed
            
            // turn off working bar
            ssbOptions.setWorkingStatus(false);
            
            // open an alert
            ssbOptions.dialog.run(
                'Unable to parse "' + file.name + '": ' + err.message,
                'Error'
            );
            return;
        }
        
        // turn off working bar
        ssbOptions.setWorkingStatus(false);
        
        // update options to latest version
        ssb.updateOptions(newOptions);
        
        // allow user to choose how to bring in the new options
        ssbOptions.dialog.run(
            ('You can use the settings and rules in the file to ' +
            'replace your current settings and rules, or only ' +
            'add the rules to your current ones.'),
            'Choose Action',
            function(action) {
                
                // cancel == 0
                if (action) {
                    
                    // turn off working bar
                    ssbOptions.setWorkingStatus(true);
                    
                    // FOR TESTING WORKING BAR (PART 1):
                    //setTimeout(function(){
                    
                    if (action == 1) {
                        // replace all options
                        ssbOptions.populate(newOptions);
                    } else {
                        // add rules to end of rules list
                        ssbOptions.formItem(
                            ssbOptions.doc.form.rules,
                            newOptions.rules, true
                        );
                    }
                    
                    // turn off working bar
                    ssbOptions.setWorkingStatus(false);
                    
                    ssbOptions.setSavedStatus(false);
                    
                    // FOR TESTING WORKING BAR (PART 2):
                    //}, 3000);
                    
                }
            },
            [['Replace', 1], ['Add', 2], ['Cancel', 0]]
        );
        
        // FOR TESTING WORKING BAR (PART 2):
        //}, 3000);
    }
    
    // handle abort on file load
    reader.onabort = function() {
        ssbOptions.setWorkingStatus(false);
        ssbOptions.dialog.run('Import of "' + file.name + '" was aborted.', 'Alert');
    }
    
    // handle error on file load
    reader.onerror = function() {
        ssbOptions.setWorkingStatus(false);
        ssbOptions.dialog.run('Error importing "' + file.name + '".', 'Alert');
    }
    
    // handlers are set, so read in the file
    reader.readAsText(file);
}


// DOEXPORT -- export settings to a file
ssbOptions.doExport = function() {
    
    // turn on working bar
    ssbOptions.setWorkingStatus(true);
    
    // FOR TESTING WORKING BAR (PART 1):
    //setTimeout(function(){
    
    // get options from storage
    chrome.storage.local.get(null, function(items) {
        
        // now that we have the options, create a JSON file
        
        // create the default filename
        var date = new Date();
        var filename = (ssbOptions.status.ssbName ? ssbOptions.status.ssbName : 'Epichrome Runtime');
        ssbOptions.doc.export_options.download = (
            filename + ' Settings ' +
            date.getFullYear() + '-' +
            ('0' + (date.getMonth()+1)).slice(-2) + '-' +
            ('0' + date.getDate()).slice(-2) + '.json'
        );
        
        // create a live file
        ssbOptions.doc.export_options.href = URL.createObjectURL(
            new Blob([JSON.stringify(items)], {type: 'application/json'})
        );
        
        // turn off working bar
        ssbOptions.setWorkingStatus(false);
        
        // simulate a click on the export object
        ssbOptions.doc.export_options.click();
    });
    
    // FOR TESTING WORKING BAR (PART 2):
    //}, 3000);
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
    }
    
    // save this status
    ssbOptions.status = curStatus;
    
    // now check final extension status
    if (curStatus.active === true) {
        
        // we are live, so activate options page
        
        // show the main tab options if necessary
        ssbOptions.doc.form.main_tab_options.style.display = (
            curStatus.mainTab ? 'block' : 'none'
        );
        
        // check if we're installing
        if (curStatus.showInstallMessage) {
            
            // show install dialog
            ssbOptions.dialog.run(
                null, 'Welcome to your Epichrome app!',
                function () {
                    // remove install message from status
                    delete curStatus.showInstallMessage;
                    localStorage.setItem('status', JSON.stringify(curStatus));
                },
                'Get Started', 'install'
            );
        }
    } else {
        
        // extension isn't active
        if (curStatus.startingUp) {
            // we're still starting up
            ssbOptions.dialog.run(
                curStatus.message, 'The extension is starting up', undefined, 0
            );
        } else {
            // real shutdown, so shut down the options page
            ssbOptions.shutdown(curStatus, 'The extension has shut down');
        }
    }
}


// SETSAVEDSTATE -- set the saved/unsaved state of the form &
//                  enable or disable the save button bar
ssbOptions.setSavedStatus = function(saved) {
    
    // if called by event handler, we're always unsaved
    if (typeof saved == 'object') {
        saved = false;
    }
    
    // only act if state is changing
    if (ssbOptions.isSaved != saved) {
        
        ssbOptions.isSaved = saved;
        
        if (saved) {
            
            // we're setting the state to SAVED
            
            // set saved state for the form
            ssbOptions.doc.button_bar.classList.remove('unsaved');
            
            // add handlers that can set state back to unsaved
            ssbOptions.jqRules.on('sortupdate.ssbSave', ssbOptions.setSavedStatus);
            ssbOptions.jqForm.on('change.ssbSave', '.change', ssbOptions.setSavedStatus);
            ssbOptions.jqForm.on('click.ssbSave', '.click', ssbOptions.setSavedStatus);
            ssbOptions.jqForm.on('input.ssbSave', '.input', ssbOptions.setSavedStatus);
            
        } else {
            
            // we're setting the state to UNSAVED
            
            // remove enabling handlers
            ssbOptions.jqRules.unbind('.ssbSave');
            ssbOptions.jqForm.unbind('.ssbSave');
            
            // set saved state for the form
            ssbOptions.doc.button_bar.classList.add('unsaved');
        }
    }
}


// SETADDBUTTONSTATE -- show or hide the empty-list add-rule button
ssbOptions.setAddButtonState = function() {
    // if there are no rules, show the button; otherwise hide it
    ssbOptions.doc.form.add_rule_list.style.display = (
        ssbOptions.doc.form.rules.children.length > 0 ?
        'none' :
        'block'
    );
}


// SETWORKINGSTATUS -- show or hide a working status bar
ssbOptions.setWorkingStatus = function(enable) {
    if (enable) {
        // show the status bar
        ssbOptions.setOverlaySize();
        ssbOptions.doc.body.classList.add('working');
    } else {
        // hide the status bar
        ssbOptions.doc.body.classList.remove('working');
    }
}


// OVERLAY -- overlay object
// -------------------------

ssbOptions.setOverlaySize = function() {
    var formrect = ssbOptions.doc.form.all.getBoundingClientRect();
    ssbOptions.doc.overlay.style.width = formrect.width+'px';
    ssbOptions.doc.overlay.style.height = formrect.height+'px';
}


// DIALOG -- object to create and run various types of dialog box
// --------------------------------------------------------------

ssbOptions.dialog = {};


// DIALOG.HANDLEBUTTON -- object to hold the custom handler for dialog buttons
ssbOptions.dialog.handleButton = null;


// DIALOG.RUN -- show a dialog, alert or buttonless modal window
ssbOptions.dialog.run = function(message, title, callback, buttons, contentClass) {
    
    // set up default buttons if necessary
    if ((typeof callback != 'function') && (buttons == undefined)) {
        // default when called with no callback is an alert
        buttons = 1;
    } else if (buttons == undefined) {
        // default when called with a callback is a yes/no dialog
        buttons = 2;
    }
    
    // set up buttons
    if (buttons != 0) {
        // if a number was passed, set up default buttons
        if (typeof buttons == 'number') {
            switch (buttons) {
                case 1: {
                    // alert
                    buttons = [ [ 'OK', true ] ];
                }
                break;
                
                case 2: {
                    // dialog
                    buttons = [ [ 'Yes', true ], [ 'No', false ] ];
                }
                break;
                
                default: {
                    // 3-option dialog
                    buttons = [ [ 'Yes', 1 ], [ 'No', 2 ], [ 'Cancel', 0 ] ];
                }
            }
        } else if (typeof buttons == 'string') {
            // one button with a custom name
            buttons = [ [ buttons, true ] ];
        }
        
        // set up object keyed on button values
        var  buttonValues = {};
        var i = buttons.length;
        while (i--) { buttonValues[buttons[i][0]] = buttons[i][1]; }
        
        // set up button handler for this dialog
        ssbOptions.dialog.handleButton = function(evt) {
            
            // hide the dialog box
            //ssbOptions.setOverlayState(false);
            ssbOptions.doc.body.classList.remove('dialog');
            
            // remove button listeners
            ssbOptions.doc.dialog.button1.removeEventListener(
                'click', ssbOptions.dialog.handleButton
            );
            ssbOptions.doc.dialog.button2.removeEventListener(
                'click', ssbOptions.dialog.handleButton
            );
            ssbOptions.doc.dialog.button3.removeEventListener(
                'click', ssbOptions.dialog.handleButton
            );
            
            // if there's a callback, call it
            if (typeof callback == 'function') {
                callback(
                    buttonValues ?
                    buttonValues[evt.target.textContent] :
                    undefined
                );
            }
        }
    }
    
    // display/hide buttons
    var curButton;
    i = 3;
    while (i--) {
        // get ID of current button
        curButton = 'button' + (i+1);
        
        if (buttons[i]) {
            // fill in this button and show it
            ssbOptions.doc.dialog[curButton].textContent = buttons[i][0];
            ssbOptions.doc.dialog[curButton].classList.add('active');
            
            // add click listener
            ssbOptions.doc.dialog[curButton].addEventListener(
                'click', ssbOptions.dialog.handleButton
            );
        } else {
            // hide this button
            ssbOptions.doc.dialog[curButton].classList.remove('active');
        }
    }
    
    // set dialog title
    ssbOptions.doc.dialog.title.innerHTML = title;
    
    // normalize message object
    if (message) {
        ssbOptions.doc.dialog.text_content.innerHTML = message;
    } else {
        ssbOptions.doc.dialog.text_content.style.display = 'none';
    }
    
    // set content class
    if (typeof contentClass == 'string') {
        ssbOptions.doc.dialog.bar.className = contentClass;
    } else {
        ssbOptions.doc.dialog.bar.className = '';
    }
    
    // display the dialog
    ssbOptions.setOverlaySize();
    ssbOptions.doc.body.classList.add('dialog');
}


// BOOTSTRAP STARTUP -- set startup to run when content has loaded
// ---------------------------------------------------------------

document.addEventListener('DOMContentLoaded', ssbOptions.startup);
