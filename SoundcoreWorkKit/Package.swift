// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundcoreWorkKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "SoundcoreWorkKit", targets: ["SoundcoreWorkKit"]),
    ],
    targets: [
        .target(
            name: "SoundcoreWorkKit",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SoundcoreWorkKitTests",
            dependencies: ["SoundcoreWorkKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
