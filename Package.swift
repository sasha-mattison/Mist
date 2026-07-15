// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SteamClient",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "SteamClient",
            path: "Sources/SteamClient"
        )
    ]
)
