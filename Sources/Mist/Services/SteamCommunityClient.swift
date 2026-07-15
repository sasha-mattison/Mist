import Foundation

/// Keyless community/stats endpoints: per-game news (ISteamNews) and the
/// global most-played chart (ISteamChartsService). Results are cached
/// in-memory so switching tabs doesn't refetch.
actor SteamCommunityClient {
    static let shared = SteamCommunityClient()

    private let session = URLSession.shared
    private var newsCache: [Int: (fetchedAt: Date, items: [GameNewsItem])] = [:]
    private var chartCache: (fetchedAt: Date, entries: [MostPlayedEntry])?

    enum CommunityError: Error, LocalizedError {
        case requestFailed

        var errorDescription: String? {
            "Couldn't reach Steam's community services. Check your connection and try again."
        }
    }

    func news(forApp appID: Int, count: Int = 6) async throws -> [GameNewsItem] {
        if let cached = newsCache[appID], Date().timeIntervalSince(cached.fetchedAt) < 10 * 60 {
            return cached.items
        }
        var components = URLComponents(string: "https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/")!
        components.queryItems = [
            URLQueryItem(name: "appid", value: String(appID)),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "maxlength", value: "400"),
            URLQueryItem(name: "format", value: "json")
        ]
        let decoded: GetNewsForAppResponse = try await get(components)
        let items = decoded.appnews?.validItems ?? []
        newsCache[appID] = (Date(), items)
        return items
    }

    func mostPlayed() async throws -> [MostPlayedEntry] {
        if let chartCache, Date().timeIntervalSince(chartCache.fetchedAt) < 15 * 60 {
            return chartCache.entries
        }
        let components = URLComponents(string: "https://api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/")!
        let decoded: GetMostPlayedGamesResponse = try await get(components)
        let entries = decoded.response.validRanks.sorted { $0.rank < $1.rank }
        chartCache = (Date(), entries)
        return entries
    }

    private func get<T: Decodable>(_ components: URLComponents) async throws -> T {
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw CommunityError.requestFailed
        }
        return decoded
    }
}
