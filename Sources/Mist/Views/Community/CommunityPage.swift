import SwiftUI

enum CommunitySection: String, CaseIterable, Identifiable {
    case news = "News"
    case friendActivity = "Friend Activity"
    case trending = "Trending"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .news: return "newspaper"
        case .friendActivity: return "person.2.wave.2"
        case .trending: return "chart.line.uptrend.xyaxis"
        }
    }
}

/// Community root: a segmented hub with a merged news feed for your games,
/// live friend activity grouped by game, and Steam's global most-played
/// chart. News and Trending are keyless, so they work before sign-in.
struct CommunityPage: View {
    let onOpenGame: (GameLibraryItem) -> Void
    let onOpenStoreItem: (StoreAppLink) -> Void
    let onSignIn: () -> Void
    let onSetupAPIKey: () -> Void

    @Environment(CommunityStore.self) private var community
    @ViewState private var section: CommunitySection = .news
    @ViewState private var searchText = ""

    var body: some View {
        Group {
            switch section {
            case .news:
                CommunityNewsView(
                    searchText: searchText,
                    onOpenGame: onOpenGame,
                    onOpenStoreItem: onOpenStoreItem
                )
            case .friendActivity:
                CommunityFriendsActivityView(
                    searchText: searchText,
                    onOpenStoreItem: onOpenStoreItem,
                    onSignIn: onSignIn,
                    onSetupAPIKey: onSetupAPIKey
                )
            case .trending:
                CommunityTrendingView(
                    searchText: searchText,
                    onOpen: onOpenStoreItem
                )
            }
        }
        .navigationTitle("Community")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search \(section.rawValue.lowercased())")
        .toolbar {
            // Automatic placement (not .principal) so the controls sit on the
            // left next to the sidebar, matching every other page's toolbar.
            ToolbarItem {
                Picker("Section", selection: $section) {
                    ForEach(CommunitySection.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem {
                if community.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await community.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await community.refreshIfStale()
        }
    }
}

/// Steam's CDN capsule art, used by news and trending rows.
enum SteamCapsuleArt {
    static func url(appID: Int) -> URL? {
        URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/capsule_231x87.jpg")
    }
}
