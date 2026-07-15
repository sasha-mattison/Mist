import Foundation

/// Navigation token for pushing a storefront app's detail page. Distinct from
/// GameLibraryItem so the same NavigationStack can route both.
struct StoreAppLink: Hashable {
    let appID: Int
    let name: String
}

/// One capsule in a featuredcategories rail. Prices are integer cents in the
/// storefront's regional currency.
struct FeaturedStoreItem: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let discounted: Bool?
    let discountPercent: Int?
    let originalPrice: Int?
    let finalPrice: Int?
    let currency: String?
    let largeCapsuleImage: String?
    let smallCapsuleImage: String?
    let headerImage: String?

    enum CodingKeys: String, CodingKey {
        case id, name, discounted, currency
        case discountPercent = "discount_percent"
        case originalPrice = "original_price"
        case finalPrice = "final_price"
        case largeCapsuleImage = "large_capsule_image"
        case smallCapsuleImage = "small_capsule_image"
        case headerImage = "header_image"
    }

    var capsuleImageURL: URL? {
        (largeCapsuleImage ?? headerImage ?? smallCapsuleImage).flatMap(URL.init(string:))
    }

    var hasDiscount: Bool {
        (discounted ?? false) && (discountPercent ?? 0) > 0
    }

    var link: StoreAppLink { StoreAppLink(appID: id, name: name) }
}

/// Response of store.steampowered.com/api/featuredcategories.
struct FeaturedCategories: Decodable {
    let specials: Category?
    let comingSoon: Category?
    let topSellers: Category?
    let newReleases: Category?

    struct Category: Decodable {
        let name: String?
        let items: [LossyDecodable<FeaturedStoreItem>]?

        var validItems: [FeaturedStoreItem] {
            (items ?? []).compactMap(\.value)
        }
    }

    enum CodingKeys: String, CodingKey {
        case specials
        case comingSoon = "coming_soon"
        case topSellers = "top_sellers"
        case newReleases = "new_releases"
    }

    struct Rail: Identifiable {
        let title: String
        let items: [FeaturedStoreItem]
        /// Unreleased titles report final_price 0, which must not render as
        /// "Free" — the Coming Soon rail hides prices entirely.
        let showsPrices: Bool

        var id: String { title }
    }

    /// Rails in display order, empty ones dropped.
    var rails: [Rail] {
        [
            Rail(title: "Specials", items: specials?.validItems ?? [], showsPrices: true),
            Rail(title: "Top Sellers", items: topSellers?.validItems ?? [], showsPrices: true),
            Rail(title: "New Releases", items: newReleases?.validItems ?? [], showsPrices: true),
            Rail(title: "Coming Soon", items: comingSoon?.validItems ?? [], showsPrices: false)
        ].filter { !$0.items.isEmpty }
    }
}

/// One row from store.steampowered.com/api/storesearch.
struct StoreSearchResult: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let price: Price?
    let tinyImage: String?

    struct Price: Decodable, Hashable {
        let currency: String?
        let initial: Int?
        let final: Int?
    }

    enum CodingKeys: String, CodingKey {
        case id, name, price
        case tinyImage = "tiny_image"
    }

    var link: StoreAppLink { StoreAppLink(appID: id, name: name) }
}

struct StoreSearchResponse: Decodable {
    let items: [LossyDecodable<StoreSearchResult>]?

    var validItems: [StoreSearchResult] {
        (items ?? []).compactMap(\.value)
    }
}

/// Storefront lists occasionally contain rows that don't match the expected
/// shape (bundles, delisted apps); a bad row shouldn't sink the whole list.
struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}
