// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Widgify",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Widgify", targets: ["Widgify"]),
        .executable(name: "WidgifyExtension", targets: ["WidgifyExtension"])
    ],
    targets: [
        .executableTarget(
            name: "Widgify",
            path: "Sources/Widgify"
        ),
        .executableTarget(
            name: "WidgifyExtension",
            path: "Sources/WidgifyExtension",
            swiftSettings: [
                .unsafeFlags(["-application-extension"])
            ]
        )
    ]
)
