# HabitTracker

A modern iOS habit tracking app built with SwiftUI and Swift 6, designed to help users build and maintain positive habits through an intuitive, clean interface.

## Features

- 📝 **Custom Habit Creation** - Create personalized habits with descriptions and target frequencies
- ✅ **Daily Tracking** - Simple check-off interface for marking habits complete
- 📊 **Progress Visualization** - Charts and streaks showing habit completion over time
- 🏷️ **Categories** - Organize habits by categories (health, productivity, personal, etc.)
- 🔔 **Smart Reminders** - Optional local notifications to keep you on track
- 📈 **Detailed Statistics** - Weekly, monthly, and yearly views of your progress

## Technical Details

- **Platform:** iOS 18.0+
- **Language:** Swift 6.1+
- **UI Framework:** SwiftUI
- **Architecture:** Model-View (MV) pattern with native SwiftUI state management
- **Concurrency:** Swift Concurrency (async/await, actors)
- **Data Persistence:** SwiftData
- **Testing:** Swift Testing framework

## Project Structure

This project uses a **workspace + Swift Package Manager** architecture:

- **HabitTracker.xcworkspace** - Main workspace container
- **HabitTracker.xcodeproj** - Minimal app shell
- **HabitTrackerPackage** - All features and business logic
- **Config/** - XCConfig build settings and entitlements

## Getting Started

### Prerequisites

- Xcode 16.0+
- iOS 18.0+ Simulator or Device
- macOS 15.0+

### Building the Project

1. Clone the repository:
   ```bash
   git clone https://github.com/tigrerol/HabitTracker.git
   cd HabitTracker
   ```

2. Open the workspace:
   ```bash
   open HabitTracker.xcworkspace
   ```

3. Build and run the project using Xcode or XcodeBuildMCP tools

### Development

All feature development should be done in the **HabitTrackerPackage** Swift Package, not in the app project. The app project is just a thin wrapper.

## Architecture

HabitTracker follows modern SwiftUI patterns:

- **No ViewModels** - Uses pure SwiftUI state management with @State, @Observable, @Environment
- **Value Types** - Leverages Swift structs and enums for data modeling
- **Dependency Injection** - Services injected via SwiftUI's Environment system
- **Strict Concurrency** - All async work properly isolated with Swift 6 concurrency

## Contributing

1. Fork the repository
2. Create your feature branch
3. Make changes in the HabitTrackerPackage
4. Add tests using Swift Testing
5. Ensure all tests pass
6. Submit a pull request

## License

[Add your license information here]

## Contact

[Add your contact information here]