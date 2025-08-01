# Live Activities Implementation

This directory contains the Live Activities implementation for HabitTracker timer habits, providing real-time timer updates on the Lock Screen and Dynamic Island.

## Files

### `TimerLiveActivity.swift`
- **TimerActivityAttributes**: Defines the structure for Live Activity data
- **TimerLiveActivityWidget**: The main widget implementation with Lock Screen and Dynamic Island presentations
- **Supporting Views**: HabitIconView, TimerProgressView, etc.

### `LiveActivityManager.swift`
- **LiveActivityManager**: Singleton class managing all Live Activity operations
- **Public API**: Start, update, complete, and end Live Activities
- **Error Handling**: Graceful handling of ActivityKit errors

## Key Features

### 🔒 Lock Screen Presentation
- **Habit Name & Icon**: Clear identification of the active timer
- **Real-time Progress**: Live countdown timer with progress bar
- **Visual Feedback**: Color changes when time is running low (< 30 seconds)
- **Status Indicators**: Shows "In Progress" or "Paused" state

### 🏝️ Dynamic Island Presentation
- **Compact Leading**: Timer icon with habit color
- **Compact Trailing**: Live countdown in MM:SS format  
- **Expanded**: Full timer details with controls
- **Minimal**: Simple timer icon for multiple activities

### ⚡ Real-time Updates
- **Efficient Updates**: Updates every 5 seconds, or every second when < 30 seconds remain
- **Battery Optimized**: Uses ActivityKit's efficient update mechanism
- **Automatic Cleanup**: Activities end automatically when timers complete

## Integration

### Timer Habit Views
Live Activities are automatically integrated into `AccessibleTimerHabitView`:

```swift
// Starting a timer automatically starts Live Activity
private func startTimer() {
    // ... existing timer logic ...
    
    // Start Live Activity
    if #available(iOS 16.1, *) {
        Task {
            await LiveActivityManager.shared.startTimerActivity(
                for: habit,
                duration: defaultDuration
            )
        }
    }
}
```

### App Lifecycle
The LiveActivityManager handles:
- **Permission Checking**: Verifies Live Activities are enabled
- **State Management**: Tracks active activities across app launches
- **Cleanup**: Properly ends activities when timers complete

## Requirements

### iOS Version
- Requires iOS 16.1+ for Live Activities
- Gracefully degrades on older iOS versions

### Entitlements
The app requires the Live Activities entitlement in `Config/HabitTracker.entitlements`:
```xml
<key>com.apple.developer.ActivityKit</key>
<true/>
```

### User Permissions
Users must have Live Activities enabled in Settings > Face ID & Passcode > Live Activities

## Usage Example

```swift
// Access the Live Activity Manager
let manager = HabitTrackerFeature.liveActivityManager

// Start a Live Activity for a timer habit
await manager.startTimerActivity(for: habit, duration: 300) // 5 minutes

// Update progress (handled automatically by timer views)
await manager.updateTimerActivity(
    for: habit.id.uuidString,
    currentProgress: 0.5,
    timeRemaining: 150,
    isRunning: true
)

// Complete the activity
await manager.completeTimerActivity(for: habit.id.uuidString)
```

## Technical Implementation

### Data Flow
1. User starts timer → Live Activity created
2. Timer updates → Activity updates every 5 seconds  
3. Timer completes → Activity shows completion briefly, then ends
4. User pauses → Activity updates to paused state

### Error Handling
- Activities fail gracefully if user has disabled them
- Network/system errors are logged but don't crash the app
- Existing activities are cleaned up on app restart

### Performance
- Minimal battery impact using ActivityKit's optimized update system
- Only essential data is passed to Live Activities
- Activities automatically end after completion

## Testing

### Simulator Testing
Live Activities work in iOS Simulator 16.1+ with proper setup:
1. Enable Live Activities in Simulator settings
2. Lock the simulator to see Lock Screen presentation
3. Test Dynamic Island on iPhone 14 Pro+ simulators

### Device Testing
Test on physical devices for the full experience:
- Dynamic Island interactions
- Lock Screen notifications
- Background app refresh scenarios

## Future Enhancements

Potential improvements for Live Activities:
- **Interactive Buttons**: Pause/resume from Lock Screen
- **Multiple Timers**: Support for concurrent timer activities
- **Habit Streaks**: Show completion streaks in activities
- **Custom Complications**: Enhanced Dynamic Island content