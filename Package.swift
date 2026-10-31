// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Keepit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Keepit",
            path: "Sources/Keepit",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)
