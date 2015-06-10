# MakeChromeSSB 2.0.1

**Please update to 2.0.1 if you've been using any previous version! There's a bug in 2.0.0 that will cause your SSBs to not realize when a new version of Chrome has been installed (as happened today, 6/9/2015).**

MakeChromeSSB is an AppleScript-based Mac application (Make Chrome SSB.app) which allows users to create Chrome-based site-specific browsers (SSBs) for Mac OSX. These SSBs are full Mac apps, and each maintains its own separate Chrome profile. The SSBs require Chrome to be installed in order to run.

Download the binary release [here](https://github.com/dmarmor/osx-chrome-ssb-gui/releases "Download").

Also, a request: I'm not super thrilled with the name "MakeChromeSSB" so if you have any good ideas for a nice punchy name for the project, please open an [issue](https://github.com/dmarmor/osx-chrome-ssb-gui/issues/new "Issues") and let me know!

See [CHANGELOG.md](https://github.com/dmarmor/osx-chrome-ssb-gui/blob/master/CHANGELOG.md "CHANGELOG") for the latest changes.


## New in version 2.0

Lots of big and small changes in this version!

- SSBs will offer to optionally update themselves if they detect that a new version of MakeChromeSSB has been installed.
  - *Note for users of version 1.0.0: To get the new auto-update functionality, you'll need to use MakeChromeSSB 2.0.0 to re-create all your existing SSBs. Make sure to give the new app the exact same name as the old one to ensure that your profile information doesn't get lost (the simplest way to do that is just to navigate to the existing SSB in the first file selection dialog and overwrite it). Once you've recreated your SSBs, they will be able to auto-update themselves whenever you download future versions of MakeChromeSSB.*

- SSBs will automatically find Chrome if it's moved or renamed, and will update themselves when Chrome is updated to a new version.

- SSBs can now have a distinct "short name" (which appears in the menubar when the SSB is running) separate from the long app name (which appears in the Dock).

- Localization: SSBs now contain the full complement of language localizations that Chrome has. Whatever language you use Chrome in, the SSB will work in that language. (Sorry--MakeChromeSSB itself is only in English for now, but see Future Development.)

- Much more robust icon creation: can now take almost any TIFF, PNG or JPG file and will crop it to square and convert it to an ICNS.

- Multi-tab mode: SSBs can now either be the default "app-style" with no address bar, or the user can specify multiple tabs which will always be opened at startup. Alternately, SSBs can be tab-style with *no* tabs specified, in which case the SSB will simply act as an instance of Chrome, with its initial tabs determined by its preferences.  (Thanks to [mrmartineau](https://github.com/mrmartineau "mrmartineau") for suggesting this!)

- Register as browser: SSBs can now optionally register themselves with OSX as browsers, allowing links to be directed to them from other applications. (Thanks to [jschuster](https://github.com/jschuster "jschuster") for suggesting this!)

- Much more extensive AppleScript interface to handle all these new features (sorry for the long chain of modal dialog boxes--see Future Development for my plan to deal with this)


## Technical Information/Limitations

Built and tested on Mac OS X 10.10.3 with Chrome version 43.0.2357.124 (64-bit).

The Chrome profile for an SSB lives in: ${HOME}/Library/Application Support/Chrome SSB/<SSB Name>

It's not currently possible to "edit" an SSB. You'd need to create a new SSB with the same name as the old one. If you keep the name identical, then the new SSB will use the existing Chrome profile and you won't need to re-create your settings. Alternately, you can copy an existing profile folder to a new name to copy settings between SSBs.


## Issues

None known at this time, but this is a major rewrite of the entire engine and interface and it's gotten *much* more complicated than version 1, so things will almost certainly crop up. Please open an [issue](https://github.com/dmarmor/osx-chrome-ssb-gui/issues/new "Issues") for any bugs you find, or features you'd like to request and I'll get to them as soon as I can.

Once the kinks are worked out, this engine should be much more robust than the previous one in that SSBs will always use the latest version of Chrome and can self-update their own runtime engine when a new release of MakeChromeSSB is installed.


## Future Development

These are my thoughts on where to take the project next, roughly in order of priority. I'm not committed to any of these specifically, but would love to hear from people using MakeChromeSSB as to which, if any, of these would improve your experience. And, of course, do let me know if you have any other/better ideas for what to do next!

- Change the project from a standalone app to a Chrome extension. I'm not sure if this will actually be feasible, or if Google would frown on an extension of this type. But given that Chrome has to be installed anyway, it makes sense, and would have some big user interface advantages. SSBs could automatically be built using the frontmost tab, or using all the tabs of a window, and it would be easy for me to do away with the clumsy modal interface.

- Write a companion Chrome extension which would run inside SSBs and would redirect links (based on a customizable pattern) to open in the "real" instance of Chrome instead of inside the SSB. I've investigated this one and it should be feasible to do. (Thanks to [treyharris](https://github.com/treyharris "treyharris") for suggesting this!)

- Make the same companion extension also abuse the Chrome downloads list in order to generate a badge on the app's dock icon. This is a bit more of a long-shot, but it would be cool to have customizable access to the app badge in the same way Fluid apps do.

- Localize MakeChromeSSB so it can work in other languages. This probably won't happen until/unless I convert it to a Chrome extension. I haven't found an easy way to localize an AppleScript app.

- Add the ability to open an existing SSB and edit it. I'd probably also only do this once I'd converted the project to being a Chrome extension.

- Figure out some way to allow the user to customize where the SSB's Chrome profile is stored. Not sure if anybody would actually want this, so I'm not likely to do it unless I hear from people.

- Automatically make composite document icons using whichever icon the user selects as the main app icon. This is a super low-priority item and I may never get to it unless there's a real clamor for it. It does appear this could be done pretty simply by bundling [docerator](https://code.google.com/p/docerator/ "Docerator") in with MakeChromeSSB.


## Acknowledgements

- The underlying SSB-creation script make-chrome-ssb.sh was inspired by [chrome-ssb-osx](https://github.com/lhl/chrome-ssb-osx "chrome-ssb-osx") by [lhl](https://github.com/lhl "lhl")

- The icon-creation script makeicon.sh was inspired by Henry's comment on 12/20/2013 at 12:24 on this [StackOverflow thread](http://stackoverflow.com/questions/12306223/how-to-manually-create-icns-files-using-iconutil "StackOverflow thread")

- The idea for using an AppleScript interface came from a utility by Mait Vilbiks posted [here](https://www.lessannoyingcrm.com/blog/2011/01/240/Updates+to+Mac+Chrome+application+shortcuts+and+the+iOS+fullscreen+webapp+generator "Mait Vilbiks utility")
