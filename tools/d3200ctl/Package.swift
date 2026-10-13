// swift-tools-version: 6.0
import Foundation
import PackageDescription

// CoreBluetooth bricht ohne NSBluetoothAlwaysUsageDescription per TCC ab. Ein
// SwiftPM-Executable hat kein Bundle, daher wird die Info.plist als
// __TEXT,__info_plist in das Binary gelinkt. Der Pfad muss absolut sein, weil
// das Arbeitsverzeichnis des Linkers nicht das Package-Root ist.
let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

/// Live-Test-Harness für SoundcoreWorkKit am echten Gerät (nur macOS).
/// Kein Teil der App – dient der Verifikation von Schritt 2 des Bauplans.
let package = Package(
    name: "d3200ctl",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../SoundcoreWorkKit"),
    ],
    targets: [
        .executableTarget(
            name: "d3200ctl",
            dependencies: [
                .product(name: "SoundcoreWorkKit", package: "SoundcoreWorkKit"),
            ],
            exclude: ["Info.plist"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-sectcreate",
                "-Xlinker", "__TEXT",
                "-Xlinker", "__info_plist",
                "-Xlinker", "\(packageDirectory)/Sources/d3200ctl/Info.plist",
            ])]
        ),
    ]
)
