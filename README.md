<h1><img src="https://github.com/dmarmor/epichrome/raw/master/images/readme/epichrome_icon.png" width="64" height="64" alt="Epichrome icon" /> Epichrome <span id="epiversion">2.4.25</span></h1>

## IMPORTANT NOTE

***I'm sad to announce I'm ending development of Epichrome.***

After more than five years of development, I no longer have time to do the major work that will be needed to keep Epichrome working with coming changes to macOS and the Chrome extension ecosystem.

I will continue doing updates to stay current with the Brave browser engine until the end of 2021. If you rely on Epichrome for your workflow, you should begin looking for an alternative as soon as possible to minimize disruption. There are many options out there, each with their own pros and cons, including [Chromeless](https://chromeless.app/ "Chromeless"), [WebCatalog](https://webcatalog.app/ "WebCatalog"), [Flotato](https://www.flotato.com/ "Flotato"), [Unite](https://www.bzgapps.com/unite "Unite"), and [Coherence](https://www.bzgapps.com/coherence "Coherence").

If you are a developer with the skills and interest to continue this project, please [contact me](mailto:info@epichrome.org). I would love to find a good home for Epichrome.

## Overview

Epichrome lets you create web-based Mac applications compatible with the full range of extensions available in the Chrome Web Store. It includes an extension to route links to your default browser.

Download the latest release **[here](https://github.com/dmarmor/epichrome/releases "Download")**, and please check out the important notes below. If you find a bug or have a feature request, please submit it **[here](https://github.com/dmarmor/epichrome/issues "Issues")**.


## Epichrome Supporters

Epichrome is open source and has been a labor of love, made possible by the generosity of our Patreon patrons. I can't thank you all enough!

<h4 align="center"><ins>Rock Star Patrons</ins></h4>
<b>
<table align="center">
<tr>
<td align="center" width="33%">Alan Latteri</td>
<td align="center" width="33%">Lyle Barrere</td>
<td align="center" width="33%">Jonathan Berger</td>
</tr>
<td align="center">Andrew Bonham</td>
<td align="center">Buck Doyle</td>
<td align="center">Lev Dubinets</td>
</tr>		
<tr>
<td align="center">Matt Fallshaw</td>
<td align="center">Lanny Heidbreder</td>
<td align="center">Eric Henderson</td>
</tr>		
<tr>
<td align="center">Scott Irwin</td>
<td align="center">Ben Johnson</td>
<td align="center">David Mankin</td>
</tr>
<tr>
<td align="center">Gregory Morse</td>
<td align="center">Alex Nauda</td>
<td align="center">Alan Ogilvie</td>
</tr>
<tr>
<td align="center">Rob Page</td>
<td align="center">Jeff Poulton</td>
<td align="center">Scott Richins</td>
</tr>
<tr>
<td align="center">Matthew Scott</td>
<td align="center">André Srinivasan</td>
<td align="center">Samuel Talleux</td>
</tr>
<tr>
<td align="center">Adam Tarnoff</td>
<td align="center">Thorbergsson</td>
<td align="center">hellot vincent</td>
</tr>
</table>
</b>


<!-- CHANGES_START -->
## New in version <span id="epiversion">2.4.25</span>

- Built-in engine updated to Brave 1.32.113


*Check out the [**change log**](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG.md") for the full list.*
<!-- CHANGES_END -->


## New in version 2.4

- Apps are now fully compatible with macOS 11 Big Sur and run natively on Apple Silicon

- Epichrome apps can now be edited by dropping them on Epichrome.app!

- Major update to icons, including automatic downloading of icons based on an app's URL, icon preview during the creation process, and an interface for creating Big Sur-compatible icons

- Added advanced settings during app creation and editing to control how apps handle updates, and to customize their IDs

- New unified app engine architecture for better compatibility with the dock, notifications, and other system services

- Apps are now automatically backed up whenever they're edited or updated (in the Backups subfolder of the app's data directory)

- Progress bars now appear during lengthy operations such as updating an app

- Added a login scan to restore apps left in an unlaunchable state after a crash, and *Epichrome Scan.app* to do the same manually

- Checking GitHub for updates is now unified across all apps so when a new update is found, you will only receive one notification, which will display info on changes in the new version

- Both the GitHub update notification and the app update prompt now show info on changes in the new version

- Many more improvements and bug fixes... (See [**change log**](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md#240---2021-03-19 "CHANGELOG.md") for details)


## Important Notes

- Do not use the "Automatically update Chrome for all users" option on Chrome's About page if you have any apps with the external Chrome engine (this includes *all* apps updated from earlier versions of Epichrome). This option will cause fatal errors in your apps. If your system contains the directory ```/Library/Google/GoogleSoftwareUpdate```, then automatic updates are on. The surest way to disable it is by *first* deleting that directory (you'll need administrator privileges), then deleting Chrome and reinstalling the latest release from Google. In rare cases, you may also need to delete your user-specific directory at ```~/Library/Google/GoogleSoftwareUpdate``` before running the reinstalled Chrome.

- Don't click the "Update Now" button on the About Chrome page in your Epichrome apps. It might not actually do anything terrible, but it also won't do anything good.

- It's a good idea to back up your Epichrome apps. You can right-click on an app in the Finder and select Compress. Then if anything goes wrong during an update, you can delete the app and double-click the zip archive to recreate it intact.

- It's also a good idea to periodically backup your apps' data. You can do this the same way as backing up the apps. The path to an app's data is ```~/Library/Application Support/Epichrome/Apps/<AppID>```. In most cases, ```AppID``` will be a short version of the app's name, possible with a 3-digit number at the end (e.g. ```Gmail384```).


## Troubleshooting

If you're having trouble with an Epichrome app, please first check the [**troubleshooting guide**](https://github.com/dmarmor/epichrome/blob/master/TROUBLESHOOTING.md "troubleshooting guide").


## Technical Information & Limitations

- Built and tested on macOS <span id="osname">Big Sur</span> <span id="osversion">11.6.1</span> and Google Chrome version <span id="chromeversion">96.0.4664.55</span>.

- Apps built with Epichrome are self-updating. If you install a new version of Epichrome on your system, the next time you run one of your apps, it will find the new version and ask if you want to update it.

- Apps can be edited by dropping them on Epichrome.app, or by running Epichrome.app and clicking the *Edit* button in the first dialog.

- On certain websites, buttons (or other non-\<A\> tag items) open links. The way Chrome handles these, the helper extension doesn't currently catch them, so can't redirect them. I'm looking at ways around this, but for now such links just open in the app. If you're experiencing this, there's an [issue](https://github.com/dmarmor/epichrome/issues/27 "Gmail shortcut links aren't delegated #27") where you can add your input.


## Acknowledgements

- The underlying SSB-creation and runtime engine were inspired by [chrome-ssb-osx](https://github.com/lhl/chrome-ssb-osx "chrome-ssb-osx") by [lhl](https://github.com/lhl "lhl").

- The built-in app engine is based on the open source [Brave Browser](https://github.com/brave/brave-browser "Brave Browser"), which is itself based on [Chromium](https://www.chromium.org/Home "Chromium").

- Epichrome apps are built using [Platypus](https://sveinbjorn.org/platypus "Platypus") (also on [GitHub](https://github.com/sveinbjornt/Platypus "Platypus on GitHub")) by [sveinbjornt](https://github.com/sveinbjornt "sveinbjornt").

- The icon-creation script makeicon.sh was inspired by Henry's comment on 12/20/2013 at 12:24 on this [StackOverflow thread](http://stackoverflow.com/questions/12306223/how-to-manually-create-icns-files-using-iconutil "StackOverflow thread").

- The idea for using an AppleScript interface came from a utility by Mait Vilbiks posted [here](https://www.lessannoyingcrm.com/blog/2011/01/240/Updates+to+Mac+Chrome+application+shortcuts+and+the+iOS+fullscreen+webapp+generator "Mait Vilbiks utility").

- *Epichrome Helper* uses [jQuery](https://jquery.com/ "jQuery") and [jQuery UI](http://jqueryui.com/ "jQuery UI") in its options page.

- The javascript for *Epichrome Helper* is compressed using [UglifyJS2](https://github.com/mishoo/UglifyJS2 "UglifyJS2"), installed under [node.js](https://nodejs.org/ "node.js").

- The app and extension icons are based on this [image](http://www.dreamstime.com/royalty-free-stock-images-abstract-chrome-ball-image19584489 "Abstract Chrome Ball Photo"), purchased from [dreamstime.com](http://www.dreamstime.com/#res11199095 "dreamstime.com"). ID 19584489 (c) Alexandr Mitiuc [(Alexmit)](http://www.dreamstime.com/alexmit_info#res11199095 "Alexmit").
