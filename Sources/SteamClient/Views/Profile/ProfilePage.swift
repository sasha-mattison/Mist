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
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header
                statTiles
                recentlyPlayedSection
                mostPlayedSection
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
                            RecentGameCard(game: game, effects: effects, index: index) {
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
                            item: item,
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

// MARK: - Components

private struct LevelBadge: View {
    let level: Int
    let accent: Color

    var body: some View {
        Text("LVL \(level)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(accent.gradient)
            )
            .shadow(color: accent.opacity(0.4), radius: 6)
    }
}

private struct RecentGameCard: View {
    let game: RecentGame
    let effects: Bool
    let index: Int
    let onOpen: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(game.appid)/header.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 240, height: 112)
                .shineSweep(trigger: isHovering, enabled: effects)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name ?? "App \(game.appid)")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let recent = game.playtime2WeeksMinutes, recent > 0 {
                        Text("\(Formatters.playtime(minutes: recent)) past two weeks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 240)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverTilt(enabled: effects)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.28 : 0.1), radius: isHovering ? 12 : 4, y: isHovering ? 7 : 2)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .entranceEffect(index: index, enabled: effects)
    }
}

private struct MostPlayedRow: View {
    let rank: Int
    let item: GameLibraryItem
    let fraction: Double
    let accent: Color
    let effects: Bool
    let index: Int
    let onOpen: () -> Void

    @ViewState private var isHovering = false
    @ViewState private var barVisible = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Text("\(rank)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(rank <= 3 ? AnyShapeStyle(accent) : AnyShapeStyle(.tertiary))
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(item.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.playtime(minutes: item.playtimeForeverMinutes))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(accent.gradient)
                                .frame(width: geo.size.width * fraction * (barVisible ? 1 : 0))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .entranceEffect(index: index, enabled: effects)
        .onAppear {
            guard effects else {
                barVisible = true
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(Double(index) * 0.06 + 0.15)) {
                barVisible = true
            }
        }
    }
}
