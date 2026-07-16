import AppKit
import SwiftUI

/// A friend's Steam profile, viewed in-app instead of opening a browser tab.
/// Uses the same Web API endpoints as ProfilePage (GetPlayerSummaries,
/// GetSteamLevel, GetRecentlyPlayedGames, GetOwnedGames) applied to the
/// friend's SteamID64 instead of the signed-in account's. Those game-data
/// endpoints silently return empty results for a profile whose game details
/// are private, so this degrades to a name/avatar/status-only header rather
/// than erroring.
struct FriendProfilePage: View {
    let link: FriendProfileLink
    let onOpenGame: (GameLibraryItem) -> Void
    let onOpenStoreItem: (StoreAppLink) -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    @ViewState private var summary: PlayerSummary?
    @ViewState private var steamLevel: Int?
    @ViewState private var recentGames: [RecentGame] = []
    @ViewState private var ownedGames: [OwnedGame] = []
    @ViewState private var isLoading = true
    @ViewState private var error: String?

    private var effects: Bool { settings.animationsEnabled }

    init(link: FriendProfileLink, onOpenGame: @escaping (GameLibraryItem) -> Void, onOpenStoreItem: @escaping (StoreAppLink) -> Void) {
        self.link = link
        self.onOpenGame = onOpenGame
        self.onOpenStoreItem = onOpenStoreItem
        _summary = ViewState(wrappedValue: link.cachedSummary)
    }

