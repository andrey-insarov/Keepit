// swift-tools-version:5.9
import PackageDescription
import Foundation

// KEEPIT_APPSTORE=1 builds the Mac App Store variant: Sparkle is not linked (the store forbids
// self-updating; `make appstore` verifies the binary with otool), and the APPSTORE compile flag
// hides the "Check for Updates" UI. The dependency itself is declared for both variants so that
// Package.resolved — the pinned Sparkle revision every release is built from — stays the same file
// whichever variant was resolved last.
let appStore = ProcessInfo.processInfo.environment["KEEPIT_APPSTORE"] == "1"

let package = Package(
    name: "Keepit",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Exact revision is pinned in Package.resolved (committed); CI refuses to build if it drifts.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        // Format layer, no AppKit: the .keepit container (docs/FORMAT.md), KDFs, sealed blobs, LZFSE.
        // Consumers: the app today; a CLI and other platforms later. Apple frameworks only for now
        // (CryptoKit, CommonCrypto, Compression); swapping them for swift-crypto is a later step.
        .target(
            name: "KeepitCore",
            path: "Sources/KeepitCore"
        ),
        .executableTarget(
            name: "Keepit",
            dependencies: ["KeepitCore"] + (appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")]),
            path: "Sources/Keepit",
            // Resources/ holds the icon and one <lang>.lproj/Localizable.strings per interface language
            // (21 of them; the list itself lives in Resources/Info.plist, CFBundleLocalizations).
            resources: [.process("Resources")],
            swiftSettings: appStore ? [.define("APPSTORE")] : [],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("LocalAuthentication"),
            ]
        ),
        .testTarget(
            name: "KeepitTests",
            dependencies: ["Keepit", "KeepitCore"],
            path: "Tests/KeepitTests",
            // Reference .keepit files (docs/FORMAT.md); FixtureTests opens them by path, not as a bundle resource.
            exclude: ["Fixtures"]
        ),
    ]
)
