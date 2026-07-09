import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Routine Service Tests")
struct RoutineServiceTests {

    /// Fresh service on an isolated UserDefaults suite (no cross-test pollution),
    /// awaited until the async init load has created the sample templates.
    @MainActor
    private func makeFreshService() async throws -> RoutineService {
        let suiteName = "test-routine-service-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let service = RoutineService(persistenceService: UserDefaultsPersistenceService(userDefaults: defaults))
        await service.ensureLoaded()
        return service
    }

    @Test("Service initializes with sample templates")
    @MainActor func serviceInitialization() async throws {
        let service = try await makeFreshService()

        #expect(!service.templates.isEmpty)
        #expect(service.templates.count >= 3)
        #expect(service.templates.contains { $0.name == "Office Day" })
        #expect(service.templates.contains { $0.name == "Home Office" })
        #expect(service.templates.contains { $0.name == "Weekend" })
    }

    @Test("Sample templates have no default routine; setting one is reflected")
    @MainActor func defaultTemplate() async throws {
        let service = try await makeFreshService()

        // No sample template is marked default; the smart selector picks instead
        #expect(service.defaultTemplate == nil)

        var template = try #require(service.templates.first)
        template.isDefault = true
        service.updateTemplate(template)

        #expect(service.defaultTemplate?.id == template.id)
    }

    @Test("Starting a session creates active session")
    @MainActor func startSession() async throws {
        let service = try await makeFreshService()
        let template = try #require(service.templates.first)

        #expect(service.currentSession == nil)

        try service.startSession(with: template)

        #expect(service.currentSession != nil)
        #expect(service.currentSession?.template.id == template.id)
    }

    @Test("Completing session clears current session")
    @MainActor func completeSession() async throws {
        let service = try await makeFreshService()
        let template = try #require(service.templates.first)

        try service.startSession(with: template)
        #expect(service.currentSession != nil)

        try service.completeCurrentSession()
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
