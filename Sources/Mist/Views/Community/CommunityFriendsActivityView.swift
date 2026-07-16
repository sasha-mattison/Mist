import SwiftUI

/// Live friend activity: in-game friends grouped by the game they're playing
/// (with a jump to its store page), followed by everyone else online. Needs
/// the same Web API key + identity as the Friends tab.
struct CommunityFriendsActivityView: View {
    let searchText: String
    let onOpenStoreItem: (StoreAppLink) -> Void
    let onOpenProfile: (FriendProfileLink) -> Void
    let onSignIn: () -> Void
    let onSetupAPIKey: () -> Void

    @Environment(GameLibraryStore.self) private var store
    @Environment(FriendsStore.self) private var friendsStore

    private var needsAPIKey: Bool { KeychainService.loadAPIKey() == nil }
    private var needsIdentity: Bool { store.activeSteamID64 == nil }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private func matches(_ friend: FriendsStore.Friend) -> Bool {
        query.isEmpty || friend.displayName.localizedCaseInsensitiveContains(query)
    }

    private var inGameGroups: [GameGroup] {
        let inGame = friendsStore.friends.filter { $0.group == .inGame }
        let grouped = Dictionary(grouping: inGame) { $0.summary?.gameExtraInfo ?? "In a game" }
        return grouped
            .map { name, members in
                GameGroup(
                    appID: members.compactMap { $0.summary?.gameID.flatMap(Int.init) }.first,
                    name: name,
                    friends: members.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            // Match either the game or someone playing it.
            .filter { group in
                query.isEmpty
                    || group.name.localizedCaseInsensitiveContains(query)
                    || group.friends.contains(where: matches)
            }
            .sorted {
                if $0.friends.count != $1.friends.count { return $0.friends.count > $1.friends.count }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var onlineFriends: [FriendsStore.Friend] {
        friendsStore.friends
            .filter { $0.group == .online && matches($0) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        Group {
            if needsAPIKey || needsIdentity {
                setupPrompt
            } else if friendsStore.friends.isEmpty && friendsStore.isLoading {
                ProgressView("Loading friend activity…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = friendsStore.error, friendsStore.friends.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't load friend activity", systemImage: "person.2.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await friendsStore.refresh() }
                    }
                }
            } else if inGameGroups.isEmpty && onlineFriends.isEmpty {
                ContentUnavailableView(
                    "It's quiet right now",
                    systemImage: "person.2.wave.2",
                    description: Text(query.isEmpty
                        ? "None of your friends are online at the moment. Check back later."
                        : "No online friends match “\(query)”.")
                )
            } else {
                activityList
            }
        }
        .task {
            await friendsStore.refreshIfStale()
        }
    }

    // MARK: - Activity list

    private var activityList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !inGameGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "Now Playing")
                        ForEach(inGameGroups) { group in
                            GameGroupCard(group: group, onOpenProfile: onOpenProfile) {
                                if let appID = group.appID {
                                    onOpenStoreItem(StoreAppLink(appID: appID, name: group.name))
                                }
                            }
                        }
                    }
                }

                if !onlineFriends.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Online (\(onlineFriends.count))")
                        ForEach(onlineFriends) { friend in
                            ActivityFriendRow(friend: friend, showsStatus: true, onOpenProfile: onOpenProfile)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Setup prompt

    private var setupPrompt: some View {
        ContentUnavailableView {
            Label("Connect to see friend activity", systemImage: "person.2.wave.2")
        } description: {
            Text(needsIdentity
                 ? "Sign in with Steam so we know whose friends to watch."
                 : "Friend activity comes from the Steam Web API — add your API key to continue.")
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

// MARK: - Game group card

private struct GameGroup: Identifiable {
    let appID: Int?
    let name: String
    let friends: [FriendsStore.Friend]

    var id: String { name }
}

private struct GameGroupCard: View {
    let group: GameGroup
    let onOpenProfile: (FriendProfileLink) -> Void
    let onOpenGame: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if let appID = group.appID {
                    AsyncImage(url: SteamCapsuleArt.url(appID: appID)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(.quaternary)
                        }
                    }
                    .frame(width: 96, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("^[\(group.friends.count) friend](inflect: true) playing")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 0)

                if group.appID != nil {
                    Button(action: onOpenGame) {
                        Image(systemName: "chevron.right.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("View store page")
                }
            }

            VStack(spacing: 0) {
                ForEach(group.friends) { friend in
                    ActivityFriendRow(friend: friend, showsStatus: false, onOpenProfile: onOpenProfile)
                }
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

// MARK: - Friend row

private struct ActivityFriendRow: View {
    let friend: FriendsStore.Friend
    let showsStatus: Bool
    let onOpenProfile: (FriendProfileLink) -> Void

    @ViewState private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: friend.summary?.avatarFullURL.flatMap(URL.init(string:))) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(Circle())

            Text(friend.displayName)
                .font(.callout)
                .lineLimit(1)

            if showsStatus {
                Text(friend.summary?.statusText ?? "Online")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }

    private func openProfile() {
        onOpenProfile(friend.profileLink)
    }
}
