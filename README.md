# Epichrome 2.2.0

**Epichrome** is made up of two parts: an AppleScript-based Mac application (*Epichrome.app*) and a companion Chrome extension (*Epichrome Helper*). *Epichrome.app* creates Chrome-based site-specific browsers (SSBs) for Mac OSX (Chrome must be installed in order to run them, but they are full Mac apps, each with its own separate Chrome profile).

Each app automatically installs *Epichrome Helper*, which uses rules to decide which links the app should handle itself, and which should be sent to the default web browser.

*Please glance through the notes on the latest version and the "Important Notes" section below.*

Download the binary release [here](https://github.com/dmarmor/epichrome/releases "Download").

See [CHANGELOG.md](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG") for the latest changes.


## New in version 2.2.0.

*Note: I'm only addressing serious bugs at the moment. I probably won't have time to work on new features or major updates for the foreseeable future.*

Version 2.2.0 changes Epichrome's underlying architecture significantly in order to allow it to work with Chrome 69, which has added much stricter security.

You shouldn't see much change in how your apps work, but there are a couple **important points** to be aware of:

- Epichrome apps are now explicitly *single-user* apps. Because of the way the Chrome engine is dynamically linked at runtime, Epichrome apps cannot be run by multiple users at once. They also cannot be run by users who don't have write permission to the app itself. For this reason, Epichrome no longer allows authentication during app creation. (This means, for instance, that if you don't have an admin account, you cannot create an Epichrome app in the /Applications folder.) The architecture may evolve in future releases, but Epichrome apps will almost certainly remain single-user from now on.

- If you're running Chrome 69 or later, your Epichrome apps must be installed on the *same* physical volume as Chrome, or the apps will at best take a very long time to start up, and at worst may not work at all.

- You should not try to copy or archive an Epichrome app while it is running. If you do, you may end up copying several hundred megabytes of data for no reason. When your apps are not running, they are under 3MB, but during runtime they may appear to be over 100MB. (Rest assured, a running Epichrome app is not actually taking up that much space on your hard drive--unless you try to copy it.)

This version also adds a "welcome" page that displays the first time you run a new app (or if you delete your profile), with instructions on how to enable Epichrome Helper, which Chrome disables by default.

See [CHANGELOG.md](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG") for more details.


## Important Notes

- Using the "Set Up Automatic Updates for All Users" option in Chrome could cause fatal errors in Epichrome apps when a Chrome update is applied. If your system contains the directory /Library/Google/GoogleSoftwareUpdate, then automatic updates are on. The surest way to disable it is by **first** deleting that directory (you'll need administrator privileges), then deleting Chrome and reinstalling the latest release from Google. In rare cases, you may also need to delete your user-specific directory at ~/Library/Google/GoogleSoftwareUpdate before running the reinstalled Chrome.

- Don't click the "Update Now" button on the About Chrome page in your Epichrome apps. It might not actually do anything terrible, but it also won't do anything good.

- It's a good idea to back up your Epichrome apps. You can right-click on an app in the Finder and select Compress. Then if anything goes wrong during an update, you can delete the app and double-click the zip archive to recreate it intact.


## Technical Information/Limitations

Built and tested on Mac OS X 10.13.6 with Chrome versions 68.0.3440.106 and XXXXX.

Apps built with Epichrome are self-updating. Apps will notice when Chrome has been updated and update themself. And if you install a new version of Epichrome.app on your system, the next time you run one of the apps, it will find the new version and update its own runtime engine.

The Chrome profile for an app lives in: ${HOME}/Library/Application Support/Epichrome/Apps/<app-id>

It's not currently easy to "edit" an app.

### Simple method

In order to change an app, you'll need to first make sure Spotlight indexing is on for the root volume. Delete the old app (and empty trash so it's completely gone), then create a new app with the *exact* same name as the old one. If you keep the name identical, the new app will end up with the same ID (this will *only* work if Spotlight indexing is on; otherwise Epichrome always tries to create a unique-looking ID). If all goes well, the new app will use the existing Chrome profile and you won't need to re-create your settings.

Alternately (or if you don't want Spotlight indexing on), you can always copy existing profile folders to a new name to copy settings between apps.

### Advanced method (change app URL)

*Warning: Only try this if you're comfortable editing shell scripts and understand what you're doing inside an app bundle. If you make a mistake with this method, it is possible to render your Epichrome app unusable.*

If you primarily want to change the URL, browse to the folder containing your app. Ctrl-click and choose *Show package contents*. Open /Contents > Resources > Scripts > config.sh/ in a text editor such as TextEdit or Atom. On the final line, you'll see something like:

```shell
SSBCommandLine=( --app=https://www.example.com )
```

Change the part after `--app` to your desired new destination. It is not recommended to change the entire app website unless you know what you're doing, but this is a good method to correct minor mistakes.


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
