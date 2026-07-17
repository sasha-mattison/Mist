import Foundation
import Observation

@MainActor
@Observable
final class GameLibraryStore {
    private(set) var installedApps: [InstalledApp] = []
    private(set) var accounts: [SteamAccount] = []
    private(set) var collections: [GameCollection] = []
    private(set) var libraryItems: [GameLibraryItem] = []
    private(set) var playerSummary: PlayerSummary?
    private(set) var loadError: String?
    private(set) var remoteError: String?
    private(set) var isSteamFound: Bool
    private(set) var isRefreshingRemote = false
    /// Set by RunningGameMonitor (M5). appmanifest's StateFlags isn't a
    /// reliable "currently running" signal, so this is the single place the
    /// grid, detail view, and menu bar all read live play state from.
    private(set) var runningAppID: Int?
    /// When the current play session started (i.e. when runningAppID last
    /// transitioned from nil/another app). Drives the menu bar's session timer.
    private(set) var runningSince: Date?
    /// SteamID64 the user explicitly signed in with (OpenID flow). Takes
    /// precedence over accounts detected from loginusers.vdf.
    private(set) var signedInSteamID64: String?
    /// User's explicit choice among locally-detected accounts, used only
    /// when there's no OpenID sign-in — lets a multi-account machine pick
    /// something other than whichever account happens to be auto-login.
    private(set) var preferredLocalSteamID64: String?
    /// Storefront verdicts for "runs natively on macOS", filled from
    /// MacCompatibilityService's disk cache at launch and streamed in while
    /// resolution runs. Installed games are implicitly compatible and are
    /// never looked up here.
    private(set) var macSupportByAppID: [Int: Bool] = [:]
    private(set) var isResolvingMacSupport = false
    /// User-added non-Steam apps/games, persisted independently of anything
    /// Steam-derived (see CustomApp) — genuine user data, not a rebuildable
    /// cache, so this lives in Application Support rather than Caches.
    private(set) var customApps: [CustomApp] = []

    private var macSupportTask: Task<Void, Never>?

    private var ownedGamesByAppID: [Int: OwnedGame] = [:]
    private let dataService: SteamLocalDataService?

    private static let signedInDefaultsKey = "signedInSteamID64"
    private static let preferredLocalDefaultsKey = "preferredLocalSteamID64"

