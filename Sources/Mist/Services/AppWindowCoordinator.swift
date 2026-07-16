import AppKit
import SwiftUI

/// Bridges AppKit-side callers (the global hotkey handler, which has no
/// SwiftUI environment) to SwiftUI's `openWindow` action. `MainWindowRoot`
/// hands its `openWindow` action to this singleton once at launch; nothing
/// else needs to know a plain SwiftUI environment value is involved.
@MainActor
final class AppWindowCoordinator {
    static let shared = AppWindowCoordinator()

    var openWindow: OpenWindowAction?

    private init() {}

    /// Brings the main window forward, recreating it if the user closed it
    /// (the app keeps running for the menu bar extra). Mirrors
    /// MenuBarContentView's "Show Library" action.
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let mainWindow = NSApp.windows.first {
            $0.identifier?.rawValue.hasPrefix(MistApp.mainWindowID) == true
        }
        if let mainWindow {
            if mainWindow.isMiniaturized { mainWindow.deminiaturize(nil) }
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            openWindow?(id: MistApp.mainWindowID)
        }
    }
}
