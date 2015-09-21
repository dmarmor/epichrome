# Epichrome 2.1.6

**Note: If you're using 2.1.2, please update to 2.1.6 as soon as possible. There's a bug that will cause the app to fail silently on startup errors.**

**Epichrome** (formerly MakeChromeSSB) is made up of two parts: an AppleScript-based Mac application (*Epichrome.app*) and a companion Chrome extension (*Epichrome Helper*). *Epichrome.app* creates Chrome-based site-specific browsers (SSBs) for Mac OSX (Chrome must be installed in order to run them, but they are full Mac apps, each with its own separate Chrome profile).

Each app automatically installs *Epichrome Helper*, which uses rules to decide which links the app should handle itself, and which should be sent to the default web browser.

Download the binary release [here](https://github.com/dmarmor/osx-chrome-ssb-gui/releases "Download").

See [CHANGELOG.md](https://github.com/dmarmor/osx-chrome-ssb-gui/blob/master/CHANGELOG.md "CHANGELOG") for the latest changes.


## New in version 2.1.6.

Epichrome should now do its best to run robustly even when Spotlight indexing is turned off. Note that if you do have Spotlight indexing off, your Epichrome apps will *not* update themselves automatically (because they can't find Epichrome without Spotlight).

*Important:* You'll need to turn Spotlight on temporarily and run each of your apps to get them to update to 2.1.6 (previous versions won't recognize there's a new version installed without Spotlight). Starting with version 2.1.6, your apps will automatically update, but *only if* Epichrome is installed exactly in: /Applications/Epichrome.app.


## New in version 2.1

(The main change in this release is the addition of *Epichrome Helper*.)

- Apps now automatically install *Epichrome Helper*, a companion Chrome extension that handles link redirection so each app can have rules for which links it handles itself and which should be sent to the default browser. Rules are set up on the extension's options page, available from the Chrome extensions page. It should pop up a welcome message when first installed. (Thanks to [treyharris](https://github.com/treyharris "treyharris") for first bringing up the idea, and to [phillip-r](https://github.com/phillip-r "phillip-r") and [cbeams](https://github.com/cbeams "cbeams") for more thoughts on how it might work.)
- Profile directories have moved to ${HOME}/Library/Application Support/Epichrome/Apps/<app-id>. Existing profile directories will be automatically migrated when each app is updated.
- Renamed the project Epichrome, mostly because I found MakeChromeSSB very annoying to say and write.


## Technical Information/Limitations

Built and tested on Mac OS X 10.10.5 with Chrome version 45.0.2454.93 (64-bit).

Apps built with Epichrome are self-updating. Apps will notice when Chrome has been updated and update themself. And if you install a new version of Epichrome.app on your system, the next time you run one of the apps, it will find the new version and update its own runtime engine.

The Chrome profile for an app lives in: ${HOME}/Library/Application Support/Epichrome/Apps/<app-id>

It's not currently possible to "edit" an app. In order to change an app, you'll need to first make sure Spotlight indexing is on for the root volume. Delete the old app (and empty trash so it's completely gone), then create a new app with the *exact* same name as the old one. If you keep the name identical, the new app will end up with the same ID (this will *only* work if Spotlight indexing is on; otherwise Epichrome always tries to create a unique-looking ID). If all goes well, the new app will use the existing Chrome profile and you won't need to re-create your settings.

Alternately (or if you don't want Spotlight indexing on), you can always copy existing profile folders to a new name to copy settings between apps.


## Issues

On certain webside, buttons (or other non-<A> tag items) open links. The way Chrome handles these, the helper extension doesn't currently catch them, so can't redirect them. I'm looking at ways around this, but for now such links just open in the Epichrome app. If you're experiencing this, there's an [open issue](https://github.com/dmarmor/epichrome/issues/27 "Gmail shortcut links aren't delegated #27") where you can add your input.

If you notice any other bugs, or have feature requests, please open a [new issue](https://github.com/dmarmor/osx-chrome-ssb-gui/issues/new "New Issue"). I'll get to them as soon as I can.


## Future Development

These are my thoughts on where to take the project next, roughly in order of priority. I'm not committed to any of these specifically, but would love to hear from people using Epichrome as to which, if any, of these would improve your experience. And, of course, do let me know if you have any other/better ideas for what to do next!

- Change *Epichrome.app* from a standalone app to a Chrome extension. I'm not sure if Google would frown on an extension of this type, but given that Chrome has to be installed for Epichrome to work, it makes sense, and would have some big user interface advantages. SSBs could automatically be built using the frontmost tab, or using all the tabs of a window, and I could finally away with the clumsy modal interface.

- Figure out some way to get the apps to show a badge on the dock icon. I tried abusing Chrome's download system, but that didn't work. This is a bit of a long-shot, but it would be cool to have customizable access to the app badge in the same way Fluid apps do.

- Localize Epichrome so it can be used easily in other languages. This probably won't happen until/unless I convert it to a Chrome extension. I haven't found an easy way to localize an AppleScript app.

- Add the ability to open an existing app and edit it. I'd probably also only do this once I'd converted the project to being a Chrome extension.

- Figure out some way to allow the user to customize where the app's Chrome profile is stored. Not sure if anybody would actually want this, so I'm not likely to do it unless I hear from people.

- Automatically make composite document icons using whichever icon the user selects as the main app icon. This is a super low-priority item and I may never get to it unless there's a real clamor for it. It does appear this could be done pretty simply by bundling [docerator](https://code.google.com/p/docerator/ "Docerator") in with Epichrome.


## Acknowledgements

- The underlying SSB-creation and runtime engines were inspired by [chrome-ssb-osx](https://github.com/lhl/chrome-ssb-osx "chrome-ssb-osx") by [lhl](https://github.com/lhl "lhl")

- The icon-creation script makeicon.sh was inspired by Henry's comment on 12/20/2013 at 12:24 on this [StackOverflow thread](http://stackoverflow.com/questions/12306223/how-to-manually-create-icns-files-using-iconutil "StackOverflow thread")

- The idea for using an AppleScript interface came from a utility by Mait Vilbiks posted [here](https://www.lessannoyingcrm.com/blog/2011/01/240/Updates+to+Mac+Chrome+application+shortcuts+and+the+iOS+fullscreen+webapp+generator "Mait Vilbiks utility")

- *Epichrome Helper* uses [jQuery](https://jquery.com/ "jQuery") and [jQuery UI](http://jqueryui.com/ "jQuery UI") in its options page.

- The javascript for *Epichrome Helper* is compressed using [UglifyJS2](https://github.com/mishoo/UglifyJS2 "UglifyJS2"), installed under [node.js](https://nodejs.org/ "node.js").

- The app and extension icons are based on this [image](http://www.dreamstime.com/royalty-free-stock-images-abstract-chrome-ball-image19584489 "Abstract Chrome Ball Photo"), purchased from [dreamstime.com](http://www.dreamstime.com/#res11199095 "dreamstime.com"). ID 19584489 (c) Alexandr Mitiuc [(Alexmit)](http://www.dreamstime.com/alexmit_info#res11199095 "Alexmit").
