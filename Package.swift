// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NothingMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NothingKit"),
        // Les traductions sont copiées dans l'app par tools/app.sh, où Bundle.main les trouve.
        .executableTarget(name: "NothingX", dependencies: ["NothingKit"], exclude: ["Traductions"]),
        .testTarget(name: "NothingKitTests", dependencies: ["NothingKit"]),
    ]
)
