# RoutineSession EXC_BAD_ACCESS Debug and Fix Plan

## Problem Analysis

### Crash Details
- **Error**: Thread 1: EXC_BAD_ACCESS (code=1, address=0x3)
- **Location**: String formatting line with duration.formattedDuration
- **Context**: ObservationRegistrar involved, suggesting @Observable macro issues
- **Pattern**: Crash occurs when session is completed and completion view is shown

### Root Cause Hypothesis
1. The RoutineSession is marked with both `@Observable` and `@MainActor`
2. The observation system is retaining weak references to the session
3. When session is deallocated, the observation system crashes trying to access it
4. The formattedDuration computed property access triggers observation tracking

## Debug Plan

### Phase 1: Isolate the Crash Source
1. **Test if it's the observation system**
   - Remove @Observable from RoutineSession temporarily
   - Use @Published properties instead
   - Test if crash persists

2. **Test if it's the TimeInterval extension**
   - Replace formattedDuration with a simple string
   - Test if crash persists

3. **Test if it's the String format**
   - Use simple string interpolation instead of String(format:)
   - Test if crash persists

### Phase 2: Deep Analysis
1. **Memory Analysis**
   - Add print statements to track object lifecycle
   - Log when session is created/destroyed
   - Track observation registrar state

2. **Stack Trace Analysis**
   - Enable Zombie Objects in scheme
   - Use Address Sanitizer
   - Capture full crash logs

### Phase 3: Systematic Fixes

## Fix Implementation Plan

### Fix 1: Remove Session Parameter from View Functions
Instead of passing session to view functions, extract all needed data upfront.

```swift
struct SessionDisplayData {
    let id: UUID
    let templateName: String
    let templateColor: String
    let habits: [Habit]
    let completions: [HabitCompletion]
    let startedAt: Date
    let completedAt: Date?
    let currentHabitIndex: Int
    let isCompleted: Bool
    let progress: Double
    let durationString: String
    let completedCount: Int
    let totalCount: Int
}
```

### Fix 2: Redesign RoutineSession Observation
1. Remove @Observable from RoutineSession
2. Make RoutineService handle all state changes
3. Use explicit state updates instead of automatic observation

### Fix 3: Implement Safe Session Access Pattern
1. Never pass RoutineSession to view functions
2. Always extract data at the top level
3. Use @State to cache extracted data

### Fix 4: Fix the TimeInterval Extension
Make the formattedDuration extension safer:
```swift
extension TimeInterval {
    var formattedDuration: String {
        guard self.isFinite && self >= 0 else { return "0:00" }
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

### Fix 5: Implement Defensive String Formatting
Replace problematic String format with safer approach:
```swift
// Instead of:
String(format: "You completed %1$d of %2$d habits in %@", ...)

// Use:
"You completed \(completedCount) of \(totalCount) habits in \(durationString)"
```

## Implementation Priority
1. **Immediate**: Fix the String formatting (Fix 5)
2. **High**: Implement safe session access (Fix 3)
3. **High**: Fix TimeInterval extension (Fix 4)
4. **Medium**: Remove session parameter from views (Fix 1)
5. **Low**: Redesign observation system (Fix 2)

## Testing Strategy
1. Test completion flow with single habit
2. Test with multiple habits
3. Test with skipped habits
4. Test rapid completion/navigation
5. Test with memory pressure

## Monitoring
- Add comprehensive logging
- Track session lifecycle
- Monitor observation registrar
- Log all state transitions