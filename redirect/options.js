var ssbOptions = {};

// options page elements
ssbOptions.doc = {};
ssbOptions.doc.form = {};
ssbOptions.doc.form.ignoreAllInternalSameDomain = document.getElementById('ignoreAllInternalSameDomain');
ssbOptions.doc.form.redirectByDefault = document.getElementById('redirectByDefault');
ssbOptions.doc.form.rules = document.getElementById('rules');
ssbOptions.doc.form.add_click = document.getElementById('add_click');
ssbOptions.doc.form.save_click = document.getElementById('save_click');
ssbOptions.doc.form.reset_click = document.getElementById('reset_click');
ssbOptions.doc.form.import_click = document.getElementById('import_click');
ssbOptions.doc.form.import_options = document.getElementById('import_options');
ssbOptions.doc.form.export_click = document.getElementById('export_options');

ssbOptions.doc.overlay = document.getElementById('overlay');

ssbOptions.doc.shutdown = {};
ssbOptions.doc.shutdown.box = document.getElementById('shutdown_box');
ssbOptions.doc.shutdown.message = document.getElementById('shutdown_message');

ssbOptions.doc.dialog = {};
ssbOptions.doc.dialog.box = document.getElementById('dialog_box');
ssbOptions.doc.dialog.title = document.getElementById('dialog_title');
ssbOptions.doc.dialog.message = document.getElementById('dialog_message');
ssbOptions.doc.dialog.button1 = document.getElementById('dialog_button1');
ssbOptions.doc.dialog.button2 = document.getElementById('dialog_button2');
ssbOptions.doc.dialog.button3 = document.getElementById('dialog_button3');

ssbOptions.state = {};
ssbOptions.state.current = {};
ssbOptions.state.changes = {};


// populate options form
ssbOptions.populate = function(items) {

    // update the form
    for (key in items) {
	if (items.hasOwnProperty(key) && ssbOptions.doc.form[key]) {
	    ssbOptions.updateOption(ssbOptions.doc.form[key], items[key]);
	}
    }
}


ssbOptions.checkStatus = function() {
    
    var curStatus = localStorage.getItem('status');

    if (curStatus == null) {
	curStatus = { active: false, message: "Extension hasn't started up." };
	localStorage.setItem('status', curStatus);
    } else {
	try {
	    curStatus = JSON.parse(curStatus);
	} catch(err) {
	    console.log('error parsing status: ' + err.message);
	    curStatus = { active: false, message: "Badly formed status." };
	    localStorage.setItem('status', curStatus);
	}
	
	if (curStatus.active == true)
	    chrome.runtime.sendMessage('ping', function(response) {
		if (! response) {
		    curStatus = { active: false, message: 'Disconnected from extension: ' + chrome.runtime.lastError };
		    localStorage.setItem('status', curStatus);
		}
	    });
    }
    
    if (curStatus.active == true) {
	ssbOptions.doc.overlay.style.display = 'none';
	ssbOptions.doc.shutdown.box.style.display = 'none';
	ssbOptions.doc.dialog.box.style.display = 'none';
    } else {
	console.log('curStatus is:', curStatus);
	ssbOptions.doc.dialog.box.style.display = 'none';
	ssbOptions.doc.shutdown.message.textContent = (curStatus.message ? curStatus.message : '');
	ssbOptions.doc.shutdown.box.style.display = 'block';
	ssbOptions.doc.overlay.style.display = 'block';
    }
}

