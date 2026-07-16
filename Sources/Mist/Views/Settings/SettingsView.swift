import AppKit
import SwiftUI

/// Settings popup (sheet) with theme & colour customization plus account
/// management. Changes apply live — the window root observes SettingsStore.
struct SettingsView: View {
    let onDismiss: () -> Void
    let onSignIn: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(SettingsStore.self) private var settings

    private enum Tab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case general = "General"
        case account = "Account"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .appearance: return "paintbrush"
            case .general: return "gearshape"
            case .account: return "person.crop.circle"
            }
        }
    }

    @ViewState private var tab: Tab = .appearance

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                Group {
                    switch tab {
                    case .appearance: appearanceTab
                    case .general: generalTab
                    case .account: accountTab
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(width: 660, height: 620)
    }

    private var header: some View {
        VStack(spacing: 14) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420)
        }
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Text("Mist \(AppVersion.display)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
            if tab == .appearance {
                Button("Reset to Defaults") { settings.resetToDefaults() }
            }
            Spacer()
            Button("Done", action: onDismiss)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Appearance tab

    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 28) {
            quickThemesSection
            themeSection
            accentSection
            effectsSection
            previewSection
        }
    }

    // MARK: - General tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 28) {
            generalSection
            notificationsSection
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                effectsToggle(
                    "Game session ended",
                    subtitle: "How long you played, right after you quit.",
                    isOn: Binding(
                        get: { settings.notifySessionEnded },
                        set: { settings.notifySessionEnded = $0 }
                    )
                )
                Divider()
                effectsToggle(
                    "Friends coming online",
                    subtitle: "When a friend who was offline comes online.",
                    isOn: Binding(
                        get: { settings.notifyFriendOnline },
                        set: { settings.notifyFriendOnline = $0 }
                    )
                )
                Divider()
                effectsToggle(
                    "Game updates",
                    subtitle: "When an installed game downloads a new update.",
                    isOn: Binding(
                        get: { settings.notifyGameUpdates },
                        set: { settings.notifyGameUpdates = $0 }
                    )
                )
                Divider()
                effectsToggle(
                    "Wishlist sales",
                    subtitle: "When something on your wishlist goes on sale (checked hourly).",
                    isOn: Binding(
                        get: { settings.notifyWishlistSales },
                        set: { settings.notifyWishlistSales = $0 }
                    )
                )
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                effectsToggle(
                    "Launch at login",
                    subtitle: "Start Mist automatically when you sign in to your Mac.",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global shortcut")
                            .font(.callout.weight(.medium))
                        Text("Summon Mist from anywhere, even when it's not frontmost.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotKeyRecorderView(
                        displayString: settings.hotKeyDisplayString,
                        onRecord: { keyCode, modifiers in settings.setHotKey(keyCode: keyCode, modifiers: modifiers) },
                        onClear: { settings.setHotKey(keyCode: nil, modifiers: nil) }
                    )
                }
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private var quickThemesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Themes")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ThemePreset.all) { preset in
                        QuickThemeCard(
                            preset: preset,
                            isSelected: !settings.useCustomAccent
                                && settings.appearance == preset.appearance
                                && settings.accentPreset == preset.accent
                        ) {
                            settings.apply(preset)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effects")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                effectsToggle(
                    "Tinted background",
                    subtitle: "A soft wash of your accent colour drifts behind the app.",
                    isOn: Binding(
                        get: { settings.tintedBackground },
                        set: { settings.tintedBackground = $0 }
                    )
                )
                Divider()
                effectsToggle(
                    "Animations & effects",
                    subtitle: "Card entrances, 3D hover tilt, shine sweeps and parallax headers.",
                    isOn: Binding(
                        get: { settings.animationsEnabled },
                        set: { settings.animationsEnabled = $0 }
                    )
                )
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private func effectsToggle(_ title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
            HStack(spacing: 12) {
                ForEach(AppearanceMode.allCases) { mode in
                    ThemeCard(
                        mode: mode,
                        isSelected: settings.appearance == mode,
                        accent: settings.accentColor
                    ) {
                        settings.appearance = mode
                    }
                }
            }
        }
    }

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent Colour")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                ForEach(AccentPreset.allCases) { preset in
                    AccentSwatch(
                        color: preset.color,
                        label: preset.label,
                        isSelected: !settings.useCustomAccent && settings.accentPreset == preset
                    ) {
                        settings.useCustomAccent = false
                        settings.accentPreset = preset
                    }
                }
            }
            customColorRow
        }
    }

    private var customColorRow: some View {
        // Explicit binding so picking a colour opts into custom mode, while
        // programmatic writes (e.g. Reset to Defaults) don't loop back and
        // re-enable it via onChange.
        let customAccent = Binding(
            get: { settings.customAccent },
            set: {
                settings.customAccent = $0
                settings.useCustomAccent = true
            }
        )
        return HStack(spacing: 12) {
            ColorPicker("Custom colour", selection: customAccent, supportsOpacity: false)
            if settings.useCustomAccent {
                Label("In use", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            } else {
                Button("Use Custom") { settings.useCustomAccent = true }
                    .controlSize(.small)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            HStack(spacing: 14) {
                Button {} label: {
                    Label("Play", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Toggle("Installed Only", isOn: .constant(true))
                    .toggleStyle(.switch)

                ProgressView(value: 0.6)
                    .frame(width: 120)

                Text("Link colour")
                    .foregroundStyle(.tint)
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 14))
            .allowsHitTesting(false)
        }
    }

    // MARK: - Account tab

    private var accountTab: some View {
        VStack(alignment: .leading, spacing: 28) {
            identitySection
            localAccountsSection
            apiKeySection
        }
    }

    // MARK: - Local account switcher

    @ViewBuilder
    private var localAccountsSection: some View {
        if store.accounts.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Local Steam Accounts")
                    .font(.headline)
                Text("Used when you're not signed in with Steam above — picks which locally-detected account's library and friends Mist reads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(store.accounts.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Divider()
                        }
                        LocalAccountRow(
                            account: account,
                            isSelected: isPreferredLocalAccount(account),
                            isDisabled: store.signedInSteamID64 != nil,
                            onSelect: { selectLocalAccount(account) }
                        )
                    }
                }
                .padding(6)
                .glassEffect(in: .rect(cornerRadius: 14))
            }
        }
    }

    private func isPreferredLocalAccount(_ account: SteamAccount) -> Bool {
        if let preferred = store.preferredLocalSteamID64 {
            return account.steamID64 == preferred
        }
        return account.isAutoLogin
            || account.steamID64 == (store.accounts.first(where: { $0.isAutoLogin }) ?? store.accounts.first)?.steamID64
    }

    private func selectLocalAccount(_ account: SteamAccount) {
        store.setPreferredLocalAccount(steamID64: account.steamID64)
        friendsStore.clear()
        profileStore.clear()
        Task {
            await store.refreshRemote()
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steam Account")
                .font(.headline)
            HStack(spacing: 14) {
                accountAvatar
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.playerSummary?.personaName ?? "Not signed in")
                        .font(.callout.weight(.semibold))
                    if let steamID = store.activeSteamID64 {
                        Text(steamID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text(store.signedInSteamID64 != nil
                             ? "Signed in with Steam"
                             : "Detected from the local Steam install")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sign in to load your profile, library and friends.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if store.signedInSteamID64 != nil {
                    Button("Sign Out") {
                        store.signOut()
                        friendsStore.clear()
                    }
                } else {
                    Button("Sign in with Steam") {
                        onDismiss()
                        onSignIn()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private var accountAvatar: some View {
        AsyncImage(url: store.playerSummary?.avatarFullURL.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var apiKeySection: some View {
        APIKeySettingsSection(store: store, friendsStore: friendsStore)
    }
}

// MARK: - Web API key management

private struct APIKeySettingsSection: View {
    let store: GameLibraryStore
    let friendsStore: FriendsStore

    @ViewState private var hasKey = KeychainService.loadAPIKey() != nil
    @ViewState private var isEditing = false
    @ViewState private var keyInput = ""
    @ViewState private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steam Web API Key")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: hasKey ? "key.fill" : "key.slash")
                        .foregroundStyle(hasKey ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(hasKey ? "Connected — used for owned games, playtime and friends." : "Not configured — remote library and friends are unavailable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hasKey {
                        Button("Remove") {
                            KeychainService.deleteAPIKey()
                            hasKey = false
                            friendsStore.clear()
                        }
                    }
                    Button(hasKey ? "Change…" : "Add Key…") {
                        isEditing.toggle()
                    }
                }
                if isEditing {
                    HStack(spacing: 8) {
                        SecureField("Paste API key", text: $keyInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(save)
                        Button("Save", action: save)
                            .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    HStack(spacing: 4) {
                        Text("Generate a personal key at")
                            .foregroundStyle(.secondary)
                        Link("steamcommunity.com/dev/apikey", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
                    }
                    .font(.caption)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private func save() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.saveAPIKey(trimmed)
            keyInput = ""
            isEditing = false
            errorMessage = nil
            hasKey = true
            Task {
                await store.refreshRemote()
                await friendsStore.refresh()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Local account row

private struct LocalAccountRow: View {
    let account: SteamAccount
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.personaName)
                        .font(.callout.weight(.medium))
                    Text(account.accountName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else if account.isAutoLogin {
                    Text("Auto-login")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isSelected)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Appearance components

private struct QuickThemeCard: View {
    let preset: ThemePreset
    let isSelected: Bool
    let onSelect: () -> Void

    @ViewState private var isHovering = false

    private var mockBackground: Color {
        preset.appearance == .light
            ? Color(red: 0.95, green: 0.95, blue: 0.97)
            : Color(red: 0.13, green: 0.13, blue: 0.15)
    }

    private var mockForeground: Color {
        preset.appearance == .light ? .black : .white
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(mockBackground)
                    VStack(alignment: .leading, spacing: 3) {
                        Circle()
                            .fill(preset.accent.color)
                            .frame(width: 12, height: 12)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(preset.accent.color)
                            .frame(width: 30, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(mockForeground.opacity(0.35))
                            .frame(width: 44, height: 5)
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 96, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            isSelected ? preset.accent.color : Color.primary.opacity(0.12),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                Text(preset.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { isHovering = $0 }
        .help("\(preset.name): \(preset.appearance.label) + \(preset.accent.label)")
    }
}

private struct ThemeCard: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let accent: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                thumbnail
                Label(mode.label, systemImage: mode.systemImage)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.06 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? accent : Color.primary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Miniature window mock-up so the three modes are visually comparable.
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(thumbnailBackground)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 34, height: 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(thumbnailForeground.opacity(0.5))
                    .frame(width: 56, height: 6)
                RoundedRectangle(cornerRadius: 2)
                    .fill(thumbnailForeground.opacity(0.3))
                    .frame(width: 44, height: 6)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 64)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var thumbnailBackground: some ShapeStyle {
        switch mode {
        case .system:
            return AnyShapeStyle(LinearGradient(
                stops: [
                    .init(color: Color(red: 0.95, green: 0.95, blue: 0.97), location: 0.5),
                    .init(color: Color(red: 0.13, green: 0.13, blue: 0.15), location: 0.5)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ))
        case .light:
            return AnyShapeStyle(Color(red: 0.95, green: 0.95, blue: 0.97))
        case .dark:
            return AnyShapeStyle(Color(red: 0.13, green: 0.13, blue: 0.15))
        }
    }

    private var thumbnailForeground: Color {
        mode == .light ? .black : .white
    }
}

private struct AccentSwatch: View {
    let color: Color
    let label: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                }
                .overlay(
                    Circle().stroke(Color.primary.opacity(isSelected ? 0.4 : 0.1), lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
