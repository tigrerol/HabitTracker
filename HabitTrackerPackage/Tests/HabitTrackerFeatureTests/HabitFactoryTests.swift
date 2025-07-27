import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Habit Factory Tests")
struct HabitFactoryTests {
    
    @Test("HabitFactory creates office morning routine correctly")
    @MainActor func testOfficeRoutineCreation() {
        let template = HabitFactory.createOfficeTemplate()
        
        #expect(template.name == "Office Day")
        #expect(template.color == "#007AFF")
        #expect(template.isDefault == false)
        #expect(!template.habits.isEmpty)
        
        // Check specific habits are present
        let habitNames = Set(template.habits.map { $0.name })
        #expect(habitNames.contains("HRV Check"))
        #expect(habitNames.contains("Strength Training"))
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Shower"))
        #expect(habitNames.contains("Prepare Workspace"))
        
        // Check habit ordering
        let sortedHabits = template.habits.sorted { $0.order < $1.order }
        #expect(sortedHabits.first?.name == "HRV Check")
        #expect(sortedHabits.first?.order == AppConstants.HabitOrder.hrv)
    }
    
    @Test("HabitFactory creates home office routine correctly")
    @MainActor func testHomeOfficeRoutineCreation() {
        let template = HabitFactory.createHomeOfficeTemplate()
        
        #expect(template.name == "Home Office")
        #expect(template.color == "#34C759")
        #expect(template.isDefault == true)
        #expect(!template.habits.isEmpty)
        
        // Check specific habits
        let habitNames = Set(template.habits.map { $0.name })
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Prepare Workspace"))
        
        // Verify context rules
        #expect(!template.contextRules.isEmpty)
        let locationRule = template.contextRules.first { $0.type == .location }
        #expect(locationRule?.locationCategory == .homeOffice)
        #expect(locationRule?.priority == AppConstants.Routine.homeOfficePriority)
    }
    
    @Test("HabitFactory creates weekend routine correctly")
    @MainActor func testWeekendRoutineCreation() {
        let template = HabitFactory.createWeekendTemplate()
        
        #expect(template.name == "Weekend")
        #expect(template.color == "#FF9500")
        #expect(template.isDefault == false)
        #expect(!template.habits.isEmpty)
        
        // Check weekend-specific habits
        let habitNames = Set(template.habits.map { $0.name })
        #expect(habitNames.contains("Coffee"))
        #expect(habitNames.contains("Supplements"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Read News"))
        
        // Verify context rules for weekend
        #expect(!template.contextRules.isEmpty)
        let timeRule = template.contextRules.first { $0.type == .timeSlot }
        #expect(timeRule?.timeSlots?.contains(.weekend) == true)
        #expect(timeRule?.priority == AppConstants.Routine.weekendPriority)
    }
    
    @Test("HabitFactory creates afternoon routine correctly")
    @MainActor func testAfternoonRoutineCreation() {
        let template = HabitFactory.createAfternoonTemplate()
        
        #expect(template.name == "Afternoon Break")
        #expect(template.color == "#FF3B30")
        #expect(template.isDefault == false)
        #expect(!template.habits.isEmpty)
        
        // Check afternoon-specific habits
        let habitNames = Set(template.habits.map { $0.name })
        #expect(habitNames.contains("Goals Review"))
        #expect(habitNames.contains("Stretching"))
        #expect(habitNames.contains("Healthy Snack"))
        #expect(habitNames.contains("Focus Time"))
        #expect(habitNames.contains("Evening Planning"))
        
        // Verify ordering
        let goalsHabit = template.habits.first { $0.name == "Goals Review" }
        #expect(goalsHabit?.order == AppConstants.HabitOrder.goalsReview)
        
        // Verify context rules
        let timeRule = template.contextRules.first { $0.type == .timeSlot }
        #expect(timeRule?.timeSlots?.contains(.afternoonWeekday) == true)
        #expect(timeRule?.priority == AppConstants.Routine.afternoonPriority)
    }
    
    @Test("HabitFactory creates pain assessment conditional habit correctly")
    @MainActor func testPainAssessmentCreation() {
        let habit = HabitFactory.createPainAssessmentHabit()
        
        #expect(habit.name == "Pain Assessment")
        #expect(habit.color == "#FF9500")
        
        // Check conditional type
        if case .conditional(let info) = habit.type {
            #expect(info.question.contains("pain"))
            #expect(info.options.count == 4)
            
            // Check specific options
            let optionTexts = Set(info.options.map { $0.text })
            #expect(optionTexts.contains("Shoulder"))
            #expect(optionTexts.contains("Knee"))
            #expect(optionTexts.contains("Back"))
            #expect(optionTexts.contains("None"))
            
            // Check that options have appropriate sub-habits
            let shoulderOption = info.options.first { $0.text == "Shoulder" }
            #expect(shoulderOption?.habits.count == 2)
            #expect(shoulderOption?.habits.contains { $0.name.contains("Shoulder") } == true)
            
            let noneOption = info.options.first { $0.text == "None" }
            #expect(noneOption?.habits.isEmpty == true)
        } else {
            Issue.record("Pain assessment habit should be conditional type")
        }
    }
    
