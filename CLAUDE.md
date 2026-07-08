# Project Overview

This is a native **iOS application** built with **Swift 6.1+** and **SwiftUI**. The codebase targets **iOS 26.0 and later** (Liquid Glass APIs available unconditionally). All concurrency is handled with **Swift Concurrency** (async/await, actors, @MainActor isolation) ensuring thread-safe code.

**Persistence:** the live app (`RoutineService.shared`) runs on SwiftData for routine templates + session history (`SwiftDataPersistenceService`, container in `DataModelConfiguration.sharedContainer`; one-shot legacy migration from UserDefaults on first load). Everything else — paused/interrupted session snapshots, day/location/time-slot settings, conditional responses — deliberately stays in UserDefaults as simple preference data. `RoutineService()`'s default init is still UserDefaults-backed for previews/tests. SwiftData gotchas encoded in the code: never wire relationships before `modelContext.insert`, keep a `ModelContainer` alive as long as its contexts are used, and fetch by predicate rather than reading inverse arrays right after inserts.

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
├── HabitTrackerWidgets/                  # Widgets extension
└── HabitTrackerUITests/                  # UI automation tests
```

**Note:** There is no watchOS target — the watch app has been set aside for now.

**Important:** All development work should be done in the **HabitTrackerPackage** Swift Package, not in the app project. The app project is a thin wrapper that creates the SwiftData model container and calls `HabitTrackerFeature.morningRoutineView()`.

## Project Memories

- **CoreGraphics Interaction:** Avoid passing non-numerical value to CoreGraphics