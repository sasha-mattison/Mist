import AppKit
import Foundation

enum GameLaunchService {
    /// `rungameid` is Valve's modern canonical launch form (skips extra
    /// dialogs for already-installed games); `run` is an older but still-
    /// functional alias, tried as a fallback. LaunchServices cold-launches
    /// Steam automatically via the registered steam:// URL scheme if it
    /// isn't already running.
    static func launch(appID: Int) {
        if let primary = URL(string: "steam://rungameid/\(appID)") {
            NSWorkspace.shared.open(primary)
        } else if let fallback = URL(string: "steam://run/\(appID)") {
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Opens Steam's install flow for an owned-but-not-installed title.
    static func install(appID: Int) {
        guard let url = URL(string: "steam://install/\(appID)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openSteam() {
        guard let url = URL(string: "steam://open/main") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openStorePage(appID: Int) {
        guard let url = URL(string: "https://store.steampowered.com/app/\(appID)/") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the app's store page inside the Steam client — the only place a
    /// purchase can actually be completed.
    static func openStoreInSteam(appID: Int) {
        guard let url = URL(string: "steam://store/\(appID)") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Opens the game's Steam Community hub (discussions, guides, artwork)
    /// in the browser.
    static func openCommunityHub(appID: Int) {
        guard let url = URL(string: "https://steamcommunity.com/app/\(appID)/") else { return }
        NSWorkspace.shared.open(url)
    }

    static func openChat(steamID64: String) {
        guard let url = URL(string: "steam://friends/message/\(steamID64)") else { return }
        NSWorkspace.shared.open(url)
    }
}
