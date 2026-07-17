import Foundation
import Observation

/// Profile-page data that isn't already on GameLibraryStore: Steam level and
/// the recently-played list. The identity (PlayerSummary) itself comes from
/// GameLibraryStore.refreshRemote.
@MainActor
@Observable
final class ProfileStore {
    private(set) var steamLevel: Int?
    private(set) var recentGames: [RecentGame] = []
    private(set) var banStatus: PlayerBanStatus?
    private(set) var badges: [PlayerBadge] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastRefreshed: Date?

    private let library: GameLibraryStore

    init(library: GameLibraryStore) {
        self.library = library
    }

    func refreshIfStale() async {
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < 120 { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        guard let apiKey = KeychainService.loadAPIKey(), let steamID64 = library.activeSteamID64 else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let client = SteamWebAPIClient(apiKey: apiKey)
        do {
            async let level = client.getSteamLevel(steamID64: steamID64)
            async let recent = client.getRecentlyPlayedGames(steamID64: steamID64)
            async let bans = client.getPlayerBans(steamIDs: [steamID64])
            async let badgesFetch = client.getBadges(steamID64: steamID64)
            // The summary powers the header; make sure it exists too.
            if library.playerSummary == nil {
                await library.refreshRemote()
            }
            let (fetchedLevel, fetchedRecent, fetchedBans, fetchedBadges) = try await (level, recent, bans, badgesFetch)
            steamLevel = fetchedLevel
            recentGames = fetchedRecent
            banStatus = fetchedBans.first
            badges = fetchedBadges
            error = nil
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clear() {
        steamLevel = nil
        recentGames = []
        banStatus = nil
        badges = []
        error = nil
        lastRefreshed = nil
    }
}
