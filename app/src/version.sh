# Epichrome version (#.#.#[#] = release version, #.#.#b#[#] = beta)

epiVersion=2.4.3
epiBuildNum=5
epiMinorChangeList=( \
        'Improved auto icon downloading to be compatible with more sites' \
        'Added advanced setting to allow app browser data to be backed up on update or edit' \
        'Added version information to package' \
        'Changed schedule to check GitHub for new versions every other day instead of once a week' \
        'Added version numbers to GitHub error reporting' \
    )  # END_epiMinorChangeList
epiMinorFixList=()  # END_epiMinorFixList
epiDescMajor=( \
        'Apps are now fully compatible with macOS 11 Big Sur and run natively on Apple Silicon' \
        'Epichrome apps can now be edited by dropping them on Epichrome.app!' \
        "Major update to icons, including automatic downloading of icons based on an app's URL, icon preview during the creation process, and an interface for creating Big Sur-compatible icons" \
        'Added advanced settings during app creation and editing to control how apps handle updates, and to customize their IDs' \
        'New unified app engine architecture for better compatibility with the dock, notifications, and other system services' \
        "Apps are now automatically backed up whenever they're edited or updated (in the Backups subfolder of the app's data directory)" \
        'Progress bars now appear during lengthy operations such as updating an app' \
        'Added a login scan to restore apps left in an unlaunchable state after a crash, and "Epichrome Scan.app" to do the same manually' \
        'Checking GitHub for updates is now unified across all apps so when a new update is found, you will only receive one notification, which will display info on changes in the new version' \
        'Both the GitHub update notification and the app update prompt now show info on changes in the new version' \
        'Many more improvements and bug fixes... (See change log on GitHub for details)' \
    )
epiDesc=( "${epiMinorChangeList[@]}" "${epiMinorFixList[@]}" )  # backward compatibility with 2.4.0
