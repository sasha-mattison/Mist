import Foundation

enum SteamPathResolver {
    /// Steam's local data root on macOS. Not a TCC-protected location, so a
    /// non-sandboxed app can read it without any entitlement or user prompt.
    static func resolveSteamRoot() -> URL? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Steam")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return root
    }
}
