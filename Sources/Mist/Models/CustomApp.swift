import Foundation

/// A user-added non-Steam app/game — Mist just remembers its name and path
/// and launches it directly via NSWorkspace, with no Steam involvement at
/// all. `id` is always negative so it can never collide with a real
/// (always-positive) Steam appID anywhere the two share ID space
/// (GameLibraryItem, RunningGameMonitor's dictionaries, navigation links).
struct CustomApp: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    var path: String
    let addedDate: Date

    var url: URL { URL(fileURLWithPath: path) }
}
