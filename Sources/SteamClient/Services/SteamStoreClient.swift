import Foundation

/// Fetches storefront metadata (description, genres, screenshots, …) from
/// the unauthenticated appdetails endpoint, with an in-memory cache so
/// revisiting a detail page is instant. Results are keyed per app and cached
/// even on "success: false" (as nil) so delisted titles aren't re-fetched on
/// every visit.
actor SteamStoreClient {
    static let shared = SteamStoreClient()

    private var cache: [Int: GameDetails?] = [:]
    private var featuredCache: (fetchedAt: Date, value: FeaturedCategories)?
    private let session = URLSession.shared

    /// Storefront region for prices; Steam falls back gracefully for
    /// unsupported codes.
    private static var countryCode: String {
        Locale.current.region?.identifier ?? "US"
    }

    enum StoreError: Error, LocalizedError {
        case requestFailed

        var errorDescription: String? {
            "Couldn't reach the Steam store. Check your connection and try again."
        }
    }

    /// Featured rails (specials, top sellers, …), cached for 15 minutes.
    func featuredCategories() async throws -> FeaturedCategories {
        if let featuredCache, Date().timeIntervalSince(featuredCache.fetchedAt) < 15 * 60 {
            return featuredCache.value
        }
        var components = URLComponents(string: "https://store.steampowered.com/api/featuredcategories")!
        components.queryItems = [
            URLQueryItem(name: "l", value: "english"),
            URLQueryItem(name: "cc", value: Self.countryCode)
        ]
        let categories: FeaturedCategories = try await get(components)
        featuredCache = (Date(), categories)
        return categories
    }

    func search(term: String) async throws -> [StoreSearchResult] {
        var components = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "l", value: "english"),
            URLQueryItem(name: "cc", value: Self.countryCode)
        ]
        let response: StoreSearchResponse = try await get(components)
        return response.validItems
    }

    private func get<T: Decodable>(_ components: URLComponents) async throws -> T {
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw StoreError.requestFailed
        }
        return decoded
    }

    func details(for appID: Int) async -> GameDetails? {
        if let cached = cache[appID] {
            return cached
        }
        let fetched = await fetch(appID: appID)
        cache[appID] = fetched
        return fetched
    }

    private func fetch(appID: Int) async -> GameDetails? {
        var components = URLComponents(string: "https://store.steampowered.com/api/appdetails")!
        components.queryItems = [
            URLQueryItem(name: "appids", value: String(appID)),
            URLQueryItem(name: "l", value: "english"),
            URLQueryItem(name: "cc", value: Self.countryCode)
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        // Response shape: { "<appid>": { "success": Bool, "data": {...} } }
        guard let envelope = try? JSONDecoder().decode([String: Envelope].self, from: data) else {
            return nil
        }
        return envelope[String(appID)]?.data
    }

    private struct Envelope: Decodable {
        let success: Bool
        let data: GameDetails?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            success = try container.decode(Bool.self, forKey: .success)
            // "data" is `[]` (not absent) for some delisted apps — tolerate
            // any non-object payload instead of failing the whole decode.
            data = try? container.decodeIfPresent(GameDetails.self, forKey: .data)
        }

        enum CodingKeys: String, CodingKey {
            case success, data
        }
    }
}
