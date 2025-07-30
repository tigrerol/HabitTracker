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
YourApp/
├── Config/                         # XCConfig build settings
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Shared.xcconfig
│   └── Tests.xcconfig
├── YourApp.xcworkspace/            # Workspace container
├── YourApp.xcodeproj/              # App shell (minimal wrapper)
├── YourApp/                        # App target - just the entry point
│   ├── Assets.xcassets/
│   ├── YourAppApp.swift           # @main entry point only
│   └── YourApp.xctestplan
├── YourAppPackage/                 # All features and business logic
│   ├── Package.swift
│   ├── Sources/
│   │   └── YourAppFeature/        # Feature modules
│   └── Tests/
│       └── YourAppFeatureTests/   # Swift Testing tests
└── YourAppUITests/                 # UI automation tests
```

**Important:** All development work should be done in the **YourAppPackage** Swift Package, not in the app project. The app project is merely a thin wrapper that imports and launches the package features.

## Project Memories

- **CoreGraphics Interaction:** Avoid passing non-numerical value to CoreGraphics

[Rest of the file remains unchanged...]