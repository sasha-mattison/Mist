import Foundation

/// Static definition of one achievement from GetSchemaForGame — name,
/// description and icons don't change, so these are cached indefinitely per
/// app by AchievementService.
struct AchievementDefinition: Hashable {
    let apiName: String
    let displayName: String
    let description: String?
    let icon: String?
    let iconGray: String?
    let hidden: Bool

    enum CodingKeys: String, CodingKey {
        case apiName = "name"
        case displayName
        case description
        case icon
        case iconGray = "icongray"
        case hidden
    }
}

extension AchievementDefinition: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiName = try container.decode(String.self, forKey: .apiName)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? apiName
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iconGray = try container.decodeIfPresent(String.self, forKey: .iconGray)
        // Steam's wire format uses 0/1; our own disk cache round-trips as a
        // plain JSON bool — tolerate either.
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: .hidden) {
            hidden = intValue != 0
        } else {
            hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(apiName, forKey: .apiName)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(iconGray, forKey: .iconGray)
        try container.encode(hidden, forKey: .hidden)
    }
}

/// One achievement merged with the signed-in player's unlock state and
/// (when available) its global unlock rarity.
struct AchievementProgress: Identifiable, Hashable {
    let definition: AchievementDefinition
    let achieved: Bool
    let unlockDate: Date?
    /// Percentage of all players who have unlocked this achievement, or nil
    /// if the global stats call failed/hasn't resolved yet.
    let globalPercent: Double?

    var id: String { definition.apiName }
}
