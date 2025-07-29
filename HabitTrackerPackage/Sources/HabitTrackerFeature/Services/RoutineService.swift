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
    
    /// Routine selector for context-aware selection
    public let routineSelector = RoutineSelector()
    
    private let persistenceService: any PersistenceServiceProtocol
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        loadTemplates()
    }
    
    /// Load templates from persistence, or create sample templates if none exist
    private func loadTemplates() {
        Task { @MainActor in
            do {
                if let loadedTemplates = try await persistenceService.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates) {
                    templates = loadedTemplates
                    
                    // Send loaded templates to watch on app startup
                    WatchConnectivityManager.shared.sendRoutineDataToWatch(templates)
                    return
                }
            } catch {
                ErrorHandlingService.shared.handleDataError(
                    .decodingFailed(type: "RoutineTemplate", underlyingError: error),
                    key: PersistenceKeys.routineTemplates,
                    operation: "load"
                )
            }
            
            // First time launch or failed to load - create sample templates
            LoggingService.shared.info(
                "Creating sample templates for first launch",
                category: .routine,
                metadata: ["reason": "no_existing_templates"]
            )
            loadSampleTemplates()
            await persistTemplates()
        }
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
    private func persistTemplates() async {
        do {
            try await persistenceService.save(templates, forKey: PersistenceKeys.routineTemplates)
            
            // Send updated templates to watch
            await MainActor.run {
                WatchConnectivityManager.shared.sendRoutineDataToWatch(templates)
            }
        } catch {
            ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "RoutineTemplate", underlyingError: error),
                key: PersistenceKeys.routineTemplates,
                operation: "save"
            )
        }
    }
    
    /// Start a new routine session with the given template
    public func startSession(with template: RoutineTemplate) throws {
        // Check if session is already active
        guard currentSession == nil else {
            let error = RoutineError.sessionAlreadyActive
            ErrorHandlingService.shared.handleRoutineError(error, sessionId: currentSession?.id)
            throw error
        }
        
        // Validate template
        guard !template.habits.isEmpty else {
            let error = RoutineError.templateValidationFailed(reason: "Template has no habits")
            ErrorHandlingService.shared.handleRoutineError(error, templateId: template.id)
            throw error
        }
        
        // Validate template exists in our collection
        guard templates.contains(where: { $0.id == template.id }) else {
            let error = RoutineError.templateNotFound(id: template.id)
            ErrorHandlingService.shared.handleRoutineError(error, templateId: template.id)
            throw error
        }
        
        currentSession = RoutineSession(template: template)
        
        // Update template's last used date
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].lastUsedAt = Date()
            Task { await persistTemplates() }
        }
    }
    
    /// Complete the current session
    public func completeCurrentSession() throws {
        guard let session = currentSession else {
            let error = RoutineError.noActiveSession
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }
        
        // Complete the session manually
        session.forceComplete()
        currentSession = nil
    }
    
    /// Cancel the current session
    public func cancelCurrentSession() throws {
        guard let session = currentSession else {
            let error = RoutineError.noActiveSession
            ErrorHandlingService.shared.handleRoutineError(error)
            throw error
        }
        
        // Log the cancellation for analytics/debugging
        LoggingService.shared.info("Routine session cancelled", category: .routine, metadata: [
            "sessionId": session.id.uuidString,
            "templateName": session.template.name,
            "progress": String(session.progress),
            "completedHabits": String(session.completions.filter { !$0.isSkipped }.count),
            "totalHabits": String(session.activeHabits.count)
        ])
        
        // Clear the current session without completing it
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
        await routineSelector.selectBestTemplate(from: templates)
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
        
        Task { await persistTemplates() }
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
            
            Task { await persistTemplates() }
        }
    }
    
    /// Delete a template
    public func deleteTemplate(withId id: UUID) {
        templates.removeAll { $0.id == id }
        Task { await persistTemplates() }
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
        ConditionalHabitService.shared.recordResponse(response)
        
        // Get the habits from the selected path
        let pathHabits = option.habits
        
        // Find the current position in the active habits
        let currentHabitIndex = session.currentHabitIndex
        
        // If there are habits in the path, inject them into the session
        if !pathHabits.isEmpty {
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
            }
            
            // Add remaining habits with adjusted sequential order values
            if currentHabitIndex + 1 < activeHabits.count {
                for i in (currentHabitIndex + 1)..<activeHabits.count {
                    var remainingHabit = activeHabits[i]
                    remainingHabit.order = currentHabitIndex + 1 + pathHabits.count + (i - currentHabitIndex - 1)
                    newOrder.append(remainingHabit)
                }
            }
            
            // Apply the reordering modification
            session.reorderHabits(newOrder)
        }
        
        // Complete the conditional habit and advance to the next habit (which should be the first injected habit)
        
        session.completeConditionalHabit(
            habitId: habitId,
            duration: nil,
            notes: "Selected: \(option.text)"
        )
        
        // Move to the next habit (first injected habit if pathHabits is not empty,
        // or the next habit in the original sequence if pathHabits is empty)
        session.goToHabit(at: session.currentHabitIndex + 1)
        
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
        ConditionalHabitService.shared.recordResponse(response)
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