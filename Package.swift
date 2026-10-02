// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpotWidget",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SpotWidget", targets: ["SpotWidget"]),
        .executable(name: "SpotWidgetExtension", targets: ["SpotWidgetExtension"])
    ],
    targets: [
        .executableTarget(
            name: "SpotWidget",
            path: "Sources/SpotWidget"
        ),
        .executableTarget(
            name: "SpotWidgetExtension",
            path: "Sources/SpotWidgetExtension",
            swiftSettings: [
                .unsafeFlags(["-application-extension"])
            ]
        )
    ]
)
