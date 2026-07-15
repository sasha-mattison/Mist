import Foundation

/// One entry from IPlayerService/GetOwnedGames.
struct OwnedGame: Decodable {
    let appid: Int
    let name: String?
    let playtimeForeverMinutes: Int
    let playtime2WeeksMinutes: Int?
    let rtimeLastPlayed: Int?
    let imgIconURL: String?

    enum CodingKeys: String, CodingKey {
        case appid
        case name
        case playtimeForeverMinutes = "playtime_forever"
        case playtime2WeeksMinutes = "playtime_2weeks"
        case rtimeLastPlayed = "rtime_last_played"
        case imgIconURL = "img_icon_url"
    }

    /// rtime_last_played is a unix timestamp; 0 means never played.
    var lastPlayed: Date? {
        guard let rtimeLastPlayed, rtimeLastPlayed > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(rtimeLastPlayed))
    }
}
