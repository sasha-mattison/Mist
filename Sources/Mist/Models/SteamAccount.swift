import Foundation

struct SteamAccount: Identifiable, Hashable {
    let steamID64: String
    let accountName: String
    let personaName: String
    let isAutoLogin: Bool

    var id: String { steamID64 }
}
