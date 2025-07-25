# Conditional Habits Feature Requirements Document

## Overview
Conditional habits allow users to add question-based branching logic to their routines. Based on the user's answer to a multiple-choice question, different paths of habits are executed.

## Core Requirements

### 1. Question Structure
- **Type**: Multiple choice questions only
- **Options**: Maximum 4 answer choices per question
- **Format**: Text-based answers (e.g., "Shoulder", "Knee", "None")
- **Behavior**: Treated as normal habit steps in routine flow
- **Skippable**: Users can skip questions without breaking the routine

### 2. Branching Logic
- **Path Type**: Simple multiple paths based on answer selection
- **Merging**: Paths can merge back together later in the routine
- **Nesting**: Nested conditional habits within paths (optional for future)
- **Completion**: If any path is completed, the entire routine is considered complete

### 3. Path Structure
- **Content**: Each path contains a sequence of regular habits
- **Types**: Paths can include any existing habit type (timers, shortcuts, checkboxes, etc.)
- **Length**: No maximum limit on habits per path
- **Empty Paths**: Options can lead to empty paths (effectively skipping ahead)
- **Preview**: No preview of upcoming habits based on answer selection

### 4. Execution Flow
- **Selection**: When user selects an option, the conditional habit is marked complete
- **Path Addition**: The selected path's habits are added to the current routine at the current position
- **Continuation**: After path completion, routine continues with remaining habits
- **Empty Path**: If selected path is empty, routine continues to next normal habit

### 5. Data Tracking
- **Responses**: Log all question responses with timestamps and routine IDs
- **Storage**: Store responses for future analysis (no immediate UI needed)
- **Analytics**: No complex analytics dashboard required
- **History**: Backend tracking only for now

### 6. User Experience
- **Visual**: Conditional habits appear as normal habits in the routine
- **Interaction**: No ability to change answers once selected
- **Error Handling**: Skip ahead on any errors or failures
- **Fallback**: Default behavior is always to skip ahead and continue routine

### 7. Integration Points
- **Routine Types**: Available in all routine types (morning, evening, daily planning, weekly)
- **Habit Types**: Each path can contain any existing habit type
- **Builder**: Created through routine builder with simple interface
- **Statistics**: Different paths don't count as separate habits for stats

## Use Cases & Examples

### Example 1: Pain Assessment
```
Question: "Any pain today?"
Options:
- Shoulder → [Shoulder Stretches, Nerve Glides]
- Knee → [Knee Mobilization, Gentle Movement]  
- Back → [Back Extensions, Core Activation]
- None → [] (empty path, continue to next habit)
```

### Example 2: Time Available
```
Question: "How much time do you have?"
Options:
- 10 minutes → [Quick Stretch (2 min), Deep Breathing (3 min)]
- 20 minutes → [Full Stretch Routine (10 min), Meditation (5 min)]
- 30+ minutes → [Workout (15 min), Recovery (5 min), Meditation (10 min)]
- Rushed → [] (empty path, skip to essential habits)
```

### Example 3: Work Setup Preparation
```
Question: "Work setup today?"
Options:
- Long sitting → [Hip Flexor Stretch, Posture Check, Desk Setup]
- Standing desk → [Calf Raises, Balance Check]
- Mobile/Travel → [Neck Rolls, Seated Stretches]  
- Rest day → [] (empty path, continue normally)
```

## Technical Implementation

### Data Model
```swift
struct ConditionalHabit: Habit {
    let question: String
    let options: [ConditionalOption] // Max 4
}

struct ConditionalOption {
    let id: UUID
    let text: String
    let habits: [Habit] // Path of habits to execute
}

struct ConditionalResponse {
    let id: UUID
    let questionId: UUID
    let selectedOptionId: UUID
    let selectedOptionText: String
    let timestamp: Date
    let routineId: UUID
}
```

### Builder Requirements
- **Simple Interface**: Easy-to-use path creation in routine builder
- **Question Input**: Text field for question
- **Option Management**: Add/remove/edit up to 4 options
- **Path Building**: Drag-and-drop or simple list for adding habits to each path
- **Validation**: Ensure at least 2 options per conditional habit

### Error Handling Strategy
- **Missing Habits**: Skip broken habits in paths, continue with remaining
- **Invalid Paths**: If entire path fails, skip to next normal habit
- **Data Corruption**: Default to empty path behavior (skip ahead)
- **Network Issues**: No network dependency, all handled locally
- **User Errors**: Graceful degradation, always allow routine continuation

## Implementation Priority

### Phase 1 (MVP)
1. Basic conditional habit type with question + 4 options
2. Simple path execution (add habits to current routine)
3. Response logging to local storage
4. Basic builder interface
5. Integration with existing habit types

### Phase 2 (Future)
1. Nested conditional habits
2. Response history UI
3. Pattern analysis and insights
4. Advanced builder features
5. Export/import of conditional routines

## Success Criteria
- Users can create conditional habits in routine builder
- Questions appear as normal habits during routine execution  
- Selected paths execute correctly and merge back to main routine
- All responses are logged for future analysis
- System gracefully handles all error conditions
- No impact on existing habit functionality