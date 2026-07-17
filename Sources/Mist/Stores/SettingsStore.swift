import AppKit
import Carbon.HIToolbox
import Observation
import ServiceManagement
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    /// nil = follow the system appearance.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum AccentPreset: String, CaseIterable, Identifiable {
    case steamBlue
    case blue
    case sky
    case cyan
    case teal
    case ocean
    case mint
    case green
    case forest
    case lime
    case yellow
    case gold
    case orange
    case coral
    case red
    case crimson
    case pink
    case magenta
    case purple
    case lavender
    case indigo
    case brown
    case graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .steamBlue: return "Steam Blue"
        case .blue: return "Blue"
        case .sky: return "Sky"
        case .cyan: return "Cyan"
        case .teal: return "Teal"
        case .ocean: return "Ocean"
        case .mint: return "Mint"
        case .green: return "Green"
        case .forest: return "Forest"
        case .lime: return "Lime"
        case .yellow: return "Yellow"
        case .gold: return "Gold"
        case .orange: return "Orange"
        case .coral: return "Coral"
        case .red: return "Red"
        case .crimson: return "Crimson"
        case .pink: return "Pink"
        case .magenta: return "Magenta"
        case .purple: return "Purple"
        case .lavender: return "Lavender"
        case .indigo: return "Indigo"
        case .brown: return "Brown"
        case .graphite: return "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .steamBlue: return Color(red: 0.10, green: 0.62, blue: 1.00)
        case .blue: return .blue
        case .sky: return Color(red: 0.35, green: 0.72, blue: 0.96)
        case .cyan: return .cyan
        case .teal: return .teal
        case .ocean: return Color(red: 0.00, green: 0.44, blue: 0.64)
        case .mint: return .mint
        case .green: return .green
        case .forest: return Color(red: 0.16, green: 0.55, blue: 0.34)
        case .lime: return Color(red: 0.58, green: 0.82, blue: 0.20)
        case .yellow: return .yellow
        case .gold: return Color(red: 0.86, green: 0.65, blue: 0.13)
        case .orange: return .orange
        case .coral: return Color(red: 1.00, green: 0.45, blue: 0.40)
        case .red: return .red
        case .crimson: return Color(red: 0.82, green: 0.10, blue: 0.26)
        case .pink: return .pink
        case .magenta: return Color(red: 0.90, green: 0.22, blue: 0.72)
        case .purple: return .purple
        case .lavender: return Color(red: 0.68, green: 0.60, blue: 0.94)
        case .indigo: return .indigo
        case .brown: return .brown
        case .graphite: return Color(red: 0.56, green: 0.58, blue: 0.62)
        }
    }
}

/// One-click appearance + accent combinations shown as "Quick Themes".
struct ThemePreset: Identifiable {
    let name: String
    let appearance: AppearanceMode
    let accent: AccentPreset

    var id: String { name }

    static let all: [ThemePreset] = [
        ThemePreset(name: "Steam Classic", appearance: .dark, accent: .steamBlue),
        ThemePreset(name: "Daylight", appearance: .light, accent: .blue),
        ThemePreset(name: "Midnight", appearance: .dark, accent: .indigo),
        ThemePreset(name: "Neon", appearance: .dark, accent: .magenta),
        ThemePreset(name: "Forest", appearance: .dark, accent: .forest),
        ThemePreset(name: "Sunset", appearance: .light, accent: .orange),
        ThemePreset(name: "Rosé", appearance: .light, accent: .pink),
        ThemePreset(name: "Ember", appearance: .dark, accent: .crimson),
        ThemePreset(name: "Aqua", appearance: .light, accent: .teal),
        ThemePreset(name: "Mono", appearance: .dark, accent: .graphite)
    ]
}

/// Portable snapshot of `SettingsStore`'s user-facing preferences, written by
/// `exportSettings()` / read by `importSettings(from:)`.
struct SettingsExport: Codable {
    let appearance: String
    let accentPreset: String
    let useCustomAccent: Bool
    let customAccentRGBA: [Double]
    let tintedBackground: Bool
    let animationsEnabled: Bool
    let hotKeyCode: UInt32?
    let hotKeyModifiers: UInt32?
    let notifySessionEnded: Bool
    let notifyFriendOnline: Bool
    let notifyGameUpdates: Bool
    let notifyWishlistSales: Bool
    let notifyPlaytimeGoal: Bool
    let autoCheckForUpdates: Bool
    let notifyAppUpdates: Bool
    let launchAtLogin: Bool
}

