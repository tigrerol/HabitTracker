
# Refactoring Suggestions for HabitTracker - 2025-07-26

This document outlines suggested refactorings for the HabitTracker codebase to improve its quality, maintainability, and readiness for the App Store.

## High Priority: Localization

The most critical issue is the lack of localization throughout the application. The UI is built with hardcoded strings, which prevents the app from being translated into other languages. This is a significant barrier for an app intended for the App Store.

**Problem:**

There are over 180 instances of hardcoded strings in `Text` views. For example, in `HabitEditorView.swift`:

```swift
Text("Basic Information")
Text("Color")
Text("Additional Notes")
```

**Solution:**

All user-facing strings must be extracted into a localizable strings file (`.strings`).

1.  **Create a `Localizable.strings` file:** If one doesn't exist, create it in the `Resources` folder of the `HabitTrackerPackage`.
2.  **Replace hardcoded strings:** Replace each hardcoded string with a `String(localized:)` initializer.

**Example:**

In `HabitEditorView.swift`, the code should be changed from:

```swift
Text("Basic Information")
```

to:

```swift
Text(String(localized: "HabitEditorView.BasicInformation.Title", bundle: .module))
```

And in `Localizable.strings (en)`:

```
"HabitEditorView.BasicInformation.Title" = "Basic Information";
```

This change needs to be applied to all user-facing strings in the app.

## Medium Priority: Address TODOs

There are a few `TODO` comments in the code that should be addressed.

1.  **Asynchronous Routine Context:**
    *   **File:** `HabitTrackerFeature/Models/RoutineContext.swift:70`
    *   **Comment:** `// TODO: Consider making this async in the future`
    *   **Suggestion:** The `updateContext` function is synchronous. As the app grows, this could lead to performance issues if context calculation becomes more complex. Refactor this to be an `async` function to avoid blocking the main thread.

2.  **Hardcoded URL Scheme Examples:**
    *   **File:** `HabitTrackerFeature/Views/HabitEditorView.swift:491`
    *   **Comment:** `Text("Examples: instagram://, spotify://, todoist://")`
    *   **Suggestion:** This is another localization issue. This string should be moved to the `Localizable.strings` file.

## Low Priority: Centralize Mock Data for Previews

The app makes extensive use of SwiftUI Previews, which is excellent. However, the mock data used in these previews is often created inline.

**Problem:**

Creating mock data directly within the preview struct leads to code duplication and makes it harder to maintain consistent preview data across the app. For example:

```swift
#Preview {
    HabitEditorView(
        habit: .constant(Habit(name: "Morning Run", type: .duration(minutes: 30))),
        onSave: { _ in },
        onDelete: { }
    )
}
```

**Solution:**

Create a centralized location for mock data. This could be a new Swift file within the `HabitTrackerFeatureTests` target or a dedicated "Mocks" folder in the `HabitTrackerFeature` source set.

**Example:**

```swift
// In a new file, e.g., HabitTrackerFeature/Mocks/MockHabits.swift

import Foundation
@testable import HabitTrackerFeature

enum Mocks {
    static var morningRun: Habit {
        Habit(name: "Morning Run", type: .duration(minutes: 30))
    }

    static var readBook: Habit {
        Habit(name: "Read a book", type: .duration(minutes: 15))
    }
}
```

Then, in the preview:

```swift
#Preview {
    HabitEditorView(
        habit: .constant(Mocks.morningRun),
        onSave: { _ in },
        onDelete: { }
    )
}
```

This approach makes previews cleaner, more consistent, and easier to manage.

## General Recommendations

*   **Build Number:** The build number is hardcoded in `RoutineBuilderView.swift` and `SmartTemplateSelectionView.swift`. This should be read from the app's bundle information instead of being hardcoded.
*   **Code Formatting:** The code is generally well-formatted, but a consistent code style should be enforced using a tool like SwiftFormat.
*   **Error Handling:** Review error handling throughout the app. Some views display generic error messages like `"Error: Option not found"`. These should be made more user-friendly and potentially offer recovery options.
