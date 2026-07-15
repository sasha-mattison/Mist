import AppKit
import Foundation

/// Resolves artwork for a game: local `librarycache` files first (zero
/// network cost, already downloaded by real Steam), then a Steam CDN fallback
/// for owned-but-not-installed titles, with an on-disk + in-memory cache.
///
/// Two kinds are served: the portrait capsule used on grid cards, and the
/// wide hero banner used as the detail page backdrop.
///
/// Local artwork filenames aren't always flat under `librarycache/<appid>/` —
/// for some titles they live in a nested content-hash subfolder instead
/// (confirmed on a real install), so this does a recursive (not just
/// top-level) search within that one app's folder.
actor ArtworkLoader {
    static let shared = ArtworkLoader()

    enum Kind: String {
        case capsule
        case hero

        var localFilenamePriority: [String] {
            switch self {
            case .capsule:
                return [
                    "library_600x900.jpg",
                    "library_hero.jpg",
                    "header.jpg",
                    "library_capsule.jpg",
                    "capsule_616x353.jpg",
                    "logo.png"
                ]
            case .hero:
                return [
                    "library_hero.jpg",
                    "header.jpg",
                    "capsule_616x353.jpg",
                    "library_600x900.jpg"
                ]
            }
        }

        var cdnFilenamePriority: [String] {
            switch self {
            case .capsule:
                return [
                    "library_600x900.jpg",
                    "header.jpg",
                    "capsule_616x353.jpg"
                ]
            case .hero:
                return [
                    "library_hero.jpg",
                    "header.jpg",
                    "capsule_616x353.jpg"
                ]
            }
        }
    }

    private struct CacheKey: Hashable {
        let appID: Int
        let kind: Kind
    }

    private var memoryCache: [CacheKey: NSImage] = [:]
    private let diskCacheURL: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        diskCacheURL = caches.appendingPathComponent("Mist/artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    func image(for appID: Int) async -> NSImage? {
        await image(for: appID, kind: .capsule)
    }

    func heroImage(for appID: Int) async -> NSImage? {
        await image(for: appID, kind: .hero)
    }

    func image(for appID: Int, kind: Kind) async -> NSImage? {
        let key = CacheKey(appID: appID, kind: kind)
        if let cached = memoryCache[key] {
            return cached
        }
        if let onDisk = loadFromDiskCache(key: key) {
            memoryCache[key] = onDisk
            return onDisk
        }
        if let localURL = findLocalArtwork(appID: appID, kind: kind), let image = NSImage(contentsOf: localURL) {
            memoryCache[key] = image
            saveToDiskCache(key: key, image: image)
            return image
        }
        if let remote = await fetchFromCDN(appID: appID, kind: kind) {
            memoryCache[key] = remote
            saveToDiskCache(key: key, image: remote)
            return remote
        }
        return nil
    }

    private func findLocalArtwork(appID: Int, kind: Kind) -> URL? {
        guard let steamRoot = SteamPathResolver.resolveSteamRoot() else { return nil }
        let appDir = steamRoot.appendingPathComponent("appcache/librarycache/\(appID)")
        guard let enumerator = FileManager.default.enumerator(
            at: appDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let priority = kind.localFilenamePriority
        var matchesByFilename: [String: URL] = [:]
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if priority.contains(name), matchesByFilename[name] == nil {
                matchesByFilename[name] = fileURL
            }
        }

        for filename in priority {
            if let url = matchesByFilename[filename] {
                return url
            }
        }
        return nil
    }

    private func fetchFromCDN(appID: Int, kind: Kind) async -> NSImage? {
        for filename in kind.cdnFilenamePriority {
            guard let url = URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/\(filename)") else {
                continue
            }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let image = NSImage(data: data) else {
                continue
            }
            return image
        }
        return nil
    }

    private func diskCacheFile(for key: CacheKey) -> URL {
        // Capsule keeps the historic "<appid>.jpg" name so existing caches
        // stay valid; hero gets a suffixed sibling.
        let filename = key.kind == .capsule ? "\(key.appID).jpg" : "\(key.appID)_\(key.kind.rawValue).jpg"
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func loadFromDiskCache(key: CacheKey) -> NSImage? {
        let file = diskCacheFile(for: key)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return NSImage(contentsOf: file)
    }

    private func saveToDiskCache(key: CacheKey, image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [:]) else {
            return
        }
        try? jpeg.write(to: diskCacheFile(for: key))
    }
}
