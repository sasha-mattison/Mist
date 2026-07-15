import SwiftUI

struct MenuBarLabelView: View {
    @Environment(GameLibraryStore.self) private var store

    var body: some View {
        Image(systemName: store.runningAppID != nil ? "gamecontroller.fill" : "gamecontroller")
    }
}
