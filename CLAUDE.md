# Project Overview

This is a native **iOS application** built with **Swift 6.1+** and **SwiftUI**. The codebase targets **iOS 18.0 and later**, allowing full use of modern Swift and iOS APIs. All concurrency is handled with **Swift Concurrency** (async/await, actors, @MainActor isolation) ensuring thread-safe code.

- **Frameworks & Tech:** SwiftUI for UI, Swift Concurrency with strict mode, Swift Package Manager for modular architecture
- **Architecture:** Model-View (MV) pattern using pure SwiftUI state management. We avoid MVVM and instead leverage SwiftUI's built-in state mechanisms (@State, @Observable, @Environment, @Binding)
- **Testing:** Swift Testing framework with modern @Test macros and #expect/#require assertions
- **Platform:** iOS (Simulator and Device)
- **Accessibility:** Full accessibility support using SwiftUI's accessibility modifiers

## Project Structure

The project follows a **workspace + SPM package** architecture:

```
HabitTracker/
├── Config/                               # XCConfig build settings + entitlements
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Shared.xcconfig
│   ├── Tests.xcconfig
│   └── HabitTracker.entitlements
├── HabitTracker.xcworkspace/             # Workspace container (open this)
├── HabitTracker.xcodeproj/              # App shell (minimal wrapper)
├── HabitTracker/                         # App target - entry point only
│   ├── Assets.xcassets/
│   ├── HabitTrackerApp.swift            # @main entry point only
│   └── HabitTracker.xctestplan
├── HabitTrackerPackage/                  # All features and business logic
│   ├── Package.swift
│   ├── Sources/HabitTrackerFeature/
│   │   ├── Components/                  # Reusable UI components
│   │   ├── LiveActivities/              # ActivityKit infrastructure
│   │   ├── Managers/                    # DayCategoryManager, LocationCategoryManager
│   │   ├── Models/                      # Data models (Habit, RoutineTemplate, etc.)
│   │   ├── Protocols/
│   │   ├── Services/                    # RoutineService, persistence, location, etc.
│   │   ├── Utils/                       # Theme, typography, haptics, geometry
│   │   └── Views/                       # All SwiftUI views
│   └── Tests/HabitTrackerFeatureTests/
├── HabitTrackerWatch Watch App/          # watchOS companion
└── HabitTrackerUITests/                  # UI automation tests
```

**Important:** All development work should be done in the **HabitTrackerPackage** Swift Package, not in the app project. The app project is a thin wrapper that creates the SwiftData model container and calls `HabitTrackerFeature.morningRoutineView()`.

## Project Memories

- **CoreGraphics Interaction:** Avoid passing non-numerical value to CoreGraphics

[Rest of the file remains unchanged...]