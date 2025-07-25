# Conditional Habits Implementation Plan (Refined)

## 1. Overview

This document outlines the step-by-step plan to implement the Conditional Habits feature. This refined version includes key design decisions to ensure the feature is robust, user-friendly, and well-integrated into the existing application structure.

The goal remains to create a new habit type that allows for branching logic within a routine based on a user's answer to a multiple-choice question.

## 2. Design Decisions & Refinements

Based on the initial plan and an analysis of the existing data models (`Habit` and `HabitType`), the following design decisions have been made:

1.  **Data Model Integration**: To keep the data structure clean and strongly typed, we will add a new `case` to the `HabitType` enum: `.conditional(ConditionalHabitInfo)`. This `ConditionalHabitInfo` struct will neatly encapsulate all data related to a question, keeping the `Habit` and `HabitType` models lean.

2.  **Flexible Habit Paths**: When building a path for an answer, the user should have maximum flexibility. Therefore, a path will support both **single-use habits** (created specifically for that path) and **links to existing habits** from the user's main library. This allows for creating quick, unique paths or reusing complex, established habits.

3.  **Dynamic Routine Execution**: The `RoutineService` will be responsible for dynamically modifying the routine queue in real-time. When a user selects an answer, the service will resolve the associated path (fetching any linked habits) and seamlessly inject them into the active routine. To ensure the UI updates smoothly, the service will post a `Notification` to signal that the routine has changed.

4.  **Intuitive UI for Path Creation**: We will create a dedicated `PathBuilderView` that mirrors the main `RoutineBuilderView`. This provides a familiar experience for the user. From the `ConditionalHabitEditorView`, tapping an option card will navigate the user to this `PathBuilderView`, where they can build the sequence of habits for that specific path.

---

## 3. File Changes & Creations

**New Files to Create:**

*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/ConditionalHabitInfo.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/ConditionalOption.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/PathHabit.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/ConditionalResponse.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/ConditionalHabitEditorView.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/PathBuilderView.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/ResponseLoggingService.swift`
*   `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/ConditionalHabitTests.swift`

**Existing Files to Modify:**

*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Models/HabitType.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/RoutineService.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/RoutineBuilderView.swift`
*   `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/RoutineExecutionView.swift`
*   `HabitTrackerPackage/Tests/HabitTrackerFeatureTests/RoutineServiceTests.swift`

---

## 4. Implementation Steps

### Phase 1: Refine the Data Models

**1. Update `HabitType.swift`**
*   Add the new `conditional` case to the `HabitType` enum.

```swift
// In HabitTrackerPackage/Sources/HabitTrackerFeature/Models/HabitType.swift
public enum HabitType: Codable, Hashable, Sendable {
    // ... existing cases
    case conditional(ConditionalHabitInfo)
}
```

**2. Create `ConditionalHabitInfo.swift`**
*   This struct will hold the core information for a conditional habit.

```swift
// In HabitTrackerPackage/Sources/HabitTrackerFeature/Models/ConditionalHabitInfo.swift
import Foundation

public struct ConditionalHabitInfo: Codable, Hashable, Sendable {
    let question: String
    let options: [ConditionalOption] // Max 4
}
```

**3. Create `ConditionalOption.swift`**
*   This struct represents an answer choice and its corresponding path of habits.

```swift
// In HabitTrackerPackage/Sources/HabitTrackerFeature/Models/ConditionalOption.swift
import Foundation

public struct ConditionalOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    let text: String
    let path: [PathHabit] // The sequence of habits for this path
}
```

**4. Create `PathHabit.swift`**
*   This enum allows a path to contain either a new, inline habit or a link to an existing one.

```swift
// In HabitTrackerPackage/Sources/HabitTrackerFeature/Models/PathHabit.swift
import Foundation

public enum PathHabit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID {
        switch self {
        case .new(let habit):
            return habit.id
        case .link(let habitID):
            return habitID
        }
    }
    
    case new(Habit)
    case link(habitID: UUID)
}
```

**5. Create `ConditionalResponse.swift`**
*   This remains the same: a struct for logging the user's answer.

### Phase 2: Implement Core Logic & Data Logging

**1. Create `ResponseLoggingService.swift`**
*   This service will save responses to `UserDefaults`. The initial implementation is sufficient.

**2. Modify `RoutineService.swift`**
*   The `RoutineService` needs to be updated to handle the new logic.
*   **Assumptions**: The service has a `habitQueue: [Habit]` and a `habitLibrary: [Habit]` that it can access.
*   **Add `handleConditionalOptionSelection(option: ConditionalOption)` function:**
    1.  Log the response using `ResponseLoggingService`.
    2.  Create a `resolvedHabits` array.
    3.  Iterate through the `option.path`:
        *   If a `PathHabit` is `.new(let habit)`, add `habit` to `resolvedHabits`.
        *   If it's `.link(let habitID)`, find the corresponding habit in the `habitLibrary` and add a *copy* of it to `resolvedHabits`.
    4.  Splice `resolvedHabits` into the main `habitQueue` at the current index.
    5.  Post a notification: `NotificationCenter.default.post(name: .routineQueueDidChange, object: nil)`.

### Phase 3: Build the User Interface

**1. Modify `RoutineBuilderView.swift`**
*   Add a new button ("Add Question") that presents `ConditionalHabitEditorView`.

**2. Create `ConditionalHabitEditorView.swift`**
*   This view is the top-level editor for a question.
*   **UI Components:**
    *   A `TextField` for the question text.
    *   A list of "Option Cards". Each card should show the option text (e.g., "Shoulder") and a summary of the path (e.g., "2 habits").
    *   Tapping a card will navigate to the `PathBuilderView` for that option.
    *   A button to "Add New Option".

**3. Create `PathBuilderView.swift`**
*   This view allows users to build the habit sequence for a single path. It should look and feel just like the main `RoutineBuilderView`.
*   **UI Components:**
    *   A navigation title showing the option it's for (e.g., "Path for 'Shoulder'").
    *   A list showing the habits in this path.
    *   An "Add Habit" button that allows the user to either:
        *   **Create a new habit**: Pushes to a standard habit creation view.
        *   **Link an existing habit**: Presents a sheet with a searchable list of habits from the main `HabitLibrary`.

**4. Modify `RoutineExecutionView.swift`**
*   When the current habit's type is `.conditional(let info)`:
    *   Display `info.question` as the main text.
    *   Display each `option` in `info.options` as a large, tappable button.
    *   When an option is tapped, call `routineService.handleConditionalOptionSelection(option:)`.
    *   The view should automatically refresh to show the next habit thanks to the `Notification` posted by the service.

### Phase 4: Testing

**1. Create `ConditionalHabitTests.swift`**
*   Add unit tests for the new data models (`ConditionalHabitInfo`, `ConditionalOption`, `PathHabit`).

**2. Modify `RoutineServiceTests.swift`**
*   Add new test cases to cover the branching logic:
    *   `test_selectingOption_insertsNewHabitsCorrectly`
    *   `test_selectingOption_resolvesLinkedHabitsCorrectly`
    *   `test_selectingEmptyPath_continuesToNextHabit`
    *   `test_responseIsLogged_onOptionSelection`
    *   `test_routineQueueDidChangeNotification_isPostedOnPathSelection`

This refined plan provides a more detailed and robust roadmap for implementation. Good luck!