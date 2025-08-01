import ActivityKit
import SwiftUI
import Foundation

/// Manages Live Activities for timer habits
@available(iOS 16.1, *)
@MainActor
public class LiveActivityManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = LiveActivityManager()
    
    // MARK: - Properties
    
    @Published public private(set) var activeActivities: [String: Activity<TimerActivityAttributes>] = [:]
    
    private init() {
        // Load existing activities on init
        loadExistingActivities()
    }
    
    // MARK: - Public Methods
    
    /// Start a Live Activity for a timer habit
    public func startTimerActivity(
        for habit: Habit,
        duration: TimeInterval,
        startTime: Date = Date()
    ) async {
        // Only support timer habits
        guard case .timer = habit.type else { return }
        
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }
        
        // End existing activity for this habit if any
        await endActivity(for: habit.id.uuidString)
        
        let attributes = TimerActivityAttributes(habitId: habit.id.uuidString)
        let initialState = TimerActivityAttributes.ContentState(
            habitName: habit.name,
            startTime: startTime,
            duration: duration,
            currentProgress: 0.0,
            isRunning: true,
            habitColor: habit.swiftUIColor.toHex(),
            timeRemaining: duration
        )
        
        do {
            let activity = try Activity<TimerActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            
            activeActivities[habit.id.uuidString] = activity
            print("Started Live Activity for habit: \(habit.name)")
            
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    /// Update an existing Live Activity with new timer state
    public func updateTimerActivity(
        for habitId: String,
        currentProgress: Double,
        timeRemaining: TimeInterval,
        isRunning: Bool
    ) async {
        guard let activity = activeActivities[habitId] else { return }
        
        let currentState = activity.content.state
        let updatedState = TimerActivityAttributes.ContentState(
            habitName: currentState.habitName,
            startTime: currentState.startTime,
            duration: currentState.duration,
            currentProgress: currentProgress,
            isRunning: isRunning,
            habitColor: currentState.habitColor,
            timeRemaining: timeRemaining
        )
        
        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: isRunning ? Date.now.addingTimeInterval(30) : nil
        )
        
        // Re-fetch the activity right before the await to avoid data race
        guard let activityToUpdate = activeActivities[habitId] else { return }
        
        do {
            await activityToUpdate.update(updatedContent)
        } catch {
            print("Failed to update Live Activity: \(error)")
        }
    }
    
    /// Complete a timer habit and end its Live Activity
    public func completeTimerActivity(for habitId: String, actualDuration: TimeInterval? = nil) async {
        guard let activity = activeActivities[habitId] else { return }
        
        let currentState = activity.content.state
        let finalState = TimerActivityAttributes.ContentState(
            habitName: currentState.habitName,
            startTime: currentState.startTime,
            duration: actualDuration ?? currentState.duration,
            currentProgress: 1.0,
            isRunning: false,
            habitColor: currentState.habitColor,
            timeRemaining: 0
        )
        
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: Date.now.addingTimeInterval(5) // Keep visible for 5 seconds
        )
        
        // Re-fetch the activity right before the await to avoid data race
        guard let activityToUpdate = activeActivities[habitId] else { return }
        
        do {
            await activityToUpdate.update(finalContent)
            
            // End the activity after a brief delay to show completion
            try await Task.sleep(for: .seconds(2))
            
            // Re-fetch again after the sleep to avoid data race
            guard let activityToEnd = activeActivities[habitId] else { return }
            await activityToEnd.end(nil, dismissalPolicy: .default)
            
            activeActivities.removeValue(forKey: habitId)
            
        } catch {
            print("Failed to complete Live Activity: \(error)")
        }
    }
    
    /// End a Live Activity for a specific habit
    public func endActivity(for habitId: String) async {
        guard let activity = activeActivities[habitId] else { return }
        
        // Re-fetch the activity right before the await to avoid data race
        guard let activityToEnd = activeActivities[habitId] else { return }
        await activityToEnd.end(nil, dismissalPolicy: .default)
        activeActivities.removeValue(forKey: habitId)
    }
    
    /// End all active Live Activities
    public func endAllActivities() async {
        // Copy the habit IDs to avoid modifying dictionary while iterating
        let habitIds = Array(activeActivities.keys)
        
        for habitId in habitIds {
            guard let activity = activeActivities[habitId] else { continue }
            await activity.end(nil, dismissalPolicy: .default)
        }
        activeActivities.removeAll()
    }
    
    /// Check if a habit has an active Live Activity
    public func hasActiveActivity(for habitId: String) -> Bool {
        return activeActivities[habitId] != nil
    }
    
    // MARK: - Private Methods
    
    private func loadExistingActivities() {
        Task {
            // Load activities that might still be active from previous app sessions
            for activity in Activity<TimerActivityAttributes>.activities {
                activeActivities[activity.attributes.habitId] = activity
            }
        }
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "%06X", rgb)
    }
}

// MARK: - ActivityAuthorizationInfo Extension

@available(iOS 16.1, *)
extension ActivityAuthorizationInfo {
    var areActivitiesEnabled: Bool {
        return self.areActivitiesEnabled
    }
}