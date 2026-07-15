import Foundation

/// Resolves whether games run natively on macOS via the storefront's
/// `appdetails?filters=platforms` endpoint (batched appids no longer work —
/// Valve disabled them — so this fetches one app at a time, gently paced to
/// stay under the ~200 requests / 5 min storefront rate limit).
///
/// Verdicts are cached permanently on disk: platform support essentially
/// never changes, so after the first pass the filter is instant. Installed
/// games never hit this service — being installed through the macOS Steam
/// client already proves they run here.
actor MacCompatibilityService {
    static let shared = MacCompatibilityService()

    private var cache: [Int: Bool]
    private let cacheFileURL: URL
    private let session = URLSession.shared
    /// Spacing between requests; ~40/min keeps well under the rate limit.
    private static let requestSpacing: Duration = .milliseconds(1400)

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("SteamClient", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheFileURL = dir.appendingPathComponent("mac-compatibility.json")

        if let data = try? Data(contentsOf: cacheFileURL),
           let stored = try? JSONDecoder().decode([String: Bool].self, from: data) {
            cache = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        } else {
            cache = [:]
        }
    }

    /// Everything already known, without any network traffic.
    func cachedVerdicts() -> [Int: Bool] {
        cache
    }

    /// Resolves the given apps, invoking `onProgress` with the growing verdict
    /// map after each fetch so callers can update the UI incrementally.
    /// Already-cached apps are skipped. Cancellable between requests.
    func resolve(appIDs: [Int], onProgress: @Sendable ([Int: Bool]) async -> Void) async {
        let pending = appIDs.filter { cache[$0] == nil }
        guard !pending.isEmpty else { return }

        for (index, appID) in pending.enumerated() {
            if Task.isCancelled { break }
            if let verdict = await fetchMacSupport(appID: appID) {
                cache[appID] = verdict
                saveCache()
                await onProgress(cache)
            }
            if index < pending.count - 1 {
                try? await Task.sleep(for: Self.requestSpacing)
            }
        }
    }

    private func fetchMacSupport(appID: Int) async -> Bool? {
        var components = URLComponents(string: "https://store.steampowered.com/api/appdetails")!
        components.queryItems = [
            URLQueryItem(name: "appids", value: String(appID)),
            URLQueryItem(name: "filters", value: "platforms")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse else {
            return nil
        }
        if http.statusCode == 429 {
            // Rate limited — back off and let a later pass retry this app.
            try? await Task.sleep(for: .seconds(60))
            return nil
        }
        guard http.statusCode == 200,
              let envelope = try? JSONDecoder().decode([String: Envelope].self, from: data),
              let entry = envelope[String(appID)] else {
            return nil
        }
        // Delisted apps ("success": false) get a definitive "no" so they
        // aren't re-fetched forever.
        return entry.data?.platforms?.mac ?? false
    }

    private func saveCache() {
        let stored = Dictionary(uniqueKeysWithValues: cache.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: cacheFileURL)
        }
    }

    private struct Envelope: Decodable {
        let success: Bool
        let data: Payload?

        struct Payload: Decodable {
            let platforms: Platforms?
        }

        struct Platforms: Decodable {
            let mac: Bool
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            success = try container.decode(Bool.self, forKey: .success)
            // "data" is `[]` for some delisted apps — tolerate non-objects.
            data = try? container.decodeIfPresent(Payload.self, forKey: .data)
        }

        enum CodingKeys: String, CodingKey {
            case success, data
        }
    }
}