ssbOptions.dialog = {};
ssbOptions.dialog.handleButton = null;
ssbOptions.dialog.run = function(message, title, callback, buttons) {

    // set up button value dict
    if (! buttons || ! (buttons.length))
	buttons = [ [ 'Yes', true ], [ 'No', false ] ];
    var buttonValues = {};
    
    for (var i = 0; i < buttons.length; i++)
	buttonValues[buttons[i][0]] = buttons[i][1];

    ssbOptions.dialog.handleButton = function(evt) {
	ssbOptions.dialog.close();
	callback(buttonValues ? buttonValues[evt.target.textContent] : undefined);
    }
    
    // set up dialog box
    ssbOptions.doc.shutdown.box.style.display = 'none';
    ssbOptions.doc.dialog.message.textContent = message;
    ssbOptions.doc.dialog.title.textContent = title;
    var curButton;
    for (i = 0; i < 3; i++) {
	curButton = 'button' + (i+1);
	console.log('working on: '+curButton);
	if (buttons[i]) {
	    ssbOptions.doc.dialog[curButton].textContent = buttons[i][0];
	    ssbOptions.doc.dialog[curButton].style.display = 'block';
	    ssbOptions.doc.dialog[curButton].addEventListener('click', ssbOptions.dialog.handleButton);
	} else {
	    ssbOptions.doc.dialog[curButton].style.display = 'none';
	}
    }
    ssbOptions.doc.dialog.box.style.display = 'block';
    ssbOptions.doc.overlay.style.display = 'block';
}

ssbOptions.dialog.alert = function(message, title, callback, button_text) {

    ssbOptions.dialog.handleButton = function() {
	ssbOptions.dialog.close();
	callback();
    }
    
    ssbOptions.doc.shutdown.box.style.display = 'none';
    ssbOptions.doc.dialog.message.textContent = message;
    ssbOptions.doc.dialog.title.textContent = title;
    ssbOptions.doc.dialog.button1.textContent = (button_text ? button_text : 'OK');
    ssbOptions.doc.dialog.button1.addEventListener('click', ssbOptions.dialog.handleButton);
    ssbOptions.doc.dialog.button1.style.display = 'block';
    ssbOptions.doc.dialog.button2.style.display = 'none';
    ssbOptions.doc.dialog.button3.style.display = 'none';
    ssbOptions.doc.dialog.box.style.display = 'block';
    ssbOptions.doc.overlay.style.display = 'block';
}

ssbOptions.dialog.close = function() {
    ssbOptions.doc.overlay.style.display = 'none';
    ssbOptions.doc.shutdown.box.style.display = 'none';
    ssbOptions.doc.dialog.box.style.display = 'none';

    ssbOptions.doc.dialog.button1.removeEventListener('click', ssbOptions.dialog.handleButton);
    ssbOptions.doc.dialog.button2.removeEventListener('click', ssbOptions.dialog.handleButton);
    ssbOptions.doc.dialog.button3.removeEventListener('click', ssbOptions.dialog.handleButton);
}

ssbOptions.doImport = function(evt) {
    
    var file = evt.target.files[0]; // FileList object
    var reader = new FileReader();
    
    // parse the info in the file
    reader.onload = function(loadevent) {
	
	ssbOptions.doc.form.import_options.value = '';
	
	var newOptions;
	
	try {
	    newOptions = JSON.parse(loadevent.target.result);
	} catch(err) {
	    ssbOptions.dialog.alert(
		'Unable to parse "' + file.name + '": ' + err.message,
		'Error');
	    return;
	}
	
	// here's where you'd need to handle updating from previous options version
	delete newOptions.optionsVersion;
	
	ssbOptions.dialog.run(
	    'You can use the settings and rules in the file to replace your current settings and rules, or only add the rules to your current ones.',
	    'Choose Action',
	    function(action) {
		
		if (action == 1) {
		    // replace
		    ssbOptions.populate(newOptions);
		} else if (action == 2) {
		    // add
		    var rulesOnly = {};
		    rulesOnly.rules = ssbOptions.state.current.rules.concat(newOptions.rules);
		    ssbOptions.populate(rulesOnly);
		}
		// else cancel
	    },
	    [['Replace', 1], ['Add', 2], ['Cancel', 0]]
	);
    }

    // handle errors/aborts
    reader.onabort = function() {
	ssbOptions.dialog.alert('Import of "' + file.name + '" was aborted.', 'Alert');
    }
    reader.onerror = function() {
	ssbOptions.dialog.alert('Error importing "' + file.name + '".', 'Alert');
    }
    
    // Read in the image file as a data URL.
    reader.readAsText(file);
}