    @Test("HabitFactory creates all default templates")
    @MainActor func testAllDefaultTemplates() {
        let templates = HabitFactory.createDefaultTemplates()
        
        #expect(templates.count >= 4)
        
        let templateNames = Set(templates.map { $0.name })
        #expect(templateNames.contains("Office Day"))
        #expect(templateNames.contains("Home Office"))
        #expect(templateNames.contains("Weekend"))
        #expect(templateNames.contains("Afternoon Break"))
        
        // Verify one default template exists
        let defaultTemplates = templates.filter { $0.isDefault }
        #expect(defaultTemplates.count == 1)
        #expect(defaultTemplates.first?.name == "Home Office")
    }
    
    @Test("HabitFactory creates habits with correct types")
    @MainActor func testHabitTypes() {
        let templates = HabitFactory.createDefaultTemplates()
        let allHabits = templates.flatMap { $0.habits }
        
        // Check that we have different habit types
        let hasCheckbox = allHabits.contains { $0.type.isCheckbox }
        let hasTimer = allHabits.contains { $0.type.isTimer }
        let hasConditional = allHabits.contains { $0.type.isConditional }
        
        #expect(hasCheckbox == true)
        #expect(hasTimer == true)
        #expect(hasConditional == true)
        
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
        let templates = HabitFactory.createDefaultTemplates()
        let allHabits = templates.flatMap { $0.habits }
        let habitIds = allHabits.map { $0.id }
        let uniqueIds = Set(habitIds)
        
        #expect(habitIds.count == uniqueIds.count)
    }
    
    @Test("HabitFactory creates valid habit colors")
    @MainActor func testHabitColors() {
        let templates = HabitFactory.createDefaultTemplates()
        let allHabits = templates.flatMap { $0.habits }
        
        for habit in allHabits {
            #expect(habit.color.hasPrefix("#"))
            #expect(habit.color.count == 7) // #RRGGBB format
        }
    }
    
    @Test("HabitFactory creates habits with valid ordering")
    @MainActor func testHabitOrdering() {
        let template = HabitFactory.createOfficeTemplate()
        let habits = template.habits.sorted { $0.order < $1.order }
        
        // Check that orders are sequential or properly spaced
        for i in 0..<habits.count - 1 {
            #expect(habits[i].order <= habits[i + 1].order)
        }
        
        // Check specific order values match constants
        let hrvHabit = habits.first { $0.name == "HRV Check" }
        #expect(hrvHabit?.order == AppConstants.HabitOrder.hrv)
        
        let strengthHabit = habits.first { $0.name == "Strength Training" }
        #expect(strengthHabit?.order == AppConstants.HabitOrder.strength)
    }
}

@Suite("Habit Type Extension Tests")  
struct HabitTypeExtensionTests {
    
    @Test("HabitType isCheckbox works correctly")
    func testIsCheckbox() {
        #expect(HabitType.checkbox.isCheckbox == true)
        #expect(HabitType.timer(defaultDuration: 300).isCheckbox == false)
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isCheckbox == false)
    }
    
    @Test("HabitType isTimer works correctly")
    func testIsTimer() {
        #expect(HabitType.timer(defaultDuration: 300).isTimer == true)
        #expect(HabitType.checkbox.isTimer == false)
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isTimer == false)
    }
    
    @Test("HabitType isConditional works correctly")
    func testIsConditional() {
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).isConditional == true)
        #expect(HabitType.checkbox.isConditional == false)
        #expect(HabitType.timer(defaultDuration: 300).isConditional == false)
    }
    
    @Test("HabitType descriptions are appropriate")
    func testDescriptions() {
        #expect(HabitType.checkbox.description == "Checkbox")
        #expect(HabitType.timer(defaultDuration: 300).description == "Timer (5:00)")
        
        let option = ConditionalOption(text: "Option 1", habits: [])
        let info = ConditionalHabitInfo(question: "Test?", options: [option])
        #expect(HabitType.conditional(info).description == "1 options")
    }
    
    @Test("HabitType iconNames are appropriate")
    func testIconNames() {
        #expect(HabitType.checkbox.iconName == "checkmark.square")
        #expect(HabitType.timer(defaultDuration: 300).iconName == "timer")
        
        let info = ConditionalHabitInfo(question: "Test?", options: [])
        #expect(HabitType.conditional(info).iconName == "questionmark.circle")
    }
}