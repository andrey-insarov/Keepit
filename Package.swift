// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keepit",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Keepit",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Keepit",
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
