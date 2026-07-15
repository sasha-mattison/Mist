import Foundation

/// One announcement from ISteamNews/GetNewsForApp.
struct GameNewsItem: Decodable, Identifiable, Hashable {
    let gid: String
    let title: String
    let url: String
    let author: String?
    let contents: String?
    let feedlabel: String?
    let date: Int
    let appid: Int

    var id: String { gid }

    var publishedAt: Date {
        Date(timeIntervalSince1970: TimeInterval(date))
    }

    /// News bodies arrive as a mix of BBCode, HTML fragments, `{STEAM_*}`
    /// CDN tokens and bare URLs; boil them down to readable plain text.
    var plainExcerpt: String {
        guard var text = contents else { return "" }
        let patterns = [
            "\\{[A-Z_]+\\}\\S*",        // {STEAM_CLAN_IMAGE}/… tokens
            "\\[/?[a-zA-Z*][^\\]]*\\]", // BBCode tags
            "<[^>]+>",                  // HTML tags
            "https?://\\S+",            // bare links
            "\\\\+"                     // stray backslashes (only the slash — the next char is real text)
        ]
        for pattern in patterns {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var articleURL: URL? {
        URL(string: url)
    }
}

struct GetNewsForAppResponse: Decodable {
    let appnews: AppNews?

    struct AppNews: Decodable {
        let newsitems: [LossyDecodable<GameNewsItem>]?

        var validItems: [GameNewsItem] {
            (newsitems ?? []).compactMap(\.value)
        }
    }
}

/// One row of ISteamChartsService/GetMostPlayedGames — Steam's global
/// most-played chart. The endpoint returns appIDs only (rank, last week's
/// rank, and today's peak player count); names are resolved separately
/// through the storefront.
struct MostPlayedEntry: Decodable, Identifiable, Hashable {
    let rank: Int
    let appid: Int
    let lastWeekRank: Int?
    let peakInGame: Int?

    var id: Int { appid }

    enum CodingKeys: String, CodingKey {
        case rank, appid
        case lastWeekRank = "last_week_rank"
        case peakInGame = "peak_in_game"
    }

    /// Positions climbed since last week (negative = dropped). Nil when the
    /// game wasn't charted last week.
    var rankDelta: Int? {
        guard let lastWeekRank, lastWeekRank > 0 else { return nil }
        return lastWeekRank - rank
    }
}

struct GetMostPlayedGamesResponse: Decodable {
    let response: Inner

    struct Inner: Decodable {
        let ranks: [LossyDecodable<MostPlayedEntry>]?

        var validRanks: [MostPlayedEntry] {
            (ranks ?? []).compactMap(\.value)
        }
    }
}

/// A chart entry joined with its storefront name for display.
struct TrendingGame: Identifiable, Hashable {
    let entry: MostPlayedEntry
    let name: String?

    var id: Int { entry.appid }

    var displayName: String {
        name ?? "App \(entry.appid)"
    }

    var link: StoreAppLink {
        StoreAppLink(appID: entry.appid, name: displayName)
    }
}
