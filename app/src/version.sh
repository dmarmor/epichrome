# Epichrome version (#.#.# = release version, #.#.#b# = beta)

epiVersion=2.4.0b1
epiBuildNum=117
epiDesc="🚀 MAJOR UPDATE!

   ▪️ Added ability to edit existing Epichrome apps
   
   ▪️ Added an advanced option during app creation and editing to customize the app's ID
   
   ▪️ Updated built-in engine to Brave 1.XX.XX
   
   ▪️ Apps are now automatically backed up whenever they are edited or updated (in the Backups subfolder of the app's data directory)
 
   ▪️ Fixed a problem that could cause apps to register as a browser after update even though they were created not to (existing apps that should not be registered browsers will need to be edited once to reset that setting)"

mcssbVersion="${epiVersion%[*}"  # backward compatibility
