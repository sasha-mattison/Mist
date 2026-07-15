import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    private var runningGame: GameLibraryItem? {
        guard let runningAppID = store.runningAppID else { return nil }
        return store.libraryItems.first { $0.appID == runningAppID }
    }

    private var recentlyPlayed: [GameLibraryItem] {
        Array(
            store.libraryItems
                .filter { $0.isInstalled && $0.lastPlayed != nil }
                .sorted { $0.lastPlayed! > $1.lastPlayed! }
                .prefix(6)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let runningGame {
                NowPlayingRow(item: runningGame)
                Divider()
            }

            if recentlyPlayed.isEmpty {
                Text("No games played yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(recentlyPlayed) { item in
                    QuickLaunchRow(item: item, isPlaying: item.appID == store.runningAppID)
                }
            }

            Divider()

            HStack {
                Button("Open Steam") { GameLaunchService.openSteam() }
                    .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
            }
            .font(.callout)
            .padding(12)
        }
        .frame(width: 280)
        .padding(.vertical, 8)
        .tint(settings.accentColor)
    }
}

private struct NowPlayingRow: View {
    let item: GameLibraryItem

    @ViewState private var isPulsing = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0.5 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(item.name)
                    .font(.callout.weight(.semibold))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct QuickLaunchRow: View {
    let item: GameLibraryItem
    let isPlaying: Bool

    @ViewState private var isHovering = false

    var body: some View {
        Button {
            GameLaunchService.launch(appID: item.appID)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "play.circle.fill" : "gamecontroller")
                    .foregroundStyle(isPlaying ? .green : .secondary)
                Text(item.name)
                    .lineLimit(1)
                Spacer()
                if let lastPlayed = item.lastPlayed {
                    Text(Formatters.lastPlayed.localizedString(for: lastPlayed, relativeTo: .now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovering ? Color.primary.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
