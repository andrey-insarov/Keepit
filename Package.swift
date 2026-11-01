// swift-tools-version:5.9
import PackageDescription
import Foundation

// KEEPIT_APPSTORE=1 builds the Mac App Store variant: no Sparkle (the store forbids self-updating),
// and the APPSTORE compile flag hides the "Check for Updates" UI.
let appStore = ProcessInfo.processInfo.environment["KEEPIT_APPSTORE"] == "1"

let package = Package(
    name: "Keepit",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: appStore ? [] : [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Keepit",
            dependencies: appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")],
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
            dependencies: ["Keepit"],
            path: "Tests/KeepitTests"
        ),
    ]
)
