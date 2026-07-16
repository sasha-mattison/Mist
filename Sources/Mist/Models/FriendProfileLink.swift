import Foundation

/// Navigation token for pushing a friend's profile page onto the
/// NavigationStack from anywhere in the app (Friends list, Community
/// activity, …). Carries whatever PlayerSummary is already cached so the
/// header can render instantly while FriendProfilePage fetches fresh data.
struct FriendProfileLink: Hashable {
    let steamID64: String
    let displayName: String
    let cachedSummary: PlayerSummary?
}
