import Foundation
import Observation

/// Loads and groups the signed-in account's friends list. Friends require
/// both a Web API key and a known SteamID (signed-in or detected locally);
/// the page shows a setup prompt until both exist.
@MainActor
@Observable
final class FriendsStore {
    enum PresenceGroup: String, CaseIterable, Identifiable {
        case inGame = "In-Game"
        case online = "Online"
        case offline = "Offline"

        var id: String { rawValue }
    }

    struct Friend: Identifiable, Hashable {
        let steamID64: String
        let friendSince: Date?
        let summary: PlayerSummary?

        var id: String { steamID64 }

        var group: PresenceGroup {
            guard let summary else { return .offline }
            if summary.isInGame { return .inGame }
            return summary.isOnline ? .online : .offline
        }

        var displayName: String {
            summary?.personaName ?? steamID64
        }

        var profileLink: FriendProfileLink {
            FriendProfileLink(steamID64: steamID64, displayName: displayName, cachedSummary: summary)
        }
    }

    private(set) var friends: [Friend] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastRefreshed: Date?

    private let library: GameLibraryStore

    init(library: GameLibraryStore) {
        self.library = library
    }

    func refreshIfStale() async {
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < 60 { return }
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
            let entries = try await client.getFriendList(steamID64: steamID64)
            let summaries = try await Self.loadSummaries(
                client: client,
                steamIDs: entries.map(\.steamid)
            )
            friends = entries
                .map { entry in
                    Friend(
                        steamID64: entry.steamid,
                        friendSince: entry.friendSinceDate,
                        summary: summaries[entry.steamid]
                    )
                }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            error = nil
            lastRefreshed = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clear() {
        friends = []
        error = nil
        lastRefreshed = nil
    }

    func friends(in group: PresenceGroup, matching query: String) -> [Friend] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return friends.filter { friend in
            friend.group == group
                && (trimmed.isEmpty || friend.displayName.localizedCaseInsensitiveContains(trimmed))
        }
    }

    /// GetPlayerSummaries caps at 100 IDs per request; chunk and merge.
    private static func loadSummaries(
        client: SteamWebAPIClient,
        steamIDs: [String]
    ) async throws -> [String: PlayerSummary] {
        var result: [String: PlayerSummary] = [:]
        for chunkStart in stride(from: 0, to: steamIDs.count, by: 100) {
            let chunk = Array(steamIDs[chunkStart..<min(chunkStart + 100, steamIDs.count)])
            let summaries = try await client.getPlayerSummaries(steamIDs: chunk)
            for summary in summaries {
                result[summary.steamID] = summary
            }
        }
        return result
    }
}
