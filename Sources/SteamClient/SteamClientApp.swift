import SwiftUI

@main
struct SteamClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The App conformer is instantiated exactly once for the process
    // lifetime, so plain stored properties (not @State) are a valid single
    // source of truth shared between the window and menu bar scenes.
    private let store: GameLibraryStore
    private let friendsStore: FriendsStore
    private let profileStore: ProfileStore
    private let settings: SettingsStore
    private let runningGameMonitor: RunningGameMonitor
    private let localDataWatcher: SteamLocalDataWatcher

    init() {
        let store = GameLibraryStore()
        self.store = store
        self.friendsStore = FriendsStore(library: store)
        self.profileStore = ProfileStore(library: store)
        self.settings = SettingsStore()
        self.runningGameMonitor = RunningGameMonitor(store: store)
        self.localDataWatcher = SteamLocalDataWatcher(store: store)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environment(store)
                .environment(friendsStore)
                .environment(profileStore)
                .environment(settings)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)

        MenuBarExtra {
            MenuBarContentView()
                .environment(store)
                .environment(settings)
        } label: {
            MenuBarLabelView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)
    }
}
