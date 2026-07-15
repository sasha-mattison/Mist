import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case library = "Library"
    case friends = "Friends"
    case store = "Store"
    case community = "Community"
    case profile = "Profile"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: return "square.grid.2x2"
        case .friends: return "person.2"
        case .store: return "cart"
        case .community: return "person.3"
        case .profile: return "person.crop.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarSection
    let onSignIn: () -> Void

    @Environment(GameLibraryStore.self) private var store

    var body: some View {
        List(SidebarSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.systemImage)
                .tag(section)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if let summary = store.playerSummary {
                ProfileFooter(
                    summary: summary,
                    gameCount: store.libraryItems.count,
                    isSignedIn: store.signedInSteamID64 != nil,
                    onOpenProfile: { selection = .profile },
                    onSignOut: { store.signOut() }
                )
            } else {
                SignInFooter(onSignIn: onSignIn)
            }
        }
    }
}

private struct ProfileFooter: View {
    let summary: PlayerSummary
    let gameCount: Int
    let isSignedIn: Bool
    let onOpenProfile: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        Button(action: onOpenProfile) {
            HStack(spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.personaName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("\(gameCount) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .help("Open your Steam profile")
        .contextMenu {
            Button("View Profile", systemImage: "person.crop.circle", action: onOpenProfile)
            if isSignedIn {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", action: onSignOut)
            }
        }
    }

    private var avatar: some View {
        AsyncImage(url: summary.avatarFullURL.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }
}

private struct SignInFooter: View {
    let onSignIn: () -> Void

    var body: some View {
        Button(action: onSignIn) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sign in with Steam")
                        .font(.callout.weight(.semibold))
                    Text("Load your profile & friends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}
