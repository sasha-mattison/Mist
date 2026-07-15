// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Mist",
    platforms: [
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "Mist",
            path: "Sources/Mist"
        )
    ]
)
