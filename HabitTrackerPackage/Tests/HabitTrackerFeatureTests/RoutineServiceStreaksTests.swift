import Testing
import Foundation
@testable import HabitTrackerFeature

/// Stub persistence service that returns a fixed session list per template id.
private actor StubPersistence: PersistenceServiceProtocol {
    var templates: [RoutineTemplate] = []
    var sessionsByTemplate: [UUID: [RoutineSessionData]] = [:]

    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        if key == PersistenceKeys.routineTemplates, let t = object as? [RoutineTemplate] {
            templates = t
        }
    }
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        if key == PersistenceKeys.routineTemplates { return templates as? T }
        return nil
    }
    func delete(forKey key: String) async {}
    func exists(forKey key: String) async -> Bool { true }

    func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData] {
        sessionsByTemplate[templateId] ?? []
    }

    func saveRoutineSession(_ session: RoutineSessionData, for templateId: UUID) async {
        var existing = sessionsByTemplate[templateId] ?? []
        existing.append(session)
        sessionsByTemplate[templateId] = existing
    }

    func setTemplates(_ t: [RoutineTemplate]) { templates = t }
    func setSessions(_ s: [RoutineSessionData], for id: UUID) { sessionsByTemplate[id] = s }
}

@Suite("RoutineService streak integration")
struct RoutineServiceStreaksTests {

    @MainActor
    @Test func computeStreaksReturnsOnlyRoutinesWithTarget() async throws {
        let stub = StubPersistence()
        let tracked = RoutineTemplate(name: "Tracked", habits: [Habit(name: "x", type: .task(subtasks: []))], weeklyTarget: 3)
        let untracked = RoutineTemplate(name: "Untracked", habits: [Habit(name: "y", type: .task(subtasks: []))])
        await stub.setTemplates([tracked, untracked])
        let service = RoutineService(persistenceService: stub)
        // Let the async loader finish.
        try await Task.sleep(for: .milliseconds(50))

        let streaks = await service.computeStreaks(now: Date())
        #expect(streaks.count == 1)
        #expect(streaks.first?.template.id == tracked.id)
    }
}
