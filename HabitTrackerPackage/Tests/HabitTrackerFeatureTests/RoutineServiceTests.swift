import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Routine Service Tests")
struct RoutineServiceTests {
    
    @Test("Service initializes with sample templates")
    @MainActor func serviceInitialization() {
        let service = RoutineService()
        
        #expect(!service.templates.isEmpty)
        #expect(service.templates.count >= 3)
        #expect(service.templates.contains { $0.name == "Office Day" })
        #expect(service.templates.contains { $0.name == "Home Office" })
        #expect(service.templates.contains { $0.name == "Weekend" })
    }
    
    @Test("Default template is correctly identified")
    @MainActor func defaultTemplate() {
        let service = RoutineService()
        
        let defaultTemplate = service.defaultTemplate
        #expect(defaultTemplate != nil)
        #expect(defaultTemplate?.name == "Home Office")
        #expect(defaultTemplate?.isDefault == true)
    }
    
    @Test("Starting a session creates active session")
    @MainActor func startSession() {
        let service = RoutineService()
        guard let template = service.templates.first else {
            Issue.record("No templates available")
            return
        }
        
        #expect(service.currentSession == nil)
        
        service.startSession(with: template)
        
        #expect(service.currentSession != nil)
        #expect(service.currentSession?.template.id == template.id)
    }
    
    @Test("Completing session clears current session")
    @MainActor func completeSession() {
        let service = RoutineService()
        guard let template = service.templates.first else {
            Issue.record("No templates available")
            return
        }
        
        service.startSession(with: template)
        #expect(service.currentSession != nil)
        
        service.completeCurrentSession()
        #expect(service.currentSession == nil)
    }
    
    @Test("Mood rating is stored correctly")
    @MainActor func moodRating() {
        let service = RoutineService()
        let sessionId = UUID()
        
        #expect(service.moodRatings.isEmpty)
        
        service.addMoodRating(.good, for: sessionId, notes: "Great morning!")
        
        #expect(service.moodRatings.count == 1)
        #expect(service.moodRatings.first?.sessionId == sessionId)
        #expect(service.moodRatings.first?.rating == .good)
        #expect(service.moodRatings.first?.notes == "Great morning!")
    }
}