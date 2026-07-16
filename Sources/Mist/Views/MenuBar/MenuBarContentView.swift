import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(GameLibraryStore.self) private var store
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @ViewState private var searchText = ""

    private var runningGame: GameLibraryItem? {
        guard let runningAppID = store.runningAppID else { return nil }
        return store.libraryItems.first { $0.appID == runningAppID }
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    /// Default view shows the six most recent games; searching widens to every
    /// installed game so the menu doubles as a quick launcher.
    private var quickLaunchItems: [GameLibraryItem] {
        let installed = store.libraryItems.filter(\.isInstalled)
        if query.isEmpty {
            return Array(
                installed
                    .filter { $0.lastPlayed != nil }
                    .sorted { $0.lastPlayed! > $1.lastPlayed! }
                    .prefix(6)
            )
        }
        return Array(
            installed
                .filter { $0.name.localizedCaseInsensitiveContains(query) }
                .prefix(8)
        )
    }

    private var onlineFriends: [FriendsStore.Friend] {
        Array(
            friendsStore.friends
                .filter { $0.group != .offline }
                .sorted { lhs, rhs in
                    if (lhs.group == .inGame) != (rhs.group == .inGame) {
                        return lhs.group == .inGame
                    }
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                .prefix(5)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let summary = store.playerSummary {
                IdentityHeader(summary: summary)
                Divider()
            }

            if let runningGame {
                NowPlayingRow(item: runningGame, since: store.runningSince)
                Divider()
            }

            searchField

            let items = quickLaunchItems
            if items.isEmpty {
                Text(query.isEmpty ? "No games played yet" : "No installed games match “\(query)”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
            } else {
                ForEach(items) { item in
                    QuickLaunchRow(item: item, isPlaying: item.appID == store.runningAppID) {
                        dismiss()
                    }
                }
            }

            if !onlineFriends.isEmpty {
                Divider()
                MenuSectionLabel(text: "Friends Online (\(friendsStore.friends.filter { $0.group != .offline }.count))")
                ForEach(onlineFriends) { friend in
                    FriendPresenceRow(friend: friend) { dismiss() }
                }
            }

            Divider()
            footer
        }
        .frame(width: 300)
        .padding(.vertical, 8)
        .tint(settings.accentColor)
        .task {
            await friendsStore.refreshIfStale()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search installed games", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.callout)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Show Library") { showMainWindow() }
            Button("Open Steam") {
                GameLaunchService.openSteam()
                dismiss()
            }
            Spacer()
            Button {
                store.refreshLocal()
                Task { await store.refreshRemote() }
            } label: {
                if store.isRefreshingRemote {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .help("Refresh library")
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .padding(12)
    }

    /// Brings the main window forward, recreating it if the user closed it
    /// (the app keeps running for the menu bar extra).
    private func showMainWindow() {
        dismiss()
        AppWindowCoordinator.shared.showMainWindow()
    }
}

// MARK: - Rows

private struct MenuSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

private struct IdentityHeader: View {
    let summary: PlayerSummary

    private var statusColor: Color {
        if summary.isInGame { return .green }
        return summary.isOnline ? .blue : .secondary.opacity(0.5)
    }

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: summary.avatarFullURL.flatMap(URL.init(string:))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(summary.personaName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(summary.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct NowPlayingRow: View {
    let item: GameLibraryItem
    let since: Date?

    @ViewState private var isPulsing = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0.5 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(item.name)
                    .font(.callout.weight(.semibold))
            }
            Spacer()
            if let since {
                TimelineView(.periodic(from: since, by: 60)) { context in
                    Text(sessionText(now: context.date, since: since))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sessionText(now: Date, since: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(since) / 60))
        return Formatters.playtime(minutes: max(minutes, 1))
    }
}

private struct QuickLaunchRow: View {
    let item: GameLibraryItem
    let isPlaying: Bool
    let onLaunch: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button {
            GameLaunchService.launch(appID: item.appID)
            onLaunch()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "play.circle.fill" : "gamecontroller")
                    .foregroundStyle(isPlaying ? .green : .secondary)
                Text(item.name)
                    .lineLimit(1)
                Spacer()
                if let lastPlayed = item.lastPlayed {
                    Text(Formatters.lastPlayed.localizedString(for: lastPlayed, relativeTo: .now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovering ? Color.primary.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

private struct FriendPresenceRow: View {
    let friend: FriendsStore.Friend
    let onOpen: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button {
            GameLaunchService.openChat(steamID64: friend.steamID64)
            onOpen()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(friend.group == .inGame ? .green : .blue)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(friend.displayName)
                        .font(.callout)
                        .lineLimit(1)
                    if friend.group == .inGame, let status = friend.summary?.statusText {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isHovering {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(isHovering ? Color.primary.opacity(0.08) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Message in Steam")
    }
}
