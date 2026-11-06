// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PickleVision",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PickleVision",
            targets: ["PickleVision"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PickleVision",
            dependencies: [],
            path: ".",
            sources: [
                "Models",
                "Core"
            ]
        ),
        .testTarget(
            name: "PickleVisionTests",
            dependencies: ["PickleVision"],
            path: "Tests/PickleVisionTests"
        ),
    ]
)
