// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftLens",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "SwiftLens",
            path: "Sources/SwiftLens"
        )
    ]
)