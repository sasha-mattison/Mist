import Foundation

struct LibraryFolder: Hashable {
    let path: String

    var steamAppsURL: URL {
        URL(fileURLWithPath: path).appendingPathComponent("steamapps")
    }
}
