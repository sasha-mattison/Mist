import Foundation

/// One entry from ISteamWishlistService/GetWishlist — a keyless, public
/// endpoint that superseded the old scraped `wishlist/profiles/.../wishlistdata`
/// page (confirmed dead — it now 302-redirects to the store homepage).
/// Carries no name/price; those come from a per-app storefront lookup.
struct WishlistItem: Decodable, Hashable {
    let appid: Int
    let priority: Int
    let dateAdded: Int

    enum CodingKeys: String, CodingKey {
        case appid, priority
        case dateAdded = "date_added"
    }

    var dateAddedDate: Date? {
        dateAdded > 0 ? Date(timeIntervalSince1970: TimeInterval(dateAdded)) : nil
    }
}
