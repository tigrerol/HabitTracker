# Edit Question Card Improvements - July 31st Plan

## Current State Analysis
The "Edit Question" card currently has:
- Question text input field
- Second text line (appears unnecessary based on feedback)
- Manual option creation interface
- Task creation capabilities within the card

## Goals
1. **Simplify the interface** by removing unnecessary UI elements
2. **Auto-create two default options** when a question is created
3. **Remove task creation capability** from within the question card
4. **Streamline the user experience** for conditional habit creation

## Planned Changes

### 1. Remove Second Text Line
- **File**: `ConditionalHabitEditorView.swift`
- **Action**: Identify and remove the unnecessary second text input field
- **Impact**: Cleaner, more focused interface

### 2. Auto-Create Two Default Options
- **Files**: 
  - `ConditionalHabitEditorView.swift` (UI changes)
  - `ConditionalHabitInfo.swift` (model changes if needed)
  - `HabitFactory.swift` (factory methods)
- **Implementation**:
  - When a new conditional habit is created, automatically generate two default options
  - Default option names could be: "Yes" and "No" or "Option 1" and "Option 2"
  - User can rename these options as needed
- **Benefit**: Reduces friction in creating conditional habits

### 3. Remove Task Creation from Question Card
- **File**: `ConditionalHabitEditorView.swift`
- **Action**: Remove UI components and logic for creating tasks within the question card
- **Rationale**: Keep the question card focused on the question and options only
- **Alternative**: Tasks/habits should be added to the individual options, not the question itself

### 4. UI/UX Improvements
- **Simplify the layout** by removing unnecessary fields
- **Focus on question input** and option management
- **Ensure accessibility** labels are updated for the simplified interface
- **Test the flow** to ensure it's intuitive

## Implementation Order

### Phase 1: Analysis and Preparation
1. **Analyze current code structure**
   - Map out current ConditionalHabitEditorView components
   - Identify which UI elements correspond to the "second text line"
   - Understand current option creation flow

2. **Identify dependencies**
   - Check how conditional habits are created/stored
   - Verify option structure and requirements
   - Ensure no breaking changes to existing data

### Phase 2: Core Changes
1. **Remove unnecessary UI elements**
   - Remove second text line field
   - Remove task creation UI from question card
   - Clean up layout and spacing

2. **Implement auto-option creation**
   - Modify conditional habit creation to include two default options
   - Update factory methods if needed
   - Ensure proper initialization

### Phase 3: Polish and Testing
1. **Update accessibility**
   - Review and update accessibility labels
   - Test with VoiceOver
   - Ensure proper focus management

2. **Test the complete flow**
   - Create new conditional habit
   - Verify two options are auto-created
   - Test editing options
   - Verify no regressions in existing functionality

## Files to Focus On

### Primary Files
- `ConditionalHabitEditorView.swift` - Main UI component
- `ConditionalHabitInfo.swift` - Data model for conditional habits
- `HabitFactory.swift` - Factory methods for habit creation

### Secondary Files (may need updates)
- `Habit.swift` - Core habit model
- `RoutineBuilderView.swift` - Integration point
- `Localizable.strings` - Updated text strings

## Success Criteria
- ✅ Second text line is removed from Edit Question card
- ✅ Two default options are automatically created for new conditional habits
- ✅ No task creation capability within the question card
- ✅ Interface is cleaner and more focused
- ✅ No regressions in existing conditional habit functionality
- ✅ Accessibility is maintained or improved

## Potential Challenges
1. **Data Migration**: Ensure existing conditional habits still work
2. **Option Naming**: Choose appropriate default option names
3. **UI Layout**: Ensure clean layout after removing elements
4. **Integration**: Verify changes don't break routine builder flow

## Notes
- Keep changes focused and minimal to avoid introducing bugs
- Test thoroughly with existing conditional habits
- Consider user feedback on default option naming
- Maintain consistent UI patterns with rest of the app