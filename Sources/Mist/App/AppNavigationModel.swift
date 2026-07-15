import Foundation
import Observation

/// Sidebar section selection, hoisted out of ContentView so main-menu
/// commands (Go ▸ Library/Store/…) can drive navigation from outside the
/// view tree.
@MainActor
@Observable
final class AppNavigationModel {
    var selectedSection: SidebarSection = .library
}
