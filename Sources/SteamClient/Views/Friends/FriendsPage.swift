import AppKit
import SwiftUI

/// Friends root: grouped presence list (In-Game / Online / Offline) with
/// search, chat and profile actions. Needs a Web API key plus a signed-in or
/// locally detected SteamID; shows a setup prompt otherwise.
struct FriendsPage: View {
    let onSignIn: () -> Void
    let onSetupAPIKey: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(FriendsStore.self) private var friendsStore
    @ViewState private var searchText = ""

    private var needsAPIKey: Bool { KeychainService.loadAPIKey() == nil }
    private var needsIdentity: Bool { store.activeSteamID64 == nil }

    var body: some View {
        Group {
            if needsAPIKey || needsIdentity {
                setupPrompt
            } else if let error = friendsStore.error, friendsStore.friends.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load friends", systemImage: "person.2.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await friendsStore.refresh() }
                    }
                }
            } else if friendsStore.friends.isEmpty && friendsStore.isLoading {
                ProgressView("Loading friends…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if friendsStore.friends.isEmpty {
                ContentUnavailableView(
                    "No friends found",
                    systemImage: "person.2",
                    description: Text("Your Steam friends list is empty, or it's set to private in your Steam profile privacy settings.")
                )
            } else {
                friendsList
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search friends")
        .toolbar {
            ToolbarItem {
                if friendsStore.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await friendsStore.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await friendsStore.refreshIfStale()
        }
    }

    // MARK: - List

    private var friendsList: some View {
        List {
            ForEach(FriendsStore.PresenceGroup.allCases) { group in
                let members = friendsStore.friends(in: group, matching: searchText)
                if !members.isEmpty {
                    Section("\(group.rawValue) (\(members.count))") {
                        ForEach(members) { friend in
                            FriendRowView(friend: friend)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = friendsStore.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Setup prompt

    private var setupPrompt: some View {
        ContentUnavailableView {
            Label("Connect to see your friends", systemImage: "person.2")
        } description: {
            Text(needsIdentity
                 ? "Sign in with Steam so we know whose friends list to load."
                 : "Friends data comes from the Steam Web API — add your API key to continue.")
        } actions: {
            if needsIdentity {
                Button("Sign in with Steam", action: onSignIn)
                    .buttonStyle(.borderedProminent)
            }
            if needsAPIKey {
                Button("Add Web API Key", action: onSetupAPIKey)
            }
        }
    }
}

// MARK: - Row

private struct FriendRowView: View {
    let friend: FriendsStore.Friend

    @Environment(SettingsStore.self) private var settings
    @ViewState private var isHovering = false

    private var statusColor: Color {
        switch friend.group {
        case .inGame: return .green
        case .online: return .blue
        case .offline: return .secondary.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(friend.summary?.statusText ?? "Offline")
                    .font(.caption)
                    .foregroundStyle(friend.group == .inGame ? .green : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isHovering {
                HStack(spacing: 6) {
                    Button {
                        GameLaunchService.openChat(steamID64: friend.steamID64)
                    } label: {
                        Image(systemName: "bubble.left.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Message in Steam")

                    Button(action: openProfile) {
                        Image(systemName: "person.crop.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("View Steam profile")
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Message in Steam", systemImage: "bubble.left") {
                GameLaunchService.openChat(steamID64: friend.steamID64)
            }
            Button("View Profile", systemImage: "person.crop.circle", action: openProfile)
            if let friendSince = friend.friendSince {
                Divider()
                Text("Friends since \(friendSince.formatted(date: .abbreviated, time: .omitted))")
            }
        }
    }

    private func openProfile() {
        let fallback = "https://steamcommunity.com/profiles/\(friend.steamID64)"
        if let url = URL(string: friend.summary?.profileURL ?? fallback) {
            NSWorkspace.shared.open(url)
        }
    }

    private var avatar: some View {
        AsyncImage(url: friend.summary?.avatarFullURL.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            statusDot
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        let dot = Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(.background, lineWidth: 2))
        if friend.group == .inGame && settings.animationsEnabled {
            dot.phaseAnimator([false, true]) { view, pulsing in
                view
                    .scaleEffect(pulsing ? 1.25 : 1.0)
                    .shadow(color: .green.opacity(pulsing ? 0.7 : 0.2), radius: pulsing ? 5 : 1)
            } animation: { _ in
                .easeInOut(duration: 1.0)
            }
        } else {
            dot
        }
    }
}
