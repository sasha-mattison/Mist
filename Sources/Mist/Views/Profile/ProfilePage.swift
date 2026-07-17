import AppKit
import SwiftUI

/// The signed-in user's Steam profile: identity header with level badge,
/// aggregate library stats, recently played rail, and most-played leaderboard.
struct ProfilePage: View {
    let onOpenGame: (GameLibraryItem) -> Void
    let onOpenStoreItem: (StoreAppLink) -> Void
    let onSignIn: () -> Void
    let onSetupAPIKey: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(ProfileStore.self) private var profile
    @Environment(SettingsStore.self) private var settings
    @ViewState private var isShowingStats = false

    private var needsAPIKey: Bool { KeychainService.loadAPIKey() == nil }
    private var needsIdentity: Bool { store.activeSteamID64 == nil }
    private var effects: Bool { settings.animationsEnabled }

    var body: some View {
        Group {
            if needsAPIKey || needsIdentity {
                setupPrompt
            } else {
                content
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingStats = true
                } label: {
                    Label("Lifetime Stats", systemImage: "chart.bar.doc.horizontal")
                }
                .disabled(needsAPIKey || needsIdentity)
            }
            ToolbarItem {
                if profile.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await profile.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await profile.refreshIfStale()
        }
        .sheet(isPresented: $isShowingStats) {
            PlaytimeStatsView(
                items: store.libraryItems,
                accent: settings.accentColor,
                onDismiss: { isShowingStats = false },
                onOpenGame: onOpenGame
            )
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header
                statTiles
                recentlyPlayedSection
                mostPlayedSection
                badgesSection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = profile.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 24) {
            AvatarGlowRing(accent: settings.accentColor, animated: effects) {
                avatar
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(store.playerSummary?.personaName ?? "Steam Profile")
                        .font(.system(size: 34, weight: .bold))
                    if let flag = store.playerSummary?.countryFlag {
                        Text(flag).font(.title)
                    }
                    if let level = profile.steamLevel {
                        LevelBadge(level: level, accent: settings.accentColor)
                    }
                    if let banStatus = profile.banStatus, !banStatus.isClean {
                        BanStatusBadge(status: banStatus)
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                    Text(store.playerSummary?.statusText ?? "Loading…")
                        .font(.callout)
                        .foregroundStyle(statusColor == .secondary ? .secondary : statusColor)
                }

                if let memberSince = store.playerSummary?.memberSince {
                    Text("Member since \(memberSince.formatted(date: .long, time: .omitted))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        openProfileInBrowser()
                    } label: {
                        Label("View on Steam Community", systemImage: "safari")
                    }
                    .buttonStyle(.glass)

                    if let steamID = store.activeSteamID64 {
                        Text(steamID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .entranceEffect(index: 0, enabled: effects)
    }

    private var statusColor: Color {
        guard let summary = store.playerSummary else { return .secondary }
        if summary.isInGame { return .green }
        return summary.isOnline ? .blue : .secondary
    }

    private var avatar: some View {
        AsyncImage(url: store.playerSummary?.avatarFullURL.flatMap(URL.init(string:))) { phase in
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
        let fallback = store.activeSteamID64.map { "https://steamcommunity.com/profiles/\($0)" }
        if let urlString = store.playerSummary?.profileURL ?? fallback,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Stats

    private var totalPlaytimeMinutes: Int {
        store.libraryItems.reduce(0) { $0 + $1.playtimeForeverMinutes }
    }

    private var twoWeekMinutes: Int {
        store.libraryItems.reduce(0) { $0 + $1.playtime2WeeksMinutes }
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
        var tiles: [(String, String, String)] = [
            ("Games", "\(store.libraryItems.count)", "square.grid.2x2"),
            ("Total Playtime", Formatters.playtime(minutes: totalPlaytimeMinutes), "clock"),
            ("Last 2 Weeks", Formatters.playtime(minutes: twoWeekMinutes), "chart.line.uptrend.xyaxis")
        ]
        if let level = profile.steamLevel {
            tiles.append(("Steam Level", "\(level)", "star.circle"))
        }
        tiles.append(("Installed", "\(store.installedApps.count)", "internaldrive"))
        return tiles
    }

    // MARK: - Recently played

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if !profile.recentGames.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Recently Played")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(Array(profile.recentGames.enumerated()), id: \.element.id) { index, game in
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
        let top = store.libraryItems
            .filter { $0.playtimeForeverMinutes > 0 }
            .sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
            .prefix(8)
        if !top.isEmpty {
            let maxMinutes = top.first?.playtimeForeverMinutes ?? 1
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Most Played")
                VStack(spacing: 6) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { index, item in
                        MostPlayedRow(
                            rank: index + 1,
                            name: item.name,
                            playtimeMinutes: item.playtimeForeverMinutes,
                            fraction: Double(item.playtimeForeverMinutes) / Double(max(maxMinutes, 1)),
                            accent: settings.accentColor,
                            effects: effects,
                            index: index
                        ) {
                            onOpenGame(item)
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

    // MARK: - Badges

    /// Most-recently-earned first, capped so a badge-heavy account doesn't
    /// fire dozens of simultaneous lazy name lookups (this VStack isn't
    /// virtualized, so every row's `.task` runs as soon as the section
    /// appears — same reasoning DLCRow's callers already lean on).
    private var displayedBadges: [PlayerBadge] {
        Array(profile.badges.sorted { ($0.completionDate ?? .distantPast) > ($1.completionDate ?? .distantPast) }.prefix(15))
    }

    @ViewBuilder
    private var badgesSection: some View {
        if !profile.badges.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Badges")
                if profile.badges.count > displayedBadges.count {
                    Text("Showing \(displayedBadges.count) most recent of \(profile.badges.count).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 0) {
                    ForEach(Array(displayedBadges.enumerated()), id: \.element.id) { index, badge in
                        if index > 0 { Divider() }
                        BadgeRow(badge: badge)
                    }
                }
                .padding(10)
                .glassEffect(in: .rect(cornerRadius: 14))
            }
        }
    }

    // MARK: - Setup prompt

    private var setupPrompt: some View {
        ContentUnavailableView {
            Label("Connect to see your profile", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            Text(needsIdentity
                 ? "Sign in with Steam so we know whose profile to show."
                 : "Profile stats come from the Steam Web API — add your API key to continue.")
        } actions: {
            if needsIdentity {
                Button("Sign in with Steam", action: onSignIn)
                    .buttonStyle(.borderedProminent)
            }
            if needsAPIKey {
                Button("Add Web API Key", action: onSetupAPIKey)
            }
        }
    }
}

