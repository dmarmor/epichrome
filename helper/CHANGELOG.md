# Epichrome Helper Change Log
This project adheres to [Semantic Versioning](http://semver.org/).

## [1.1.0] - 2015-07-
### Changed
- Added the ability to switch an app-style window to a tab-style window and back with a hotkey or context menu.
- Added option to stop click propagation when a click is redirected (some websites seem to do funky JavaScript stuff that requires this so we don't get a duplicate navigation in the SSB).
- Changed options page to size dynamically so it'll be easier to add fields in the future.
- Added "Unsaved changes" status message to options box.
- Extension now retrieves name of SSB from native host and applies it as the default name when exporting options.
### Fixed
- Removed unnecessary permissions from the manifest.
- Fixed off-by-one error in month in default filename when exporting options.

### Fixed

## [1.0.1] - 2015-07-15
### Changed
- Changed default options so that on initial install, incoming links won't be sent to the main window.

## [1.0.0] - 2015-07-15
- First version of *Epichrome Helper*, a companion Chrome extension that handles link redirection so each app can have rules for which links it handles itself and which should be sent to the default browser. (Thanks to [treyharris](https://github.com/treyharris "treyharris") for first bringing up the idea, and to [phillip-r](https://github.com/phillip-r "phillip-r") and [cbeams](https://github.com/cbeams "cbeams") for more thoughts on how it might work.)
