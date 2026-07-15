import SwiftUI

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case name = "Name"
    case recentlyPlayed = "Recently Played"
    case mostPlayed = "Most Played"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .name: return "textformat"
        case .recentlyPlayed: return "clock"
        case .mostPlayed: return "chart.bar"
        }
    }
}

struct ContentView: View {
    @Environment(GameLibraryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @ViewState private var isShowingAPIKeySetup = false
    @ViewState private var isShowingSignIn = false
    @ViewState private var isShowingSettings = false
    @ViewState private var selectedSidebarSection: SidebarSection = .library
    @ViewState private var navigationPath = NavigationPath()
    @ViewState private var searchText = ""
    @ViewState private var sortOrder: LibrarySortOrder = .recentlyPlayed
    @ViewState private var showInstalledOnly = false
    @ViewState private var showMacOnly = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selectedSidebarSection,
                onSignIn: { isShowingSignIn = true }
            )
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailContent
                    .navigationDestination(for: GameLibraryItem.self) { item in
                        GameDetailPage(item: item)
                    }
                    .navigationDestination(for: StoreAppLink.self) { link in
                        StoreDetailPage(link: link)
                    }
                    .toolbar { settingsToolbar }
            }
            .background {
                if settings.tintedBackground {
                    AmbientAccentBackground(
                        accent: settings.accentColor,
                        animated: settings.animationsEnabled
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .tint(settings.accentColor)
        .preferredColorScheme(settings.colorScheme)
        .onChange(of: selectedSidebarSection) { _, _ in
            navigationPath = NavigationPath()
        }
        .task {
            store.refreshLocal()
            await store.loadCachedMacSupport()
            if KeychainService.loadAPIKey() != nil {
                await store.refreshRemote()
            }
        }
        .sheet(isPresented: $isShowingAPIKeySetup) {
            APIKeySetupView(store: store, onDismiss: { isShowingAPIKeySetup = false })
        }
        .sheet(isPresented: $isShowingSignIn) {
            SteamSignInSheet(
                store: store,
                onDismiss: { isShowingSignIn = false },
                onNeedsAPIKey: presentAPIKeySetupSoon
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                onDismiss: { isShowingSettings = false },
                onSignIn: presentSignInSoon
            )
        }
    }

    /// Presenting a sheet in the same tick another one dismisses is flaky on
    /// macOS; give the dismissal a beat to finish first.
    private func presentAPIKeySetupSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isShowingAPIKeySetup = true
        }
    }

    private func presentSignInSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            isShowingSignIn = true
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                isShowingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            .help("Settings")
        }
    }

    // MARK: - Section routing

    private var detailContent: some View {
        // ZStack keeps outgoing/incoming sections alive together so the
        // cross-fade transition can play when switching tabs.
        ZStack {
            switch selectedSidebarSection {
            case .library:
                libraryRoot
                    .transition(sectionTransition)
            case .store:
                StorePage(onOpen: { navigationPath.append($0) })
                    .transition(sectionTransition)
            case .friends:
                FriendsPage(
                    onSignIn: { isShowingSignIn = true },
                    onSetupAPIKey: { isShowingAPIKeySetup = true }
                )
                .transition(sectionTransition)
            case .profile:
                ProfilePage(
                    onOpenGame: { navigationPath.append($0) },
                    onOpenStoreItem: { navigationPath.append($0) },
                    onSignIn: { isShowingSignIn = true },
                    onSetupAPIKey: { isShowingAPIKeySetup = true }
                )
                .transition(sectionTransition)
            }
        }
        .animation(
            settings.animationsEnabled ? .smooth(duration: 0.3) : nil,
            value: selectedSidebarSection
        )
    }

    private var sectionTransition: AnyTransition {
        .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.995))
    }

    // MARK: - Library

    private var visibleItems: [GameLibraryItem] {
        var items = store.libraryItems
        if showInstalledOnly {
            items = items.filter(\.isInstalled)
        }
        if showMacOnly {
            items = items.filter { store.isMacPlayable($0) }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        switch sortOrder {
        case .name:
            return items
        case .recentlyPlayed:
            return items.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .mostPlayed:
            return items.sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
        }
    }

    @ViewBuilder
    private var libraryRoot: some View {
        if !store.isSteamFound {
            SteamNotFoundView()
        } else if let loadError = store.loadError {
            ContentUnavailableView(
                "Couldn't read Steam library",
                systemImage: "xmark.octagon",
                description: Text(loadError)
            )
        } else if store.libraryItems.isEmpty {
            loadingSkeletonGrid
        } else {
            libraryContent
                .navigationTitle("Library")
                .searchable(text: $searchText, placement: .toolbar, prompt: "Search games")
                .toolbar { libraryToolbar }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        let items = visibleItems
        if items.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            GameLibraryGridView(items: items) { item in
                navigationPath.append(item)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 6) {
                    if let remoteError = store.remoteError {
                        RemoteErrorBanner(message: remoteError)
                    }
                    if showMacOnly, store.isResolvingMacSupport {
                        MacFilterProgressBanner(remaining: store.unresolvedMacSupportCount)
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Sort By", selection: $sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Label(order.rawValue, systemImage: order.systemImage).tag(order)
                    }
                }
                .pickerStyle(.inline)
                Divider()
                Toggle("Installed Only", isOn: $showInstalledOnly)
                Toggle("Playable on Mac", isOn: Binding(
                    get: { showMacOnly },
                    set: { enabled in
                        showMacOnly = enabled
                        // Verdicts stream in from the storefront; the grid
                        // grows live as titles are confirmed.
                        if enabled { store.resolveMacSupport() }
                    }
                ))
            } label: {
                Label("Sort & Filter", systemImage: "line.3.horizontal.decrease")
            }
        }
        ToolbarItem {
            if KeychainService.loadAPIKey() == nil {
                Button {
                    isShowingAPIKeySetup = true
                } label: {
                    Label("Connect Steam Web API", systemImage: "key")
                }
            } else if store.isRefreshingRemote {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refreshRemote() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var loadingSkeletonGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 20)], spacing: 24) {
                ForEach(0..<8, id: \.self) { _ in
                    GameCardSkeletonView()
                }
            }
            .padding(24)
        }
    }
}

private struct MacFilterProgressBanner: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text("Checking Mac support with the Steam store — \(remaining) to go. Games appear as they're confirmed.")
                .font(.callout)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(in: .capsule)
        .padding(.top, 8)
    }
}

private struct RemoteErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
            .padding(.top, 8)
    }
}
