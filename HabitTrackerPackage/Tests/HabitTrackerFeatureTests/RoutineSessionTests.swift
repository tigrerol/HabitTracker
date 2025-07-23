import Testing
@testable import HabitTrackerFeature

@Suite("Routine Session Tests")
struct RoutineSessionTests {
    
    private func createTestTemplate() -> RoutineTemplate {
        let habits = [
            Habit(name: "Test Habit 1", type: .checkbox, order: 0),
            Habit(name: "Test Habit 2", type: .timer(defaultDuration: 300), order: 1),
            Habit(name: "Test Habit 3", type: .checkbox, order: 2)
        ]
        
        return RoutineTemplate(
            name: "Test Template",
            habits: habits
        )
    }
    
    @Test("Session initializes correctly")
    func sessionInitialization() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        #expect(session.template.id == template.id)
        #expect(session.currentHabitIndex == 0)
        #expect(session.completions.isEmpty)
        #expect(session.isCompleted == false)
        #expect(session.progress == 0.0)
    }
    
    @Test("Current habit is correctly identified")
    func currentHabit() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        #expect(session.currentHabit?.name == "Test Habit 1")
        #expect(session.currentHabit?.order == 0)
    }
    
    @Test("Completing habit advances to next")
    func completeHabit() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        #expect(session.currentHabitIndex == 0)
        #expect(session.completions.count == 0)
        
        session.completeCurrentHabit()
        
        #expect(session.currentHabitIndex == 1)
        #expect(session.completions.count == 1)
        #expect(session.currentHabit?.name == "Test Habit 2")
    }
    
    @Test("Skipping habit is recorded correctly")
    func skipHabit() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        session.skipCurrentHabit(reason: "Not feeling it today")
        
        #expect(session.completions.count == 1)
        #expect(session.completions.first?.isSkipped == true)
        #expect(session.completions.first?.notes == "Not feeling it today")
        #expect(session.currentHabitIndex == 1)
    }
    
    @Test("Progress calculation is accurate")
    func progressCalculation() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        #expect(session.progress == 0.0)
        
        session.completeCurrentHabit()
        #expect(session.progress ≈ 0.333, within: 0.01)
        
        session.completeCurrentHabit()
        #expect(session.progress ≈ 0.666, within: 0.01)
        
        session.completeCurrentHabit()
        #expect(session.progress == 1.0)
        #expect(session.isCompleted == true)
    }
    
    @Test("Going to previous habit works correctly")
    func goToPreviousHabit() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        // Complete first habit
        session.completeCurrentHabit()
        #expect(session.currentHabitIndex == 1)
        #expect(session.completions.count == 1)
        
        // Go back to previous
        session.goToPreviousHabit()
        #expect(session.currentHabitIndex == 0)
        #expect(session.completions.isEmpty) // Completion should be removed
    }
    
    @Test("Session duration is tracked")
    func sessionDuration() {
        let template = createTestTemplate()
        let session = RoutineSession(template: template)
        
        // Duration should be minimal right after creation
        #expect(session.duration < 1.0)
        
        // Complete all habits to finish session
        for _ in 0..<3 {
            session.completeCurrentHabit()
        }
        
        #expect(session.isCompleted == true)
        #expect(session.duration >= 0.0)
    }
}