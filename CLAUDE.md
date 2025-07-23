# Project Overview

This is a native **iOS application** built with **Swift 6.1+** and **SwiftUI**. HabitTracker is a modern habit tracking app that helps users build and maintain positive habits through an intuitive, clean interface. The codebase targets **iOS 18.0 and later**, allowing full use of modern Swift and iOS APIs. All concurrency is handled with **Swift Concurrency** (async/await, actors, @MainActor isolation) ensuring thread-safe code.

- **Frameworks & Tech:** SwiftUI for UI, Swift Concurrency with strict mode, Swift Package Manager for modular architecture
- **Architecture:** Model-View (MV) pattern using pure SwiftUI state management. We avoid MVVM and instead leverage SwiftUI's built-in state mechanisms (@State, @Observable, @Environment, @Binding)
- **Testing:** Swift Testing framework with modern @Test macros and #expect/#require assertions
- **Platform:** iOS (Simulator and Device)
- **Accessibility:** Full accessibility support using SwiftUI's accessibility modifiers

## Project Structure

The project follows a **workspace + SPM package** architecture:

```
HabitTracker/
├── Config/                         # XCConfig build settings
│   ├── Debug.xcconfig
│   ├── Release.xcconfig
│   ├── Shared.xcconfig
│   ├── Tests.xcconfig
│   └── HabitTracker.entitlements
├── HabitTracker.xcworkspace/       # Workspace container
├── HabitTracker.xcodeproj/         # App shell (minimal wrapper)
├── HabitTracker/                   # App target - just the entry point
│   ├── Assets.xcassets/
│   ├── HabitTrackerApp.swift      # @main entry point only
│   └── HabitTracker.xctestplan
├── HabitTrackerPackage/            # All features and business logic
│   ├── Package.swift
│   ├── Sources/
│   │   └── HabitTrackerFeature/   # Feature modules
│   └── Tests/
│       └── HabitTrackerFeatureTests/  # Swift Testing tests
└── HabitTrackerUITests/            # UI automation tests
```

**Important:** All development work should be done in the **HabitTrackerPackage** Swift Package, not in the app project. The app project is merely a thin wrapper that imports and launches the package features.

# App Features & Core Functionality

## Habit Tracking Features
- **Habit Creation:** Users can create custom habits with names, descriptions, and target frequencies
- **Daily Tracking:** Simple check-off interface for marking habits as complete
- **Progress Visualization:** Charts and streaks to show habit completion over time
- **Habit Categories:** Organize habits by categories (health, productivity, personal, etc.)
- **Reminders:** Optional local notifications to remind users about their habits
- **Statistics:** Weekly/monthly/yearly views of habit completion rates

## Data Model
- **Habit:** Core habit entity with title, description, category, target frequency
- **HabitEntry:** Daily completion records linked to habits
- **Category:** Grouping mechanism for organizing habits
- **Statistics:** Computed values for streaks, completion rates, etc.

# Code Quality & Style Guidelines

## Swift Style & Conventions

- **Naming:** Use `UpperCamelCase` for types, `lowerCamelCase` for properties/functions. Choose descriptive names (e.g., `calculateCompletionRate()` not `calcRate`)
- **Value Types:** Prefer `struct` for models and data, use `class` only when reference semantics are required
- **Enums:** Leverage Swift's powerful enums with associated values for state representation
- **Early Returns:** Prefer early return pattern over nested conditionals to avoid pyramid of doom

## Optionals & Error Handling

- Use optionals with `if let`/`guard let` for nil handling
- Never force-unwrap (`!`) without absolute certainty - prefer `guard` with failure path
- Use `do/try/catch` for error handling with meaningful error types
- Handle or propagate all errors - no empty catch blocks

# Modern SwiftUI Architecture Guidelines (2025)

### No ViewModels - Use Native SwiftUI Data Flow
**New features MUST follow these patterns:**

1. **Views as Pure State Expressions**
   ```swift
   struct HabitListView: View {
       @Environment(HabitService.self) private var habitService
       @State private var viewState: ViewState = .loading
       
       enum ViewState {
           case loading
           case loaded(habits: [Habit])
           case error(String)
       }
       
       var body: some View {
           // View is just a representation of its state
       }
   }
   ```

2. **Use Environment Appropriately**
   - **App-wide services**: HabitService, NotificationService, ThemeService - use `@Environment`
   - **Feature-specific services**: Individual habit logic, single-view logic - use `let` properties with `@Observable`
   - Rule: Environment for cross-app/cross-feature dependencies, let properties for single-feature services
   - Access app-wide via `@Environment(ServiceType.self)`
   - Feature services: `private let myService = MyObservableService()`

3. **Local State Management**
   - Use `@State` for view-specific state
   - Use `enum` for view states (loading, loaded, error)
   - Use `.task(id:)` and `.onChange(of:)` for side effects
   - Pass state between views using `@Binding`

4. **No ViewModels Required**
   - Views should be lightweight and disposable
   - Business logic belongs in services/clients
   - Test services independently, not views
   - Use SwiftUI previews for visual testing

