# Next Steps for Junior Developer

## Current Status
✅ **COMPLETED**: Platform compatibility build errors resolved - iOS-only implementation complete
🔄 **READY**: Begin Phase 1 refactoring with zero-regression priority

## Phase 1.1: Fix LocationService Memory Leaks (NEXT TASK)

### Problem Description
The LocationService has potential memory leaks due to strong reference cycles in closures and delegate patterns. This can cause the app to consume excessive memory over time.

### Technical Requirements
1. **Location**: `/Sources/HabitTrackerFeature/Services/LocationService.swift`
2. **Goal**: Replace strong references with weak references in closures
3. **Pattern**: Use `[weak self]` in all closures that capture `self`
4. **Testing**: Verify no functionality breaks after changes

### Implementation Steps

#### Step 1: Analyze Current Memory Issues
```bash
# Navigate to the service
cd HabitTrackerPackage/Sources/HabitTrackerFeature/Services
```

Look for patterns like:
```swift
// ❌ WRONG - Creates retain cycle
someAsyncOperation { result in
    self.handleResult(result)  // Strong capture
}

// ✅ CORRECT - Prevents retain cycle
someAsyncOperation { [weak self] result in
    self?.handleResult(result)  // Weak capture
}
```

#### Step 2: Search for Memory Leak Patterns
Use these commands to find potential issues:
```bash
# Find closures that might need weak self
grep -n "{ " LocationService.swift | grep -v "weak"
grep -n "self\." LocationService.swift
```

#### Step 3: Apply Weak Reference Pattern
Replace patterns like:
```swift
// Before
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    self.updateLocation()
}

// After
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.updateLocation()
}
```

#### Step 4: Handle Delegate Patterns
Look for delegate assignments and ensure they're weak:
```swift
// Before
locationManager.delegate = self

// After - verify delegate property is weak
// Check: weak var delegate: LocationManagerDelegate?
```

#### Step 5: Test the Changes
```bash
# Build and verify no regressions
swift build

# Look for these potential issues:
# - Nil crashes from self? calls
# - Missing updates due to premature deallocation
# - Changed app behavior
```

### What to Look For

#### Common Memory Leak Sources:
1. **Timer callbacks** without `[weak self]`
2. **Network completion handlers** with strong self
3. **Notification observers** not properly removed
4. **Closure properties** that capture self strongly
5. **Delegate cycles** (less common with proper delegate patterns)

#### Files to Check:
- `LocationService.swift` (primary)
- `SmartRoutineSelector.swift` (uses LocationService)
- Any view that holds LocationService references

### Success Criteria
- [ ] All closures in LocationService use `[weak self]` where appropriate
- [ ] App builds without errors or warnings
- [ ] Location functionality still works correctly
- [ ] No crashes introduced
- [ ] Memory usage doesn't grow over time during location updates

### Testing Approach
1. **Build Test**: `swift build` must succeed
2. **Functionality Test**: Location-based routine selection still works
3. **Memory Test**: Run app and use location features repeatedly - memory should be stable

### Common Pitfalls to Avoid
1. **Don't break the optional chain**: `self?.property?.method()` not `self.property?.method()`
2. **Guard for self when needed**: 
   ```swift
   { [weak self] in
       guard let self = self else { return }
       self.complexOperation()
   }
   ```
3. **Don't add weak where not needed**: Simple value returns don't need weak self

### When You're Done
Update the todo list:
```swift
// Mark Phase 1.1 as in_progress when you start
// Mark as completed when all memory leaks are fixed
```

Move to **Phase 1.2**: Add user-facing error presentation framework

---

## Phase 1.2 Preview: Error Presentation Framework
**Next task after 1.1**: Create user-friendly error messages and recovery options for common failures like location permission denied, network errors, etc.

### Preview of Phase 1.2 Requirements
1. **Create ErrorPresentationService**: Centralized error handling for user-facing errors
2. **Design Error Recovery**: Actionable buttons for common failures
3. **Implement Toast/Alert System**: Non-intrusive error notifications
4. **Location Permission Errors**: Specific handling for location access denied
5. **Network Errors**: Retry mechanisms and offline state handling

---

## Phase 1.3 Preview: Fix LocationService Race Conditions
**Next task after 1.2**: Implement atomic updates and proper synchronization for location data access.

### Preview of Phase 1.3 Requirements
1. **Identify Race Conditions**: Multiple threads accessing location data simultaneously
2. **Implement Actor Pattern**: Convert LocationService to use Swift Actor for thread safety
3. **Atomic Updates**: Ensure location updates are atomic and consistent
4. **Background Thread Safety**: Proper handling of location updates from background threads

---

## Phase 1.4 Preview: Standardize Actor Isolation
**Next task after 1.3**: Ensure all UI services use @MainActor isolation consistently.

### Preview of Phase 1.4 Requirements
1. **Audit Actor Isolation**: Review all services for proper actor isolation
2. **UI Services to @MainActor**: Ensure UI-related services are main actor isolated
3. **Background Services**: Ensure data services use appropriate actor isolation
4. **Fix Isolation Warnings**: Resolve any Swift 6 concurrency warnings

---

## Questions?
If you encounter:
- **Unclear weak/strong patterns**: Ask for specific code review
- **Test failures**: Share the exact error messages
- **Architecture questions**: Ask about the overall memory management strategy

**Remember**: Zero-regression priority means if anything breaks, stop and ask for help rather than guessing!

## Development Commands Reference

### Building and Testing
```bash
# Navigate to package
cd HabitTrackerPackage

# Build the project
swift build

# Run tests (when available)
swift test

# Check for issues
swift build 2>&1 | head -50
```

### Code Analysis
```bash
# Find potential memory leaks
grep -r "\[weak self\]" Sources/
grep -r "self\." Sources/ | grep -v "weak"

# Find closures
grep -r "{ " Sources/ | grep -v "weak"

# Find timer usage
grep -r "Timer\." Sources/
```

### Git Workflow
```bash
# Create feature branch
git checkout -b fix/locationservice-memory-leaks

# Commit changes
git add .
git commit -m "fix: resolve LocationService memory leaks with weak references

- Add [weak self] to all relevant closures
- Prevent retain cycles in timer callbacks
- Ensure proper delegate weak reference patterns"

# When ready to merge
git checkout main
git merge fix/locationservice-memory-leaks
```