import Foundation

/// Fetches and merges a game's achievement schema (names/descriptions/icons —
/// permanent, so disk-cached indefinitely like MacCompatibilityService's
/// verdicts), the signed-in player's unlock state (fetched fresh every visit
/// since it changes as you play), and global unlock rarity (cached in memory
/// for the process lifetime — it shifts slowly, no need to persist it).
actor AchievementService {
    static let shared = AchievementService()

    private var schemaCache: [Int: [AchievementDefinition]]
    private let schemaCacheFileURL: URL
    private var globalPercentCache: [Int: [String: Double]] = [:]
    private let session = URLSession.shared

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("Mist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        schemaCacheFileURL = dir.appendingPathComponent("achievement-schemas.json")

        if let data = try? Data(contentsOf: schemaCacheFileURL),
           let stored = try? JSONDecoder().decode([String: [AchievementDefinition]].self, from: data) {
            schemaCache = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                Int(key).map { ($0, value) }
            })
        } else {
            schemaCache = [:]
        }
    }

    /// Full progress list for one app, or nil if it has no achievements at
    /// all (or the schema couldn't be resolved). Player-achieved state is
    /// simply omitted — not surfaced as an error — when the profile's game
    /// details are private; every achievement just reads as locked.
    func progress(appID: Int, steamID64: String, apiKey: String) async -> [AchievementProgress]? {
        guard let definitions = await schema(appID: appID, apiKey: apiKey), !definitions.isEmpty else {
            return nil
        }

        async let playerAchieved = fetchPlayerAchievements(appID: appID, steamID64: steamID64, apiKey: apiKey)
        async let percents = globalPercentages(appID: appID)
        let (achieved, globalPercent) = await (playerAchieved, percents)

        return definitions.map { definition in
            let unlocked = achieved[definition.apiName]
            return AchievementProgress(
                definition: definition,
                achieved: unlocked?.achieved ?? false,
                unlockDate: unlocked?.unlockDate,
                globalPercent: globalPercent[definition.apiName]
            )
        }
    }

    // MARK: - Schema (disk-cached indefinitely)

    private func schema(appID: Int, apiKey: String) async -> [AchievementDefinition]? {
        if let cached = schemaCache[appID] {
            return cached
        }
        guard let fetched = await fetchSchema(appID: appID, apiKey: apiKey) else {
            return nil
        }
        schemaCache[appID] = fetched
        saveSchemaCache()
        return fetched
    }

    private func fetchSchema(appID: Int, apiKey: String) async -> [AchievementDefinition]? {
        var components = URLComponents(string: "https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "appid", value: String(appID)),
            URLQueryItem(name: "l", value: "english")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(GetSchemaForGameResponse.self, from: data) else {
            return nil
        }
        // Games with no stats at all simply omit availableGameStats — that's
        // a confirmed "no achievements", not a failure, so cache the empty
        // result rather than re-fetching on every visit.
        return decoded.game.availableGameStats?.achievements ?? []
    }

    private func saveSchemaCache() {
        let stored = Dictionary(uniqueKeysWithValues: schemaCache.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: schemaCacheFileURL)
        }
    }

    // MARK: - Player unlock state (fetched fresh every call, not cached)

    private func fetchPlayerAchievements(
        appID: Int,
        steamID64: String,
        apiKey: String
    ) async -> [String: PlayerAchievement] {
        var components = URLComponents(string: "https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64),
            URLQueryItem(name: "appid", value: String(appID)),
            URLQueryItem(name: "l", value: "english")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(GetPlayerAchievementsResponse.self, from: data),
              decoded.playerstats.success,
              let achievements = decoded.playerstats.achievements else {
            // Private profile / no stats for this app — everything reads
            // locked rather than surfacing an error.
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: achievements.map { ($0.apiName, $0) })
    }

    // MARK: - Global rarity (in-memory cache, process lifetime only)

    private func globalPercentages(appID: Int) async -> [String: Double] {
        if let cached = globalPercentCache[appID] {
            return cached
        }
        var components = URLComponents(
            string: "https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/"
        )!
        // This endpoint is keyless and uses "gameid", not "appid".
        components.queryItems = [
            URLQueryItem(name: "gameid", value: String(appID)),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(GetGlobalAchievementPercentagesResponse.self, from: data),
              let achievements = decoded.achievementpercentages.achievements else {
            return [:]
        }
        let percents = Dictionary(uniqueKeysWithValues: achievements.map { ($0.name, $0.percent) })
        globalPercentCache[appID] = percents
        return percents
    }

    // MARK: - Wire formats

    private struct GetSchemaForGameResponse: Decodable {
        let game: Game

        struct Game: Decodable {
            let availableGameStats: AvailableGameStats?
        }

        struct AvailableGameStats: Decodable {
            let achievements: [AchievementDefinition]?
        }
    }

    private struct PlayerAchievement: Decodable {
        let apiName: String
        let achieved: Bool
        let unlockTime: Int

        enum CodingKeys: String, CodingKey {
            case apiName = "apiname"
            case achieved
            case unlockTime = "unlocktime"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            apiName = try container.decode(String.self, forKey: .apiName)
            achieved = (try container.decode(Int.self, forKey: .achieved)) != 0
            unlockTime = try container.decodeIfPresent(Int.self, forKey: .unlockTime) ?? 0
        }

        var unlockDate: Date? {
            unlockTime > 0 ? Date(timeIntervalSince1970: TimeInterval(unlockTime)) : nil
        }
    }

    private struct GetPlayerAchievementsResponse: Decodable {
        let playerstats: PlayerStats

        struct PlayerStats: Decodable {
            let success: Bool
            let achievements: [PlayerAchievement]?
        }
    }

    private struct GlobalPercentage: Decodable {
        let name: String
        let percent: Double
    }

    private struct GetGlobalAchievementPercentagesResponse: Decodable {
        let achievementpercentages: Inner

        struct Inner: Decodable {
            let achievements: [GlobalPercentage]?
        }
    }
}