    private static func customAppsFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Mist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom-apps.json")
    }

    init() {
        signedInSteamID64 = UserDefaults.standard.string(forKey: Self.signedInDefaultsKey)
        preferredLocalSteamID64 = UserDefaults.standard.string(forKey: Self.preferredLocalDefaultsKey)
        if let root = SteamPathResolver.resolveSteamRoot() {
            dataService = SteamLocalDataService(steamRoot: root)
            isSteamFound = true
        } else {
            dataService = nil
            isSteamFound = false
        }
        if let data = try? Data(contentsOf: Self.customAppsFileURL()),
           let stored = try? JSONDecoder().decode([CustomApp].self, from: data) {
            customApps = stored
        }
    }

    /// Adds a user-picked non-Steam app/game to the library. `path` should
    /// point at an .app bundle — RunningGameMonitor's "now playing" detection
    /// only observes NSWorkspace's app-level launch/terminate notifications,
    /// which raw (non-bundle) executables don't participate in.
    func addCustomApp(name: String, path: URL) {
        guard !customApps.contains(where: { $0.path == path.path }) else { return }
        let nextID = (customApps.map(\.id).min() ?? 0) - 1
        customApps.append(CustomApp(id: nextID, name: name, path: path.path, addedDate: Date()))
        saveCustomApps()
        rebuildLibraryItems()
    }

    func removeCustomApp(id: Int) {
        customApps.removeAll { $0.id == id }
        saveCustomApps()
        rebuildLibraryItems()
    }

    private func saveCustomApps() {
        if let data = try? JSONEncoder().encode(customApps) {
            try? data.write(to: Self.customAppsFileURL())
        }
    }

    /// Identity used for all Web API calls: an explicit sign-in wins, else an
    /// explicit local-account choice (if it still exists), else fall back to
    /// the local Steam install's auto-login account.
    var activeSteamID64: String? {
        if let signedInSteamID64 { return signedInSteamID64 }
        if let preferredLocalSteamID64, accounts.contains(where: { $0.steamID64 == preferredLocalSteamID64 }) {
            return preferredLocalSteamID64
        }
        return (accounts.first(where: { $0.isAutoLogin }) ?? accounts.first)?.steamID64
    }

    func completeSignIn(steamID64: String) {
        signedInSteamID64 = steamID64
        UserDefaults.standard.set(steamID64, forKey: Self.signedInDefaultsKey)
        refreshCollections()
    }

    func signOut() {
        signedInSteamID64 = nil
        UserDefaults.standard.removeObject(forKey: Self.signedInDefaultsKey)
        playerSummary = nil
        ownedGamesByAppID = [:]
        remoteError = nil
        refreshCollections()
        rebuildLibraryItems()
    }

    /// Sets which locally-detected account to use when not signed in with
    /// Steam. Pass nil to go back to the auto-login default. Clears
    /// remote-derived state so a stale identity's data isn't shown under the
    /// new one; callers should follow up with `refreshRemote()`.
    func setPreferredLocalAccount(steamID64: String?) {
        preferredLocalSteamID64 = steamID64
        if let steamID64 {
            UserDefaults.standard.set(steamID64, forKey: Self.preferredLocalDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.preferredLocalDefaultsKey)
        }
        playerSummary = nil
        ownedGamesByAppID = [:]
        remoteError = nil
        refreshCollections()
        rebuildLibraryItems()
    }

    func refreshLocal() {
        guard let dataService else { return }
        let previousBuildIDs = Dictionary(uniqueKeysWithValues: installedApps.map { ($0.appID, $0.buildID) })
        do {
            accounts = try dataService.loadAccounts()
            let libraries = try dataService.loadLibraryFolders()
            installedApps = dataService
                .loadInstalledApps(in: libraries)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        notifyOfGameUpdates(previousBuildIDs: previousBuildIDs)
        refreshCollections()
        rebuildLibraryItems()
    }

    /// Compares each installed app's build id against what it was before
    /// this refresh — Steam bumps it on every update. Skipped on the very
    /// first load (nothing to compare against yet, which would otherwise
    /// "detect" an update for every already-installed game).
    private func notifyOfGameUpdates(previousBuildIDs: [Int: String?]) {
        guard !previousBuildIDs.isEmpty else { return }
        for app in installedApps {
            guard let newBuildID = app.buildID,
                  let previousEntry = previousBuildIDs[app.appID],
                  let oldBuildID = previousEntry,
                  oldBuildID != newBuildID else { continue }
            NotificationService.shared.notifyGameUpdateAvailable(gameName: app.name)
        }
    }

    private func refreshCollections() {
        guard let dataService, let steamID64 = activeSteamID64 else {
            collections = []
            return
        }
        collections = dataService.loadCollections(steamID64: steamID64)
    }

    func refreshRemote() async {
        guard let apiKey = KeychainService.loadAPIKey() else { return }
        guard let steamID64 = activeSteamID64 else {
            remoteError = "No Steam account found — sign in with Steam to load your library."
            return
        }

        isRefreshingRemote = true
        defer { isRefreshingRemote = false }

        let client = SteamWebAPIClient(apiKey: apiKey)
        do {
            async let ownedGames = client.getOwnedGames(steamID64: steamID64)
            async let summaries = client.getPlayerSummaries(steamIDs: [steamID64])
            let (games, players) = try await (ownedGames, summaries)
            ownedGamesByAppID = Dictionary(uniqueKeysWithValues: games.map { ($0.appid, $0) })
            playerSummary = players.first
            remoteError = nil
        } catch {
            remoteError = error.localizedDescription
        }
        rebuildLibraryItems()
    }

    func setRunningAppID(_ appID: Int?) {
        if appID != runningAppID {
            runningSince = appID == nil ? nil : Date()
        }
        runningAppID = appID
    }

    /// Whether an item counts as playable on this Mac: installed via the
    /// macOS Steam client, or storefront-confirmed native support.
    func isMacPlayable(_ item: GameLibraryItem) -> Bool {
        item.isInstalled || macSupportByAppID[item.appID] == true
    }

    /// Pending lookups for the "Playable on Mac" filter. Zero once every
    /// non-installed library item has a cached verdict.
    var unresolvedMacSupportCount: Int {
        libraryItems.filter { !$0.isInstalled && macSupportByAppID[$0.appID] == nil }.count
    }

    func loadCachedMacSupport() async {
        macSupportByAppID = await MacCompatibilityService.shared.cachedVerdicts()
    }

    /// Kicks off (or continues) storefront resolution for items with no
    /// verdict yet. Safe to call repeatedly; only one pass runs at a time.
    func resolveMacSupport() {
        guard macSupportTask == nil else { return }
        let pending = libraryItems
            .filter { !$0.isInstalled && macSupportByAppID[$0.appID] == nil }
            .map(\.appID)
        guard !pending.isEmpty else { return }

        isResolvingMacSupport = true
        macSupportTask = Task {
            await MacCompatibilityService.shared.resolve(appIDs: pending) { verdicts in
                await MainActor.run { self.macSupportByAppID = verdicts }
            }
            isResolvingMacSupport = false
            macSupportTask = nil
        }
    }

    private func rebuildLibraryItems() {
        var itemsByAppID: [Int: GameLibraryItem] = [:]

        for app in installedApps {
            let owned = ownedGamesByAppID[app.appID]
            itemsByAppID[app.appID] = GameLibraryItem(
                appID: app.appID,
                name: app.name,
                isInstalled: true,
                sizeOnDisk: app.sizeOnDisk,
                lastPlayed: app.lastPlayed ?? owned?.lastPlayed,
                playtimeForeverMinutes: owned?.playtimeForeverMinutes ?? 0,
                playtime2WeeksMinutes: owned?.playtime2WeeksMinutes ?? 0,
                installDir: app.installDir,
                libraryPath: app.libraryPath,
                customAppPath: nil
            )
        }

        for (appID, game) in ownedGamesByAppID where itemsByAppID[appID] == nil {
            itemsByAppID[appID] = GameLibraryItem(
                appID: appID,
                name: game.name ?? "App \(appID)",
                isInstalled: false,
                sizeOnDisk: 0,
                lastPlayed: game.lastPlayed,
                playtimeForeverMinutes: game.playtimeForeverMinutes,
                playtime2WeeksMinutes: game.playtime2WeeksMinutes ?? 0,
                installDir: nil,
                libraryPath: nil,
                customAppPath: nil
            )
        }

        for app in customApps {
            itemsByAppID[app.id] = GameLibraryItem(
                appID: app.id,
                name: app.name,
                isInstalled: true,
                sizeOnDisk: 0,
                lastPlayed: nil,
                playtimeForeverMinutes: 0,
                playtime2WeeksMinutes: 0,
                installDir: nil,
                libraryPath: nil,
                customAppPath: app.url
            )
        }

        libraryItems = itemsByAppID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
