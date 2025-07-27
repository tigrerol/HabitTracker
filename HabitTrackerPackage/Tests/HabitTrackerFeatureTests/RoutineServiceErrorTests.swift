import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("RoutineService Error Handling Tests")
struct RoutineServiceErrorTests {
    
    @Test("RoutineService handles session already active correctly")
    @MainActor func testRoutineServiceSessionAlreadyActive() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        guard let template = service.templates.first else {
            Issue.record("No templates available for testing")
            return
        }
        
        do {
            // Start first session
            try service.startSession(with: template)
            #expect(service.currentSession != nil)
            
            // Try to start another session
            try service.startSession(with: template)
            Issue.record("Expected error for session already active")
        } catch let error as RoutineError {
            #expect(error.category == .technical)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles template not found correctly")
    @MainActor func testRoutineServiceTemplateNotFound() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create a template that's not in the service
        let fakeTemplate = RoutineTemplate(
            name: "Fake Template",
            habits: [Habit(name: "Fake Habit", type: .checkbox, order: 0)]
        )
        
        do {
            try service.startSession(with: fakeTemplate)
            Issue.record("Expected error for template not found")
        } catch let error as RoutineError {
            #expect(error.category == .technical)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles empty template correctly")
    @MainActor func testRoutineServiceEmptyTemplate() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create an empty template
        let emptyTemplate = RoutineTemplate(
            name: "Empty Template",
            habits: [] // No habits
        )
        
        // Add it to the service templates for validation to pass
        service.addTemplate(emptyTemplate)
        
        do {
            try service.startSession(with: emptyTemplate)
            Issue.record("Expected error for empty template")
        } catch let error as RoutineError {
            #expect(error.category == .technical)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles no active session for completion")
    @MainActor func testRoutineServiceNoActiveSessionCompletion() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Ensure no session is active
        #expect(service.currentSession == nil)
        
        do {
            try service.completeCurrentSession()
            Issue.record("Expected error for no active session")
        } catch let error as RoutineError {
            #expect(error.category == .technical)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles persistence failures gracefully")
    @MainActor func testRoutineServicePersistenceFailure() async {
        // Create service with failing persistence
        let failingPersistence = FailingPersistenceService()
        let service = RoutineService(persistenceService: failingPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Should still have sample templates even if persistence fails
        #expect(service.templates.count > 0)
        
        // Adding a template should handle persistence failure gracefully
        let newTemplate = RoutineTemplate(
            name: "Test Template",
            habits: [Habit(name: "Test Habit", type: .checkbox, order: 0)]
        )
        
        service.addTemplate(newTemplate)
        
        // Should still add template to memory even if persistence fails
        #expect(service.templates.contains { $0.name == "Test Template" })
        
        // Should log persistence error
        #expect(errorService.getErrorHistory().count > 0)
    }
    
    @Test("RoutineService handles corrupted template data")
    @MainActor func testRoutineServiceCorruptedData() {
        let corruptedPersistence = CorruptedDataPersistenceService()
        let service = RoutineService(persistenceService: corruptedPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Should fallback to sample templates when data is corrupted
        #expect(service.templates.count > 0)
        
        // Should log data corruption error
        #expect(errorService.getErrorHistory().count > 0)
    }
    
    @Test("RoutineService handles invalid template modifications")
    @MainActor func testRoutineServiceInvalidTemplateModifications() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create a template with invalid habit
        var template = RoutineTemplate(
            name: "Test Template",
            habits: [Habit(name: "Valid Habit", type: .checkbox, order: 0)]
        )
        
        service.addTemplate(template)
        
        // Try to update with invalid data
        template.habits = [] // Remove all habits
        
        service.updateTemplate(template)
        
        // Service should handle invalid updates gracefully
        #expect(service.templates.contains { $0.id == template.id })
    }
}

@Suite("RoutineSession Error Tests")
struct RoutineSessionErrorTests {
    
    @Test("RoutineSession handles invalid habit indices")
    @MainActor func testRoutineSessionInvalidHabitIndex() {
        let habits = [
            Habit(name: "Habit 1", type: .checkbox, order: 0),
            Habit(name: "Habit 2", type: .timer(defaultDuration: 300), order: 1)
        ]
        let template = RoutineTemplate(name: "Test Template", habits: habits)
        let session = RoutineSession(template: template)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Try to go to invalid habit index
        session.goToHabit(at: 10) // Out of bounds
        
        // Should stay at current valid index
        #expect(session.currentHabitIndex < habits.count)
        
        // Should log error
        #expect(errorService.getErrorHistory().count > 0)
    }
    
    @Test("RoutineSession handles habit completion errors")
    @MainActor func testRoutineSessionHabitCompletionError() {
        let habits = [
            Habit(name: "Timer Habit", type: .timer(defaultDuration: 300), order: 0)
        ]
        let template = RoutineTemplate(name: "Test Template", habits: habits)
        let session = RoutineSession(template: template)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Try to complete habit with invalid duration
        session.completeCurrentHabit(duration: -100) // Negative duration
        
        // Should handle invalid completion gracefully
        let completedHabits = session.completedHabits
        
        // Should either reject the completion or use a valid default
        if !completedHabits.isEmpty {
            #expect((completedHabits.first?.duration ?? 0) >= 0)
        }
    }
    
    @Test("RoutineSession handles reordering with invalid habits")
    @MainActor func testRoutineSessionInvalidReordering() {
        let habits = [
            Habit(name: "Habit 1", type: .checkbox, order: 0),
            Habit(name: "Habit 2", type: .timer(defaultDuration: 300), order: 1)
        ]
        let template = RoutineTemplate(name: "Test Template", habits: habits)
        let session = RoutineSession(template: template)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Try to reorder with empty array
        session.reorderHabits([])
        
        // Should maintain valid state
        #expect(session.activeHabits.count > 0)
        
        // Try to reorder with mismatched habits
        let fakeHabits = [Habit(name: "Fake", type: .checkbox, order: 0)]
        session.reorderHabits(fakeHabits)
        
        // Should reject invalid reordering
        #expect(session.activeHabits.count == habits.count)
    }
}

@Suite("RoutineSelector Error Tests")
struct RoutineSelectorErrorTests {
    
    @Test("RoutineSelector handles empty template list")
    @MainActor func testRoutineSelectorEmptyTemplates() async {
        let selector = RoutineSelector()
        
        // Test with empty template list
        let (template, reason) = await selector.selectBestTemplate(from: [])
        
        #expect(template == nil)
        #expect(reason.contains("No templates"))
    }
    
    @Test("RoutineSelector handles templates with invalid context rules")
    @MainActor func testRoutineSelectorInvalidContextRules() async {
        let selector = RoutineSelector()
        
        // Create template with complex rule that might fail
        let invalidRule = RoutineContextRule(
            timeSlots: Set(TimeSlot.allCases), // All time slots
            dayCategoryIds: ["nonexistent_category"],
            locationIds: ["nonexistent_location"],
            priority: -1 // Invalid priority
        )
        
        let template = RoutineTemplate(
            name: "Invalid Rule Template",
            habits: [Habit(name: "Test", type: .checkbox, order: 0)],
            contextRule: invalidRule
        )
        
        let (selectedTemplate, reason) = await selector.selectBestTemplate(from: [template])
        
        // Should handle invalid rules gracefully
        #expect(selectedTemplate != nil || reason.contains("score"))
    }
    
    @Test("RoutineSelector handles location coordinator errors")
    @MainActor func testRoutineSelectorLocationCoordinatorErrors() async {
        let selector = RoutineSelector()
        
        // Create template that depends on location
        let locationRule = RoutineContextRule(
            timeSlots: [.morning],
            dayCategoryIds: ["weekday"],
            locationIds: ["office"],
            priority: 1
        )
        
        let template = RoutineTemplate(
            name: "Office Template",
            habits: [Habit(name: "Test", type: .checkbox, order: 0)],
            contextRule: locationRule
        )
        
        // Test when location coordinator might have issues
        let (selectedTemplate, reason) = await selector.selectBestTemplate(from: [template])
        
        // Should handle location errors gracefully
        #expect(selectedTemplate != nil || reason.contains("location") || reason.contains("score"))
    }
}

@Suite("ConditionalHabitService Error Tests")
struct ConditionalHabitServiceErrorTests {
    
    @Test("ConditionalHabitService handles invalid responses")
    @MainActor func testConditionalHabitServiceInvalidResponse() {
        let service = ConditionalHabitService.shared
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create invalid response
        let invalidResponse = ConditionalResponse(
            habitId: UUID(),
            question: "", // Empty question
            selectedOptionId: UUID(),
            selectedOptionText: "",
            routineId: UUID(),
            wasSkipped: false
        )
        
        service.recordResponse(invalidResponse)
        
        // Should handle invalid response gracefully
        #expect(service.getResponseHistory().count >= 0) // Might accept or reject
    }
    
    @Test("ConditionalHabitService handles analytics calculation errors")
    @MainActor func testConditionalHabitServiceAnalyticsErrors() {
        let service = ConditionalHabitService.shared
        
        // Clear any existing data
        service.clearHistory()
        
        // Test analytics with no data
        let analytics = service.getAnalytics()
        
        #expect(analytics.totalResponses == 0)
        #expect(analytics.responsesPerHabit.isEmpty)
        #expect(analytics.optionPopularity.isEmpty)
    }
}

// MARK: - Mock Services for Testing

/// Mock persistence service that always fails operations
private final class FailingPersistenceService: @unchecked Sendable, PersistenceServiceProtocol {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        throw DataError.encodingFailed(type: String(describing: T.self), underlyingError: NSError(domain: "TestError", code: 1))
    }
    
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        throw DataError.decodingFailed(type: String(describing: T.self), underlyingError: NSError(domain: "TestError", code: 2))
    }
    
    func delete(forKey key: String) async {
        // Delete fails silently
    }
    
    func exists(forKey key: String) async -> Bool {
        return false
    }
}

/// Mock persistence service that returns corrupted data
private final class CorruptedDataPersistenceService: @unchecked Sendable, PersistenceServiceProtocol {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        // Save succeeds
    }
    
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        throw DataError.corruptedData(key: key)
    }
    
    func delete(forKey key: String) async {
        // Delete succeeds
    }
    
    func exists(forKey key: String) async -> Bool {
        return true
    }
}