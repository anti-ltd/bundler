// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Bundler",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(path: "../iUX"),
    ],
    targets: [
        .executableTarget(
            name: "Bundler",
            dependencies: ["iUX"],
            path: "Sources/Bundler"
        ),
    ]
)
