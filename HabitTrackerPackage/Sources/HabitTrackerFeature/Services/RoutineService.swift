import Foundation
import SwiftUI

// MARK: - Notifications
extension Notification.Name {
    static let routineQueueDidChange = Notification.Name("routineQueueDidChange")
}

/// Service for managing routine templates and sessions
@MainActor
@Observable
public final class RoutineService {
    public private(set) var templates: [RoutineTemplate] = []
    public private(set) var currentSession: RoutineSession?
    public private(set) var moodRatings: [MoodRating] = []
    
    /// Smart routine selector for context-aware selection
    public let smartSelector = SmartRoutineSelector()
    
    private let persistenceService: any PersistenceServiceProtocol
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        loadTemplates()
    }
    
    /// Load templates from persistence, or create sample templates if none exist
    private func loadTemplates() {
        do {
            if let loadedTemplates = try persistenceService.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates) {
                templates = loadedTemplates
                print("✅ Loaded \(templates.count) templates from persistence")
                return
            }
        } catch {
            print("❌ Failed to load templates from persistence: \(error)")
        }
        
        // First time launch or failed to load - create sample templates
        print("🆕 Creating sample templates (first launch)")
        loadSampleTemplates()
        persistTemplates()
    }
    
    /// Load predefined sample templates
    private func loadSampleTemplates() {
        templates = [
            createOfficeTemplate(),
            createHomeOfficeTemplate(),
            createWeekendTemplate(),
            createAfternoonTemplate()
        ]
    }
    
    /// Persist templates using PersistenceService
    private func persistTemplates() {
        do {
            try persistenceService.save(templates, forKey: PersistenceKeys.routineTemplates)
            print("✅ Persisted \(templates.count) templates")
        } catch {
            print("❌ Failed to persist templates: \(error)")
        }
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
    
    /// Get smart template based on current context
    @MainActor
    public func getSmartTemplate() async -> (template: RoutineTemplate?, reason: String) {
        await smartSelector.selectBestTemplate(from: templates)
    }
    
    /// Add a new template
    public func addTemplate(_ template: RoutineTemplate) {
        templates.append(template)
        
        // If this is the first template or marked as default, make it default
        if templates.count == 1 || template.isDefault {
            // Unset other defaults if this is default
            if template.isDefault {
                for index in templates.indices {
                    if templates[index].id != template.id {
                        templates[index].isDefault = false
                    }
                }
            }
        }
        
        persistTemplates()
    }
    
    /// Update an existing template
    public func updateTemplate(_ template: RoutineTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            
            // Handle default status
            if template.isDefault {
                for i in templates.indices where i != index {
                    templates[i].isDefault = false
                }
            }
            
            persistTemplates()
        }
    }
    
    /// Delete a template
    public func deleteTemplate(withId id: UUID) {
        templates.removeAll { $0.id == id }
        persistTemplates()
    }
    
    /// Handle selection of a conditional habit option
    public func handleConditionalOptionSelection(
        option: ConditionalOption,
        for habitId: UUID,
        question: String
    ) {
        guard let session = currentSession else { return }
        
        // Log the response
        let response = ConditionalResponse(
            habitId: habitId,
            question: question,
            selectedOptionId: option.id,
            selectedOptionText: option.text,
            routineId: session.id,
            wasSkipped: false
        )
        ResponseLoggingService.shared.logResponse(response)
        
        // Get the habits from the selected path
        let pathHabits = option.habits
        
        // If there are habits in the path, inject them into the session
        if !pathHabits.isEmpty {
            // Find the current position in the active habits
            let currentIndex = session.currentHabitIndex
            let activeHabits = session.activeHabits
            
            // Create a reordered habit list that inserts the path habits after the current conditional
            var newOrder: [Habit] = []
            
            // Add habits up to and including current position
            for i in 0...currentIndex {
                if i < activeHabits.count {
                    newOrder.append(activeHabits[i])
                }
            }
            
            // Insert the path habits with adjusted order values
            let baseOrder = currentIndex + 1
            for (index, habit) in pathHabits.enumerated() {
                var pathHabit = habit
                pathHabit.order = baseOrder + index
                newOrder.append(pathHabit)
            }
            
            // Add remaining habits with adjusted order values
            if currentIndex + 1 < activeHabits.count {
                for i in (currentIndex + 1)..<activeHabits.count {
                    var remainingHabit = activeHabits[i]
                    remainingHabit.order = baseOrder + pathHabits.count + (i - currentIndex - 1)
                    newOrder.append(remainingHabit)
                }
            }
            
            // Apply the reordering modification
            session.reorderHabits(newOrder)
        }
        
        // Post notification that routine queue changed
        NotificationCenter.default.post(name: .routineQueueDidChange, object: nil)
    }
    
    /// Handle skipping a conditional habit
    public func skipConditionalHabit(habitId: UUID, question: String) {
        guard let session = currentSession else { return }
        
        // Log the skip response
        let response = ConditionalResponse.skip(
            habitId: habitId,
            question: question,
            routineId: session.id
        )
        ResponseLoggingService.shared.logResponse(response)
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
        
        // Office routine is for weekday mornings at the office
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning],
            dayCategoryIds: ["weekday"],
            locationIds: ["office"],
            priority: 2
        )
        
        return RoutineTemplate(
            name: "Office Day",
            description: "Morning routine for office workdays",
            habits: habits,
            color: "#007AFF",
            contextRule: contextRule
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
        
        // Home office routine is for weekday mornings at home
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning, .lateMorning],
            dayCategoryIds: ["weekday"],
            locationIds: ["home"],
            priority: 2
        )
        
        return RoutineTemplate(
            name: "Home Office",
            description: "Morning routine for working from home",
            habits: habits,
            color: "#34C759",
            isDefault: false,
            contextRule: contextRule
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
        
        // Weekend routine is for any time on weekends, any location
        let contextRule = RoutineContextRule(
            timeSlots: [.earlyMorning, .morning, .lateMorning, .afternoon, .evening, .night],
            dayCategoryIds: ["weekend"],
            locationIds: [], // Any location
            priority: 1
        )
        
        return RoutineTemplate(
            name: "Weekend",
            description: "Relaxed weekend morning routine",
            habits: habits,
            color: "#FDCB6E",
            contextRule: contextRule
        )
    }
    
    /// Create afternoon routine template
    private func createAfternoonTemplate() -> RoutineTemplate {
        let habits = [
            Habit(
                name: "Review Daily Goals",
                type: .checkbox,
                color: "#007AFF",
                order: 1
            ),
            Habit(
                name: "Afternoon Stretch",
                type: .timer(defaultDuration: 300),
                color: "#34C759",
                order: 2
            ),
            Habit(
                name: "Healthy Snack",
                type: .checkbox,
                color: "#FF9500",
                order: 3
            ),
            Habit(
                name: "Focus Time",
                type: .timer(defaultDuration: 1500),
                color: "#5856D6",
                order: 4
            ),
            Habit(
                name: "Evening Planning",
                type: .checkboxWithSubtasks(subtasks: [
                    Subtask(name: "Review tomorrow's calendar"),
                    Subtask(name: "Set top 3 priorities"),
                    Subtask(name: "Prepare for meetings")
                ]),
                color: "#FF3B30",
                order: 5
            )
        ]
        
        // Afternoon routine is for weekday and weekend afternoons/evenings at any location
        let contextRule = RoutineContextRule(
            timeSlots: [.afternoon, .evening],
            dayCategoryIds: ["weekday", "weekend"],
            locationIds: [], // Any location
            priority: 3 // Higher priority than weekend template
        )
        
        return RoutineTemplate(
            name: "Afternoon Focus",
            description: "Afternoon productivity and evening prep",
            habits: habits,
            color: "#FF9500",
            isDefault: false,
            contextRule: contextRule
        )
    }
}