<h1><img src="https://github.com/dmarmor/epichrome/raw/master/images/readme/epichrome_icon.png" width="64" height="64" alt="Epichrome icon" /> Epichrome 2.3.14</h1>

## Overview

Epichrome lets you create web-based Mac applications compatible with the full range of extensions available in the Chrome Web Store. It includes an extension to route links to your default browser.

Download the latest release **[here](https://github.com/dmarmor/epichrome/releases "Download")**, and please check out the important notes below. If you find a bug or have a feature request, please submit it **[here](https://github.com/dmarmor/epichrome/issues "Issues")**.


## How To Support Epichrome

<p align="center"><a href="https://www.patreon.com/bePatron?u=27108162" target="_blank"><img src="https://github.com/dmarmor/epichrome/blob/master/images/readme/patreon_button.svg" width="176" height="35" alt="Become a patron"/></a></p>

Epichrome is open source and a labor of love, made possible by the generosity of our Patreon patrons. If you find it useful, please consider supporting its continued development by joining them!

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
<td align="center">Ben Johnson</td>
<td align="center">David Mankin</td>
<td align="center">Gregory Morse</td>
</tr>
<tr>
<td align="center">Alex Nauda</td>
<td align="center">Alan Ogilvie</td>
<td align="center">Rob Page</td>
</tr>
<tr>
<td align="center">Matthew Scott</td>
<td align="center">Samuel Talleux</td>
<td align="center">Adam Tarnoff</td>
</tr>
<tr>
<td align="center" colspan="3">Thorbergsson</td>
</tr>
</table>
</b>


## New in version 2.3.14

- The built-in engine has been updated to Brave 1.15.76.


*Check out the [**change log**](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG.md") for the full list.*


## New in version 2.3

- Epichrome has been completely rewritten for full compatibility with macOS 10.15 Catalina, including accessing the system microphone and camera from within apps and interacting with AppleScript.

- A new built-in engine has been added, using the Chrome-compatible open source [Brave Browser](https://github.com/brave/brave-browser "Brave Browser") to allow more app-like behavior including better link-routing and custom icons on desktop notifications.

- The welcome page that appears when apps are created or updated now gives useful contextual information and prompts for important actions like (re)installing extensions.

<!-- ## New in version 2.3 -->


## Important Notes

- Do not use the "Automatically update Chrome for all users" option on Chrome's About page if you have any apps with the external Chrome engine (this includes *all* apps updated from earlier versions of Epichrome). This option will cause fatal errors in your apps. If your system contains the directory ```/Library/Google/GoogleSoftwareUpdate```, then automatic updates are on. The surest way to disable it is by *first* deleting that directory (you'll need administrator privileges), then deleting Chrome and reinstalling the latest release from Google. In rare cases, you may also need to delete your user-specific directory at ```~/Library/Google/GoogleSoftwareUpdate``` before running the reinstalled Chrome.

- Don't click the "Update Now" button on the About Chrome page in your Epichrome apps. It might not actually do anything terrible, but it also won't do anything good.

- It's a good idea to back up your Epichrome apps. You can right-click on an app in the Finder and select Compress. Then if anything goes wrong during an update, you can delete the app and double-click the zip archive to recreate it intact.

- It's also a good idea to periodically backup your apps' data. You can do this the same way as backing up the apps. The path to an app's data is ```~/Library/Application Support/Epichrome/Apps/<AppID>```. In most cases, ```AppID``` will be a short version of the app's name, possible with a 3-digit number at the end (e.g. ```Gmail384```).


## Troubleshooting

If you're having trouble with an Epichrome app, please first check the [**troubleshooting guide**](https://github.com/dmarmor/epichrome/blob/master/TROUBLESHOOTING.md "troubleshooting guide").

## Technical Information & Limitations

- Built and tested on macOS Catalina 10.15.7 and Google Chrome version 86.0.4240.111.

- Apps built with Epichrome are self-updating. If you install a new version of Epichrome on your system, the next time you run one of your apps, it will find the new version and ask if you want to update it.

- It's not currently possible to "edit" an app. The simplest solution right now is to simply delete the app and create a new one with whatever changes you want. If you want, you can then move the old app's browser settings to the new app's data directory.

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
