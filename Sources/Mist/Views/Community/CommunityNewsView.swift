import AppKit
import SwiftUI

/// Merged announcement feed for the user's games (or trending games when the
/// library is empty), filterable per game via chips and the shared search
/// field. Rows open the article in the browser.
struct CommunityNewsView: View {
    let searchText: String
    let onOpenGame: (GameLibraryItem) -> Void
    let onOpenStoreItem: (StoreAppLink) -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(CommunityStore.self) private var community
    @Environment(SettingsStore.self) private var settings
    @ViewState private var filterAppID: Int?

    private var effects: Bool { settings.animationsEnabled }

    /// Games that actually have articles in the feed, for the chips row.
    private var availableFilters: [(appID: Int, name: String)] {
        let appIDsWithNews = Set(community.newsItems.map(\.appid))
        return community.newsSourceNames
            .filter { appIDsWithNews.contains($0.key) }
            .map { (appID: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var visibleItems: [GameNewsItem] {
        var items = community.newsItems
        if let filterAppID {
            items = items.filter { $0.appid == filterAppID }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || (community.newsSourceNames[$0.appid]?.localizedCaseInsensitiveContains(query) ?? false)
            }
        }
        return items
    }

    var body: some View {
        Group {
            if community.newsItems.isEmpty && community.isLoading {
                ProgressView("Loading game news…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if community.newsItems.isEmpty, let error = community.newsError {
                ContentUnavailableView {
                    Label("Couldn't load news", systemImage: "newspaper")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await community.refresh() }
                    }
                }
            } else if community.newsItems.isEmpty {
                ContentUnavailableView(
                    "No news yet",
                    systemImage: "newspaper",
                    description: Text("Once your library has games (or the trending chart loads), their announcements show up here.")
                )
            } else {
                feed
            }
        }
    }

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                let items = visibleItems
                if items.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NewsRow(
                            item: item,
                            gameName: community.newsSourceNames[item.appid] ?? "App \(item.appid)",
                            effects: effects,
                            index: index,
                            onOpenGame: { openGame(appID: item.appid) }
                        )
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            filterChips
        }
    }

    // MARK: - Game filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All Games",
                    isSelected: filterAppID == nil,
                    onSelect: { filterAppID = nil }
                )
                ForEach(availableFilters, id: \.appID) { filter in
                    FilterChip(
                        title: filter.name,
                        isSelected: filterAppID == filter.appID,
                        onSelect: {
                            filterAppID = filterAppID == filter.appID ? nil : filter.appID
                        }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func openGame(appID: Int) {
        if let item = store.libraryItems.first(where: { $0.appID == appID }) {
            onOpenGame(item)
        } else {
            onOpenStoreItem(StoreAppLink(appID: appID, name: community.newsSourceNames[appID] ?? "App \(appID)"))
        }
    }
}

// MARK: - Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    if isSelected {
                        Capsule().fill(.tint)
                    } else {
                        Capsule().fill(Color.primary.opacity(0.07))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct NewsRow: View {
    let item: GameNewsItem
    let gameName: String
    let effects: Bool
    let index: Int
    let onOpenGame: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: openArticle) {
            HStack(alignment: .top, spacing: 14) {
                capsule

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(gameName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                        if let feedlabel = item.feedlabel, !feedlabel.isEmpty {
                            Text(feedlabel)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        Text(Formatters.lastPlayed.localizedString(for: item.publishedAt, relativeTo: .now))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    let excerpt = item.plainExcerpt
                    if !excerpt.isEmpty {
                        Text(excerpt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.07 : 0.03))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .entranceEffect(index: index, enabled: effects)
        .help("Open article in browser")
        .contextMenu {
            Button("Open Article", systemImage: "safari", action: openArticle)
            Button("View Game", systemImage: "gamecontroller", action: onOpenGame)
            Button("Open Community Hub", systemImage: "person.3") {
                GameLaunchService.openCommunityHub(appID: item.appid)
            }
        }
    }

    private var capsule: some View {
        AsyncImage(url: SteamCapsuleArt.url(appID: item.appid)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.quaternary)
                    .overlay {
                        Image(systemName: "newspaper")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 120, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func openArticle() {
        if let url = item.articleURL {
            NSWorkspace.shared.open(url)
        }
    }
}
