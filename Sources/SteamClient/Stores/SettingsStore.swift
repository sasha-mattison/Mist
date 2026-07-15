import AppKit
import Observation
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

    // MARK: - Color persistence (sRGB components in UserDefaults)

    private static func saveColor(_ color: Color, forKey key: String) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        let components = [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, srgb.alphaComponent]
        UserDefaults.standard.set(components.map(Double.init), forKey: key)
    }

    private static func loadColor(forKey key: String) -> Color? {
        guard let components = UserDefaults.standard.array(forKey: key) as? [Double],
              components.count == 4 else {
            return nil
        }
        return Color(.sRGB, red: components[0], green: components[1], blue: components[2], opacity: components[3])
    }
}
