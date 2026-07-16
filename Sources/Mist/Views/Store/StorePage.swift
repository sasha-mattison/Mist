import SwiftUI

/// Storefront root: featured rails (specials, top sellers, new releases,
/// coming soon) from the unauthenticated storefront API, with live search.
struct StorePage: View {
    let onOpen: (StoreAppLink) -> Void
    let onSignIn: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @ViewState private var featured: FeaturedCategories?
    @ViewState private var loadError: String?
    @ViewState private var searchText = ""
    @ViewState private var searchResults: [StoreSearchResult] = []
    @ViewState private var isSearching = false
    @ViewState private var reloadToken = 0
    @ViewState private var isShowingWishlist = false

    private var isShowingSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Group {
            if isShowingSearch {
                searchContent
            } else if let featured {
                railsContent(featured)
            } else if let loadError {
                ContentUnavailableView {
                    Label("Store unavailable", systemImage: "cart.badge.questionmark")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Try Again") { reloadToken += 1 }
                }
            } else {
                ProgressView("Loading the Steam store…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Store")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search the Steam store")
        .toolbar {
            ToolbarItem {
                Button {
                    isShowingWishlist = true
                } label: {
                    Label("Wishlist", systemImage: "heart")
                }
                .help("Wishlist")
            }
        }
        .sheet(isPresented: $isShowingWishlist) {
            WishlistView(
                steamID64: store.activeSteamID64,
                onOpenStoreItem: { onOpen($0) },
                onSignIn: {
                    isShowingWishlist = false
                    onSignIn()
                },
                onDismiss: { isShowingWishlist = false }
            )
        }
        .task(id: reloadToken) {
            loadError = nil
            do {
                featured = try await SteamStoreClient.shared.featuredCategories()
            } catch {
                loadError = error.localizedDescription
            }
        }
        .task(id: searchText) {
            let term = searchText.trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else {
                searchResults = []
                return
            }
            isSearching = true
            // Debounce so we don't hit the API on every keystroke.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let results = (try? await SteamStoreClient.shared.search(term: term)) ?? []
            guard !Task.isCancelled else { return }
            searchResults = results
            isSearching = false
        }
    }

    // MARK: - Featured rails

    private func railsContent(_ featured: FeaturedCategories) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                ForEach(featured.rails) { rail in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(rail.title)
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(Array(rail.items.enumerated()), id: \.element.id) { index, item in
                                    StoreCapsuleCard(
                                        item: item,
                                        index: index,
                                        showsPrice: rail.showsPrices,
                                        isInLibrary: store.libraryItems.contains { $0.appID == item.id },
                                        onOpen: { onOpen(item.link) }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                        }
                        .scrollClipDisabled()
                    }
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var searchContent: some View {
        if isSearching && searchResults.isEmpty {
            ProgressView("Searching…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(searchResults) { result in
                        StoreSearchRow(
                            result: result,
                            isInLibrary: store.libraryItems.contains { $0.appID == result.id },
                            onOpen: { onOpen(result.link) }
                        )
                    }
                }
                .padding(24)
            }
        }
    }
}

// MARK: - Capsule card

private struct StoreCapsuleCard: View {
    let item: FeaturedStoreItem
    let index: Int
    let showsPrice: Bool
    let isInLibrary: Bool
    let onOpen: () -> Void

    @Environment(SettingsStore.self) private var settings
    @ViewState private var isHovering = false

    private var effects: Bool { settings.animationsEnabled }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                capsuleImage
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if showsPrice {
                        priceRow
                    }
                }
            }
            .frame(width: 280)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .hoverTilt(enabled: effects)
        .shadow(color: .black.opacity(isHovering ? 0.3 : 0.12), radius: isHovering ? 14 : 5, y: isHovering ? 8 : 3)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .entranceEffect(index: index, enabled: effects)
    }

    private var capsuleImage: some View {
        AsyncImage(url: item.capsuleImageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.quaternary)
                    .overlay {
                        Image(systemName: "gamecontroller")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 280, height: 130)
        .shineSweep(trigger: isHovering, enabled: effects)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            if isInLibrary {
                Label("In Library", systemImage: "checkmark")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(in: .capsule)
                    .padding(8)
            }
        }
    }

    @ViewBuilder
    private var priceRow: some View {
        HStack(spacing: 8) {
            if item.hasDiscount, let percent = item.discountPercent {
                Text("−\(percent)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green, in: RoundedRectangle(cornerRadius: 4))
                if let original = item.originalPrice {
                    Text(Formatters.price(cents: original, currencyCode: item.currency))
                        .font(.caption)
                        .strikethrough()
                        .foregroundStyle(.secondary)
                }
            }
            Text(priceText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.hasDiscount ? .green : .secondary)
        }
    }

    private var priceText: String {
        guard let final = item.finalPrice else { return "Free" }
        if final == 0 { return "Free" }
        return Formatters.price(cents: final, currencyCode: item.currency)
    }
}

// MARK: - Search row

private struct StoreSearchRow: View {
    let result: StoreSearchResult
    let isInLibrary: Bool
    let onOpen: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                AsyncImage(url: result.tinyImage.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(width: 120, height: 45)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if isInLibrary {
                        Label("In Library", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(priceText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(hasDiscount ? .green : .secondary)
            }
            .padding(10)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var hasDiscount: Bool {
        guard let price = result.price, let initial = price.initial, let final = price.final else { return false }
        return final < initial
    }

    private var priceText: String {
        guard let price = result.price, let final = price.final, final > 0 else { return "Free" }
        return Formatters.price(cents: final, currencyCode: price.currency)
    }
}
