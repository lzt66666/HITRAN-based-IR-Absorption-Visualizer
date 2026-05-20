// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IRVisualizer",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "IRVisualizer",
            path: "Sources/IRVisualizer"
        )
    ]
)
