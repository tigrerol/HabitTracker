// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HabitTrackerFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(
            name: "HabitTrackerFeature",
            targets: ["HabitTrackerFeature"]
        ),
        .library(
            name: "HabitTrackerWidgetShared",
            targets: ["HabitTrackerWidgetShared"]
        ),
    ],
    targets: [
        .target(
            name: "HabitTrackerFeature",
            dependencies: ["HabitTrackerWidgetShared"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HabitTrackerWidgetShared"
        ),
        .testTarget(
            name: "HabitTrackerFeatureTests",
            dependencies: [
                "HabitTrackerFeature"
            ]
        ),
    ]
)
