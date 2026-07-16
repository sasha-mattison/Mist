import Foundation

/// Marketing version and build number, stamped into the app bundle's
/// Info.plist by Scripts/build-app.sh from the VERSION file and the git
/// commit count.
enum AppVersion {
    /// e.g. "0.2.0 (14)"; falls back to "dev" when running outside an app
    /// bundle (plain `swift run`).
    static var display: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "dev" }
        guard let build = info?["CFBundleVersion"] as? String else { return short }
        return "\(short) (\(build))"
    }

    /// Parsed `CFBundleShortVersionString`; `nil` when running outside an
    /// app bundle (plain `swift run`), which UpdateChecker treats as "don't
    /// check for updates".
    static var current: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }
}

/// A `major.minor.patch` version, parsed from strings like "1.2.3" or the
/// "v1.2.3" tag format GitHub releases use.
struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ raw: String) {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") { trimmed.removeFirst() }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]) else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}
