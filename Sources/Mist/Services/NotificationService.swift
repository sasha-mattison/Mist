import Foundation
import UserNotifications

/// Posts Mist's local notifications, gated per-type by SettingsStore
/// toggles (all off by default). System authorization is requested lazily —
/// the first time the user turns any toggle on — rather than up front at
/// launch, so the permission prompt only appears once it's actually wanted.
///
/// `settings` is assigned once from MistApp at launch so call sites
/// (RunningGameMonitor, FriendsStore, GameLibraryStore, WishlistSaleMonitor)
/// don't need a SettingsStore dependency of their own.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    weak var settings: SettingsStore?

    private var hasRequestedAuthorization = false

    private init() {}

    func requestAuthorizationIfNeeded() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifySessionEnded(gameName: String, minutes: Int) {
        guard settings?.notifySessionEnded == true, minutes > 0 else { return }
        post(
            id: "session-ended.\(gameName)",
            title: gameName,
            body: "You played for \(Formatters.playtime(minutes: minutes))."
        )
    }

    func notifyFriendOnline(name: String) {
        guard settings?.notifyFriendOnline == true else { return }
        // Unique per-post id (not per-friend) so the same friend can notify
        // again on a later online transition instead of the request just
        // replacing an unseen earlier one with the same identifier.
        post(
            id: "friend-online.\(name).\(Date().timeIntervalSince1970)",
            title: "\(name) is online",
            body: ""
        )
    }

    func notifyGameUpdateAvailable(gameName: String) {
        guard settings?.notifyGameUpdates == true else { return }
        post(
            id: "game-update.\(gameName)",
            title: "Update available",
            body: "\(gameName) has been updated."
        )
    }

    func notifyWishlistSale(gameName: String, discountPercent: Int) {
        guard settings?.notifyWishlistSales == true else { return }
        post(
            id: "wishlist-sale.\(gameName)",
            title: "\(gameName) is on sale",
            body: "−\(discountPercent)% right now on your wishlist."
        )
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
