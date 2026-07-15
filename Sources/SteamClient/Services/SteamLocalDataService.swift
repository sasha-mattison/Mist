import Foundation

/// Reads Steam's local VDF/ACF files: config/loginusers.vdf,
/// steamapps/libraryfolders.vdf, and each library's appmanifest_*.acf files.
struct SteamLocalDataService {
    let steamRoot: URL

    func loadAccounts() throws -> [SteamAccount] {
        let url = steamRoot.appendingPathComponent("config/loginusers.vdf")
        let text = try String(contentsOf: url, encoding: .utf8)
        let root = try VDFParser.parse(text)
        guard let users = root["users"]?.objectValue else { return [] }

        return users.compactMap { steamID64, value in
            guard let fields = value.objectValue,
                  let accountName = fields["AccountName"]?.stringValue,
                  let personaName = fields["PersonaName"]?.stringValue else {
                return nil
            }
            return SteamAccount(
                steamID64: steamID64,
                accountName: accountName,
                personaName: personaName,
                isAutoLogin: fields["AutoLogin"]?.stringValue == "1"
            )
        }
    }

    func loadLibraryFolders() throws -> [LibraryFolder] {
        let url = steamRoot.appendingPathComponent("steamapps/libraryfolders.vdf")
        let text = try String(contentsOf: url, encoding: .utf8)
        let root = try VDFParser.parse(text)
        guard let foldersRoot = root["libraryfolders"]?.objectValue else { return [] }

        // Keys are numeric strings ("0", "1", ...) — one per library folder
        // (main install plus any external-drive libraries the user added).
        return foldersRoot.values.compactMap { value in
            guard let fields = value.objectValue,
                  let path = fields["path"]?.stringValue else {
                return nil
            }
            return LibraryFolder(path: path)
        }
    }

    func loadInstalledApps(in libraries: [LibraryFolder]) -> [InstalledApp] {
        libraries.flatMap { library in
            loadInstalledApps(in: library)
        }
    }

    private func loadInstalledApps(in library: LibraryFolder) -> [InstalledApp] {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: library.steamAppsURL,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return entries
            .filter { $0.lastPathComponent.hasPrefix("appmanifest_") && $0.pathExtension == "acf" }
            .compactMap { manifestURL in
                parseManifest(at: manifestURL, libraryPath: library.path)
            }
    }

    private func parseManifest(at url: URL, libraryPath: String) -> InstalledApp? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let root = try? VDFParser.parse(text),
              let fields = root["AppState"]?.objectValue,
              let appIDString = fields["appid"]?.stringValue,
              let appID = Int(appIDString),
              let name = fields["name"]?.stringValue,
              let installDir = fields["installdir"]?.stringValue else {
            return nil
        }

        let sizeOnDisk = fields["SizeOnDisk"]?.stringValue.flatMap(Int64.init) ?? 0
        let lastPlayedEpoch = fields["LastPlayed"]?.stringValue.flatMap(Int.init) ?? 0
        let lastPlayed = lastPlayedEpoch > 0 ? Date(timeIntervalSince1970: TimeInterval(lastPlayedEpoch)) : nil

        return InstalledApp(
            appID: appID,
            name: name,
            installDir: installDir,
            sizeOnDisk: sizeOnDisk,
            lastPlayed: lastPlayed,
            libraryPath: libraryPath
        )
    }
}
