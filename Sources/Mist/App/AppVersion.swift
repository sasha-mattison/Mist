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
}
