import Foundation

/// Reads a local Steam account's own captured screenshots straight off disk
/// — no network, no API key. Steam stores these under
/// `userdata/<accountID>/760/remote/<appid>/screenshots`, keyed by the
/// account's SteamID3 (a 32-bit id), not the SteamID64 used everywhere else
/// in the app.
enum LocalScreenshotService {
    /// Newest-first list of this app's screenshot files for the given
    /// SteamID64's local account. Empty if Steam isn't installed locally, the
    /// SteamID64 doesn't map to a local account, or no screenshots exist —
    /// all treated the same (nothing to show), not an error.
    static func screenshots(appID: Int, steamID64: String) -> [URL] {
        guard let steamRoot = SteamPathResolver.resolveSteamRoot(),
              let accountID = accountID(fromSteamID64: steamID64) else {
            return []
        }
        let dir = steamRoot
            .appendingPathComponent("userdata/\(accountID)/760/remote/\(appID)/screenshots")
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]
        return entries
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { modificationDate(of: $0) > modificationDate(of: $1) }
    }

    private static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// SteamID64 -> SteamID3, the account-relative id Steam names local
    /// userdata folders with. For individual accounts (universe 1, instance
    /// 1, type 1) SteamID64 = 76561197960265728 + accountID.
    private static let steamID64Base: UInt64 = 76_561_197_960_265_728

    static func accountID(fromSteamID64 steamID64: String) -> String? {
        guard let id64 = UInt64(steamID64), id64 > steamID64Base else { return nil }
        return String(id64 - steamID64Base)
    }
}
