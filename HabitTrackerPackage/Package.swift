// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HabitTrackerPackage",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "HabitTrackerFeature",
            targets: ["HabitTrackerFeature"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HabitTrackerFeature",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HabitTrackerFeatureTests",
            dependencies: ["HabitTrackerFeature"]
        ),
    ]
)