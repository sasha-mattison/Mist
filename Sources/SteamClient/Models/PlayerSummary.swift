import Foundation

/// One entry from ISteamUser/GetPlayerSummaries.
struct PlayerSummary: Decodable, Identifiable, Hashable {
    let steamID: String
    let personaName: String
    let avatarFullURL: String?
    /// 0 offline, 1 online, 2 busy, 3 away, 4 snooze, 5 looking to trade,
    /// 6 looking to play. Absent for private profiles.
    let personaState: Int?
    /// Name of the game currently being played, when in-game and visible.
    let gameExtraInfo: String?
    let gameID: String?
    let lastLogoff: Int?
    let profileURL: String?
    /// Account creation unix timestamp; only present for public profiles.
    let timeCreated: Int?
    let locCountryCode: String?

    var id: String { steamID }

    enum CodingKeys: String, CodingKey {
        case steamID = "steamid"
        case personaName = "personaname"
        case avatarFullURL = "avatarfull"
        case personaState = "personastate"
        case gameExtraInfo = "gameextrainfo"
        case gameID = "gameid"
        case lastLogoff = "lastlogoff"
        case profileURL = "profileurl"
        case timeCreated = "timecreated"
        case locCountryCode = "loccountrycode"
    }

    var memberSince: Date? {
        guard let timeCreated, timeCreated > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timeCreated))
    }

    /// Regional-indicator flag for the profile's country, e.g. "🇨🇦".
    var countryFlag: String? {
        guard let locCountryCode, locCountryCode.count == 2 else { return nil }
        let base: UInt32 = 0x1F1E6
        var flag = ""
        for scalar in locCountryCode.uppercased().unicodeScalars {
            guard ("A"..."Z").contains(Character(scalar)),
                  let indicator = Unicode.Scalar(base + scalar.value - Unicode.Scalar("A").value) else {
                return nil
            }
            flag.unicodeScalars.append(indicator)
        }
        return flag
    }

    var isInGame: Bool { gameID != nil || gameExtraInfo != nil }
    var isOnline: Bool { (personaState ?? 0) != 0 }

    var lastLogoffDate: Date? {
        guard let lastLogoff, lastLogoff > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(lastLogoff))
    }

    /// Human-readable presence, e.g. "Playing Dota 2", "Away", "Last online 3d ago".
    var statusText: String {
        if let gameExtraInfo {
            return "Playing \(gameExtraInfo)"
        }
        if isInGame {
            return "In-Game"
        }
        switch personaState ?? 0 {
        case 1: return "Online"
        case 2: return "Busy"
        case 3: return "Away"
        case 4: return "Snooze"
        case 5: return "Looking to Trade"
        case 6: return "Looking to Play"
        default:
            if let lastLogoffDate {
                return "Last online \(Formatters.lastPlayed.localizedString(for: lastLogoffDate, relativeTo: .now))"
            }
            return "Offline"
        }
    }
}