5. **When Views Get Complex**
   - Split into smaller subviews
   - Use compound views that compose smaller views
   - Pass state via bindings between views
   - Never reach for a ViewModel as the solution

## SwiftUI State Management (MV Pattern)

- **@State:** For all state management, including observable model objects
- **@Observable:** Modern macro for making model classes observable (replaces ObservableObject)
- **@Environment:** For dependency injection and shared app state
- **@Binding:** For two-way data flow between parent and child views
- **@Bindable:** For creating bindings to @Observable objects
- Avoid ViewModels - put view logic directly in SwiftUI views using these state mechanisms
- Keep views focused and extract reusable components

## Concurrency

- **@MainActor:** All UI updates must use @MainActor isolation
- **Actors:** Use actors for expensive operations like disk I/O, network calls, or heavy computation
- **async/await:** Always prefer async functions over completion handlers
- **Task:** Use structured concurrency with proper task cancellation
- **.task modifier:** Always use .task { } on views for async operations tied to view lifecycle - it automatically handles cancellation
- **Avoid Task { } in onAppear:** This doesn't cancel automatically and can cause memory leaks or crashes
- No GCD usage - Swift Concurrency only

# Data Persistence

For HabitTracker, we use **SwiftData** for persistent data storage of habits, completion records, and user preferences.

## SwiftData Models

```swift
import SwiftData

@Model
final class Habit {
    var title: String
    var description: String
    var category: HabitCategory
    var targetFrequency: Int // per week
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade)
    var entries: [HabitEntry] = []
    
    init(title: String, description: String, category: HabitCategory, targetFrequency: Int = 7) {
        self.title = title
        self.description = description
        self.category = category
        self.targetFrequency = targetFrequency
        self.createdAt = Date()
    }
}

@Model
final class HabitEntry {
    var date: Date
    var isCompleted: Bool
    
    @Relationship(inverse: \Habit.entries)
    var habit: Habit?
    
    init(date: Date, isCompleted: Bool = false) {
        self.date = date
        self.isCompleted = isCompleted
    }
}

enum HabitCategory: String, CaseIterable, Codable {
    case health = "Health"
    case productivity = "Productivity"
    case personal = "Personal"
    case fitness = "Fitness"
    case learning = "Learning"
    case social = "Social"
}
```

# XcodeBuildMCP Tool Usage

To work with this project, build, test, and development commands should use XcodeBuildMCP tools instead of raw command-line calls.

## Project Discovery & Setup

```javascript
// Discover Xcode projects in the workspace
discover_projs({
    workspaceRoot: "/path/to/HabitTracker"
})

// List available schemes
list_schems_ws({
    workspacePath: "/path/to/HabitTracker.xcworkspace"
})
```

## Building and Running

```javascript
// Build for iPhone simulator
build_sim_name_ws({
    workspacePath: "/path/to/HabitTracker.xcworkspace",
    scheme: "HabitTracker",
    simulatorName: "iPhone 16",
    configuration: "Debug"
})

// Build and run in one step
build_run_sim_name_ws({
    workspacePath: "/path/to/HabitTracker.xcworkspace",
    scheme: "HabitTracker", 
    simulatorName: "iPhone 16"
})
```

## Testing

```javascript
// Run tests on simulator
test_sim_name_ws({
    workspacePath: "/path/to/HabitTracker.xcworkspace",
    scheme: "HabitTracker",
    simulatorName: "iPhone 16"
})

// Test Swift Package
swift_package_test({
    packagePath: "/path/to/HabitTrackerPackage"
})
```

# Development Workflow

1. **Make changes in the Package**: All feature development happens in HabitTrackerPackage/Sources/
2. **Write tests**: Add Swift Testing tests in HabitTrackerPackage/Tests/
3. **Build and test**: Use XcodeBuildMCP tools to build and run tests
4. **Run on simulator**: Deploy to simulator for manual testing
5. **UI automation**: Use describe_ui and automation tools for UI testing
6. **Device testing**: Deploy to physical device when needed

# Best Practices

## SwiftUI & State Management

- Keep views small and focused
- Extract reusable components into their own files
- Use @ViewBuilder for conditional view composition
- Leverage SwiftUI's built-in animations and transitions
- Avoid massive body computations - break them down
- **Always use .task modifier** for async work tied to view lifecycle - it automatically cancels when the view disappears
- Never use Task { } in onAppear - use .task instead for proper lifecycle management

## Performance

- Use .id() modifier sparingly as it forces view recreation
- Implement Equatable on models to optimize SwiftUI diffing
- Use LazyVStack/LazyHStack for large lists
- Profile with Instruments when needed
- @Observable tracks only accessed properties, improving performance over @Published

## Accessibility

- Always provide accessibilityLabel for interactive elements
- Use accessibilityIdentifier for UI testing
- Implement accessibilityHint where actions aren't obvious
- Test with VoiceOver enabled
- Support Dynamic Type

## Security & Privacy

- Never log sensitive information
- Use Keychain for credential storage
- All network calls must use HTTPS
- Request minimal permissions
- Follow App Store privacy guidelines

---

Remember: This project prioritizes clean, simple SwiftUI code using the platform's native state management. Keep the app shell minimal and implement all features in the Swift Package.