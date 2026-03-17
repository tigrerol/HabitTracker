# HabitTracker — iOS App

A session-based habit tracking app for iOS built with SwiftUI and Swift 6.1+. Guides users through structured daily routines (morning, afternoon, evening) with smart template selection based on time, day type, and location context.

## Features

### Routine Execution
- Session-based routine flow with sequential habit presentation
- Smart template selection — picks the best routine based on current time, day category, and detected location
- Quick start with swipe-to-begin
- Progress header with estimated time remaining
- Skip, complete, and navigate between habits

### Habit Types
- **Checkbox** — simple completion tap
- **Timer** — countdown with pause/resume, repeating sequences (breathing, interval training)
- **Rest Timer** — work/rest interval sets with auto-advance
- **Counter** — increment toward a daily target
- **App Launch** — opens another app and tracks return
- **Web Link** — in-app browser with time tracking
- **Action** — multi-step tasks with estimated duration

### Context Awareness
- Time slot detection (morning, afternoon, evening, night)
- Multiple day categories per weekday (workday, rest day, travel, etc.)
- Location-based context (home, office, gym, custom locations)
- Smart template scoring based on all three signals

### Themes
- **Sunstone** — warm light theme
- **Slate** — focused dark theme
- Theme selection persists via UserDefaults; switches iOS color scheme

### Other
- Mood rating after routine completion
- Haptic and acoustic feedback throughout
- Live Activities infrastructure for active timer habits
- Apple Watch connectivity
- Data export (JSON)
- Full VoiceOver accessibility support
- Snippet library for reusable habits

## Architecture

```
HabitTracker/
├── HabitTracker.xcworkspace        # Open this in Xcode
├── HabitTracker.xcodeproj          # App shell (entry point only)
├── HabitTracker/
│   ├── HabitTrackerApp.swift       # @main, model container setup
│   └── Assets.xcassets/
├── HabitTrackerPackage/            # All feature code lives here
│   ├── Sources/HabitTrackerFeature/
│   │   ├── Components/             # Reusable UI components
│   │   ├── LiveActivities/         # ActivityKit infrastructure
│   │   ├── Managers/               # DayCategoryManager, LocationCategoryManager
│   │   ├── Models/                 # Habit, RoutineTemplate, RoutineSession, etc.
│   │   ├── Protocols/              # HabitInteractionHandler
│   │   ├── Services/               # RoutineService, SwiftDataPersistenceService, etc.
│   │   ├── Utils/                  # Theme, typography, color, haptics, geometry
│   │   └── Views/                  # All SwiftUI views
│   └── Tests/HabitTrackerFeatureTests/
├── HabitTrackerWatch Watch App/    # watchOS companion
└── Config/                         # XCConfig build settings + entitlements
```

**All development happens in `HabitTrackerPackage/Sources/HabitTrackerFeature/`.**
The app target is a thin wrapper that creates the model container and calls `HabitTrackerFeature.morningRoutineView()`.

## Tech Stack

| Area | Technology |
|------|-----------|
| Language | Swift 6.1+ (strict concurrency) |
| UI | SwiftUI (MV pattern, no ViewModels) |
| State | `@Observable`, `@Environment`, `@State` |
| Persistence | SwiftData |
| Concurrency | Swift Concurrency (`async/await`, `@MainActor`, actors) |
| Testing | Swift Testing (`@Test`, `#expect`) |
| Minimum OS | iOS 18.0 |

## Development

### Build & Run
Open `HabitTracker.xcworkspace` in Xcode and run on any iOS 18+ simulator.

### Tests
```bash
# Run package tests
swift test --package-path HabitTrackerPackage

# Or via Xcode: Product → Test (⌘U)
```

### Adding a New Habit Type
1. Add a case to `HabitType` in `Models/HabitType.swift`
2. Implement interaction UI in `Views/HabitInteractionView.swift`
3. Add an editor in `Views/HabitEditorView.swift`
4. Register in `HabitFactory`

### Adding a New Theme
1. Add a case to `AppTheme` in `Models/Settings/ThemeSettings.swift`
2. Provide `accentColor`, `accentHex`, `preferredColorScheme`, and all `preview*` colors
3. `ThemeManager` will automatically pick it up via `AppTheme.allCases`

### Configuration
Build settings are in `Config/`:
- `Shared.xcconfig` — bundle ID, deployment target, Swift version
- `Debug.xcconfig` / `Release.xcconfig` — environment-specific overrides
- `HabitTracker.entitlements` — app capabilities

## AI Assistant Rules
- **Claude Code**: `CLAUDE.md` — architecture patterns, coding standards
- **GitHub Copilot**: `.github/copilot-instructions.md`
