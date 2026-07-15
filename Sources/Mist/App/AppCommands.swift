import SwiftUI

/// Main menu bar additions: a Go menu mirroring the sidebar (⌘1…⌘n) and a
/// Library menu for refresh/launch actions that previously only existed as
/// toolbar buttons.
struct AppCommands: Commands {
    let navigation: AppNavigationModel
    let store: GameLibraryStore

    var body: some Commands {
        SidebarCommands()

        CommandMenu("Go") {
            ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                Button(section.rawValue) {
                    navigation.selectedSection = section
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
        }

        CommandMenu("Library") {
            Button("Refresh") {
                store.refreshLocal()
                Task { await store.refreshRemote() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Launch Last Played Game") {
                let lastPlayed = store.libraryItems
                    .filter { $0.isInstalled && $0.lastPlayed != nil }
                    .max { $0.lastPlayed! < $1.lastPlayed! }
                if let lastPlayed {
                    GameLaunchService.launch(appID: lastPlayed.appID)
                }
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider()

            Button("Open Steam") {
                GameLaunchService.openSteam()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
