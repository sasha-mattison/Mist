import Foundation

/// A user-curated Steam library collection, read from the local Steam
/// install — used to group/filter the library. Only static (manually
/// curated) collections are surfaced; dynamic/rule-based "smart" collections
/// have no fixed app list and are skipped rather than reimplementing
/// Steam's filter DSL.
struct GameCollection: Identifiable, Hashable {
    let id: String
    let name: String
    let appIDs: [Int]
}
