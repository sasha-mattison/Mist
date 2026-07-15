import AppKit
import Foundation
import Observation

/// Publishes the currently-running installed game into GameLibraryStore.
///
/// appmanifest's `StateFlags` is confirmed unreliable for this (verified
/// empirically: it stayed "4" — fully installed — while the game's process
/// was actually running), so this instead observes NSWorkspace's
/// launch/terminate notifications and matches the running app's bundle path
/// against each installed game's `steamapps/common/<installdir>/` prefix.
@MainActor
final class RunningGameMonitor {
    private weak var store: GameLibraryStore?
    private var launchObserver: NSObjectProtocol?
    private var terminateObserver: NSObjectProtocol?

    init(store: GameLibraryStore) {
        self.store = store
        let center = NSWorkspace.shared.notificationCenter
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        terminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
        observeLibraryChanges()
    }

    /// The init-time refresh() runs before the store has loaded any library
    /// items, so a game that was already running at app launch would never be
    /// detected (launch/terminate notifications won't fire for it). Re-check
    /// whenever libraryItems is rebuilt.
    private func observeLibraryChanges() {
        withObservationTracking {
            _ = store?.libraryItems
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                self.observeLibraryChanges()
            }
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        if let launchObserver { center.removeObserver(launchObserver) }
        if let terminateObserver { center.removeObserver(terminateObserver) }
    }

    func refresh() {
        guard let store else { return }
        let runningPaths = NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.path }

        for item in store.libraryItems where item.isInstalled {
            guard let installPath = item.installURL?.path else { continue }
            if runningPaths.contains(where: { $0.hasPrefix(installPath) }) {
                store.setRunningAppID(item.appID)
                return
            }
        }
        store.setRunningAppID(nil)
    }
}