/// User-tweakable appearance settings, persisted to UserDefaults. The window
/// root applies `accentColor` via .tint and `colorScheme` via
/// .preferredColorScheme, so every control follows these live.
@MainActor
@Observable
final class SettingsStore {
    private enum Keys {
        static let appearance = "settings.appearance"
        static let accentPreset = "settings.accentPreset"
        static let useCustomAccent = "settings.useCustomAccent"
        static let customAccent = "settings.customAccentRGBA"
        static let tintedBackground = "settings.tintedBackground"
        static let animationsEnabled = "settings.animationsEnabled"
        static let hotKeyCode = "settings.hotKeyCode"
        static let hotKeyModifiers = "settings.hotKeyModifiers"
        static let notifySessionEnded = "settings.notifySessionEnded"
        static let notifyFriendOnline = "settings.notifyFriendOnline"
        static let notifyGameUpdates = "settings.notifyGameUpdates"
        static let notifyWishlistSales = "settings.notifyWishlistSales"
        static let notifyPlaytimeGoal = "settings.notifyPlaytimeGoal"
        static let autoCheckForUpdates = "settings.autoCheckForUpdates"
        static let notifyAppUpdates = "settings.notifyAppUpdates"
        static let lastUpdateCheckDate = "settings.lastUpdateCheckDate"
        static let skippedUpdateVersion = "settings.skippedUpdateVersion"
    }

