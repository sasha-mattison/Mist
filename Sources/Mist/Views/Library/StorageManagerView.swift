import AppKit
import SwiftUI

/// Installed games ranked by disk usage — all from `sizeOnDisk`, already
/// parsed locally by SteamLocalDataService, so this is pure presentation over
/// existing data. There's no confirmed `steam://uninstall/<id>` handler, so
/// "manage" opens the title's Steam store page (where Steam's own uninstall
/// lives) rather than promising an in-app uninstall.
struct StorageManagerView: View {
    let items: [GameLibraryItem]
    let onOpenGame: (GameLibraryItem) -> Void
    let onDismiss: () -> Void

    @Environment(SettingsStore.self) private var settings

    private var installed: [GameLibraryItem] {
        // Custom (non-Steam) entries are excluded: their size isn't measured
        // (would always rank as 0 bytes), so they'd just be dead weight in a
        // view that's specifically about ranking by disk usage.
        items.filter { $0.isInstalled && !$0.isCustom }.sorted { $0.sizeOnDisk > $1.sizeOnDisk }
    }

    private var totalBytes: Int64 {
        installed.reduce(0) { $0 + $1.sizeOnDisk }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if installed.isEmpty {
                ContentUnavailableView(
                    "Nothing installed",
                    systemImage: "internaldrive",
                    description: Text("Install some games via Steam to see them here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(installed) { item in
                            StorageRow(
                                item: item,
                                fraction: fraction(for: item),
                                accent: settings.accentColor,
                                onOpenGame: {
                                    onDismiss()
                                    onOpenGame(item)
                                }
                            )
                        }
                    }
                    .padding(24)
                }
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 620)
        // Sheets don't inherit .tint() from the presenting window on macOS.
        .tint(settings.accentColor)
    }

    private func fraction(for item: GameLibraryItem) -> Double {
        guard totalBytes > 0 else { return 0 }
        return Double(item.sizeOnDisk) / Double(totalBytes)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Storage")
                .font(.title2.weight(.semibold))
            Text("^[\(installed.count) game](inflect: true) installed — \(Formatters.size.string(fromByteCount: totalBytes)) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
}

private struct StorageRow: View {
    let item: GameLibraryItem
    let fraction: Double
    let accent: Color
    let onOpenGame: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // The tappable "open detail" area is a plain view with a tap
            // gesture, not a Button — nesting the Finder/Steam buttons inside
            // a Button's label fires every action on one click (confirmed
            // the hard way in GameCardView; see its header comment).
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(item.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(Formatters.size.string(fromByteCount: item.sizeOnDisk))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule()
                            .fill(accent.gradient)
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 5)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenGame)

            if let installURL = item.installURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([installURL])
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
            }

            Button {
                GameLaunchService.openStoreInSteam(appID: item.appID)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Manage in Steam (uninstall, verify files, …)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
