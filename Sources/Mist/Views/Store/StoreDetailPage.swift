import AppKit
import SwiftUI

/// Detail page for a storefront app (reached from the Store tab). Mirrors
/// GameDetailPage's layout but leads with price/purchase actions; if the app
/// is already in the library it offers Play/Install instead.
struct StoreDetailPage: View {
    let link: StoreAppLink

    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @ViewState private var heroArtwork: NSImage?
    @ViewState private var details: GameDetails?
    @ViewState private var isLoading = true

    private var effects: Bool { settings.animationsEnabled }

    private var libraryItem: GameLibraryItem? {
        store.libraryItems.first { $0.appID == link.appID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroHeader
                Group {
                    aboutSection
                        .entranceEffect(index: 0, enabled: effects)
                    screenshotsSection
                        .entranceEffect(index: 2, enabled: effects)
                    informationSection
                        .entranceEffect(index: 4, enabled: effects)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(link.name)
        .task(id: link.appID) {
            async let hero = ArtworkLoader.shared.heroImage(for: link.appID)
            async let fetched = SteamStoreClient.shared.details(for: link.appID)
            heroArtwork = await hero
            details = await fetched
            isLoading = false
        }
    }

    // MARK: - Hero header

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackdrop
            VStack(alignment: .leading, spacing: 12) {
                Text(details?.name ?? link.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
                    .lineLimit(2)

                if let genres = details?.genres, !genres.isEmpty {
                    GenreChips(genres: genres)
                }

                actionRow
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
            priceCapsule

            if let libraryItem {
                if libraryItem.isInstalled {
                    Button {
                        GameLaunchService.launch(appID: link.appID)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(minWidth: 110)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .controlSize(.extraLarge)
                } else {
                    Button {
                        GameLaunchService.install(appID: link.appID)
                    } label: {
                        Label("Install via Steam", systemImage: "arrow.down.circle.fill")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                }
            } else {
                Button {
                    GameLaunchService.openStoreInSteam(appID: link.appID)
                } label: {
                    Label(purchaseLabel, systemImage: "cart.fill")
                        .frame(minWidth: 130)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .help("Opens the store page in Steam, where purchases are completed")
            }

            Button {
                GameLaunchService.openStorePage(appID: link.appID)
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }
            .buttonStyle(.glass)
            .controlSize(.extraLarge)
        }
    }

    private var purchaseLabel: String {
        if details?.isFree == true { return "Get on Steam" }
        return "Buy on Steam"
    }

    @ViewBuilder
    private var priceCapsule: some View {
        if libraryItem != nil {
            Label("In Library", systemImage: "checkmark")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(in: .capsule)
        } else if details?.isFree == true {
            priceBadge(text: "Free to Play", emphasized: true)
        } else if let price = details?.priceOverview {
            HStack(spacing: 8) {
                if price.hasDiscount, let percent = price.discountPercent {
                    Text("−\(percent)%")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green, in: RoundedRectangle(cornerRadius: 5))
                    if let initial = price.initialPriceText {
                        Text(initial)
                            .font(.callout)
                            .strikethrough()
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                if let final = price.finalPriceText {
                    priceBadge(text: final, emphasized: price.hasDiscount)
                }
            }
        }
    }

    private func priceBadge(text: String, emphasized: Bool) -> some View {
        Text(text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(emphasized ? .green : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(in: .capsule)
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        if isLoading {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Loading store details…")
                    .foregroundStyle(.secondary)
            }
        } else if let details {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "About")
                if let short = details.shortDescription, !short.isEmpty {
                    Text(short)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let about = details.aboutText {
                    Text(about)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        } else {
            ContentUnavailableView(
                "No store details",
                systemImage: "cart.badge.questionmark",
                description: Text("Steam didn't return details for this app — it may be delisted or region-locked.")
            )
        }
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotsSection: some View {
        if let screenshots = details?.screenshots, !screenshots.isEmpty {
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

    @ViewBuilder
    private var informationSection: some View {
        if details != nil || libraryItem != nil {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Information")
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), spacing: 14, alignment: .topLeading)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    if let developers = details?.developers, !developers.isEmpty {
                        InfoCell(label: "Developer", value: developers.joined(separator: ", "))
                    }
                    if let publishers = details?.publishers, !publishers.isEmpty {
                        InfoCell(label: "Publisher", value: publishers.joined(separator: ", "))
                    }
                    if let release = details?.releaseDate, !release.date.isEmpty {
                        InfoCell(label: "Released", value: release.comingSoon ? "Coming soon" : release.date)
                    }
                    if let platforms = details?.platforms, !platforms.names.isEmpty {
                        InfoCell(label: "Platforms", value: platforms.names.joined(separator: ", "))
                    }
                    if let score = details?.metacritic?.score {
                        InfoCell(label: "Metacritic", value: "\(score)")
                    }
                    InfoCell(label: "App ID", value: "\(link.appID)")
                    if let website = details?.website, let url = URL(string: website) {
                        InfoCell(label: "Website", value: url.host() ?? website, link: url)
                    }
                }
            }
        }
    }
}