    var appearance: AppearanceMode {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var accentPreset: AccentPreset {
        didSet { UserDefaults.standard.set(accentPreset.rawValue, forKey: Keys.accentPreset) }
    }

    var useCustomAccent: Bool {
        didSet { UserDefaults.standard.set(useCustomAccent, forKey: Keys.useCustomAccent) }
    }

    var customAccent: Color {
        didSet { Self.saveColor(customAccent, forKey: Keys.customAccent) }
    }

    /// Accent-tinted ambient background behind content.
    var tintedBackground: Bool {
        didSet { UserDefaults.standard.set(tintedBackground, forKey: Keys.tintedBackground) }
    }

    /// Master switch for the app's motion layer (entrances, tilt, shine,
    /// parallax, ambient drift, …).
    var animationsEnabled: Bool {
        didSet { UserDefaults.standard.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    /// Source of truth is SMAppService itself (not UserDefaults) — the user
    /// can also toggle this from System Settings ▸ General ▸ Login Items,
    /// so a locally-cached preference could drift from what's actually
    /// registered.
    private(set) var launchAtLogin: Bool
    private(set) var launchAtLoginError: String?

    /// Global "summon Mist" shortcut. Carbon registrations don't persist
    /// across launches, so a saved combo is re-registered in `init()`.
    private(set) var hotKeyCode: UInt32?
    private(set) var hotKeyModifiers: UInt32?

    var hotKeyDisplayString: String? {
        guard let hotKeyCode, let hotKeyModifiers else { return nil }
        return Self.displayString(keyCode: hotKeyCode, modifiers: hotKeyModifiers)
    }

    /// Notification toggles — all off by default (never opt someone into
    /// system notifications without them asking). Turning any of these on
    /// triggers the one-time system authorization prompt.
    var notifySessionEnded: Bool {
        didSet {
            UserDefaults.standard.set(notifySessionEnded, forKey: Keys.notifySessionEnded)
            if notifySessionEnded { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    var notifyFriendOnline: Bool {
        didSet {
            UserDefaults.standard.set(notifyFriendOnline, forKey: Keys.notifyFriendOnline)
            if notifyFriendOnline { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    var notifyGameUpdates: Bool {
        didSet {
            UserDefaults.standard.set(notifyGameUpdates, forKey: Keys.notifyGameUpdates)
            if notifyGameUpdates { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    var notifyWishlistSales: Bool {
        didSet {
            UserDefaults.standard.set(notifyWishlistSales, forKey: Keys.notifyWishlistSales)
            if notifyWishlistSales { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    var notifyPlaytimeGoal: Bool {
        didSet {
            UserDefaults.standard.set(notifyPlaytimeGoal, forKey: Keys.notifyPlaytimeGoal)
            if notifyPlaytimeGoal { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    /// Whether Mist itself should periodically check GitHub for a newer
    /// release. On by default — unlike the notification toggles above, this
    /// isn't a system permission prompt, just a background network poll.
    var autoCheckForUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckForUpdates, forKey: Keys.autoCheckForUpdates) }
    }

    /// Separate from `notifyGameUpdates` (installed Steam games updating) —
    /// this is specifically about Mist's own releases.
    var notifyAppUpdates: Bool {
        didSet {
            UserDefaults.standard.set(notifyAppUpdates, forKey: Keys.notifyAppUpdates)
            if notifyAppUpdates { NotificationService.shared.requestAuthorizationIfNeeded() }
        }
    }

    var lastUpdateCheckDate: Date? {
        didSet { UserDefaults.standard.set(lastUpdateCheckDate, forKey: Keys.lastUpdateCheckDate) }
    }

    /// Release tag the user dismissed via "Skip This Version" — cleared
    /// automatically once a newer tag appears.
    var skippedUpdateVersion: String? {
        didSet { UserDefaults.standard.set(skippedUpdateVersion, forKey: Keys.skippedUpdateVersion) }
    }

    var accentColor: Color {
        useCustomAccent ? customAccent : accentPreset.color
    }

    var colorScheme: ColorScheme? {
        appearance.colorScheme
    }

    init() {
        let defaults = UserDefaults.standard
        appearance = defaults.string(forKey: Keys.appearance)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
        accentPreset = defaults.string(forKey: Keys.accentPreset)
            .flatMap(AccentPreset.init(rawValue:)) ?? .steamBlue
        useCustomAccent = defaults.bool(forKey: Keys.useCustomAccent)
        customAccent = Self.loadColor(forKey: Keys.customAccent) ?? AccentPreset.steamBlue.color
        tintedBackground = defaults.object(forKey: Keys.tintedBackground) as? Bool ?? true
        animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        notifySessionEnded = defaults.bool(forKey: Keys.notifySessionEnded)
        notifyFriendOnline = defaults.bool(forKey: Keys.notifyFriendOnline)
        notifyGameUpdates = defaults.bool(forKey: Keys.notifyGameUpdates)
        notifyWishlistSales = defaults.bool(forKey: Keys.notifyWishlistSales)
        notifyPlaytimeGoal = defaults.bool(forKey: Keys.notifyPlaytimeGoal)
        autoCheckForUpdates = defaults.object(forKey: Keys.autoCheckForUpdates) as? Bool ?? true
        notifyAppUpdates = defaults.object(forKey: Keys.notifyAppUpdates) as? Bool ?? true
        lastUpdateCheckDate = defaults.object(forKey: Keys.lastUpdateCheckDate) as? Date
        skippedUpdateVersion = defaults.string(forKey: Keys.skippedUpdateVersion)
        launchAtLogin = SMAppService.mainApp.status == .enabled

        if let savedCode = defaults.object(forKey: Keys.hotKeyCode) as? Int,
           let savedModifiers = defaults.object(forKey: Keys.hotKeyModifiers) as? Int {
            hotKeyCode = UInt32(savedCode)
            hotKeyModifiers = UInt32(savedModifiers)
            GlobalHotKeyService.shared.register(keyCode: UInt32(savedCode), modifiers: UInt32(savedModifiers)) {
                AppWindowCoordinator.shared.showMainWindow()
            }
        }
    }

    /// Registers (or, passing nil, clears) the global "summon Mist" shortcut.
    func setHotKey(keyCode: UInt32?, modifiers: UInt32?) {
        hotKeyCode = keyCode
        hotKeyModifiers = modifiers
        if let keyCode, let modifiers {
            UserDefaults.standard.set(Int(keyCode), forKey: Keys.hotKeyCode)
            UserDefaults.standard.set(Int(modifiers), forKey: Keys.hotKeyModifiers)
            GlobalHotKeyService.shared.register(keyCode: keyCode, modifiers: modifiers) {
                AppWindowCoordinator.shared.showMainWindow()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.hotKeyCode)
            UserDefaults.standard.removeObject(forKey: Keys.hotKeyModifiers)
            GlobalHotKeyService.shared.unregister()
        }
    }

    /// Common keys only (letters, digits, a few named keys) — good enough
    /// for the vast majority of hotkey choices; anything else falls back to
    /// a numeric label rather than mistranslating it.
    private static let keyCodeNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
        27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
        46: "M", 47: ".",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
    ]

    private static func displayString(keyCode: UInt32, modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        result += keyCodeNames[keyCode] ?? "Key \(keyCode)"
        return result
    }

    /// Registers/unregisters the app as a login item via SMAppService. The
    /// user approves this once in System Settings ▸ General ▸ Login Items;
    /// no paid Developer Program entitlement is required.
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func apply(_ preset: ThemePreset) {
        appearance = preset.appearance
        accentPreset = preset.accent
        useCustomAccent = false
    }

    func resetToDefaults() {
        appearance = .system
        accentPreset = .steamBlue
        useCustomAccent = false
        customAccent = AccentPreset.steamBlue.color
        tintedBackground = true
        animationsEnabled = true
    }

    // MARK: - Export / import

    /// Dumps user-facing preferences to a portable JSON blob, for backing up
    /// or moving to another Mac. Deliberately excludes runtime bookkeeping
    /// that isn't really a "preference" — `lastUpdateCheckDate` and
    /// `skippedUpdateVersion` are tied to this machine's update-check
    /// history, not something worth carrying across.
    func exportSettings() throws -> Data {
        let export = SettingsExport(
            appearance: appearance.rawValue,
            accentPreset: accentPreset.rawValue,
            useCustomAccent: useCustomAccent,
            customAccentRGBA: Self.colorComponents(customAccent),
            tintedBackground: tintedBackground,
            animationsEnabled: animationsEnabled,
            hotKeyCode: hotKeyCode,
            hotKeyModifiers: hotKeyModifiers,
            notifySessionEnded: notifySessionEnded,
            notifyFriendOnline: notifyFriendOnline,
            notifyGameUpdates: notifyGameUpdates,
            notifyWishlistSales: notifyWishlistSales,
            notifyPlaytimeGoal: notifyPlaytimeGoal,
            autoCheckForUpdates: autoCheckForUpdates,
            notifyAppUpdates: notifyAppUpdates,
            launchAtLogin: launchAtLogin
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// Applies a previously-exported blob, going through the same setters
    /// (and thus the same `didSet` persistence / side effects, e.g.
    /// re-registering the hotkey or requesting notification authorization)
    /// as if the user had changed each one by hand.
    func importSettings(from data: Data) throws {
        let export = try JSONDecoder().decode(SettingsExport.self, from: data)
        appearance = AppearanceMode(rawValue: export.appearance) ?? appearance
        accentPreset = AccentPreset(rawValue: export.accentPreset) ?? accentPreset
        useCustomAccent = export.useCustomAccent
        if export.customAccentRGBA.count == 4 {
            customAccent = Color(
                .sRGB,
                red: export.customAccentRGBA[0],
                green: export.customAccentRGBA[1],
                blue: export.customAccentRGBA[2],
                opacity: export.customAccentRGBA[3]
            )
        }
        tintedBackground = export.tintedBackground
        animationsEnabled = export.animationsEnabled
        notifySessionEnded = export.notifySessionEnded
        notifyFriendOnline = export.notifyFriendOnline
        notifyGameUpdates = export.notifyGameUpdates
        notifyWishlistSales = export.notifyWishlistSales
        notifyPlaytimeGoal = export.notifyPlaytimeGoal
        autoCheckForUpdates = export.autoCheckForUpdates
        notifyAppUpdates = export.notifyAppUpdates
        setHotKey(keyCode: export.hotKeyCode, modifiers: export.hotKeyModifiers)
        setLaunchAtLogin(export.launchAtLogin)
    }

    // MARK: - Color persistence (sRGB components in UserDefaults)

    private static func saveColor(_ color: Color, forKey key: String) {
        UserDefaults.standard.set(colorComponents(color), forKey: key)
    }

    private static func colorComponents(_ color: Color) -> [Double] {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return [0, 0, 0, 1] }
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent]
    }

    private static func loadColor(forKey key: String) -> Color? {
        guard let components = UserDefaults.standard.array(forKey: key) as? [Double],
              components.count == 4 else {
            return nil
        }
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }
}
