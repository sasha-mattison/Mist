import SwiftUI

/// Lifetime library stats, purely derived from data GameLibraryStore already
/// has — no new network calls. Not a true year-in-review: Steam's Web API
/// only exposes cumulative-forever and last-2-weeks playtime, no
/// monthly/yearly breakdown, so this is a snapshot rather than a trend.
struct PlaytimeStatsView: View {
    let items: [GameLibraryItem]
    let accent: Color
    let onDismiss: () -> Void
    let onOpenGame: (GameLibraryItem) -> Void

    private var playedItems: [GameLibraryItem] {
        items.filter { $0.playtimeForeverMinutes > 0 }
    }

    private var totalMinutes: Int {
        items.reduce(0) { $0 + $1.playtimeForeverMinutes }
    }

    private var neverPlayedPercent: Int {
        guard !items.isEmpty else { return 0 }
        let neverPlayed = items.count - playedItems.count
        return Int((Double(neverPlayed) / Double(items.count) * 100).rounded())
    }

    private var longestSincePlayed: GameLibraryItem? {
        playedItems
            .filter { $0.lastPlayed != nil }
            .min { ($0.lastPlayed ?? .distantFuture) < ($1.lastPlayed ?? .distantFuture) }
    }

    private var topPlayed: [GameLibraryItem] {
        Array(playedItems.sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }.prefix(5))
    }

    private var maxMinutes: Int {
        topPlayed.first?.playtimeForeverMinutes ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statTiles
                    mostPlayedSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 560)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Lifetime Stats")
                .font(.title2.weight(.semibold))
            Text("Everything you own, all in one place.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Done", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private var statTiles: some View {
        GlassEffectContainer {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                StatTile(title: "Games Owned", value: "\(items.count)", systemImage: "square.grid.2x2")
                StatTile(title: "Total Playtime", value: Formatters.playtime(minutes: totalMinutes), systemImage: "clock")
                StatTile(title: "Never Played", value: "\(neverPlayedPercent)%", systemImage: "moon.zzz")
                if let longestSincePlayed, let lastPlayed = longestSincePlayed.lastPlayed {
                    StatTile(
                        title: "Longest Since Played",
                        value: Formatters.lastPlayed.localizedString(for: lastPlayed, relativeTo: .now),
                        systemImage: "hourglass"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var mostPlayedSection: some View {
        if !topPlayed.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Most Played")
                VStack(spacing: 6) {
                    ForEach(Array(topPlayed.enumerated()), id: \.element.id) { index, item in
                        MostPlayedRow(
                            rank: index + 1,
                            name: item.name,
                            playtimeMinutes: item.playtimeForeverMinutes,
                            fraction: Double(item.playtimeForeverMinutes) / Double(max(maxMinutes, 1)),
                            accent: accent,
                            effects: true,
                            index: index
                        ) {
                            onDismiss()
                            onOpenGame(item)
                        }
                    }
                }
            }
        }
    }
}