ssbOptions.doExport = function() {
    chrome.storage.local.get(null, function(items) {
	var date = new Date();
	ssbOptions.doc.form.export_options.download =
	    'SSB Redirect Settings ' +
	    date.getFullYear() + '-' +
	    ('0' + date.getMonth()).slice(-2) + '-' +
	    ('0' + date.getDate()).slice(-2) + '.txt';
	ssbOptions.doc.form.export_options.href =
	    URL.createObjectURL(new Blob([JSON.stringify(items)],
					 {type: 'application/json'}));
	ssbOptions.doc.form.export_options.click();
    });
}

// getter and setter for option fields in the form
ssbOptions.updateOption = function(option, newValue) {
    var oldValue = undefined;
    
    if (!option.id) {
	
	// this is a rule
	var curRule = option.parentNode;
	var rules = curRule.parentNode;
	if (rules.id != 'rules') {
	    console.log('unexpected parent node!');
	    return;
	}
	for (var i = 0; i < rules.children.length; i++) {
	    if (rules.children[i] === curRule) break;
	}
	
	// update current state of options
	curRule = ssbOptions.state.current.rules[i];
	if (option.className == 'redirect') {
	    curRule.redirect = (option.value == 'true');
	} else {
	    curRule[option.className] = option.value;
	}
	
	// set us up to compare with the saved options
	oldValue = newValue = ssb.clone(ssbOptions.state.current['rules']);
	option = rules;
	
    } else {
	
	var doSet = (newValue !== undefined);
	
	// this is a top-level option
	
	switch(option.id) {
	case 'ignoreAllInternalSameDomain':
	    oldValue = option.checked;
	    if (doSet) option.checked = newValue; else newValue = oldValue;
	    break;

	case 'redirectByDefault':
	    oldValue = (option.value == 'true');
	    if (doSet) option.value = newValue; else newValue = oldValue;
	    break;

	case 'rules':
	    oldValue = [];
	    var curRule;
	    var oldNumRules = option.children.length;
	    for (var i = 0; i < oldNumRules; i++) {
		curRule = option.children[i];
		oldValue.push({pattern: curRule.getElementsByClassName('pattern')[0].value,
			       target: curRule.getElementsByClassName('target')[0].value,
			       redirect: (curRule.getElementsByClassName('redirect')[0].value == 'true')});
	    }
	    
	    if (doSet) {
		for (var i = 0; i < newValue.length; i++) {
		    if (i >= oldNumRules) {
			// new rules list is longer than the old one, so add an entry
			option.appendChild(ssbOptions.rulePrototype.cloneNode(true));
		    }

		    // fill in the current entry
		    curRule = option.children[i];
		    curRule.getElementsByClassName('pattern')[0].value = newValue[i].pattern;
		    curRule.getElementsByClassName('target')[0].value = newValue[i].target;
		    curRule.getElementsByClassName('redirect')[0].value = (newValue[i].redirect ? 'true' : 'false');
		}
		
		// if new rules list is shorter than old, delete extra entries
		for (var j = oldNumRules - 1; j >= i; j--) {
		    curRule = option.children[j];
		    curRule.parentNode.removeChild(curRule);
		}

		newValue = ssb.clone(newValue); // safe copy of newValue
	    }
	    else
		newValue = oldValue;
	    break;
	    
	case 'optionsVersion':
	    // this is ignored
	    return;
	    
	default:
	    // unknown ID -- abort
	    console.log('unknown ID ' + option.id);
	    return;
	}
	
	// update current state of options
	ssbOptions.state.current[option.id] = newValue;
    }
    
    // compare new value to saved value
    if (! ssb.equal(newValue, ssb.options[option.id]))
	ssbOptions.state.changes[option.id] = newValue;
    else
	delete ssbOptions.state.changes[option.id];
    
    // enable or disable save button
    ssbOptions.buttonDisabled(ssbOptions.doc.form.save_click,
			      (Object.getOwnPropertyNames(ssbOptions.state.changes).length == 0));
    
    return oldValue;
}

ssbOptions.buttonDisabled = function(button, disabled) {
    button.style.cursor = (disabled ? 'auto' : 'pointer');
    button.disabled = disabled;
}
    
ssbOptions.doOptionChange = function(evt) {

    console.log('detected option change for '+evt.target.id+':', evt.target);
    
    // update the state of the form
    ssbOptions.updateOption(evt.target);
}


