import Foundation
import Observation

/// Data for the Community tab: a merged news feed for the user's games plus
/// Steam's global most-played chart. News sources come from the library
/// (recently played first); with an empty library the feed falls back to the
/// trending chart's games, so the tab works before any sign-in.
@MainActor
@Observable
final class CommunityStore {
    private(set) var newsItems: [GameNewsItem] = []
    /// Display names for every appID the news feed covers (chips, filters).
    private(set) var newsSourceNames: [Int: String] = [:]
    private(set) var trending: [TrendingGame] = []
    private(set) var isLoading = false
    private(set) var newsError: String?
    private(set) var trendingError: String?
    private(set) var lastRefreshed: Date?

    private let library: GameLibraryStore

    /// Cap on per-game news requests per refresh; keeps a large library from
    /// fanning out into dozens of calls.
    private static let maxNewsSources = 12

    init(library: GameLibraryStore) {
        self.library = library
    }

    func refreshIfStale() async {
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < 5 * 60 { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Trending first: it doubles as the news-source fallback for users
        // with no library yet.
        await loadTrending()
        await loadNews()
        lastRefreshed = Date()
    }

    // MARK: - Trending

    private func loadTrending() async {
        do {
            let entries = Array(try await SteamCommunityClient.shared.mostPlayed().prefix(20))
            // The chart carries appIDs only; resolve names through the
            // storefront (SteamStoreClient caches per app).
            let names = await withTaskGroup(of: (Int, String?).self) { group in
                for entry in entries {
                    group.addTask {
                        (entry.appid, await SteamStoreClient.shared.details(for: entry.appid)?.name)
                    }
                }
                var result: [Int: String] = [:]
                for await (appID, name) in group where name != nil {
                    result[appID] = name
                }
                return result
            }
            trending = entries.map { TrendingGame(entry: $0, name: names[$0.appid]) }
            trendingError = nil
        } catch {
            trendingError = error.localizedDescription
        }
    }

    // MARK: - News

    private func loadNews() async {
        let sources = newsSources()
        guard !sources.isEmpty else {
            newsItems = []
            newsSourceNames = [:]
            return
        }
        newsSourceNames = Dictionary(sources, uniquingKeysWith: { first, _ in first })

        var succeededAtLeastOnce = false
        let feed = await withTaskGroup(of: [GameNewsItem]?.self) { group in
            for (appID, _) in sources {
                group.addTask {
                    try? await SteamCommunityClient.shared.news(forApp: appID)
                }
            }
            var merged: [GameNewsItem] = []
            for await items in group {
                guard let items else { continue }
                succeededAtLeastOnce = true
                merged.append(contentsOf: items)
            }
            return merged
        }

        newsItems = feed.sorted { $0.date > $1.date }
        newsError = succeededAtLeastOnce
            ? nil
            : SteamCommunityClient.CommunityError.requestFailed.localizedDescription
        await resolveCrossPostedNames()
    }

    /// Feeds occasionally carry items whose appid differs from the requested
    /// game (cross-posted announcements); resolve those names too so rows
    /// don't fall back to "App 12345".
    private func resolveCrossPostedNames() async {
        let unknown = Set(newsItems.map(\.appid)).subtracting(newsSourceNames.keys)
        guard !unknown.isEmpty else { return }
        let resolved = await withTaskGroup(of: (Int, String?).self) { group in
            for appID in unknown {
                group.addTask {
                    (appID, await SteamStoreClient.shared.details(for: appID)?.name)
                }
            }
            var result: [Int: String] = [:]
            for await (appID, name) in group where name != nil {
                result[appID] = name
            }
            return result
        }
        newsSourceNames.merge(resolved) { current, _ in current }
    }

    /// Games whose news feeds make up the timeline: the library ranked by
    /// recency then playtime, or the trending chart when the library is empty.
    private func newsSources() -> [(Int, String)] {
        let ranked = library.libraryItems.sorted { lhs, rhs in
            let lhsDate = lhs.lastPlayed ?? .distantPast
            let rhsDate = rhs.lastPlayed ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.playtimeForeverMinutes > rhs.playtimeForeverMinutes
        }
        if !ranked.isEmpty {
            return ranked.prefix(Self.maxNewsSources).map { ($0.appID, $0.name) }
        }
        return trending.prefix(10).map { ($0.entry.appid, $0.displayName) }
    }
}
