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
