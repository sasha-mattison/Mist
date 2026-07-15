import SwiftUI

struct GameLibraryGridView: View {
    let items: [GameLibraryItem]
    let onOpenDetail: (GameLibraryItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 24)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    GameCardView(item: item, index: index, onOpenDetail: { onOpenDetail(item) })
                }
            }
            .padding(24)
        }
    }
}