ssbOptions.doResetToDefault = function() {
    ssbOptions.dialog.run(
	'This will overwrite all your options and rules. Are you sure you want to continue?',
	'Confirm',
	function(success) {
	    if (success) {
		
		ssbOptions.populate(ssb.defaultOptions);
		
		ssbOptions.setOptions(ssb.defaultOptions, 'Reset failed.');
	    }
	});
}

ssbOptions.setOptions = function(newOptions, failPrefix) {
    
    ssb.setOptions(newOptions, function(success, message) {
	if (success) {
	    ssbOptions.state.changes = {};
	    ssbOptions.doc.form.save_click.disabled = true;
	    
	    // update status of reset to defaults button
	    ssbOptions.doc.form.reset_click.disabled =
		ssb.equal(ssb.options, ssb.defaultOptions);
	    
	} else {
	    // failed
	    ssbOptions.dialog.alert(failPrefix + ' ' + message, 'Warning');
	}
    });
}


ssbOptions.doAddRule = function() {

    // add a new copy of the prototype rule
    var rules = ssbOptions.doc.form.rules;
    rules.appendChild(ssbOptions.rulePrototype.cloneNode(true));

    // give focus to the pattern & select all text
    var pattern =
	rules.children[rules.children.length - 1].getElementsByClassName('pattern')[0];    
    pattern.focus();
    pattern.select();
    
    // update the current state
    ssbOptions.updateOption(ssbOptions.doc.form.rules);
}

// restore options window state from storage
ssbOptions.startup = function() {

    ssb.startup('options', function(success, message) {

	if (success) {

	    // get prototype rule entry
	    ssbOptions.rulePrototype = ssbOptions.doc.form.rules.children[0].cloneNode(true);
	    
	    // set up listeners
	    
	    // handle changes to options
	    
	    ssbOptions.doc.form.ignoreAllInternalSameDomain.addEventListener('change', ssbOptions.doOptionChange);
	    ssbOptions.doc.form.rules.addEventListener('change', ssbOptions.doOptionChange);
	    ssbOptions.doc.form.redirectByDefault.addEventListener('change', ssbOptions.doOptionChange);
	    
	    ssbOptions.doc.form.save_click.disabled = true;
	    ssbOptions.doc.form.save_click.addEventListener('click', ssbOptions.doSave);

	    ssbOptions.doc.form.add_click.addEventListener('click', ssbOptions.doAddRule);
	    
	    window.addEventListener('storage', ssbOptions.checkStatus);

	    // reset to default button
	    ssbOptions.doc.form.reset_click.disabled =
		ssb.equal(ssb.options, ssb.defaultOptions);

	    ssbOptions.doc.form.reset_click.addEventListener('click', ssbOptions.doResetToDefault);
	    
	    // handle import button
	    ssbOptions.doc.form.import_options.addEventListener('change', ssbOptions.doImport);
	    
	    ssbOptions.doc.form.import_click.addEventListener('click', function() {
		ssbOptions.doc.form.import_options.click();
	    });
	    
	    // handle export button
	    ssbOptions.doc.form.export_click.addEventListener('click', ssbOptions.doExport);
	    
	    // get extension status
	    ssbOptions.checkStatus();
	    	    
	    // use options in storage to populate the page
	    ssbOptions.populate(ssb.options);

	    $( "#rules" ).sortable({
		axis: 'y',
		handle: '.drag-handle',
		tolerance: 'pointer',
		update: ssbOptions.doOptionChange
	    });

	    ssbOptions.doc.form.rules.addEventListener('click', function(e) {
		if (e.target.className == 'delete-button') {
		    console.log('got delete click');
		    var thisRule = e.target.parentNode;
		    var parent = thisRule.parentNode;
		    parent.removeChild(thisRule);
		    ssbOptions.updateOption(parent);
		}
	    });
	    
	} else {
	    ssbOptions.dialog.alert(message, 'Error');
	}
    });
}

// save options to chrome.storage.local
ssbOptions.doSave = function() {
    ssbOptions.setOptions(ssbOptions.state.current, 'Failed to save options.');
}

document.addEventListener('DOMContentLoaded', ssbOptions.startup);
