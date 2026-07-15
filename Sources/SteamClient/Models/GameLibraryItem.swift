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

    var id: Int { appID }

    /// Path where the game's executable/bundle lives, used by
    /// RunningGameMonitor (M5) to detect the process. Only available for
    /// installed games.
    var installURL: URL? {
        guard let libraryPath, let installDir else { return nil }
        return URL(fileURLWithPath: libraryPath)
            .appendingPathComponent("steamapps/common")
            .appendingPathComponent(installDir)
    }
}
