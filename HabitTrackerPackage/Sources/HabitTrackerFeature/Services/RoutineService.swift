import Foundation
import SwiftUI

/// Service for managing routine templates and sessions
@Observable
public final class RoutineService: Sendable {
    public private(set) var templates: [RoutineTemplate] = []
    public private(set) var currentSession: RoutineSession?
    public private(set) var moodRatings: [MoodRating] = []
    
    public init() {
        loadSampleTemplates()
    }
    
    /// Load predefined sample templates
    private func loadSampleTemplates() {
        templates = [
            createOfficeTemplate(),
            createHomeOfficeTemplate(),
            createWeekendTemplate()
        ]
    }
    
    /// Start a new routine session with the given template
    public func startSession(with template: RoutineTemplate) {
        currentSession = RoutineSession(template: template)
        
        // Update template's last used date
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].lastUsedAt = Date()
        }
    }
    
    /// Complete the current session
    public func completeCurrentSession() {
        currentSession = nil
    }
    
    /// Add a mood rating for the completed session
    public func addMoodRating(_ mood: Mood, for sessionId: UUID, notes: String? = nil) {
        let rating = MoodRating(
            sessionId: sessionId,
            rating: mood,
            notes: notes
        )
        moodRatings.append(rating)
    }
    
    /// Get the most recently used template (for quick start)
    public var lastUsedTemplate: RoutineTemplate? {
        templates
            .filter { $0.lastUsedAt != nil }
            .max { ($0.lastUsedAt ?? Date.distantPast) < ($1.lastUsedAt ?? Date.distantPast) }
    }
    
    /// Get default template if set
    public var defaultTemplate: RoutineTemplate? {
        templates.first { $0.isDefault }
    }
}

// MARK: - Sample Templates
extension RoutineService {
    private func createOfficeTemplate() -> RoutineTemplate {
        let habits = [
            Habit(
                name: "Measure HRV",
                type: .appLaunch(bundleId: "com.morpheus.app", appName: "Morpheus"),
                color: "#FF6B6B",
                order: 0
            ),
            Habit(
                name: "Strength Training",
                type: .website(url: URL(string: "https://your-workout-site.com")!, title: "Workout Site"),
                color: "#4ECDC4",
                order: 1
            ),
            Habit(
                name: "Coffee",
                type: .checkbox,
                color: "#8B4513",
                order: 2
            ),
            Habit(
                name: "Supplements",
                type: .counter(items: ["Vitamin D", "Magnesium", "Omega-3"]),
                color: "#FFD93D",
                order: 3
            ),
            Habit(
                name: "Stretching",
                type: .timer(defaultDuration: 600), // 10 minutes
                color: "#6BCF7F",
                order: 4
            ),
            Habit(
                name: "Shower",
                type: .checkbox,
                color: "#74B9FF",
                order: 5
            )
        ]
        
        return RoutineTemplate(
            name: "Office Day",
            description: "Morning routine for office workdays",
            habits: habits,
            color: "#007AFF"
        )
    }
    
    private func createHomeOfficeTemplate() -> RoutineTemplate {
        let habits = [
            Habit(
                name: "Measure HRV",
                type: .appLaunch(bundleId: "com.morpheus.app", appName: "Morpheus"),
                color: "#FF6B6B",
                order: 0
            ),
            Habit(
                name: "Strength Training",
                type: .website(url: URL(string: "https://your-workout-site.com")!, title: "Workout Site"),
                color: "#4ECDC4",
                order: 1
            ),
            Habit(
                name: "Coffee",
                type: .checkbox,
                color: "#8B4513",
                order: 2
            ),
            Habit(
                name: "Supplements",
                type: .counter(items: ["Vitamin D", "Magnesium", "Omega-3"]),
                color: "#FFD93D",
                order: 3
            ),
            Habit(
                name: "Stretching",
                type: .timer(defaultDuration: 900), // 15 minutes (longer for home)
                color: "#6BCF7F",
                order: 4
            ),
            Habit(
                name: "Shower",
                type: .checkbox,
                color: "#74B9FF",
                order: 5
            ),
            Habit(
                name: "Prep Workspace",
                type: .checkbox,
                color: "#A29BFE",
                order: 6
            )
        ]
        
        return RoutineTemplate(
            name: "Home Office",
            description: "Morning routine for working from home",
            habits: habits,
            color: "#34C759",
            isDefault: true
        )
    }
    
    private func createWeekendTemplate() -> RoutineTemplate {
        let habits = [
            Habit(
                name: "Measure HRV",
                type: .appLaunch(bundleId: "com.morpheus.app", appName: "Morpheus"),
                color: "#FF6B6B",
                order: 0
            ),
            Habit(
                name: "Coffee",
                type: .checkbox,
                color: "#8B4513",
                order: 1
            ),
            Habit(
                name: "Supplements",
                type: .counter(items: ["Vitamin D", "Magnesium"]), // Fewer supplements on weekend
                color: "#FFD93D",
                order: 2
            ),
            Habit(
                name: "Long Stretching",
                type: .timer(defaultDuration: 1200), // 20 minutes
                color: "#6BCF7F",
                order: 3
            ),
            Habit(
                name: "Read News",
                type: .website(url: URL(string: "https://news.ycombinator.com")!, title: "Hacker News"),
                isOptional: true,
                color: "#FF7675",
                order: 4
            )
        ]
        
        return RoutineTemplate(
            name: "Weekend",
            description: "Relaxed weekend morning routine",
            habits: habits,
            color: "#FDCB6E"
        )
    }
}