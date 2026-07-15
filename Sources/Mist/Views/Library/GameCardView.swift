import AppKit
import SwiftUI

/// One tile in the library grid. Clicking an installed game launches it
/// directly (no separate play button); clicking a not-installed game opens
/// its detail page. The hover ⓘ button and the context menu both lead to the
/// detail page as well.
struct GameCardView: View {
    let item: GameLibraryItem
    var index: Int = 0
    let onOpenDetail: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @ViewState private var artwork: NSImage?
    @ViewState private var isHovering = false
    @ViewState private var isLaunching = false

    private var isPlaying: Bool { store.runningAppID == item.appID }
    private var effects: Bool { settings.animationsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The ⓘ button must be a sibling of the launch Button, not part
            // of its label — a Button nested inside another Button's label
            // fires BOTH actions on click (verified: launched the game while
            // opening the detail page).
            ZStack(alignment: .topTrailing) {
                Button(action: primaryAction) {
                    artworkCard
                }
                .buttonStyle(.plain)

                infoButton
            }
            .compositingGroup()
            .shadow(color: shadowColor, radius: isHovering || isPlaying ? 18 : 5, y: isHovering ? 10 : 3)
            .scaleEffect(isHovering ? 1.04 : 1.0)
            .hoverTilt(enabled: effects)

            titleRow
        }
        .frame(width: 200)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { isLaunching = false }
        }
        .contextMenu { contextMenuItems }
        .entranceEffect(index: index, enabled: effects)
        .task(id: item.appID) {
            artwork = await ArtworkLoader.shared.image(for: item.appID)
        }
    }

    private func primaryAction() {
        if item.isInstalled {
            launch()
        } else {
            onOpenDetail()
        }
    }

    private func launch() {
        guard !isPlaying, !isLaunching else { return }
        GameLaunchService.launch(appID: item.appID)
        isLaunching = true
        Task {
            // RunningGameMonitor flips isPlaying when the process appears;
            // this timeout just clears the spinner if the launch went nowhere.
            try? await Task.sleep(for: .seconds(10))
            isLaunching = false
        }
    }

    private var artworkCard: some View {
        artworkView
            .frame(width: 200, height: 300)
            .overlay { hoverOverlay }
            .shineSweep(trigger: isHovering, enabled: effects)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if isPlaying {
                    playingGlow
                }
            }
    }

    @ViewBuilder
    private var hoverOverlay: some View {
        if isLaunching {
            ZStack {
                Rectangle().fill(.black.opacity(0.45))
                ProgressView()
                    .controlSize(.large)
            }
            .transition(.opacity)
        } else if isHovering, item.isInstalled, !isPlaying {
            ZStack {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var infoButton: some View {
        if isHovering {
            Button(action: onOpenDetail) {
                Image(systemName: "info")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(10)
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .help("View details")
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if isPlaying {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }
            Group {
                if isPlaying {
                    Text("Now playing")
                        .foregroundStyle(.green)
                } else if !item.isInstalled {
                    Text("Not installed")
                        .foregroundStyle(.secondary)
                } else if let lastPlayed = item.lastPlayed {
                    Text("Played \(Formatters.lastPlayed.localizedString(for: lastPlayed, relativeTo: .now))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if item.isInstalled {
            Button("Play", systemImage: "play.fill") { launch() }
                .disabled(isPlaying)
        } else {
            Button("Install via Steam", systemImage: "arrow.down.circle") {
                GameLaunchService.install(appID: item.appID)
            }
        }
        Button("View Details", systemImage: "info.circle", action: onOpenDetail)
        Divider()
        if let installURL = item.installURL {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([installURL])
            }
        }
        Button("Steam Store Page", systemImage: "cart") {
            GameLaunchService.openStorePage(appID: item.appID)
        }
    }

    private var shadowColor: Color {
        if isPlaying { return .green.opacity(0.5) }
        return .black.opacity(isHovering ? 0.35 : 0.15)
    }

    private var playingGlow: some View {
        PhaseAnimator([false, true]) { phase in
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.green, lineWidth: 3)
                .opacity(phase ? 0.35 : 0.9)
        } animation: { _ in
            .easeInOut(duration: 1.1)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "gamecontroller")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}
