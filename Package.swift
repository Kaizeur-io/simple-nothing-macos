// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NothingMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NothingKit"),
        .executableTarget(name: "NothingX", dependencies: ["NothingKit"]),
        .testTarget(name: "NothingKitTests", dependencies: ["NothingKit"]),
    ]
)
