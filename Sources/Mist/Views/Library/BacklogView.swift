import SwiftUI

/// Surfaces owned games with zero playtime — the "haven't gotten to it yet"
/// pile — plus a random pick to cut through decision paralysis. Purely
/// derived from GameLibraryStore's existing data, no new service needed.
struct BacklogView: View {
    let items: [GameLibraryItem]
    let onOpenGame: (GameLibraryItem) -> Void
    let onDismiss: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @ViewState private var pick: GameLibraryItem?
    @ViewState private var isRolling = false
    @ViewState private var showInstalledOnly = false
    @ViewState private var selectedCollectionID: String?

    /// Filters affect both the roulette and the list below it, so what gets
    /// rolled always matches what's visible — a roll that could land outside
    /// the shown set would be confusing. Custom (non-Steam) entries are
    /// excluded outright: playtime isn't tracked for them, so they'd always
    /// read as "zero playtime" and permanently clutter the backlog.
    private var backlog: [GameLibraryItem] {
        var result = items.filter { $0.playtimeForeverMinutes == 0 && !$0.isCustom }
        if showInstalledOnly {
            result = result.filter(\.isInstalled)
        }
        if let selectedCollectionID, let collection = store.collections.first(where: { $0.id == selectedCollectionID }) {
            let ids = Set(collection.appIDs)
            result = result.filter { ids.contains($0.appID) }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if backlog.isEmpty {
                ContentUnavailableView(
                    "Backlog's empty",
                    systemImage: "checkmark.circle",
                    description: Text(isFiltering
                        ? "Nothing matches these filters. Try loosening them."
                        : "Every game you own has at least some playtime. Nicely done.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        pickCard
                        restOfBacklogSection
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 620)
        .onAppear {
            guard pick == nil else { return }
            if let persisted = PlaytimeGoalStore.shared.currentBacklogPick(in: backlog) {
                pick = persisted
            } else {
                rollPick()
            }
        }
        .onChange(of: showInstalledOnly) { _, _ in rerollIfNeeded() }
        .onChange(of: selectedCollectionID) { _, _ in rerollIfNeeded() }
    }

    /// Filters can invalidate the current pick (or the persisted one from a
    /// prior session) — reroll from the now-filtered set rather than leaving
    /// a pick on screen that contradicts the active filter.
    private func rerollIfNeeded() {
        if let pick, !backlog.contains(pick) {
            rollPick()
        } else if pick == nil {
            rollPick()
        }
    }

    private var isFiltering: Bool { showInstalledOnly || selectedCollectionID != nil }

    private var header: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("What Should I Play?")
                    .font(.title2.weight(.semibold))
                Text("^[\(backlog.count) game](inflect: true) in your backlog — owned, never played.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                filterMenu
            }
        }
        .padding(.horizontal, 20)
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
    private var pickCard: some View {
        if let pick {
            VStack(alignment: .leading, spacing: 12) {
                AsyncImage(url: URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(pick.appID)/header.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .opacity(isRolling ? 0.3 : 1)
                .scaleEffect(isRolling ? 0.97 : 1)

                Text(pick.name)
                    .font(.title3.weight(.bold))

                if let pickedDate = PlaytimeGoalStore.shared.pickedBacklogDate {
                    Text("Picked \(Formatters.lastPlayed.localizedString(for: pickedDate, relativeTo: .now)) — stays until you roll again or a week passes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        onDismiss()
                        onOpenGame(pick)
                    } label: {
                        Label("View Details", systemImage: "info.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: rollPick) {
                        Label("Roll Again", systemImage: "shuffle")
                    }
                }
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 18))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isRolling)
        }
    }

    private var restOfBacklogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Full Backlog")
            VStack(spacing: 6) {
                ForEach(backlog) { item in
                    Button {
                        onDismiss()
                        onOpenGame(item)
                    } label: {
                        HStack {
                            Text(item.name)
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                            if item.isInstalled {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .help("Installed")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Toggle("Installed Only", isOn: $showInstalledOnly)
            if !store.collections.isEmpty {
                Divider()
                Picker("Collection", selection: $selectedCollectionID) {
                    Text("All Games").tag(String?.none)
                    ForEach(store.collections) { collection in
                        Text(collection.name).tag(String?.some(collection.id))
                    }
                }
            }
        } label: {
            Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundStyle(isFiltering ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .help("Filter which games can be picked")
    }

    private func rollPick() {
        guard !backlog.isEmpty else { return }
        isRolling = true
        let newPick = backlog.randomElement()
        pick = newPick
        PlaytimeGoalStore.shared.setBacklogPick(newPick)
        Task {
            try? await Task.sleep(for: .milliseconds(280))
            isRolling = false
        }
    }
}
