import SwiftUI

/// Steam's global most-played chart: ranked rows with live concurrent and
/// daily-peak player counts. Rows push the app's own store detail page.
struct CommunityTrendingView: View {
    let searchText: String
    let onOpen: (StoreAppLink) -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(CommunityStore.self) private var community
    @Environment(SettingsStore.self) private var settings

    private var effects: Bool { settings.animationsEnabled }

    private var visibleGames: [TrendingGame] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return community.trending }
        return community.trending.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if community.trending.isEmpty && community.isLoading {
                ProgressView("Loading the most-played chart…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if community.trending.isEmpty, let error = community.trendingError {
                ContentUnavailableView {
                    Label("Couldn't load the chart", systemImage: "chart.line.downtrend.xyaxis")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await community.refresh() }
                    }
                }
            } else if visibleGames.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                let games = visibleGames
                let maxPeak = community.trending.compactMap(\.entry.peakInGame).max() ?? 1
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    TrendingRow(
                        game: game,
                        fraction: Double(game.entry.peakInGame ?? 0) / Double(max(maxPeak, 1)),
                        isInLibrary: store.libraryItems.contains { $0.appID == game.entry.appid },
                        accent: settings.accentColor,
                        effects: effects,
                        index: index,
                        onOpen: { onOpen(game.link) }
                    )
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(.secondary)
                Text("Most played on Steam, by today's peak player count.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
            .padding(.top, 8)
        }
    }
}

// MARK: - Row

private struct TrendingRow: View {
    let game: TrendingGame
    let fraction: Double
    let isInLibrary: Bool
    let accent: Color
    let effects: Bool
    let index: Int
    let onOpen: () -> Void

    @ViewState private var isHovering = false
    @ViewState private var barVisible = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Text("\(game.entry.rank)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(game.entry.rank <= 3 ? AnyShapeStyle(accent) : AnyShapeStyle(.tertiary))
                    .frame(width: 34, alignment: .trailing)

                AsyncImage(url: SteamCapsuleArt.url(appID: game.entry.appid)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 107, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(game.displayName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if isInLibrary {
                            Label("In Library", systemImage: "checkmark")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let peak = game.entry.peakInGame {
                            Text("\(peak.formatted()) peak today")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
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

                    rankMovement
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
        .contextMenu {
            Button("View Store Page", systemImage: "cart", action: onOpen)
            Button("Open in Browser", systemImage: "safari") {
                GameLaunchService.openStorePage(appID: game.entry.appid)
            }
            Button("Open Community Hub", systemImage: "person.3") {
                GameLaunchService.openCommunityHub(appID: game.entry.appid)
            }
        }
        .onAppear {
            guard effects else {
                barVisible = true
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(Double(index % 12) * 0.05 + 0.1)) {
                barVisible = true
            }
        }
    }

    @ViewBuilder
    private var rankMovement: some View {
        if let delta = game.entry.rankDelta {
            if delta > 0 {
                Label("Up \(delta) since last week", systemImage: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if delta < 0 {
                Label("Down \(-delta) since last week", systemImage: "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Label("Holding steady", systemImage: "equal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } else {
            Label("New on the chart", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(.tint)
        }
    }
}
