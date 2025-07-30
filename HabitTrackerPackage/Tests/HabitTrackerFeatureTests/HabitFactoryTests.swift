import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Habit Factory Tests")
struct HabitFactoryTests {
    
    @Test("HabitFactory creates office morning routine correctly")
    @MainActor func testOfficeRoutineCreation() {
        let habits = HabitFactory.createOfficeMorningHabits()
        
        #expect(!habits.isEmpty)
        
        // Check specific habits are present
        let habitNames = Set(habits.map { $0.name })
        #expect(habitNames.contains("Measure HRV"))
        #expect(habitNames.contains("Strength Training"))
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Shower"))
        
        // Check habit ordering
        let sortedHabits = habits.sorted { $0.order < $1.order }
        #expect(sortedHabits.first?.name == "Measure HRV")
        #expect(sortedHabits.first?.order == AppConstants.HabitOrder.hrv)
    }
    
    @Test("HabitFactory creates home office routine correctly")
    @MainActor func testHomeOfficeRoutineCreation() {
        let habits = HabitFactory.createHomeOfficeHabits()
        
        #expect(!habits.isEmpty)
        
        // Check specific habits
        let habitNames = Set(habits.map { $0.name })
        #expect(habitNames.contains("Measure HRV"))
        #expect(habitNames.contains("Strength Training"))
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Shower"))
        #expect(habitNames.contains("Prep Workspace"))
    }
    
    @Test("HabitFactory creates weekend routine correctly")
    @MainActor func testWeekendRoutineCreation() {
        let habits = HabitFactory.createWeekendHabits()
        
        #expect(!habits.isEmpty)
        
        // Check weekend-specific habits
        let habitNames = Set(habits.map { $0.name })
        #expect(habitNames.contains("Measure HRV"))
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Long Stretching"))
        #expect(habitNames.contains("Read News"))
    }
    
    @Test("HabitFactory creates afternoon routine correctly")
    @MainActor func testAfternoonRoutineCreation() {
        let habits = HabitFactory.createAfternoonHabits()
        
        #expect(!habits.isEmpty)
        
        // Check afternoon-specific habits
        let habitNames = Set(habits.map { $0.name })
        #expect(habitNames.contains("Review Daily Goals"))
        #expect(habitNames.contains("Afternoon Stretch"))
        #expect(habitNames.contains("Healthy Snack"))
        #expect(habitNames.contains("Focus Time"))
        #expect(habitNames.contains("Evening Planning"))
        
        // Verify ordering
        let goalsHabit = habits.first { $0.name == "Review Daily Goals" }
        #expect(goalsHabit?.order == AppConstants.HabitOrder.goalsReview)
    }
    
    @Test("HabitFactory creates habits with proper content")
    @MainActor func testHabitContent() {
        let officeHabits = HabitFactory.createOfficeMorningHabits()
        let homeOfficeHabits = HabitFactory.createHomeOfficeHabits()
        let weekendHabits = HabitFactory.createWeekendHabits()
        let afternoonHabits = HabitFactory.createAfternoonHabits()
        
        // All should have content
        #expect(!officeHabits.isEmpty)
        #expect(!homeOfficeHabits.isEmpty)
        #expect(!weekendHabits.isEmpty)
        #expect(!afternoonHabits.isEmpty)
        
        // Check that habits have valid names and colors
        for habit in officeHabits + homeOfficeHabits + weekendHabits + afternoonHabits {
            #expect(!habit.name.isEmpty)
            #expect(habit.color.hasPrefix("#"))
            #expect(habit.color.count == 7) // #RRGGBB format
        }
    }
    
    @Test("HabitFactory creates habits with correct types")
    @MainActor func testHabitTypes() {
        let allHabits = HabitFactory.createOfficeMorningHabits() + 
                       HabitFactory.createHomeOfficeHabits() + 
                       HabitFactory.createWeekendHabits() + 
                       HabitFactory.createAfternoonHabits()
        
        // Check that we have different habit types
        let hasTask = allHabits.contains { $0.type.isTask }
        let hasTimer = allHabits.contains { $0.type.isTimer }
        let hasAppLaunch = allHabits.contains { 
            if case .appLaunch = $0.type { return true }
            return false
        }
        let hasWebsite = allHabits.contains {
            if case .website = $0.type { return true }
            return false
        }
        
        #expect(hasTask == true)
        #expect(hasTimer == true)
        #expect(hasAppLaunch == true)
        #expect(hasWebsite == true)
        
        // Check timer durations are reasonable
        let timerHabits = allHabits.filter { $0.type.isTimer }
        for habit in timerHabits {
            if case .timer(let duration) = habit.type {
                #expect(duration > 0)
                #expect(duration <= 3600) // Max 1 hour
            }
        }
    }
    
    @Test("HabitFactory creates unique habit IDs")
    @MainActor func testUniqueHabitIDs() {
        let allHabits = HabitFactory.createOfficeMorningHabits() + 
                       HabitFactory.createHomeOfficeHabits() + 
                       HabitFactory.createWeekendHabits() + 
                       HabitFactory.createAfternoonHabits()
        let habitIds = allHabits.map { $0.id }
        let uniqueIds = Set(habitIds)
        
        #expect(habitIds.count == uniqueIds.count)
    }
    
    @Test("HabitFactory creates habits with valid ordering")
    @MainActor func testHabitOrdering() {
        let habits = HabitFactory.createOfficeMorningHabits().sorted { $0.order < $1.order }
        
        // Check that orders are sequential or properly spaced
        for i in 0..<habits.count - 1 {
            #expect(habits[i].order <= habits[i + 1].order)
        }
        
        // Check specific order values match constants
        let hrvHabit = habits.first { $0.name == "Measure HRV" }
        #expect(hrvHabit?.order == AppConstants.HabitOrder.hrv)
        
        let strengthHabit = habits.first { $0.name == "Strength Training" }
        #expect(strengthHabit?.order == AppConstants.HabitOrder.strength)
    }
}

@Suite("Habit Type Extension Tests")  
struct HabitTypeExtensionTests {
    
    @Test("HabitType isTask works correctly")
    func testIsTask() {
        #expect(HabitType.task(subtasks: []).isTask == true)
        #expect(HabitType.timer(defaultDuration: 300).isTask == false)
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isTask == false)
    }
    
    @Test("HabitType isTimer works correctly")
    func testIsTimer() {
        #expect(HabitType.timer(defaultDuration: 300).isTimer == true)
        #expect(HabitType.task(subtasks: []).isTimer == false)
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isTimer == false)
    }
    
    @Test("HabitType isConditional works correctly")
    func testIsConditional() {
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isConditional == true)
        #expect(HabitType.task(subtasks: []).isConditional == false)
        #expect(HabitType.timer(defaultDuration: 300).isConditional == false)
    }
    
    @Test("HabitType descriptions are appropriate")
    func testDescriptions() {
        #expect(HabitType.task(subtasks: []).description == "Task")
        #expect(HabitType.timer(defaultDuration: 300).description == "Timer (5:00)")
        
        let option = ConditionalOption(text: "Option 1", habits: [])
        let info = ConditionalHabitInfo(question: "Test?", options: [option])
        #expect(HabitType.conditional(info).description == "1 options")
    }
    
    @Test("HabitType iconNames are appropriate")
    func testIconNames() {
        #expect(HabitType.task(subtasks: []).iconName == "checkmark.square")
        #expect(HabitType.timer(defaultDuration: 300).iconName == "timer")
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).iconName == "questionmark.circle")
    }
}