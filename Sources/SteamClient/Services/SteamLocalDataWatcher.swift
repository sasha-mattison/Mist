import Foundation

/// Watches each library's steamapps/ directory (install/uninstall changes
/// appmanifest_*.acf files there) plus the Steam root's steamapps/ folder
/// (catches libraryfolders.vdf edits) and triggers a debounced local re-scan.
/// Hand-rolled DispatchSource watcher rather than an external FSEvents
/// dependency, since it only needs to watch a handful of directories.
///
/// Known limitation: a library folder added on a new drive after launch
/// isn't watched until restart — only directories present at init time (plus
/// the Steam root, which catches the libraryfolders.vdf edit that adds it)
/// are covered.
@MainActor
final class SteamLocalDataWatcher {
    private weak var store: GameLibraryStore?
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceTask: Task<Void, Never>?

    init(store: GameLibraryStore) {
        self.store = store
        watchSteamAppsDirectories()
    }

    deinit {
        for source in sources { source.cancel() }
        debounceTask?.cancel()
    }

    private func watchSteamAppsDirectories() {
        guard let steamRoot = SteamPathResolver.resolveSteamRoot() else { return }
        let dataService = SteamLocalDataService(steamRoot: steamRoot)
        let libraries = (try? dataService.loadLibraryFolders()) ?? []

        var directories = Set([steamRoot.appendingPathComponent("steamapps")])
        for library in libraries {
            directories.insert(library.steamAppsURL)
        }
        for directory in directories {
            watch(directory: directory)
        }
    }

    private func watch(directory: URL) {
        let descriptor = open(directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleRefresh()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        sources.append(source)
    }

    private func scheduleRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.store?.refreshLocal()
        }
    }
}
