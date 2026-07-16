import AppKit
import Foundation

/// Downloads a GitHub release's .zip asset, verifies it's actually a Mist
/// build, swaps it into place, and relaunches. Safe to self-replace here
/// because Mist runs unsandboxed (Mist.entitlements has app-sandbox = false)
/// — the same assumption Scripts/build-app.sh already relies on when it
/// `rm -rf`s and `ditto`s straight into /Applications.
@MainActor
@Observable
final class UpdateInstaller {
    static let shared = UpdateInstaller()

    private(set) var phase: Phase?
    private(set) var installError: String?

    enum Phase {
        case downloading
        case verifying
        case installing

        var label: String {
            switch self {
            case .downloading: return "Downloading…"
            case .verifying: return "Verifying…"
            case .installing: return "Installing…"
            }
        }
    }

    private init() {}

    func install(_ release: GitHubRelease) async {
        guard let asset = release.zipAsset else {
            installError = UpdateCheckError.noDownloadableAsset.localizedDescription
            return
        }
        installError = nil

        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MistUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

            phase = .downloading
            let (downloadedURL, response) = try await URLSession.shared.download(from: asset.browserDownloadURL)
            try Self.validate(response)
            let zipPath = workDir.appendingPathComponent("Mist.zip")
            try FileManager.default.moveItem(at: downloadedURL, to: zipPath)

            phase = .verifying
            let expandDir = workDir.appendingPathComponent("expanded", isDirectory: true)
            try FileManager.default.createDirectory(at: expandDir, withIntermediateDirectories: true)
            try Self.run("/usr/bin/ditto", ["-x", "-k", zipPath.path, expandDir.path])

            let expandedAppPath = expandDir.appendingPathComponent("Mist.app")
            guard FileManager.default.fileExists(atPath: expandedAppPath.path),
                  let bundle = Bundle(url: expandedAppPath),
                  bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw UpdateInstallError.unexpectedContents
            }
            try Self.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", expandedAppPath.path])

            phase = .installing
            try Self.launchRelauncher(installedAppPath: Bundle.main.bundleURL.path,
                                       newAppPath: expandedAppPath.path,
                                       workDir: workDir)

            // Give the detached relauncher a moment to actually start before
            // we exit — it waits for our PID to disappear before swapping.
            try? await Task.sleep(for: .milliseconds(300))
            phase = nil
            NSApp.terminate(nil)
        } catch {
            phase = nil
            installError = error.localizedDescription
            try? FileManager.default.removeItem(at: workDir)
        }
    }

    /// Writes a tiny relaunch script that waits for this process to exit,
    /// then replaces the installed bundle and reopens it — and launches it
    /// detached so it survives past our own termination (macOS reparents
    /// orphaned children to launchd rather than killing them).
    private static func launchRelauncher(installedAppPath: String, newAppPath: String, workDir: URL) throws {
        let scriptPath = workDir.appendingPathComponent("relaunch.sh")
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(installedAppPath)"
        /usr/bin/ditto "\(newAppPath)" "\(installedAppPath)"
        /usr/bin/open "\(installedAppPath)"
        rm -rf "\(workDir.path)"
        """
        try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = [scriptPath.path]
        try relauncher.run()
    }

    @discardableResult
    private static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw UpdateInstallError.commandFailed(executable: executable, output: output)
        }
        return output
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }
    }
}

enum UpdateInstallError: Error, LocalizedError {
    case unexpectedContents
    case commandFailed(executable: String, output: String)

    var errorDescription: String? {
        switch self {
        case .unexpectedContents:
            return "The downloaded update doesn't look like a valid Mist build."
        case .commandFailed(let executable, let output):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\((executable as NSString).lastPathComponent) failed\(trimmed.isEmpty ? "" : ": \(trimmed)")"
        }
    }
}
