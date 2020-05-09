# Epichrome 2.3.0

## Overview

Epichrome lets you create web-based Mac applications compatible with the full range of extensions available in the Chrome Web Store. It includes an extension to route links to your default browser.

Download the latest release **[here](https://github.com/dmarmor/epichrome/releases "Download")**, and please check out the important notes below. If you find a bug or have a feature request, please submit it **[here](https://github.com/dmarmor/epichrome/issues "Issues")**.


## How To Support Epichrome

<div id="patreon" class="patreon">
  <div style="display: flex; align-items: center;">
    <svg style="width: 140px" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 3200 1260" style="enable-background:new 0 0 3200 1260;" xml:space="preserve" class="patreon_logo">
      <g>
        <g>
          <rect x="3021.2" y="95.9" class="st0" width="78.4" height="1068.6"/>
        </g>
        <g>
          <path class="st0" d="M99.6,452.1h141.8c75,0,123.4,56.6,123.4,122.4s-48.4,122.4-123.4,122.4H178v93.9H99.6V452.1z M286,574.5 c0-31.5-21.3-58.6-54.2-58.6H178v117.1h53.7C264.7,633.1,286,606,286,574.5z"/>
          <path class="st0" d="M664.9,790.8l-13.1-41.1H531.3l-13.1,41.1h-83.7l121-338.8h72.1l122.4,338.8H664.9z M591.8,548.9l-41.6,139.4 h82.3L591.8,548.9z"/>
          <path class="st0" d="M881.7,519.8h-76.4v-67.7H1037v67.7h-77v271h-78.4V519.8z"/>
          <path class="st0" d="M1159,452.1h142.3c75,0,123.4,56.6,123.4,122.4c0,47.4-25.2,89.5-67.3,109.4l67.8,106.9h-91l-60-93.9h-36.8 v93.9H1159V452.1z M1345.3,574.5c0-31.5-21.3-58.6-54.2-58.6h-53.7v117.1h53.7C1324,633.1,1345.3,606,1345.3,574.5z"/>
          <path class="st0" d="M1636.2,515v76.9h128.2v61.5h-128.2v74.5h128.2v62.9h-206.6V452.1h206.6V515H1636.2z"/>
          <path class="st0" d="M1891.7,621.5c0-92.9,66.8-178.1,179.6-178.1c112.3,0,179.1,85.2,179.1,178.1s-66.8,178.1-179.1,178.1 C1958.5,799.6,1891.7,714.4,1891.7,621.5z M2170.5,621.5c0-55.7-37.8-107.4-99.2-107.4c-61.9,0-99.2,51.8-99.2,107.4 c0,55.7,37.3,107.4,99.2,107.4C2132.7,728.9,2170.5,677.1,2170.5,621.5z"/>
          <path class="st0" d="M2584.7,672.8V452.1h77.9v338.8h-81.8l-122-217.8v217.8h-78.4V452.1h81.8L2584.7,672.8z"/>
        </g>
      </g>
    </svg>
    <img style="width: 48px" src="https://github.com/dmarmor/epichrome/raw/master/images/webstore/webstore_icon.png" alt="Epichrome icon" />
  </div>
  <p class="patreon_msg">Epichrome is open source and a labor of love, made possible by the generosity of our Patreon patrons. If you find it useful, please consider supporting its continued development by joining them!</p>
  <a href="https://www.patreon.com/bePatron?u=27108162" style="display:inline-flex;
    justify-content:center;
    align-items:center;
    color:rgb(255, 255, 255);
    font-family:aktiv-grotesk, sans-serif;
    font-size:14px;
    font-weight:500;
    height:34px;
    width:176px;
    background-color:rgb(232, 91, 70);
    border-bottom-left-radius:9999px;
    border-bottom-right-radius:9999px;
    border-top-left-radius:9999px;
    border-top-right-radius:9999px;
    box-sizing:border-box;
    cursor:pointer;" target="_blank">
    <svg style="width: 24px;
      height: 24px;
      padding-right: 8px;" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 569 546" style="enable-background:new 0 0 569 546;" xml:space="preserve">
      <g>
        <circle id="Oval" style="fill:#FFFFFF;" cx="362.6" cy="204.6" r="204.6"/>
        <rect id="Rectangle" style="fill:#FFFFFF;" width="100" height="545.8"/>
      </g>
    </svg>
    Become a Patron!</a>
      <h5 style="text-decoration: underline;">Rock Star Patrons</h5>
      <ul style="list-style-type: none;
        font-weight: bold;">
        <li>Alan Latteri</li>
        <li>Lyle Barrere</li>
        <li>Jonathan Berger</li>
        <li>Andrew Bonham</li>
        <li>Lev Dubinets</li>
        <li>Matt Fallshaw</li>
        <li>Lanny Heidbreder</li>
        <li>Eric Henderson</li>
        <li>Ben Johnson</li>
        <li>Gregory Morse</li>
        <li>Alex Nauda</li>
        <li>Orbital Impact</li>
        <li>Matthew Scott</li>
        <li>Samuel Talleux</li>
      </ul>
  </div> <!-- #patreon -->


## New in version 2.3.0

- Epichrome has been completely rewritten for full compatibility with macOS 10.15 Catalina, including accessing the system microphone and camera from within apps and interacting with AppleScript.

- A new built-in engine has been added, using the Chrome-compatible open source [Brave Browser](https://github.com/brave/brave-browser "Brave Browser") to allow more app-like behavior including better link-routing and custom icons on desktop notifications.

- The welcome page that appears when apps are created or updated now gives useful contextual information and prompts for important actions like (re)installing extensions.

<!-- ## New in version 2.3 -->

*Check out the [change log](https://github.com/dmarmor/epichrome/blob/master/app/CHANGELOG.md "CHANGELOG.md") for more details.*


## Important Notes

- Do not use the "Set Up Automatic Updates for All Users" option in Chrome if you have any apps with the external Chrome engine (this includes *all* apps updated from earlier versions of Epichrome). This option will cause fatal errors in your apps. If your system contains the directory ```/Library/Google/GoogleSoftwareUpdate```, then automatic updates are on. The surest way to disable it is by *first* deleting that directory (you'll need administrator privileges), then deleting Chrome and reinstalling the latest release from Google. In rare cases, you may also need to delete your user-specific directory at ```~/Library/Google/GoogleSoftwareUpdate``` before running the reinstalled Chrome.

- Don't click the "Update Now" button on the About Chrome page in your Epichrome apps. It might not actually do anything terrible, but it also won't do anything good.

- It's a good idea to back up your Epichrome apps. You can right-click on an app in the Finder and select Compress. Then if anything goes wrong during an update, you can delete the app and double-click the zip archive to recreate it intact.

- It's also a good idea to periodically backup your apps' data. You can do this the same way as backing up the apps. The path to an app's data is ```~/Library/Application Support/Epichrome/Apps/<AppID>```. In most cases, ```AppID``` will be a short version of the app's name, possible with a 3-digit number at the end (e.g. ```Gmail384```).


## Technical Information & Limitations

- Built and tested on macOS Catalina 10.15.4 and Google Chrome version 81.0.4044.138.

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
