# Epichrome version (#.#.#[#] = release version, #.#.#b#[#] = beta)

epiVersion=2.4.0b4
epiBuildNum=60
epiDesc='   ▪️ Progress bars now appear when creating and updating apps and their engines, as well as while parsing browser extensions
   ▪️ The login scan can now be enabled and disabled from within Epichrome
   
   ▪️ Improved reliability of launching newly-created and updated apps

   ▪️ Reorganized and cleaned up the app welcome page

   ▪️ Improved browser extension parsing and added a cache to improve startup time for new apps

   ▪️ Added a button to open an issue on GitHub when an app or Epichrome aborts due to error

   ▪️ Fixed a problem where Chrome-engine apps would show "Chrome" as their menubar name

   ▪️ Updated built-in engine to Brave 1.16.68

   ▪️ And many more small fixes and improvements...'
# epiDescMajor=( \
#         'Epichrome apps can now be edited by dropping them on Epichrome.app!' \
#         'Added advanced settings during app creation and editing to control how the app handles updates, and to customize its ID' \
#         'New unified app engine architecture for better compatibility with the dock, notifications, and other system services' \
#         'Added two new apps, "Epichrome Scan.app" and "Epichrome Login.app" to restore apps left in an unlaunchable state after a crash' \
#         'Checking GitHub for updates is now unified across all apps and Epichrome itself, so when a new update is found, you will only receive one notification' \
#         'Many more improvements and bug fixes (see change log on GitHub for details)' )
   # Apps are now automatically backed up whenever they are edited or updated (in the Backups subfolder of the app's data directory)
   #
   # ▪️ Fixed a problem that could cause apps to register as a browser after update even though they were created not to (existing apps that should not be registered browsers will need to be edited once to reset that setting)
   #
   # ▪️ Updated built-in engine to Brave 1.13.86
