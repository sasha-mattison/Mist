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

    /// Reads the user's manually-curated Steam library Collections (the
    /// post-2022 Library UI feature) for grouping/filtering the local
    /// library. Best-effort: this reads an internal, undocumented Steam
    /// Cloud storage blob (`WebStorage.user-collections` in
    /// localconfig.vdf, itself a VDF string containing escaped JSON) whose
    /// exact schema isn't published anywhere and could not be verified
    /// against a real populated collection during development (this
    /// machine's account has none saved) — parsing is deliberately tolerant
    /// so an unexpected shape just yields no collections rather than
    /// failing or crashing.
    func loadCollections(steamID64: String) -> [GameCollection] {
        guard let accountID = LocalScreenshotService.accountID(fromSteamID64: steamID64) else { return [] }
        let url = steamRoot.appendingPathComponent("userdata/\(accountID)/config/localconfig.vdf")
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let root = try? VDFParser.parse(text),
              let jsonString = root["UserLocalConfigStore"]?.objectValue?["WebStorage"]?.objectValue?["user-collections"]?.stringValue,
              let jsonData = jsonString.data(using: .utf8) else {
            return []
        }
        guard let raw = try? JSONDecoder().decode([String: LossyDecodable<RawCollection>].self, from: jsonData) else {
            return []
        }
        return raw.values
            .compactMap(\.value)
            .compactMap { entry in
                // Dynamic/"smart" collections carry a filter spec instead of
                // a fixed app list — skip those; only surface manually
                // curated, static sets.
                guard !entry.isDynamic, let added = entry.added, !added.isEmpty else { return nil }
                return GameCollection(id: entry.id, name: entry.name, appIDs: added)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// One entry from `user-collections`. The real shape couldn't be
    /// verified (see `loadCollections`), so this accepts either a flat
    /// `{name, added, filterSpec}` object or one nested under a `value` key,
    /// since Steam Cloud WebStorage entries are sometimes wrapped that way.
    private struct RawCollection: Decodable {
        let id: String
        let name: String
        let added: [Int]?
        let isDynamic: Bool

        private enum OuterKeys: String, CodingKey {
            case value
        }

        private struct Fields: Decodable {
            let id: String?
            let name: String
            let added: [Int]?
            let filterSpec: FilterSpecMarker?
        }

        /// Only used to detect *presence* of a filter spec (dynamic
        /// collection) — its internal shape isn't modeled since dynamic
        /// collections are skipped regardless.
        private struct FilterSpecMarker: Decodable {}

        init(from decoder: Decoder) throws {
            let fields: Fields
            if let outer = try? decoder.container(keyedBy: OuterKeys.self),
               let nested = try? outer.decode(Fields.self, forKey: .value) {
                fields = nested
            } else {
                fields = try Fields(from: decoder)
            }
            id = fields.id ?? fields.name
            name = fields.name
            added = fields.added
            isDynamic = fields.filterSpec != nil
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
