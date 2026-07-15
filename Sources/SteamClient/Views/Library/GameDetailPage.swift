import AppKit
import SwiftUI

/// Full detail page for one game, pushed onto the library NavigationStack.
/// Combines local install data, Web API playtime, and storefront metadata
/// (description, genres, screenshots) under a hero-artwork header.
struct GameDetailPage: View {
    let item: GameLibraryItem

    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @ViewState private var heroArtwork: NSImage?
    @ViewState private var storeDetails: GameDetails?
    @ViewState private var isLoadingDetails = true
    @ViewState private var isLaunching = false

    private var effects: Bool { settings.animationsEnabled }

    /// The store rebuilds items on refresh, so re-resolve by appID to keep
    /// playtime/install state live while this page is on screen.
    private var currentItem: GameLibraryItem {
        store.libraryItems.first { $0.appID == item.appID } ?? item
    }

    private var isPlaying: Bool { store.runningAppID == item.appID }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroHeader
                Group {
                    statTiles
                        .entranceEffect(index: 0, enabled: effects)
                    aboutSection
                        .entranceEffect(index: 2, enabled: effects)
                    screenshotsSection
                        .entranceEffect(index: 4, enabled: effects)
                    informationSection
                        .entranceEffect(index: 6, enabled: effects)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(item.name)
        .onChange(of: isPlaying) { _, playing in
            if playing { isLaunching = false }
        }
        .task(id: item.appID) {
            async let hero = ArtworkLoader.shared.heroImage(for: item.appID)
            async let details = SteamStoreClient.shared.details(for: item.appID)
            heroArtwork = await hero
            storeDetails = await details
            isLoadingDetails = false
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackdrop
            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.name)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                        .lineLimit(2)

                    if let genres = storeDetails?.genres, !genres.isEmpty {
                        GenreChips(genres: genres)
                    }

                    actionRow
                }
                Spacer(minLength: 0)
            }
            .padding(28)
        }
    }

    private var heroBackdrop: some View {
        Group {
            if let heroArtwork {
                Image(nsImage: heroArtwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .parallaxStretchHeader(height: 380, enabled: effects)
        .frame(maxWidth: .infinity)
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.15), location: 0),
                    .init(color: .clear, location: 0.35),
                    .init(color: .black.opacity(0.65), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if currentItem.isInstalled {
                Button(action: launch) {
                    if isPlaying {
                        Label("Playing", systemImage: "checkmark")
                            .frame(minWidth: 110)
                    } else if isLaunching {
                        Label("Launching…", systemImage: "hourglass")
                            .frame(minWidth: 110)
                    } else {
                        Label("Play", systemImage: "play.fill")
                            .frame(minWidth: 110)
                    }
                }
                .buttonStyle(.glassProminent)
                .tint(.green)
                .controlSize(.extraLarge)
                .disabled(isPlaying || isLaunching)

                if let installURL = currentItem.installURL {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([installURL])
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.extraLarge)
                }
            } else {
                Button {
                    GameLaunchService.install(appID: item.appID)
                } label: {
                    Label("Install via Steam", systemImage: "arrow.down.circle.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
            }

            Button {
                GameLaunchService.openStorePage(appID: item.appID)
            } label: {
                Label("Store Page", systemImage: "cart")
            }
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
        }
    }

    private func launch() {
        guard !isPlaying, !isLaunching else { return }
        GameLaunchService.launch(appID: item.appID)
        isLaunching = true
        Task {
            try? await Task.sleep(for: .seconds(10))
            isLaunching = false
        }
    }

    // MARK: - Stats

    private var statTiles: some View {
        GlassEffectContainer {
            HStack(spacing: 14) {
                StatTile(
                    title: "Total Playtime",
                    value: Formatters.playtime(minutes: currentItem.playtimeForeverMinutes),
                    systemImage: "clock"
                )
                if currentItem.playtime2WeeksMinutes > 0 {
                    StatTile(
                        title: "Last 2 Weeks",
                        value: Formatters.playtime(minutes: currentItem.playtime2WeeksMinutes),
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }
                StatTile(
                    title: "Last Played",
                    value: currentItem.lastPlayed.map {
                        Formatters.lastPlayed.localizedString(for: $0, relativeTo: .now)
                    } ?? "Never",
                    systemImage: "calendar"
                )
                if currentItem.isInstalled {
                    StatTile(
                        title: "Size on Disk",
                        value: Formatters.size.string(fromByteCount: currentItem.sizeOnDisk),
                        systemImage: "internaldrive"
                    )
                }
                if let score = storeDetails?.metacritic?.score {
                    StatTile(
                        title: "Metacritic",
                        value: "\(score)",
                        systemImage: "star.fill",
                        valueColor: metacriticColor(score)
                    )
                }
            }
        }
    }

    private func metacriticColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        if isLoadingDetails {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading store details…")
                    .foregroundStyle(.secondary)
            }
        } else if let storeDetails {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "About")
                if let short = storeDetails.shortDescription, !short.isEmpty {
                    Text(short)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let about = storeDetails.aboutText {
                    Text(about)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotsSection: some View {
        if let screenshots = storeDetails?.screenshots, !screenshots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Screenshots")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(screenshots) { screenshot in
                            ScreenshotThumbnail(screenshot: screenshot)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Information

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Information")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: 14, alignment: .topLeading)],
                alignment: .leading,
                spacing: 14
            ) {
                if let developers = storeDetails?.developers, !developers.isEmpty {
                    InfoCell(label: "Developer", value: developers.joined(separator: ", "))
                }
                if let publishers = storeDetails?.publishers, !publishers.isEmpty {
                    InfoCell(label: "Publisher", value: publishers.joined(separator: ", "))
                }
                if let release = storeDetails?.releaseDate, !release.date.isEmpty {
                    InfoCell(label: "Released", value: release.comingSoon ? "Coming soon" : release.date)
                }
                if let platforms = storeDetails?.platforms, !platforms.names.isEmpty {
                    InfoCell(label: "Platforms", value: platforms.names.joined(separator: ", "))
                }
                InfoCell(label: "App ID", value: "\(item.appID)")
                if let installURL = currentItem.installURL {
                    InfoCell(label: "Install Location", value: installURL.path)
                }
                if let website = storeDetails?.website, let url = URL(string: website) {
                    InfoCell(label: "Website", value: url.host() ?? website, link: url)
                }
            }
        }
    }
}

// Shared components (SectionHeader, StatTile, InfoCell, ScreenshotThumbnail)
// live in Views/Shared/DetailComponents.swift.
