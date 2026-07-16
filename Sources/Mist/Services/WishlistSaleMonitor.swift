import Foundation

/// Periodically checks the signed-in user's wishlist for new discounts and
/// notifies the first time each item's price drops — a lightweight, opt-in
/// substitute for Steam's own wishlist sale emails. Runs for the app's
/// lifetime once started; "last seen discount" per app is kept on disk so a
/// relaunch doesn't re-notify for sales already seen.
@MainActor
final class WishlistSaleMonitor {
    static let shared = WishlistSaleMonitor()

    private weak var store: GameLibraryStore?
    private var loopTask: Task<Void, Never>?
    private var lastSeenDiscounts: [Int: Int]
    private let cacheFileURL: URL

    private static let checkInterval: Duration = .seconds(60 * 60)
    private static let initialDelay: Duration = .seconds(30)
    /// Spacing between per-item storefront lookups, well under the
    /// ~200-requests/5-min rate limit (same pacing MacCompatibilityService
    /// uses for the same endpoint).
    private static let requestSpacing: Duration = .milliseconds(1400)

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("Mist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cacheFileURL = dir.appendingPathComponent("wishlist-last-seen-discounts.json")

        if let data = try? Data(contentsOf: cacheFileURL),
           let stored = try? JSONDecoder().decode([String: Int].self, from: data) {
            lastSeenDiscounts = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        } else {
            lastSeenDiscounts = [:]
        }
    }

    /// Starts the background loop. Safe to call once at app launch; a
    /// second call is a no-op even if the store instance differs.
    func start(store: GameLibraryStore) {
        guard loopTask == nil else { return }
        self.store = store
        loopTask = Task { [weak self] in
            try? await Task.sleep(for: Self.initialDelay)
            while !Task.isCancelled {
                await self?.checkOnce()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    /// Also called directly by WishlistView on open, so a sale is caught
    /// immediately rather than waiting for the next hourly tick.
    func checkOnce() async {
        guard NotificationService.shared.settings?.notifyWishlistSales == true,
              let steamID64 = store?.activeSteamID64,
              let items = try? await SteamCommunityClient.shared.wishlist(steamID64: steamID64) else {
            return
        }

        for item in items {
            guard let details = await SteamStoreClient.shared.details(for: item.appid),
                  let price = details.priceOverview, price.hasDiscount,
                  let percent = price.discountPercent, percent > 0 else {
                // Not discounted right now — clear any stale "seen" entry so
                // a future sale on this item is treated as new again.
                lastSeenDiscounts.removeValue(forKey: item.appid)
                continue
            }
            if lastSeenDiscounts[item.appid] != percent {
                NotificationService.shared.notifyWishlistSale(
                    gameName: details.name ?? "App \(item.appid)",
                    discountPercent: percent
                )
            }
            lastSeenDiscounts[item.appid] = percent
            try? await Task.sleep(for: Self.requestSpacing)
        }
        saveCache()
    }

    private func saveCache() {
        let stored = Dictionary(uniqueKeysWithValues: lastSeenDiscounts.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: cacheFileURL)
        }
    }
}
