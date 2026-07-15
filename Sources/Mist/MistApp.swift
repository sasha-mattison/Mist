import SwiftUI

@main
struct MistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// WindowGroup identifier, used by the menu bar extra to reopen the main
    /// window after the user closes it (the app keeps running).
    static let mainWindowID = "main"

    // The App conformer is instantiated exactly once for the process
    // lifetime, so plain stored properties (not @State) are a valid single
    // source of truth shared between the window and menu bar scenes.
    private let store: GameLibraryStore
    private let friendsStore: FriendsStore
    private let profileStore: ProfileStore
    private let communityStore: CommunityStore
    private let settings: SettingsStore
    private let navigation: AppNavigationModel
    private let runningGameMonitor: RunningGameMonitor
    private let localDataWatcher: SteamLocalDataWatcher

    init() {
        LegacyMigration.migrateIfNeeded()
        let store = GameLibraryStore()
        self.store = store
        self.friendsStore = FriendsStore(library: store)
        self.profileStore = ProfileStore(library: store)
        self.communityStore = CommunityStore(library: store)
        self.settings = SettingsStore()
        self.navigation = AppNavigationModel()
        self.runningGameMonitor = RunningGameMonitor(store: store)
        self.localDataWatcher = SteamLocalDataWatcher(store: store)
    }

    // IMPORTANT: scene root content must stay a single unmodified view.
    // On this OS build, chaining 6+ modifiers directly inside WindowGroup's
    // closure made SwiftUI silently create no window at all (scene body ran,
    // process stayed alive, zero windows) — found by bisection. All modifiers
    // therefore live inside the wrapper views' bodies below.
    var body: some Scene {
        WindowGroup(id: Self.mainWindowID) {
            MainWindowRoot(
                store: store,
                friendsStore: friendsStore,
                profileStore: profileStore,
                communityStore: communityStore,
                settings: settings,
                navigation: navigation
            )
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
        .commands {
            AppCommands(navigation: navigation, store: store)
        }

        MenuBarExtra {
            MenuBarRoot(store: store, friendsStore: friendsStore, settings: settings)
        } label: {
            MenuBarLabelView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MainWindowRoot: View {
    let store: GameLibraryStore
    let friendsStore: FriendsStore
    let profileStore: ProfileStore
    let communityStore: CommunityStore
    let settings: SettingsStore
    let navigation: AppNavigationModel

    var body: some View {
        ContentView()
            .frame(minWidth: 900, minHeight: 600)
            .environment(store)
            .environment(friendsStore)
            .environment(profileStore)
            .environment(communityStore)
            .environment(settings)
            .environment(navigation)
    }
}

private struct MenuBarRoot: View {
    let store: GameLibraryStore
    let friendsStore: FriendsStore
    let settings: SettingsStore

    var body: some View {
        MenuBarContentView()
            .environment(store)
            .environment(friendsStore)
            .environment(settings)
    }
}
