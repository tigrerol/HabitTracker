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
        print("🔥 DEBUG: handleConditionalOptionSelection called")
        print("🔥 DEBUG: Option text: \(option.text)")
        print("🔥 DEBUG: Option has \(option.habits.count) habits")
        print("🔥 DEBUG: HabitId: \(habitId)")
        
        guard let session = currentSession else { 
            print("🔥 DEBUG: ERROR - No current session!")
            return 
        }
        
        print("🔥 DEBUG: Current session index: \(session.currentHabitIndex)")
        print("🔥 DEBUG: Active habits count: \(session.activeHabits.count)")
        
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
        
        // Find the current position in the active habits
        let currentHabitIndex = session.currentHabitIndex
        
        // If there are habits in the path, inject them into the session
        if !pathHabits.isEmpty {
            print("🔥 DEBUG: Injecting \(pathHabits.count) path habits")
            let activeHabits = session.activeHabits
            
            // Create a reordered habit list that inserts the path habits after the current conditional
            var newOrder: [Habit] = []
            
            // Add habits up to and including current position
            for i in 0...currentHabitIndex {
                if i < activeHabits.count {
                    var habit = activeHabits[i]
                    habit.order = i  // Ensure correct sequential order
                    newOrder.append(habit)
                }
            }
            
            // Insert the path habits with sequential order values
            for (index, habit) in pathHabits.enumerated() {
                var pathHabit = habit
                pathHabit.order = currentHabitIndex + 1 + index  // Sequential after current
                newOrder.append(pathHabit)
                print("🔥 DEBUG: Injected habit '\(pathHabit.name)' with order \(pathHabit.order)")
            }
            
            // Add remaining habits with adjusted sequential order values
            if currentHabitIndex + 1 < activeHabits.count {
                for i in (currentHabitIndex + 1)..<activeHabits.count {
                    var remainingHabit = activeHabits[i]
                    remainingHabit.order = currentHabitIndex + 1 + pathHabits.count + (i - currentHabitIndex - 1)
                    newOrder.append(remainingHabit)
                    print("🔥 DEBUG: Reordered habit '\(remainingHabit.name)' with order \(remainingHabit.order)")
                }
            }
            
            print("🔥 DEBUG: Final newOrder before reorderHabits:")
            for (i, h) in newOrder.enumerated() {
                print("🔥 DEBUG:   [\(i)] \(h.name) order=\(h.order) id=\(h.id)")
            }
            
            // Apply the reordering modification
            session.reorderHabits(newOrder)
        }
        
        // Complete the conditional habit and advance to the next habit (which should be the first injected habit)
        print("🔥 DEBUG: About to complete conditional habit")
        print("🔥 DEBUG: BEFORE completion - Active habits:")
        for (i, h) in session.activeHabits.enumerated() {
            let isCompleted = session.completions.contains { $0.habitId == h.id }
            print("🔥 DEBUG:   [\(i)] \(h.name) (ID: \(h.id)) - Completed: \(isCompleted)")
        }
        print("🔥 DEBUG: BEFORE completion - Completions:")
        for comp in session.completions {
            print("🔥 DEBUG:   - \(comp.habitId) at \(comp.completedAt)")
        }
        
        session.completeConditionalHabit(
            habitId: habitId,
            duration: nil,
            notes: "Selected: \(option.text)"
        )
        
        print("🔥 DEBUG: AFTER completion - Active habits:")
        for (i, h) in session.activeHabits.enumerated() {
            let isCompleted = session.completions.contains { $0.habitId == h.id }
            print("🔥 DEBUG:   [\(i)] \(h.name) (ID: \(h.id)) - Completed: \(isCompleted)")
        }
        print("🔥 DEBUG: AFTER completion - Completions:")
        for comp in session.completions {
            print("🔥 DEBUG:   - \(comp.habitId) at \(comp.completedAt)")
        }
        
        // Move to the next habit (first injected habit if pathHabits is not empty,
        // or the next habit in the original sequence if pathHabits is empty)
        session.goToHabit(at: session.currentHabitIndex + 1)
        
        
        print("🔥 DEBUG: AFTER goToHabit - currentHabitIndex: \(session.currentHabitIndex)")
        print("🔥 DEBUG: AFTER goToHabit - currentHabit: \(session.currentHabit?.name ?? "nil") (ID: \(session.currentHabit?.id.uuidString ?? "nil"))")
        
        // Post notification that routine queue changed
        print("🔥 DEBUG: Posting .routineQueueDidChange notification")
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
        let habits = HabitFactory.createOfficeMorningHabits()
        
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
        let habits = HabitFactory.createHomeOfficeHabits()
        
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
        let habits = HabitFactory.createWeekendHabits()
        
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
        let habits = HabitFactory.createAfternoonHabits()
        
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