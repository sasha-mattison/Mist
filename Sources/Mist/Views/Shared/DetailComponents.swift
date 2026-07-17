import AppKit
import SwiftUI

/// Building blocks shared by GameDetailPage (library) and StoreDetailPage
/// (storefront) so both read as the same design.

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.weight(.semibold))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 130, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}

struct InfoCell: View {
    let label: String
    let value: String
    var link: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if let link {
                Link(value, destination: link)
                    .font(.callout)
            } else {
                Text(value)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScreenshotThumbnail: View {
    let screenshot: GameDetails.Screenshot

    var body: some View {
        AsyncImage(url: URL(string: screenshot.pathThumbnail)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 292, height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            if let url = URL(string: screenshot.pathFull) {
                NSWorkspace.shared.open(url)
            }
        }
        .help("Open full-size screenshot")
    }
}

/// "LVL 42" pill used on both the signed-in user's profile and friends'.
struct LevelBadge: View {
    let level: Int
    let accent: Color

    var body: some View {
        Text("LVL \(level)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(accent.gradient)
            )
            .shadow(color: accent.opacity(0.4), radius: 6)
    }
}

/// Trust indicator shown next to the identity header — only renders
/// something when the account actually has a VAC/game/community ban;
/// `PlayerBanStatus.isClean` guards call sites so a clean record just shows
/// nothing rather than a reassuring badge nobody needs.
struct BanStatusBadge: View {
    let status: PlayerBanStatus

    private var summary: String {
        if status.vacBanned { return "VAC Banned" }
        if status.numberOfGameBans > 0 { return "Game Banned" }
        if status.communityBanned { return "Community Banned" }
        return "Trade Banned"
    }

    private var detail: String {
        var parts: [String] = []
        if status.vacBanned {
            parts.append("\(status.numberOfVACBans) VAC ban\(status.numberOfVACBans == 1 ? "" : "s")")
        }
        if status.numberOfGameBans > 0 {
            parts.append("\(status.numberOfGameBans) game ban\(status.numberOfGameBans == 1 ? "" : "s")")
        }
        if status.communityBanned { parts.append("Community banned") }
        if status.daysSinceLastBan > 0 { parts.append("last ban \(status.daysSinceLastBan) days ago") }
        return parts.isEmpty ? "Restricted trading" : parts.joined(separator: " · ")
    }

    var body: some View {
        Label(summary, systemImage: "exclamationmark.shield.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.red.gradient))
            .help(detail)
    }
}

/// One capsule in a "Recently Played" horizontal rail, shared by
/// ProfilePage (the signed-in user) and FriendProfilePage.
struct RecentGameCard: View {
    let appID: Int
    let name: String
    let subtitle: String?
    let effects: Bool
    let index: Int
    let onOpen: () -> Void

    @ViewState private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.quaternary)
                            .overlay {
                                Image(systemName: "gamecontroller")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 240, height: 112)
                .shineSweep(trigger: isHovering, enabled: effects)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 240)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverTilt(enabled: effects)
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.28 : 0.1), radius: isHovering ? 12 : 4, y: isHovering ? 7 : 2)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
        .entranceEffect(index: index, enabled: effects)
    }
}

/// One row in a ranked "Most Played" leaderboard, shared by ProfilePage (the
/// signed-in user's library) and FriendProfilePage (a friend's owned games).
struct MostPlayedRow: View {
    let rank: Int
    let name: String
    let playtimeMinutes: Int
    let fraction: Double
    let accent: Color
    let effects: Bool
    let index: Int
    let onOpen: () -> Void

    @ViewState private var isHovering = false
    @ViewState private var barVisible = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                Text("\(rank)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(rank <= 3 ? AnyShapeStyle(accent) : AnyShapeStyle(.tertiary))
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Text(Formatters.playtime(minutes: playtimeMinutes))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(accent.gradient)
                                .frame(width: geo.size.width * fraction * (barVisible ? 1 : 0))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .entranceEffect(index: index, enabled: effects)
        .onAppear {
            guard effects else {
                barVisible = true
                return
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85).delay(Double(index) * 0.06 + 0.15)) {
                barVisible = true
            }
        }
    }
}

