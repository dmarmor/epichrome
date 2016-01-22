# Epichrome.app Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

## [2.1.7] - 2016-01-22
### Fixed
- Fixed an incompatibility with Chrome 48.0.2564.82. For whatever reason, Epichrome apps would no longer run unless they had a link to the Chrome Versions directory in their bundles. This update adds that link.

Thank to [ylluminate](https://github.com/ylluminate "ylluminate"), [evansthompson](https://github.com/evansthompson "evansthompson"), [msubel](https://github.com/msubel "msubel"), 
and everyone else who pointed this issue out. Special thanks to [breeden](https://github.com/breeden "breeden") for helping test the solution!


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
