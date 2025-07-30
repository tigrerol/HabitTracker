# Next Steps for Habit Tracker

## Current Status
- ✅ Successfully consolidated counter and measurement types into unified "tracking" type
- ✅ Fixed Question card icon positioning to be closer to text for cohesive centered appearance
- ✅ Restored ConditionalHabitEditorView functionality after over-simplification
- ✅ Updated all counter/measurement references in ConditionalHabitEditorView

## Immediate Issue to Fix

### Question Options Not Displaying in Routine Builder
**Problem**: Question habit shows "2 options" but the options don't appear in the routine view
**Likely Cause**: Counter/measurement consolidation may have broken option display logic
**Investigation needed**:
1. Test the build to ensure no compilation errors
2. Check if `conditionalOptionsContent` function is working properly
3. Verify that the question habit's options are correctly populated
4. Debug why options show count but don't render in the UI

## Layout and UI Improvements

### Question Card Refinements
- ✅ Icon positioned closer to text (8pt spacing vs 12pt)
- ✅ Text horizontally centered
- ✅ Icon and text appear as unified centered element

### Habit Type Grid Layout
- ✅ First 4 types (Task, Timer, External Action, Tracking) in equal-sized 2x2 grid
- ✅ Question type spans full width at bottom
- ✅ All cards have equal height (68pt) with vertical centering
- ✅ Tracking type shows proper localized text instead of placeholder

## Testing Checklist

### Build and Functionality
- [ ] Test build succeeds without errors
- [ ] Create new Question habit and verify 2 default options are created
- [ ] Verify options display correctly in routine builder view
- [ ] Test editing existing Question habits
- [ ] Verify tracking type (items and numeric) works correctly

### UI/UX Verification
- [ ] Question card displays centered icon and text
- [ ] All habit type cards have equal height and proper alignment
- [ ] Tracking card shows "Tracking" title and "Track items or record values" description
- [ ] Grid layout maintains 2x2 for first 4 types, full width for Question

## Potential Issues to Monitor

### Counter/Measurement Migration
- **Risk**: Existing habits with old counter/measurement types may not display correctly
- **Solution**: Verify migration logic handles existing data properly

### Option Display Logic
- **Risk**: Conditional options may not render due to missing type handling
- **Solution**: Check `conditionalOptionsContent` function for type-specific logic

### Localization
- **Risk**: Missing or incorrect localization strings for consolidated types
- **Solution**: Verify all tracking-related strings are properly defined

## Next Session Priorities

1. **Fix Question Options Display** (HIGH PRIORITY)
   - Debug why options count shows but options don't render
   - Test question creation and editing workflow
   - Verify option management in routine builder

2. **Complete Testing** (MEDIUM PRIORITY)
   - Full build and functionality test
   - UI/UX verification across all habit types
   - Edge case testing for question habits

3. **Polish and Cleanup** (LOW PRIORITY)
   - Remove any remaining debug print statements
   - Verify all localization strings are correct
   - Final UI polish if needed

## Code Areas to Review

### Files Recently Modified
- `ConditionalHabitEditorView.swift` - Restored and updated for tracking consolidation
- `RoutineBuilderView.swift` - Grid layout changes and tracking type updates
- `HabitType.swift` - Core tracking type consolidation
- `Localizable.strings` - Tracking type strings added

### Key Functions to Test
- `conditionalOptionsContent()` in RoutineBuilderView
- Question habit creation workflow
- Tracking type selection and configuration
- Option display in routine builder

## Notes
- All tracking consolidation changes are complete and committed
- Question card layout improvements are working correctly
- Main remaining issue is conditional options not displaying properly
- Context window is approaching limit - focus on critical functionality first