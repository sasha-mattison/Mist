import Foundation

/// The merged view-model the UI renders: local install state combined with
/// Web API ownership/playtime data. A game may be present locally, remotely,
/// or both.
struct GameLibraryItem: Identifiable, Hashable {
    let appID: Int
    let name: String
    let isInstalled: Bool
    let sizeOnDisk: Int64
    let lastPlayed: Date?
    let playtimeForeverMinutes: Int
    let playtime2WeeksMinutes: Int
    let installDir: String?
    let libraryPath: String?
    /// Set for user-added non-Steam apps/games (see CustomApp) — nil for
    /// real Steam library items. Takes priority over the installDir/
    /// libraryPath pair in `installURL` when present.
    let customAppPath: URL?

    var id: Int { appID }

    var isCustom: Bool { customAppPath != nil }

    /// Path where the game's executable/bundle lives, used by
    /// RunningGameMonitor (M5) to detect the process. Only available for
    /// installed games.
    var installURL: URL? {
        if let customAppPath { return customAppPath }
        guard let libraryPath, let installDir else { return nil }
        return URL(fileURLWithPath: libraryPath)
            .appendingPathComponent("steamapps/common")
            .appendingPathComponent(installDir)
    }
}
