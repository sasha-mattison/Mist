import AppIntents

/// Siri/Spotlight/Shortcuts entry point: "Launch <game> in Mist". Reads the
/// local Steam install directly (same SteamPathResolver/SteamLocalDataService
/// pair GameLibraryStore uses) rather than depending on a live
/// GameLibraryStore instance, since an intent can run before — or without —
/// any of Mist's SwiftUI scenes having appeared.
struct LaunchGameIntent: AppIntent {
    static var title: LocalizedStringResource = "Launch Game"
    static var description = IntentDescription("Launches an installed Steam game through Mist.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Game")
    var game: GameEntity

    func perform() async throws -> some IntentResult {
        GameLaunchService.launch(appID: game.appID)
        return .result()
    }
}

struct GameEntity: AppEntity {
    let appID: Int
    let name: String

    var id: Int { appID }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Game"
    static var defaultQuery = GameEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GameEntityQuery: EntityStringQuery {
    func entities(for identifiers: [Int]) async throws -> [GameEntity] {
        Self.installedGames().filter { identifiers.contains($0.appID) }
    }

    func entities(matching string: String) async throws -> [GameEntity] {
        Self.installedGames().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [GameEntity] {
        Self.installedGames()
    }

    /// Fresh read of installed apps every call — intentionally not cached,
    /// since an intent could run long after the app last refreshed and
    /// installs/uninstalls should be picked up immediately.
    private static func installedGames() -> [GameEntity] {
        guard let root = SteamPathResolver.resolveSteamRoot() else { return [] }
        let service = SteamLocalDataService(steamRoot: root)
        guard let libraries = try? service.loadLibraryFolders() else { return [] }
        return service.loadInstalledApps(in: libraries)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { GameEntity(appID: $0.appID, name: $0.name) }
    }
}

struct MistShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LaunchGameIntent(),
            phrases: [
                "Launch \(\.$game) in \(.applicationName)",
                "Play \(\.$game) in \(.applicationName)"
            ],
            shortTitle: "Launch Game",
            systemImageName: "gamecontroller.fill"
        )
    }
}