struct GenreChips: View {
    let genres: [GameDetails.Genre]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(genres.prefix(4), id: \.self) { genre in
                Text(genre.description)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(in: .capsule)
            }
        }
    }
}

/// A locally-captured Steam screenshot (your own gallery), as opposed to
/// ScreenshotThumbnail's storefront marketing screenshots. `AsyncImage`
/// handles `file://` URLs the same as remote ones.
struct LocalScreenshotThumbnail: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 292, height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            NSWorkspace.shared.open(url)
        }
        .contextMenu {
            Button("Reveal in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        .help("Open in Preview")
    }
}

/// One row of a DLC list: lazily fetches its own name/price via
/// `SteamStoreClient.details(for:)` when it appears, so a DLC section only
/// pays for as many storefront calls as are actually visible (e.g. inside a
/// collapsed DisclosureGroup, rows aren't mounted — and don't fetch — until
/// expanded).
struct DLCRow: View {
    let appID: Int
    let isOwned: Bool

    @ViewState private var details: GameDetails?

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let details {
                    Text(details.name ?? "App \(appID)")
                } else {
                    Text("App \(appID)")
                        .redacted(reason: .placeholder)
                }
            }
            .font(.callout)
            .lineLimit(1)

            Spacer(minLength: 0)

            if isOwned {
                Label("Owned", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            } else if details?.isFree == true {
                Text("Free")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let price = details?.priceOverview?.finalPriceText {
                Text(price)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .task(id: appID) {
            details = await SteamStoreClient.shared.details(for: appID)
        }
    }
}

/// One badge from GetBadges: game trading-card badges lazily resolve their
/// game's name the same way DLCRow does; special/community badges (no
/// appid) fall back to a generic label since Steam's API has no display-name
/// lookup for those.
struct BadgeRow: View {
    let badge: PlayerBadge

    @ViewState private var details: GameDetails?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "seal.fill")
                .foregroundStyle(.yellow)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let appID = badge.appID {
                        if let details {
                            Text(details.name ?? "App \(appID)")
                        } else {
                            Text("App \(appID)")
                                .redacted(reason: .placeholder)
                        }
                    } else {
                        Text("Special Badge")
                    }
                }
                .font(.callout)
                .lineLimit(1)

                if let date = badge.completionDate {
                    Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if badge.level > 1 {
                Text("Level \(badge.level)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .task(id: badge.appID) {
            if let appID = badge.appID {
                details = await SteamStoreClient.shared.details(for: appID)
            }
        }
    }
}

/// One achievement, unlocked or not, with its global unlock rarity when
/// known. Hidden (spoiler) achievements show a placeholder name/description
/// until unlocked, matching Steam's own behavior.
struct AchievementTile: View {
    let progress: AchievementProgress

    private var isSpoiler: Bool { progress.definition.hidden && !progress.achieved }

    private var displayName: String {
        isSpoiler ? "Hidden Achievement" : progress.definition.displayName
    }

    private var displayDescription: String? {
        isSpoiler ? nil : progress.definition.description
    }

    private var iconURL: URL? {
        let path = progress.achieved ? progress.definition.icon : (progress.definition.iconGray ?? progress.definition.icon)
        return path.flatMap(URL.init(string:))
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    Rectangle().fill(.quaternary)
                        .overlay {
                            Image(systemName: "questionmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(progress.achieved ? 1 : 0.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(progress.achieved ? .primary : .secondary)
                    .lineLimit(1)
                if let displayDescription, !displayDescription.isEmpty {
                    Text(displayDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            if let globalPercent = progress.globalPercent {
                Text(String(format: "%.1f%%", globalPercent))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 12))
        .opacity(progress.achieved ? 1 : 0.8)
    }
}