    var body: some View {
        Group {
            if summary == nil, isLoading {
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if summary == nil, let error {
                ContentUnavailableView {
                    Label("Couldn't load profile", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await load() }
                    }
                }
            } else {
                content
            }
        }
        .navigationTitle(summary?.personaName ?? link.displayName)
        .toolbar {
            ToolbarItem {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await load() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task(id: link.steamID64) {
            await load()
        }
    }

    private func load() async {
        guard let apiKey = KeychainService.loadAPIKey() else {
            error = "Add a Steam Web API key in Settings to view profiles in the app."
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        let client = SteamWebAPIClient(apiKey: apiKey)
        do {
            async let summaries = client.getPlayerSummaries(steamIDs: [link.steamID64])
            async let level = client.getSteamLevel(steamID64: link.steamID64)
            async let recent = client.getRecentlyPlayedGames(steamID64: link.steamID64)
            async let owned = client.getOwnedGames(steamID64: link.steamID64)
            let (fetchedSummaries, fetchedLevel, fetchedRecent, fetchedOwned) = try await (summaries, level, recent, owned)
            summary = fetchedSummaries.first ?? summary
            steamLevel = fetchedLevel
            recentGames = fetchedRecent
            ownedGames = fetchedOwned
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header
                if !ownedGames.isEmpty || steamLevel != nil {
                    statTiles
                }
                recentlyPlayedSection
                mostPlayedSection
                libraryComparisonSection
                if isPrivate {
                    privacyNote
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
                    .padding(.top, 8)
            }
        }
    }

    private var isPrivate: Bool {
        !isLoading && error == nil && ownedGames.isEmpty && recentGames.isEmpty && steamLevel == nil
    }

    private var privacyNote: some View {
        Label("This player's game details are private.", systemImage: "lock")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 24) {
            AvatarGlowRing(accent: settings.accentColor, animated: effects) {
                avatar
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(summary?.personaName ?? link.displayName)
                        .font(.system(size: 34, weight: .bold))
                    if let flag = summary?.countryFlag {
                        Text(flag).font(.title)
                    }
                    if let steamLevel {
                        LevelBadge(level: steamLevel, accent: settings.accentColor)
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                    Text(summary?.statusText ?? "Loading…")
                        .font(.callout)
                        .foregroundStyle(statusColor == .secondary ? .secondary : statusColor)
                }

                if let memberSince = summary?.memberSince {
                    Text("Member since \(memberSince.formatted(date: .long, time: .omitted))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button(action: openProfileInBrowser) {
                        Label("View on Steam Community", systemImage: "safari")
                    }
                    .buttonStyle(.glass)

                    Button {
                        GameLaunchService.openChat(steamID64: link.steamID64)
                    } label: {
                        Label("Message in Steam", systemImage: "bubble.left")
                    }
                    .buttonStyle(.glass)

                    Text(link.steamID64)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .entranceEffect(index: 0, enabled: effects)
    }

    private var statusColor: Color {
        guard let summary else { return .secondary }
        if summary.isInGame { return .green }
        return summary.isOnline ? .blue : .secondary
    }

    private var avatar: some View {
        AsyncImage(url: summary?.avatarFullURL.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }

    private func openProfileInBrowser() {
        let fallback = "https://steamcommunity.com/profiles/\(link.steamID64)"
        if let url = URL(string: summary?.profileURL ?? fallback) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Stats

    private var totalPlaytimeMinutes: Int {
        ownedGames.reduce(0) { $0 + $1.playtimeForeverMinutes }
    }

    private var twoWeekMinutes: Int {
        ownedGames.reduce(0) { $0 + ($1.playtime2WeeksMinutes ?? 0) }
    }

    private var statTiles: some View {
        GlassEffectContainer {
            HStack(spacing: 14) {
                let tiles = statTileData
                ForEach(Array(tiles.enumerated()), id: \.element.0) { index, tile in
                    StatTile(title: tile.0, value: tile.1, systemImage: tile.2)
                        .entranceEffect(index: index + 1, enabled: effects)
                }
            }
        }
    }

    private var statTileData: [(String, String, String)] {
        var tiles: [(String, String, String)] = []
        if let steamLevel {
            tiles.append(("Steam Level", "\(steamLevel)", "star.circle"))
        }
        if !ownedGames.isEmpty {
            tiles.append(("Games", "\(ownedGames.count)", "square.grid.2x2"))
            tiles.append(("Total Playtime", Formatters.playtime(minutes: totalPlaytimeMinutes), "clock"))
            tiles.append(("Last 2 Weeks", Formatters.playtime(minutes: twoWeekMinutes), "chart.line.uptrend.xyaxis"))
        }
        return tiles
    }

    // MARK: - Recently played

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if !recentGames.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Recently Played")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(recentGames.enumerated()), id: \.element.id) { index, game in
                            RecentGameCard(
                                appID: game.appid,
                                name: game.name ?? "App \(game.appid)",
                                subtitle: game.playtime2WeeksMinutes.flatMap { $0 > 0 ? "\(Formatters.playtime(minutes: $0)) past two weeks" : nil },
                                effects: effects,
                                index: index
                            ) {
                                open(appID: game.appid, name: game.name ?? "App \(game.appid)")
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Most played

    @ViewBuilder
    private var mostPlayedSection: some View {
        let top = ownedGames
            .filter { $0.playtimeForeverMinutes > 0 }
            .sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
            .prefix(8)
        if !top.isEmpty {
            let maxMinutes = top.first?.playtimeForeverMinutes ?? 1
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Most Played")
                VStack(spacing: 6) {
                    ForEach(Array(top.enumerated()), id: \.element.appid) { index, game in
                        MostPlayedRow(
                            rank: index + 1,
                            name: game.name ?? "App \(game.appid)",
                            playtimeMinutes: game.playtimeForeverMinutes,
                            fraction: Double(game.playtimeForeverMinutes) / Double(max(maxMinutes, 1)),
                            accent: settings.accentColor,
                            effects: effects,
                            index: index
                        ) {
                            open(appID: game.appid, name: game.name ?? "App \(game.appid)")
                        }
                    }
                }
            }
        }
    }

    private func open(appID: Int, name: String) {
        if let item = store.libraryItems.first(where: { $0.appID == appID }) {
            onOpenGame(item)
        } else {
            onOpenStoreItem(StoreAppLink(appID: appID, name: name))
        }
    }

    // MARK: - Library comparison

    private var yourOwnedAppIDs: Set<Int> {
        Set(store.libraryItems.map(\.appID))
    }

    private var inCommonCount: Int {
        ownedGames.filter { yourOwnedAppIDs.contains($0.appid) }.count
    }

    /// Games they own that you don't, ranked by their playtime — a simple
    /// "you might like this" signal since it reflects what they actually play.
    private var recommendations: [OwnedGame] {
        Array(
            ownedGames
                .filter { !yourOwnedAppIDs.contains($0.appid) && $0.playtimeForeverMinutes > 0 }
                .sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
                .prefix(5)
        )
    }

    @ViewBuilder
    private var libraryComparisonSection: some View {
        if !ownedGames.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Library Comparison")
                GlassEffectContainer {
                    HStack(spacing: 14) {
                        StatTile(title: "In Common", value: "\(inCommonCount)", systemImage: "person.2.fill")
                        StatTile(title: "They Have", value: "\(ownedGames.count - inCommonCount)", systemImage: "arrow.down.circle")
                        StatTile(title: "You Have", value: "\(store.libraryItems.count - inCommonCount)", systemImage: "arrow.up.circle")
                    }
                }
                if !recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You might like")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            ForEach(recommendations, id: \.appid) { game in
                                FriendGameRow(
                                    name: game.name ?? "App \(game.appid)",
                                    playtimeMinutes: game.playtimeForeverMinutes
                                ) {
                                    open(appID: game.appid, name: game.name ?? "App \(game.appid)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FriendGameRow: View {
    let name: String
    let playtimeMinutes: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack {
                Text(name)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
                Text(Formatters.playtime(minutes: playtimeMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
