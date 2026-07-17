import SwiftUI

/// The signed-in user's Steam wishlist, fetched via the keyless
/// IWishlistService/GetWishlist endpoint. Each row lazily resolves its own
/// name/price/discount via SteamStoreClient (same pattern as DLCRow) so a
/// large wishlist doesn't fan out dozens of storefront calls at once.
struct WishlistView: View {
    let steamID64: String?
    let onOpenStoreItem: (StoreAppLink) -> Void
    let onSignIn: () -> Void
    let onDismiss: () -> Void

    @Environment(SettingsStore.self) private var settings
    @ViewState private var items: [WishlistItem] = []
    @ViewState private var isLoading = true
    @ViewState private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 560, height: 620)
        // Sheets don't inherit .tint() from the presenting window on macOS.
        .tint(settings.accentColor)
        .task {
            guard steamID64 != nil else { return }
            await load()
        }
    }

    private func load() async {
        guard let steamID64 else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await SteamCommunityClient.shared.wishlist(steamID64: steamID64)
                .sorted { ($0.dateAddedDate ?? .distantPast) > ($1.dateAddedDate ?? .distantPast) }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        // Cheap: both the wishlist and each item's storefront details are
        // already cached, so this just catches a sale immediately instead of
        // waiting for the monitor's next hourly tick.
        await WishlistSaleMonitor.shared.checkOnce()
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Wishlist")
                .font(.title2.weight(.semibold))
            if steamID64 != nil {
                Text("^[\(items.count) game](inflect: true) on your Steam wishlist.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    @ViewBuilder
    private var content: some View {
        if steamID64 == nil {
            ContentUnavailableView {
                Label("Sign in to see your wishlist", systemImage: "heart")
            } description: {
                Text("Wishlist data is public and keyless, but Mist needs your SteamID to know whose to load.")
            } actions: {
                Button("Sign in with Steam", action: onSignIn)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isLoading && items.isEmpty {
            ProgressView("Loading wishlist…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error, items.isEmpty {
            ContentUnavailableView {
                Label("Couldn't load wishlist", systemImage: "heart.slash")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await load() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            ContentUnavailableView(
                "Wishlist's empty",
                systemImage: "heart",
                description: Text("Add games to your wishlist on Steam and they'll show up here — or it may be set to private in your profile settings.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(items, id: \.appid) { item in
                        WishlistRow(item: item) {
                            onDismiss()
                            onOpenStoreItem(StoreAppLink(appID: item.appid, name: "App \(item.appid)"))
                        }
                    }
                }
                .padding(24)
            }
        }
    }
}

private struct WishlistRow: View {
    let item: WishlistItem
    let onOpen: () -> Void

    @ViewState private var details: GameDetails?

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                AsyncImage(url: details?.headerImageURL.flatMap(URL.init(string:))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 120, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        if let details {
                            Text(details.name ?? "App \(item.appid)")
                        } else {
                            Text("App \(item.appid)")
                                .redacted(reason: .placeholder)
                        }
                    }
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    if let added = item.dateAddedDate {
                        Text("Added \(added.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                priceView
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: item.appid) {
            details = await SteamStoreClient.shared.details(for: item.appid)
        }
    }

    @ViewBuilder
    private var priceView: some View {
        if let price = details?.priceOverview {
            VStack(alignment: .trailing, spacing: 4) {
                if price.hasDiscount, let percent = price.discountPercent {
                    Text("−\(percent)%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green, in: RoundedRectangle(cornerRadius: 4))
                }
                if let final = price.finalPriceText {
                    Text(final)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(price.hasDiscount ? .green : .primary)
                }
            }
        } else if details?.isFree == true {
            Text("Free")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
