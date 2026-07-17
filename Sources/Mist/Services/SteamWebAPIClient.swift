import Foundation

/// Thin async/await client for the Steam Web API.
struct SteamWebAPIClient {
    let apiKey: String

    private let session = URLSession.shared
    private let baseURL = URL(string: "https://api.steampowered.com")!

    func getOwnedGames(steamID64: String) async throws -> [OwnedGame] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("IPlayerService/GetOwnedGames/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "include_appinfo", value: "true"),
            URLQueryItem(name: "include_played_free_games", value: "true")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetOwnedGamesResponse.self, from: data)
        return decoded.response.games ?? []
    }

    func getPlayerSummaries(steamIDs: [String]) async throws -> [PlayerSummary] {
        guard !steamIDs.isEmpty else { return [] }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ISteamUser/GetPlayerSummaries/v0002/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamids", value: steamIDs.joined(separator: ","))
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetPlayerSummariesResponse.self, from: data)
        return decoded.response.players
    }

    func getFriendList(steamID64: String) async throws -> [FriendEntry] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ISteamUser/GetFriendList/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64),
            URLQueryItem(name: "relationship", value: "friend")
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetFriendListResponse.self, from: data)
        return decoded.friendslist?.friends ?? []
    }

    func getSteamLevel(steamID64: String) async throws -> Int? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("IPlayerService/GetSteamLevel/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64)
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetSteamLevelResponse.self, from: data)
        return decoded.response.playerLevel
    }

    func getRecentlyPlayedGames(steamID64: String) async throws -> [RecentGame] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("IPlayerService/GetRecentlyPlayedGames/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64)
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetRecentlyPlayedGamesResponse.self, from: data)
        return decoded.response.games ?? []
    }

    func getBadges(steamID64: String) async throws -> [PlayerBadge] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("IPlayerService/GetBadges/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamID64)
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetBadgesResponse.self, from: data)
        return decoded.response.badges ?? []
    }

    /// Unlike the other endpoints here, the response isn't nested under
    /// "response" — Steam returns `{"players": [...]}` directly at the top
    /// level for this one.
    func getPlayerBans(steamIDs: [String]) async throws -> [PlayerBanStatus] {
        guard !steamIDs.isEmpty else { return [] }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("ISteamUser/GetPlayerBans/v1/"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamids", value: steamIDs.joined(separator: ","))
        ]
        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GetPlayerBansResponse.self, from: data)
        return decoded.players
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw SteamWebAPIError.httpStatus(http.statusCode)
        }
    }
}

enum SteamWebAPIError: Error, LocalizedError {
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .httpStatus(401):
            return "Steam returned 401 Unauthorized — the profile's friends list may be private, or the API key is invalid."
        case .httpStatus(403):
            return "Steam rejected the API key (403 Forbidden). Double-check the key from steamcommunity.com/dev/apikey."
        case .httpStatus(let code):
            return "Steam Web API returned HTTP \(code)"
        }
    }
}

/// One entry from ISteamUser/GetFriendList.
struct FriendEntry: Decodable {
    let steamid: String
    let friendSince: Int?

    enum CodingKeys: String, CodingKey {
        case steamid
        case friendSince = "friend_since"
    }

    var friendSinceDate: Date? {
        guard let friendSince, friendSince > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(friendSince))
    }
}

private struct GetFriendListResponse: Decodable {
    let friendslist: Inner?

    struct Inner: Decodable {
        let friends: [FriendEntry]?
    }
}

/// One entry from IPlayerService/GetRecentlyPlayedGames.
struct RecentGame: Decodable, Identifiable, Hashable {
    let appid: Int
    let name: String?
    let playtime2WeeksMinutes: Int?
    let playtimeForeverMinutes: Int

    var id: Int { appid }

    enum CodingKeys: String, CodingKey {
        case appid, name
        case playtime2WeeksMinutes = "playtime_2weeks"
        case playtimeForeverMinutes = "playtime_forever"
    }
}

private struct GetSteamLevelResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let playerLevel: Int?

        enum CodingKeys: String, CodingKey {
            case playerLevel = "player_level"
        }
    }
}

private struct GetRecentlyPlayedGamesResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let games: [RecentGame]?
    }
}

private struct GetOwnedGamesResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let gameCount: Int?
        let games: [OwnedGame]?

        enum CodingKeys: String, CodingKey {
            case gameCount = "game_count"
            case games
        }
    }
}

private struct GetPlayerSummariesResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let players: [PlayerSummary]
    }
}

/// One entry from ISteamUser/GetPlayerBans — VAC/game/community/trade-ban
/// status. Shown as a trust indicator only when something's actually
/// flagged; a clean record intentionally renders nothing rather than a
/// reassuring badge nobody needs.
struct PlayerBanStatus: Decodable {
    let steamID: String
    let communityBanned: Bool
    let vacBanned: Bool
    let numberOfVACBans: Int
    let numberOfGameBans: Int
    let daysSinceLastBan: Int
    let economyBan: String

    enum CodingKeys: String, CodingKey {
        case steamID = "SteamId"
        case communityBanned = "CommunityBanned"
        case vacBanned = "VACBanned"
        case numberOfVACBans = "NumberOfVACBans"
        case numberOfGameBans = "NumberOfGameBans"
        case daysSinceLastBan = "DaysSinceLastBan"
        case economyBan = "EconomyBan"
    }

    var isClean: Bool {
        !vacBanned && !communityBanned && numberOfGameBans == 0 && economyBan == "none"
    }
}

private struct GetPlayerBansResponse: Decodable {
    let players: [PlayerBanStatus]
}

/// One entry from IPlayerService/GetBadges. `appID` is present for
/// game-specific (trading card) badges and absent for special/community
/// badges (e.g. sale event badges) — Steam's API has no display-name lookup
/// for those, so callers fall back to a generic label for them.
struct PlayerBadge: Decodable, Identifiable {
    let badgeID: Int
    let level: Int
    let completionTime: Int
    let xp: Int
    let appID: Int?

    enum CodingKeys: String, CodingKey {
        case badgeID = "badgeid"
        case level
        case completionTime = "completion_time"
        case xp
        case appID = "appid"
    }

    /// Not globally unique across all badge kinds (badgeid alone can repeat
    /// per-game), so pair with appid where present.
    var id: String { "\(badgeID)-\(appID ?? 0)" }

    var completionDate: Date? {
        completionTime > 0 ? Date(timeIntervalSince1970: TimeInterval(completionTime)) : nil
    }
}

private struct GetBadgesResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let badges: [PlayerBadge]?
    }
}
