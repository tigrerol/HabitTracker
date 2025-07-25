# Conditional Habits Implementation Notes

## Updated Design Decisions Based on Clarifications

### 1. Core Behavior
- **Path Merging**: Paths simply continue with the next habit in the main queue after completion
- **No Linked Habits**: Remove the `PathHabit` enum concept - all habits in paths are independent copies
- **Visual Indicator**: Add an appropriate icon (❓ or 🔀) to distinguish conditional habits in lists
- **No Answer Preview**: Users cannot see available paths before answering
- **No Answer Changes**: Once selected, answers cannot be changed during execution

### 2. Data & Analytics
- **Track**: Response data (question, selected option, timestamp, routine ID)
- **Track**: Skip rates for questions
- **Storage**: No limit on response data retention
- **Privacy**: No special privacy considerations needed

### 3. Error Handling
- **Failed Path Loading**: Skip to next main queue habit with brief error toast
- **Circular References**: Prevent at creation time via UI validation
- **Corrupted Conditional**: Treat as skip and continue routine
- **Skip Behavior**: Log skipped questions, mark conditional habit as "skipped" status

### 4. UI/UX Guidelines
- **Nesting**: UI prevents adding conditional habits beyond depth 2
- **Path Builder**: 
  - Include "duplicate from library" button (filters by habit type)
  - No quick-add needed
  - No special reordering UI needed
- **Empty Paths**: Allowed, implementation-dependent visual treatment
- **Editing**: 
  - Questions and options are editable after creation
  - Historical response data is preserved even if options are removed
  - Editing allowed even during active routines

### 5. Statistics & Integration
- **Habit Counting**: Habits within executed paths count toward individual statistics
- **Conditional Completion**: The conditional habit itself counts as 1 completion
- **Routine Sharing**: Conditional habits included in exports/shares
- **Templates**: No special handling needed

### 6. Simplified Data Model

```swift
// Remove PathHabit enum, simplify to:
public struct ConditionalOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    let text: String
    let habits: [Habit] // Direct array of habit copies
}
```

### 7. Implementation Priority Adjustments
- Remove all "link" functionality from PathBuilderView
- Add "Duplicate from Library" with type filtering
- Implement depth validation in ConditionalHabitEditorView
- Add skip tracking to ResponseLoggingService

## Key Simplifications
1. No PathHabit enum - just use [Habit] directly
2. All habits in paths are independent copies
3. Simple linear flow - no complex merging logic
4. Straightforward error handling - always fail forward