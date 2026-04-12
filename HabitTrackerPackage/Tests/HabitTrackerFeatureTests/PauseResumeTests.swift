import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Pause & Resume Tests")
struct PauseResumeTests {

    private func createTestTemplate() -> RoutineTemplate {
        let habits = [
            Habit(name: "Habit 1", type: .task(subtasks: []), order: 0),
            Habit(name: "Habit 2", type: .timer(style: .down, duration: 120), order: 1),
            Habit(name: "Habit 3", type: .task(subtasks: []), order: 2),
            Habit(name: "Habit 4", type: .task(subtasks: []), order: 3)
        ]
        return RoutineTemplate(name: "Test Routine", habits: habits)
    }

    // MARK: - Pause Tests

    @Test("Pausing creates snapshot and clears currentSession")
    @MainActor func pauseCreatesSnapshot() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)

        #expect(service.currentSession != nil)
        #expect(service.pausedSessions.isEmpty)

        try service.pauseCurrentSession()

        #expect(service.currentSession == nil)
        #expect(service.pausedSessions.count == 1)
        #expect(service.pausedSessions.first?.template.id == template.id)
    }

    @Test("Pause with no active session throws")
    @MainActor func pauseWithNoSession() {
        let service = RoutineService()

        #expect(throws: RoutineError.self) {
            try service.pauseCurrentSession()
        }
    }

    @Test("Paused snapshot preserves progress")
    @MainActor func pausePreservesProgress() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)

        // Complete 2 habits
        service.currentSession?.completeCurrentHabit()
        service.currentSession?.completeCurrentHabit()

        #expect(service.currentSession?.currentHabitIndex == 2)
        #expect(service.currentSession?.completions.count == 2)

        try service.pauseCurrentSession()

        let snapshot = try #require(service.pausedSessions.first)
        #expect(snapshot.currentHabitIndex == 2)
        #expect(snapshot.completions.count == 2)
        #expect(snapshot.completedCount == 2)
        #expect(snapshot.totalCount == 4)
        #expect(abs(snapshot.progress - 0.5) < 0.01)
    }

    // MARK: - Resume Tests

    @Test("Resume restores session state")
    @MainActor func resumeRestoresState() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)

        // Complete 2 habits then pause
        service.currentSession?.completeCurrentHabit()
        service.currentSession?.completeCurrentHabit()
        let originalId = service.currentSession?.id

        try service.pauseCurrentSession()
        let snapshotId = try #require(service.pausedSessions.first?.id)

        try service.resumeSession(withId: snapshotId)

        #expect(service.currentSession != nil)
        #expect(service.currentSession?.id == originalId)
        #expect(service.currentSession?.currentHabitIndex == 2)
        #expect(service.currentSession?.completions.count == 2)
        #expect(service.pausedSessions.isEmpty)
    }

    @Test("Resume auto-pauses current session")
    @MainActor func resumeAutoPauses() throws {
        let service = RoutineService()
        let template1 = createTestTemplate()
        var template2 = createTestTemplate()
        template2 = RoutineTemplate(name: "Second Routine", habits: template1.habits)

        service.addTemplate(template1)
        service.addTemplate(template2)

        // Start and pause first routine
        try service.startSession(with: template1)
        service.currentSession?.completeCurrentHabit()
        try service.pauseCurrentSession()

        // Start second routine
        try service.startSession(with: template2)
        service.currentSession?.completeCurrentHabit()
        service.currentSession?.completeCurrentHabit()

        let pausedId = try #require(service.pausedSessions.first?.id)

        // Resume first — should auto-pause second
        try service.resumeSession(withId: pausedId)

        #expect(service.currentSession?.template.name == "Test Routine")
        #expect(service.currentSession?.completions.count == 1)
        #expect(service.pausedSessions.count == 1)
        #expect(service.pausedSessions.first?.template.name == "Second Routine")
        #expect(service.pausedSessions.first?.completions.count == 2)
    }

    @Test("Resume with invalid ID throws")
    @MainActor func resumeInvalidId() {
        let service = RoutineService()

        #expect(throws: RoutineError.self) {
            try service.resumeSession(withId: UUID())
        }
    }

    // MARK: - Discard Tests

    @Test("Discard removes paused session")
    @MainActor func discardRemoves() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)
        try service.pauseCurrentSession()

        #expect(service.pausedSessions.count == 1)
        let snapshotId = try #require(service.pausedSessions.first?.id)

        service.discardPausedSession(withId: snapshotId)

        #expect(service.pausedSessions.isEmpty)
    }

    // MARK: - Snapshot Codable Tests

    @Test("PausedSessionSnapshot round-trips through Codable")
    @MainActor func snapshotCodable() throws {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        session.completeCurrentHabit()
        session.completeCurrentHabit()

        let snapshot = session.toPausedSnapshot()

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PausedSessionSnapshot.self, from: data)

        #expect(decoded.id == snapshot.id)
        #expect(decoded.templateId == snapshot.templateId)
        #expect(decoded.currentHabitIndex == snapshot.currentHabitIndex)
        #expect(decoded.completions.count == snapshot.completions.count)
        #expect(decoded.totalCount == snapshot.totalCount)
        #expect(decoded.completedCount == snapshot.completedCount)
    }

    // MARK: - Duration Tests

    @Test("Duration includes prior active time after resume")
    @MainActor func durationIncludesPriorTime() throws {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)

        // Simulate some active time via snapshot
        let snapshot = PausedSessionSnapshot(
            id: session.id,
            templateId: template.id,
            template: template,
            startedAt: Date().addingTimeInterval(-600),
            pausedAt: Date().addingTimeInterval(-300),
            currentHabitIndex: 1,
            completions: [],
            modifications: [],
            activeHabitsSnapshot: template.habits,
            accumulatedActiveTime: 300 // 5 minutes of active time
        )

        let restored = RoutineSession(from: snapshot)

        // Duration should be priorActiveTime + time since segmentStartedAt
        // priorActiveTime is 300, segmentStartedAt is ~now, so duration ≈ 300
        #expect(restored.duration >= 300)
        #expect(restored.duration < 310) // small tolerance for test execution time
    }

    // MARK: - Multiple Paused Sessions

    // MARK: - Timer State Tests

    @Test("Paused snapshot preserves timer state for multiple-timer habit")
    @MainActor func pausePreservesMultipleTimerState() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)

        // Simulate timer progress on the second habit (which is a multiple-timer)
        let timerHabitId = template.habits[1].id
        let timerState = TimerHabitState(
            timeRemaining: 45,
            timeElapsed: 75,
            currentStepIndex: 1,
            currentRound: 2,
            totalElapsed: 75
        )
        service.currentSession?.updateTimerState(habitId: timerHabitId, state: timerState)

        try service.pauseCurrentSession()

        let snapshot = try #require(service.pausedSessions.first)
        let saved = try #require(snapshot.timerStates[timerHabitId.uuidString])
        #expect(saved.timeRemaining == 45)
        #expect(saved.currentStepIndex == 1)
        #expect(saved.currentRound == 2)
        #expect(saved.totalElapsed == 75)
    }

    @Test("Resumed session restores timer state for multiple-timer habit")
    @MainActor func resumeRestoresMultipleTimerState() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)

        let timerHabitId = template.habits[1].id
        let timerState = TimerHabitState(
            timeRemaining: 45,
            timeElapsed: 75,
            currentStepIndex: 1,
            currentRound: 2,
            totalElapsed: 75
        )
        service.currentSession?.updateTimerState(habitId: timerHabitId, state: timerState)

        try service.pauseCurrentSession()
        let snapshotId = try #require(service.pausedSessions.first?.id)
        try service.resumeSession(withId: snapshotId)

        let restored = try #require(service.currentSession?.timerStates[timerHabitId.uuidString])
        #expect(restored.timeRemaining == 45)
        #expect(restored.currentStepIndex == 1)
        #expect(restored.currentRound == 2)
        #expect(restored.totalElapsed == 75)
    }

    @Test("Timer state is absent when no timer was started before pause")
    @MainActor func pauseWithNoTimerStateHasEmptyTimerStates() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)
        try service.startSession(with: template)
        try service.pauseCurrentSession()

        let snapshot = try #require(service.pausedSessions.first)
        #expect(snapshot.timerStates.isEmpty)
    }

    @Test("PausedSessionSnapshot Codable round-trip preserves timer state")
    @MainActor func snapshotCodableWithTimerState() throws {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        let habitId = template.habits[1].id
        session.updateTimerState(
            habitId: habitId,
            state: TimerHabitState(timeRemaining: 30, timeElapsed: 90, currentStepIndex: 2, currentRound: 3, totalElapsed: 90)
        )

        let snapshot = session.toPausedSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PausedSessionSnapshot.self, from: data)

        let restoredState = try #require(decoded.timerStates[habitId.uuidString])
        #expect(restoredState.timeRemaining == 30)
        #expect(restoredState.currentStepIndex == 2)
        #expect(restoredState.currentRound == 3)
    }

    @Test("Old snapshot without timerStates decodes without error (backward compat)")
    @MainActor func oldSnapshotDecodesWithoutTimerStates() throws {
        let template = createTestTemplate()
        // Build a JSON payload without the timerStates key to simulate old persisted data
        let oldJson = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "templateId": "\(template.id.uuidString)",
          "template": \(String(data: try JSONEncoder().encode(template), encoding: .utf8)!),
          "startedAt": 0,
          "pausedAt": 100,
          "currentHabitIndex": 1,
          "completions": [],
          "modifications": [],
          "activeHabitsSnapshot": [],
          "accumulatedActiveTime": 60
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(PausedSessionSnapshot.self, from: Data(oldJson.utf8))
        #expect(decoded.timerStates.isEmpty)
        #expect(decoded.currentHabitIndex == 1)
    }

    // MARK: - Multiple Paused Sessions

    @Test("Multiple sessions can be paused for same template")
    @MainActor func multiplePausedSameTemplate() throws {
        let service = RoutineService()
        let template = createTestTemplate()
        service.addTemplate(template)

        // First session: complete 1 habit, pause
        try service.startSession(with: template)
        service.currentSession?.completeCurrentHabit()
        try service.pauseCurrentSession()

        // Second session: complete 2 habits, pause
        try service.startSession(with: template)
        service.currentSession?.completeCurrentHabit()
        service.currentSession?.completeCurrentHabit()
        try service.pauseCurrentSession()

        #expect(service.pausedSessions.count == 2)
        #expect(service.pausedSessions[0].completions.count == 1)
        #expect(service.pausedSessions[1].completions.count == 2)
    }
}
