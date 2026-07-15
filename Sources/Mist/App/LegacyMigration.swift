import Foundation

/// One-time carry-over from the app's pre-rename identity ("SteamClient",
/// bundle id dev.sasha.SteamClient). UserDefaults are keyed by bundle id, so
/// the rename would otherwise drop the sign-in and appearance settings; the
/// caches directory is moved so artwork and Mac-support verdicts survive too.
/// Must run before any store reads UserDefaults (see MistApp.init).
enum LegacyMigration {
    private static let migratedKey = "migratedFromSteamClient"
    private static let legacyDomain = "dev.sasha.SteamClient"
    private static let defaultsKeys = [
        "signedInSteamID64",
        "settings.appearance",
        "settings.accentPreset",
        "settings.useCustomAccent",
        "settings.customAccentRGBA",
        "settings.tintedBackground",
        "settings.animationsEnabled"
    ]

    static func migrateIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)

        if let legacy = UserDefaults(suiteName: legacyDomain) {
            for key in defaultsKeys where defaults.object(forKey: key) == nil {
                if let value = legacy.object(forKey: key) {
                    defaults.set(value, forKey: key)
                }
            }
        }

        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let oldDir = caches.appendingPathComponent("SteamClient", isDirectory: true)
            let newDir = caches.appendingPathComponent("Mist", isDirectory: true)
            if FileManager.default.fileExists(atPath: oldDir.path),
               !FileManager.default.fileExists(atPath: newDir.path) {
                try? FileManager.default.moveItem(at: oldDir, to: newDir)
            }
        }
    }
}
