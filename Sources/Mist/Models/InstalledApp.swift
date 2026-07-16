import Foundation

/// A game installed locally, parsed from an appmanifest_<appid>.acf file.
///
/// Note: the manifest's `StateFlags` field is not a reliable "currently
/// running" signal (confirmed empirically: it stays "4" while the game's
/// process is actually running) — running state must come from
/// RunningGameMonitor instead.
struct InstalledApp: Identifiable, Hashable {
    let appID: Int
    let name: String
    let installDir: String
    let sizeOnDisk: Int64
    let lastPlayed: Date?
    let libraryPath: String
    /// Steam's content-build identifier, bumped every time the game is
    /// updated — used to detect "this game was just updated" by diffing
    /// across refreshes, not for anything else.
    let buildID: String?

    var id: Int { appID }

    var installURL: URL {
        URL(fileURLWithPath: libraryPath)
            .appendingPathComponent("steamapps/common")
            .appendingPathComponent(installDir)
    }
}
