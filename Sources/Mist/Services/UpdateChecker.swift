import Foundation

/// Periodically polls the Mist GitHub repo's latest release and surfaces it
/// when it's newer than the running build. Follows WishlistSaleMonitor's
/// singleton/poll-loop shape and SteamWebAPIClient's request/validate/decode
/// shape for the HTTP call itself.
@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    weak var settings: SettingsStore?

    /// The newest release GitHub reports, only populated once it's actually
    /// newer than `AppVersion.current` and not the version the user skipped.
    private(set) var availableRelease: GitHubRelease?
    private(set) var isChecking = false
    private(set) var lastError: String?

    private static let apiURL = URL(string: "https://api.github.com/repos/sasha-mattison/Mist/releases/latest")!
    private static let checkInterval: Duration = .seconds(60 * 60 * 24)
    private static let initialDelay: Duration = .seconds(15)

    private var loopTask: Task<Void, Never>?

    private init() {}

    /// Starts the background loop. Safe to call once at app launch.
    func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            try? await Task.sleep(for: Self.initialDelay)
            while !Task.isCancelled {
                if self?.settings?.autoCheckForUpdates != false {
                    await self?.checkOnce()
                }
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    /// Also callable directly from a "Check Now" button, regardless of the
    /// auto-check setting (that toggle only gates the background loop).
    func checkOnce() async {
        guard let current = AppVersion.current else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.apiURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                // No releases published yet — not an error, just nothing to report.
                availableRelease = nil
                lastError = nil
                settings?.lastUpdateCheckDate = Date()
                return
            }
            try Self.validate(response)

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            settings?.lastUpdateCheckDate = Date()
            lastError = nil

            guard let remoteVersion = SemanticVersion(release.tagName), remoteVersion > current else {
                availableRelease = nil
                return
            }
            guard settings?.skippedUpdateVersion != release.tagName else {
                availableRelease = nil
                return
            }

            let isNewlyDiscovered = availableRelease?.tagName != release.tagName
            availableRelease = release
            if isNewlyDiscovered {
                NotificationService.shared.notifyUpdateAvailable(version: remoteVersion.description)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Dismisses `release` so it stops showing as available until a newer
    /// tag appears.
    func skip(_ release: GitHubRelease) {
        settings?.skippedUpdateVersion = release.tagName
        if availableRelease?.tagName == release.tagName {
            availableRelease = nil
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }
    }
}

enum UpdateCheckError: Error, LocalizedError {
    case httpStatus(Int)
    case noDownloadableAsset

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "GitHub returned HTTP \(code) while checking for updates."
        case .noDownloadableAsset:
            return "The latest GitHub release doesn't have a .zip asset attached."
        }
    }
}

/// The subset of GitHub's release API response Mist needs.
struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }

    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    var zipAsset: Asset? { assets.first { $0.name.hasSuffix(".zip") } }
}
