import Foundation

/// Rich per-game metadata from the public Steam storefront
/// (store.steampowered.com/api/appdetails). No API key required — this is a
/// separate, unauthenticated surface from the Steam Web API.
struct GameDetails: Decodable {
    let name: String?
    let shortDescription: String?
    let aboutTheGame: String?
    let headerImageURL: String?
    let developers: [String]?
    let publishers: [String]?
    let genres: [Genre]?
    let releaseDate: ReleaseDate?
    let metacritic: Metacritic?
    let screenshots: [Screenshot]?
    let platforms: Platforms?
    let website: String?
    let isFree: Bool?
    let priceOverview: PriceOverview?

    struct Genre: Decodable, Hashable {
        let description: String
    }

    struct PriceOverview: Decodable {
        let currency: String?
        let initial: Int?
        let final: Int?
        let discountPercent: Int?
        let initialFormatted: String?
        let finalFormatted: String?

        enum CodingKeys: String, CodingKey {
            case currency, initial, final
            case discountPercent = "discount_percent"
            case initialFormatted = "initial_formatted"
            case finalFormatted = "final_formatted"
        }

        var hasDiscount: Bool { (discountPercent ?? 0) > 0 }

        /// Steam's *_formatted strings are sometimes empty; fall back to
        /// formatting the integer-cents value locally.
        var finalPriceText: String? {
            if let finalFormatted, !finalFormatted.isEmpty { return finalFormatted }
            guard let final else { return nil }
            return Formatters.price(cents: final, currencyCode: currency)
        }

        var initialPriceText: String? {
            if let initialFormatted, !initialFormatted.isEmpty { return initialFormatted }
            guard let initial else { return nil }
            return Formatters.price(cents: initial, currencyCode: currency)
        }
    }

    struct ReleaseDate: Decodable {
        let comingSoon: Bool
        let date: String

        enum CodingKeys: String, CodingKey {
            case comingSoon = "coming_soon"
            case date
        }
    }

    struct Metacritic: Decodable {
        let score: Int
        let url: String?
    }

    struct Screenshot: Decodable, Identifiable {
        let id: Int
        let pathThumbnail: String
        let pathFull: String

        enum CodingKeys: String, CodingKey {
            case id
            case pathThumbnail = "path_thumbnail"
            case pathFull = "path_full"
        }
    }

    struct Platforms: Decodable {
        let windows: Bool
        let mac: Bool
        let linux: Bool

        var names: [String] {
            var result: [String] = []
            if mac { result.append("macOS") }
            if windows { result.append("Windows") }
            if linux { result.append("Linux") }
            return result
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case shortDescription = "short_description"
        case aboutTheGame = "about_the_game"
        case headerImageURL = "header_image"
        case developers
        case publishers
        case genres
        case releaseDate = "release_date"
        case metacritic
        case screenshots
        case platforms
        case website
        case isFree = "is_free"
        case priceOverview = "price_overview"
    }

    /// `about_the_game` arrives as storefront HTML; the detail page renders
    /// plain text, so tags are stripped and common entities decoded here.
    var aboutText: String? {
        guard let aboutTheGame, !aboutTheGame.isEmpty else { return nil }
        var text = aboutTheGame
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|h1|h2|h3|li|ul)>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&nbsp;": " "]
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
