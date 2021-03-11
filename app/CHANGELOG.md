# Epichrome.app Change Log
This project adheres to [Semantic Versioning](http://semver.org/).


## [2.4.0] - 2021-XX-XX
### Changed
- Fully compatible with macOS 11 Big Sur
- New unified app engine architecture for better compatibility with the dock, notifications, and other system services
- Added ability to edit existing Epichrome apps
- Added a login scan to restore apps left in an unlaunchable state after a crash, and a new app, "Epichrome Scan.app" to do the same manually
- Added option to try and find an app icon based on the app's URL
- Updated all icons for compatibility with Big Sur, and added interface for creating Big Sur-compatible app icons
- Improved icon creation interface to show preview of icon during app creation process
- Added an advanced setting during app creation and editing to control how the app handles updates
- Added an advanced setting during app creation and editing to customize the app's ID
- Added progress bars that appear while creating and updating apps and their engines, as well as while parsing browser extensions
- Unified GitHub update-checking across apps and Epichrome itself, so when a new update is found, you will only receive one notification (issue #???)
- The GitHub update-found dialog now shows info about changes in the new version
- The app update prompt now shows info about changes in the new version
- Added button to open an issue on GitHub when an app or Epichrome aborts due to error
- Apps are now automatically backed up whenever they are edited or updated (in the Backups subfolder of the app's data directory)
- Minor improvements to logging
- Reorganized and cleaned up the app welcome page
- Improved browser extension parsing, and added cache to improve startup time for new apps
- Improved retention of extension state across engine changes (extensions like Session Buddy with databases won't lose them any more)
- Updated built-in engine to Brave 1.1X.XX
### Fixed
- Apps will now retain their register browser setting across updates (existing apps that should not be registered browsers will need to be edited once to set that)


## [2.3.27] - 2021-03-07
### Changed
- Updated built-in engine to Brave 1.21.74


## [2.3.26] - 2021-02-24
### Changed
- Updated built-in engine to Brave 1.20.108


## [2.3.25] - 2021-02-07
### Changed
- Updated built-in engine to Brave 1.19.92


## [2.3.24] - 2021-01-21
### Changed
- Updated built-in engine to Brave 1.19.86


## [2.3.23] - 2021-01-03
### Changed
- Updated built-in engine to Brave 1.18.77


## [2.3.22] - 2020-12-24
### Changed
- Updated built-in engine to Brave 1.18.75


## [2.3.21] - 2020-12-11
### Changed
- Updated built-in engine to Brave 1.18.70


## [2.3.20] - 2020-12-08
### Fixed
- Fixed a problem with Big Sur that prevented apps from opening when other apps were already running ([issue #275](https://github.com/dmarmor/epichrome/issues/275 "issue #275")


## [2.3.19] - 2020-12-04
### Changed
- Updated built-in engine to Brave 1.17.75


## [2.3.18] - 2020-11-20
### Changed
- Updated built-in engine to Brave 1.17.73


## [2.3.17] - 2020-11-11
### Changed
- Updated built-in engine to Brave 1.16.75


## [2.3.16] - 2020-11-04
### Changed
- Updated built-in engine to Brave 1.16.72


## [2.3.15] - 2020-10-27
### Changed
- Updated built-in engine to Brave 1.16.68


## [2.3.14] - 2020-10-27
### Changed
- Updated built-in engine to Brave 1.15.76


## [2.3.13] - 2020-10-14
### Changed
- Updated built-in engine to Brave 1.15.72
### Fixed
- Restored app name to menubar for Chrome-engine apps, fixing problem introduced in Chrome 86.0.4240.80 ([issue #267](https://github.com/dmarmor/epichrome/issues/267 "issue #267")

## [2.3.12] - 2020-09-24
### Changed
- Updated built-in engine to Brave 1.14.84


## [2.3.11] - 2020-09-17
### Changed
- Updated built-in engine to Brave 1.14.81


## [2.3.10] - 2020-09-11
### Changed
- Updated built-in engine to Brave 1.13.86


## [2.3.9] - 2020-08-28
### Changed
- Updated built-in engine to Brave 1.13.82


## [2.3.8] - 2020-08-20
### Changed
- Updated built-in engine to Brave 1.12.114


## [2.3.7] - 2020-08-14
### Changed
- Change update code so release apps will not prompt to update to beta versions
- Updated built-in engine to Brave 1.12.112


## [2.3.6] - 2020-07-28
### Changed
- Updated built-in engine to Brave 1.11.104


## [2.3.5] - 2020-07-22
### Changed
- Updated built-in engine to Brave 1.11.97


## [2.3.4] - 2020-06-23
### Changed
- Updated built-in engine to Brave 1.10.97
### Fixed
- The "Launch Now" button at the end of app creation works again after being broken in 2.3.3


## [2.3.3] - 2020-06-18
### Changed
- Updated built-in engine to Brave 1.10.90
- Rewrote main Epichrome.app code in JavaScript and unified interface scripts into a single API to prepare for adding app editing in a future release
- Added progress bar to Epichrome.app during app creation both to give a better sense of how long it can sometimes take, and to allow it to be aborted
### Fixed
- Apps using built-in engine will now always prompt to update if their version of Epichrome is not installed, even on first run and even if they've previously chosen to skip the new version ([issue #248](https://github.com/dmarmor/epichrome/issues/248 "issue #248")
- Added a check for the rare situation where a new app with the built-in engine is created with the same ID as another app with an external engine, so the new app will no longer refuse to launch ([issue #247](https://github.com/dmarmor/epichrome/issues/247 "issue #247")


## [2.3.2] - 2020-05-31
### Changed
- Updated built-in engine to Brave 1.9.76
- Abstracted codesigning identity as a first step toward making it easier for anyone to build
- Refactored main Epichrome.app code to prepare for adding app editing in a future release
### Fixed
- Fixed problem updating certain 2.2.4 apps that could not display the update dialog and also couldn't update their Chrome engine due to incompatibility with Chrome 83 ([issue #228](https://github.com/dmarmor/epichrome/issues/228 "issue #228"))
- Added code signature to main Platypus app executable to prevent anti-virus software from reporting a false virus match ([issue #213](https://github.com/dmarmor/epichrome/issues/213 "issue #213"))
- [Unconfirmed] Added code signature to Brave executable for built-in engine in hopes of preventing occasional problem where Brave-based apps lose session state and saved passwords between runs ([issue #215](https://github.com/dmarmor/epichrome/issues/215 "issue #215"))
- [Unconfirmed] Added workaround to /usr/bin/open bug that could cause app engine or an updated app to fail to launch ([issue #232](https://github.com/dmarmor/epichrome/issues/232 "issue #232"))


## [2.3.1] - 2020-05-14
### Changed
- Updated built-in engine to Brave 1.8.96
### Fixed
- Fixed typo in update dialog


## [2.3.0] - 2020-05-09
### Changed
- Completely rewritten for full compatibility with macOS 10.15 Catalina, including system resource permissions (e.g. microphone and camera) and AppleScript interaction
- Added built-in Chrome-compatible [Brave Browser](https://github.com/brave/brave-browser "Brave Browser") engine for more app-like behavior, including more robust link-routing and custom icons on desktop notifications
- Rewrote welcome page to give useful contextual information and prompt for important actions like (re)installing extensions
- Added complete logging system
- Epichrome is now distributed as an installer package rather than a DMG due to changes in how app engines are handled
### Fixed
- Improved handling of runtime errors


## [2.2.4] - 2019-03-12
### Fixed
- Addressed very slow opening of links in the default browser under macOS Mojave [(Issue #167)](https://github.com/dmarmor/epichrome/issues/167 "Issue #167") by adding a code signature to Epichrome apps. Thanks to [cmacminn](https://github.com/cmacminn "cmacminn"), [whatknows](https://github.com/whatknows "whatknows"), and everyone else who helped describe the problem.
- The same change appears to also help most users with the problem of Epichrome apps's icons and names reverting to Chrome after certain actions like downloading files [(Issue #173)](https://github.com/dmarmor/epichrome/issues/173 "Issue #173"). Thanks to [daviddumonde](https://github.com/daviddumonde "daviddumonde") and everyone who helped with this problem.
- Addressed a problem routing links to Chrome when it's the default browser [(Issue #163)](https://github.com/dmarmor/epichrome/issues/163 "Issue #163"). The system would get confused between Chrome and any Epichrome apps that were launched before Chrome. Added a special case to the native messaging host to detect when Chrome is the default browser and send links there explicitly. Thanks to [GrogHills](https://github.com/GrogHills "GrogHills"), [heyfletch](https://github.com/heyfletch "heyfletch"), [ylluminate](https://github.com/ylluminate "ylluminate"), and everyone else who helped identify the problem.


## [2.2.3] - 2018-09-12
### Changed
- Added --debug flag to Epichrome executable so it can log debugging info to stderr.
### Fixed
- Changed the method the cleanup process uses to wait for Epichrome apps to quit. /usr/sbin/lsof was eating way too much CPU. Thanks to [pedramamini](https://github.com/pedramamini "pedramamini") for first noticing this and [henderea](https://github.com/henderea "henderea") for contributing the fix.
- Changed how Epichrome apps search for Epichrome, so they should now always find only the latest installed version. Thanks to [henderea](https://github.com/henderea "henderea") for noticing this problem.
- Fixed a bug in how Epichrome checks for new versions of itself on github. It should no longer pop up a notification about a new version that matches the current version.
- Fixed a bug in the way Epichrome stores info from its previous run, so certain actions will no longer cause it to forget everything about its last run.


## [2.2.2] - 2018-09-03
### Fixed
- Fixed a permission problem that was causing Epichrome and its apps to silently fail to check github for a new version of Epichrome.


## [2.2.1] - 2018-09-02
### Changed
- Rewrote the engine architecture so it will work with Chrome 69. The Chrome engine now links dynamically at runtime and is deleted on quit. If the installed Chrome is version 69 or later, the engine is now also hard-linked to withstand Chrome 69's much stricter security. Thanks to [webxl](https://github.com/webxl "webxl") and everyone else who reported the problem.
- Added a welcome page that displays the first time a new app is run (or if the profile folder is deleted), with instructions on how to enable Epichrome Helper (which Chrome disables by default).
- Epichrome is now explicitly single-user, and will not allow a user to create an Epichrome app in a folder they don't have write permission for (authentication code has been removed). This is a first step toward a possible different relationship between Epichrome apps and user profile directories.
- Epichrome is now properly code-signed, so should be installable without disabling GateKeeper. Thanks to [henderea](https://github.com/henderea "henderea") and everyone else who asked for this, and sorry it took so long to finally happen.
### Fixed
- Fixed relative path for python in runtime.sh. Thanks to [mattHawthorn](https://github.com/mattHawthorn "mattHawthorn") for the pull request to fix this.


## [2.1.20] - 2017-07-22
### Changed
- Added functionality that should allow Epichrome apps to work properly with Chrome extensions that use native messaging (such as 1Password as of version 6.8). Thanks to [tamaracks](https://github.com/tamaracks "tamaracks") and [henderea](https://github.com/henderea "henderea") for catching this change and helping figure out the solution.
- Tweaked internal code so future beta releases with version numbers like 2.1.20a will be recognized for auto-updating.
### Fixed
- Rolled back a change to the Chrome engine so that the CFExecutable key once again points to Google Chrome. The change seems to have caused some link redirection problems, and possibly other problems too. Thanks to [ylluminate](https://github.com/ylluminate "ylluminate") for catching this.
- Updated the macOS 10.12.5 workaround from Epichrome 2.1.17 now that macOS 10.12.6 has been released. Now the Epichrome Helper native messaging host only uses the subprocess method when it's running under macOS 10.12.5, and uses the original, more efficient webbrowser method on all other macOS versions.

## [2.1.18] - 2017-07-16
### Fixed
- Added key to Chrome Engine Info.plist so SSBs run at high-res on retina displays. Thanks to [linusbobcat](https://github.com/linusbobcat "linusbobcat") for first catching this.


## [2.1.17] - 2017-07-15
### Fixed
- Worked around a bug in macOS 10.12.5 that caused Epichrome Helper to open all external URLs in Firefox or Safari no matter what the default browser is. Special thanks to [henderea](https://github.com/henderea "henderea") for first identifying and then coming up with the fix for this. Thanks also to everyone else who helped diagnose the problem.
- Changed the way the internal Chrome Engine works in order to hopefully get rid of the annoying proliferation of copies of ChromeEngine.app in the list of system browsers. Thanks to [jarredt](https://github.com/jarredt "jarredt") for raising this issue.
- Fixed a bug in how Epichrome.app handles the Launch button at the end of app creation. It should now no longer accidentally launch other apps with the same name as your new app. Thanks to [pvinis](https://github.com/pvinis "pvinis") for catching this.

### Changed
- Added text to the Success dialogue to warn users that they will now need to manually enable Epichrome Helper in new apps.
- Removed the alert that used to pop up in each Epichrome app when it detected a new version of Chrome. They now silently relink to the new version and only show an alert if something goes wrong.

## [2.1.16] - 2016-11-03
### Fixed
- Finally squashed the bug that caused those failed Chrome updates to destroy the entire app. From now on, even if a Chrome update fails, the app should stay intact.


## [2.1.15] - 2016-11-01
### Fixed
- Fixed a small bug in the code that checks github for new versions. Apps will no longer insist that there's a new version on github even though they've just been updated to that new version.


## [2.1.14] - 2016-11-01
### Changed
- Epichrome apps now attempt to update themselves to the latest Epichrome engine _before_ updating themselves to the latest version of Chrome. Doing it the other way around was causing problems if people had installed a current version of Epichrome but hadn't updated their apps before a new version of Chrome was installed. Thanks to [gnyrd](https://github.com/gnyrd "gnyrd") and everyone else who noticed and helped diagnose this problem.
- Rewrote icon-creation code to handle JPG, GIF and other formats with indexed color or without alpha channels. Custom document icons are now also created. Thanks to [io41](https://github.com/io41 "io41") and [freewind](https://github.com/freewind "freewind") for identifying the shortcomings with the old icon code.

### Fixed
- Fixed a bug introduced in 2.1.13 that caused the Epichrome update dialog box to fail, which renders apps unable to ever update to a later version. Added a terminal one-liner in the [README](https://github.com/dmarmor/epichrome) as a workaround to allow 2.1.13 apps to update to 2.1.14.


## [2.1.13] - 2016-10-07
### Changed
- Added code to automatically check Github once a week for a new version of Epichrome. If one is found, a dialog is displayed giving the user the option to go to the download page for the new release, check again later or ignore this version. Thanks to [Zettt](https://github.com/Zettt "Zettt") for proposing an update-checking system.

### Fixed
- Added a check in the icon-conversion code to point out that it can't handle images with no alpha channel. Thanks to [io41](https://github.com/io41 "io41") and [freewind](https://github.com/freewind "freewind") for helping diagnose this. Sorry I don't have time to actually make the code handle non-alpha images right now.


## [2.1.12] - 2016-09-18
### Fixed
- Fixed a minor bug in processing Chrome localization strings files. It may improve your performance using the Chrome beta channel (but may not). Thanks to [vhf](https://github.com/vhf "vhf") for the fix!


## [2.1.11] - 2016-02-21
### Fixed
- Fixed a bug that broke compatibility with Browser Fairy. For now, links are still not able to launch an Epichrome app (but will route properly if the app is already open). The next update of Browser Fairy should fix that last problem too. Thanks again to [rschend](https://github.com/rschend "rschend") for identifying this, and to [jschuster](https://github.com/jschuster "jschuster"), the creator of Browser Fairy, for helping with the fix!


## [2.1.10] - 2016-02-14
### Fixed
- Fixed a potentially serious bug where updates to Chrome could break Epichrome apps permanently, so they'd have to be deleted and recreated. The internal ChromeEngine in each app had Info.plist keys that would cause it to try to auto-update and that would break it. Those keys are now removed.
- Fixed a minor bug that would cause apps to display the wrong dock icon if an app was used to download a file or display certain dialog boxes. The internal ChromeEngine now uses the localized name and icons of the main app, so that when the download badge appears, the icon and name don't change. Thanks to [rschend](https://github.com/rschend "rschend") for finding this and tracking down the cause, and to the others who contributed their reports.
- Added warning to README that Chrome should not be set up with Automatic Updates for All Users.
- [wizonesolutions](https://github.com/wizonesolutions "wizonesolutions") contributed README documentation for editing an app's URL.

## [2.1.9] - 2016-01-31
### Fixed
- Fixed a minor bug in 2.1.8 where on first run after update, apps would display the wrong icon in the task switcher and dock. Thanks to [trak3r](https://github.com/trak3r "trak3r") for reporting this.


## [2.1.8] - 2016-01-23
### Fixed
- Fixed a long-standing bug that caused Epichrome apps to run without hardware graphics acceleration due to the GPU process crashing on startup. This caused sluggish graphics response (especially on retina displays) and failures to load WebGL sites. Big thanks to [mhwinkler](https://github.com/mhwinkler "mhwinkler") and [jdsimcoe](https://github.com/jdsimcoe "jdsimcoe") for identifying this bug (in two utterly different forms) and putting in a bunch of time helping isolate it and test approaches to a fix, and to [breeden](https://github.com/breeden "breeden") for once again testing the new update before I inflicted it on everyone else.


## [2.1.7] - 2016-01-22
### Fixed
- Fixed an incompatibility with Chrome 48.0.2564.82. For whatever reason, Epichrome apps would no longer run unless they had a link to the Chrome Versions directory in their bundles. This update adds that link. Thanks to [ylluminate](https://github.com/ylluminate "ylluminate"), [evansthompson](https://github.com/evansthompson "evansthompson"), [msubel](https://github.com/msubel "msubel"), and everyone else who pointed this issue out. Special thanks to [breeden](https://github.com/breeden "breeden") for helping test the solution!


## [2.1.6] - 2015-09-21
### Fixed
- Epichrome now does its best to run robustly even when Spotlight indexing is turned off. Thanks to [linusbobcat](https://github.com/linusbobcat "linusbobcat"), [TraderStf](https://github.com/TraderStf "TraderStf") and [breeden](https://github.com/breeden "breeden") for identifying and helping diagnose this.


## [2.1.5] - 2015-08-21
### Changed
- Added the ability to create an Epichrome app in the Applications directory (or really anywhere), even if the user running Epichrome is not an administrator. Epichrome will attempt to invoke admin privileges. Thanks to [Zettt](https://github.com/Zettt "Zettt") for suggesting this.
- Related to that, added the ability for a user to invoke admin privileges in order to update an app that they didn't create and don't have permissions to alter.
- Minor change: the summary screen just before app creation now shows the path where the app will be created.

### Fixed
- Several minor bugs that could cause temporary directories to be left in place in some circumstances.


## [2.1.4] - 2015-07-22
### Fixed
- Another small fix to the alert/dialog bug. Hopefully really fixed now.


## [2.1.3] - 2015-07-21
### Fixed
- Caught bug that would prevent alerts from being displayed on error. This is potentially bad, since if something goes wrong on startup, there won't be any way to know what.


## [2.1.2] - 2015-07-20
### Fixed
- Apps created with a custom icon in ICNS format no longer ignore the custom icon. Thanks to [jdsimcoe](https://github.com/jdsimcoe "jdsimcoe") and [pattulus](https://github.com/pattulus "pattulus") for catching this.


## [2.1.1] - 2015-07-16
### Changed
- Changed the way profile folders are created so that Chrome will no longer pop up that dialog box asking if you want it to be the default browser the first time an app runs.

### Fixed
- Browser Tab-style apps with only one tab are no longer mistakenly created as App Window-style apps instead. Added text to pre-creation summary dialog to clarify which style is being created. Thanks to [cbeams](https://github.com/cbeams "cbeams") for catching this.
- The profile folder should now be properly migrated to the new profile location when an app is updated.
- The app version number should no longer be mistakenly updated to the latest Epichrome version in the rare occasion that a new version of Epichrome is installed, and a new version of Chrome is installed, *and* the user decided not to update the app, but do it later.
- The Helper extension should now stay properly auto-installed even if a user deletes their profile folder.


## [2.1.0] - 2015-07-15
### Changed
- Renamed the project Epichrome, mostly because I found MakeChromeSSB very annoying to say and write.
- Apps now automatically install *Epichrome Helper*, a companion Chrome extension that handles link redirection so each app can have rules for which links it handles itself and which should be sent to the default browser. (Thanks to [treyharris](https://github.com/treyharris "treyharris") for first bringing up the idea, and to [phillip-r](https://github.com/phillip-r "phillip-r") and [cbeams](https://github.com/cbeams "cbeams") for more thoughts on how it might work.)
- Profile directories have moved to ${HOME}/Library/Application Support/Epichrome/Apps/<app-id>. Existing profile directories will be automatically migrated when each app is updated.

### Fixed
- Umlauts can now be used in app names. (Possibly this is a general fix for unicode characters in app names, but I can't be sure as I have no good way to test it on my system.) (Thanks to [Zettt](https://github.com/Zettt "Zettt") for finding this.)
- Apps should now display properly on retina screens. (Thanks to [mikejacobs](https://github.com/mikejacobs "mikejacobs"), [Zettt](https://github.com/Zettt "Zettt") and [mhwinkler](https://github.com/mhwinkler "mhwinkler") for pointing this out and helping test the fix.)
- Streamlined error-handling in the runtime engine.


## [2.0.1] - 2015-06-09
### Changed
- Rewrote Info.plist parsing code in Python for better XML robustness.

### Fixed
- Fixed a bug in the way Google Chrome's version is retrieved. I had been scanning the Versions directory, but my sorting code didn't handle a change from a 2-digit version to a 3-digit one (in this case, 43.0.2357.81 to 43.0.2357.124), so it still thought Chrome was on an old version, which caused an error. Now the version is retrieved using /usr/bin/mdls, which should be much more robust. (Thanks to [bikeatefoucault](https://github.com/bikeatefoucault "bikeatefoucault") and [thinkspill](https://github.com/thinkspill "thinkspill") for catching this and helping track it down!)


## [2.0.0] - 2015-06-03
# Changed
- SSBs will offer to optionally update themselves if they detect that a new version of MakeChromeSSB has been installed.
  - *Note for users of version 1.0.0: To get the new auto-update functionality, you'll need to use MakeChromeSSB 2.0.0 to re-create all your existing SSBs. Make sure to give the new app the exact same name as the old one to ensure that your profile information doesn't get lost (the simplest way to do that is just to navigate to the existing SSB in the first file selection dialog and overwrite it). Once you've recreated your SSBs, they will be able to auto-update themselves whenever you download future versions of MakeChromeSSB.*

- SSBs will automatically find Chrome if it's moved or renamed, and will update themselves when Chrome is updated to a new version.

- SSBs can now have a distinct "short name" (which appears in the menubar when the SSB is running) separate from the long app name (which appears in the Dock).

- Localization: SSBs now contain the full complement of language localizations that Chrome has. Whatever language you use Chrome in, the SSB will work in that language. (Sorry--MakeChromeSSB itself is only in English for now, but see Future Development.)

- Much more robust icon creation: can now take almost any TIFF, PNG or JPG file and will crop it to square and convert it to an ICNS.

- Multi-tab mode: SSBs can now either be the default "app-style" with no address bar, or the user can specify multiple tabs which will always be opened at startup. Alternately, SSBs can be tab-style with *no* tabs specified, in which case the SSB will simply act as an instance of Chrome, with its initial tabs determined by its preferences.  (Thanks to [mrmartineau](https://github.com/mrmartineau "mrmartineau") for suggesting this!)

- Register as browser: SSBs can now optionally register themselves with OSX as browsers, allowing links to be directed to them from other applications. (Thanks to [jschuster](https://github.com/jschuster "jschuster") for suggesting this!)

- Much more extensive AppleScript interface to handle all these new features (sorry for the long chain of modal dialog boxes--see Future Development for my plan to deal with this)


## [1.0.0] - 2015-01-06
- First version with very basic functionality, inspired by [chrome-ssb-osx](https://github.com/lhl/chrome-ssb-osx "chrome-ssb-osx") by [lhl](https://github.com/lhl "lhl") and Mait Vilbiks' [AppleScript wrapper](https://www.lessannoyingcrm.com/blog/2011/01/240/Updates+to+Mac+Chrome+application+shortcuts+and+the+iOS+fullscreen+webapp+generator "Mait Vilbiks utility")
