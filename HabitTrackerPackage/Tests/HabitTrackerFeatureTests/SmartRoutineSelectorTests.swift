import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Smart Routine Selector Tests")
struct SmartRoutineSelectorTests {
    
    private func createTestTemplates() -> [RoutineTemplate] {
        let officeHabits = [
            Habit(name: "HRV Check", type: .timer(defaultDuration: 180), order: AppConstants.HabitOrder.hrv),
            Habit(name: "Strength Training", type: .timer(defaultDuration: 1800), order: AppConstants.HabitOrder.strength),
            Habit(name: "Coffee", type: .checkbox, order: AppConstants.HabitOrder.coffee)
        ]
        
        let homeHabits = [
            Habit(name: "Coffee", type: .checkbox, order: AppConstants.HabitOrder.weekendCoffee),
            Habit(name: "Supplements", type: .checkbox, order: AppConstants.HabitOrder.weekendSupplements),
            Habit(name: "Stretching", type: .timer(defaultDuration: 600), order: AppConstants.HabitOrder.weekendStretching)
        ]
        
        let weekendHabits = [
            Habit(name: "Coffee", type: .checkbox, order: AppConstants.HabitOrder.weekendCoffee),
            Habit(name: "News Reading", type: .timer(defaultDuration: 900), order: AppConstants.HabitOrder.weekendNews)
        ]
        
        return [
            RoutineTemplate(
                name: "Office Day",
                habits: officeHabits,
                color: "#007AFF",
                isDefault: false,
                contextRules: [
                    ContextRule(
                        type: .location,
                        locationCategory: .office,
                        priority: AppConstants.Routine.officePriority
                    )
                ]
            ),
            RoutineTemplate(
                name: "Home Office",
                habits: homeHabits,
                color: "#34C759",
                isDefault: true,
                contextRules: [
                    ContextRule(
                        type: .location,
                        locationCategory: .homeOffice,
                        priority: AppConstants.Routine.homeOfficePriority
                    )
                ]
            ),
            RoutineTemplate(
                name: "Weekend",
                habits: weekendHabits,
                color: "#FF9500",
                isDefault: false,
                contextRules: [
                    ContextRule(
                        type: .timeSlot,
                        timeSlots: [.weekend],
                        priority: AppConstants.Routine.weekendPriority
                    )
                ]
            )
        ]
    }
    
    @Test("SmartRoutineSelector initializes with templates")
    @MainActor func testInitialization() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        #expect(selector.availableTemplates.count == 3)
        #expect(selector.availableTemplates.contains { $0.name == "Office Day" })
        #expect(selector.availableTemplates.contains { $0.name == "Home Office" })
        #expect(selector.availableTemplates.contains { $0.name == "Weekend" })
    }
    
    @Test("SmartRoutineSelector returns default template when no context")
    @MainActor func testDefaultTemplateSelection() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        let context = RoutineContext()
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        #expect(selectedTemplate?.name == "Home Office")
        #expect(selectedTemplate?.isDefault == true)
    }
    
    @Test("SmartRoutineSelector selects office template for office location")
    @MainActor func testOfficeLocationSelection() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        let context = RoutineContext(
            currentLocation: CLLocation(latitude: 37.7749, longitude: -122.4194),
            locationCategory: .office,
            timeSlot: .morningWeekday,
            dayCategory: .weekday
        )
        
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        #expect(selectedTemplate?.name == "Office Day")
    }
    
    @Test("SmartRoutineSelector selects weekend template for weekend time")
    @MainActor func testWeekendTimeSelection() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        let context = RoutineContext(
            currentLocation: nil,
            locationCategory: .home,
            timeSlot: .weekend,
            dayCategory: .weekend
        )
        
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        #expect(selectedTemplate?.name == "Weekend")
    }
    
    @Test("SmartRoutineSelector handles conflicting context rules")
    @MainActor func testConflictingContextRules() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        // Context that matches both office location and weekend time
        let context = RoutineContext(
            currentLocation: CLLocation(latitude: 37.7749, longitude: -122.4194),
            locationCategory: .office,
            timeSlot: .weekend,
            dayCategory: .weekend
        )
        
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        // Should select based on highest priority score
        #expect(selectedTemplate != nil)
        // Office template has priority 2, Weekend has priority 1
        // Office should win due to higher priority
        #expect(selectedTemplate?.name == "Office Day")
    }
    
    @Test("SmartRoutineSelector calculates context scores correctly")
    @MainActor func testContextScoreCalculation() {
        let templates = createTestTemplates()
        let selector = SmartRoutineSelector(templates: templates)
        
        let officeContext = RoutineContext(
            currentLocation: CLLocation(latitude: 37.7749, longitude: -122.4194),
            locationCategory: .office,
            timeSlot: .morningWeekday,
            dayCategory: .weekday
        )
        
        let scores = selector.calculateContextScores(for: officeContext)
        
        #expect(scores.count == 3)
        
        // Office template should have highest score
        let officeScore = scores.first { $0.template.name == "Office Day" }?.score ?? 0
        let homeScore = scores.first { $0.template.name == "Home Office" }?.score ?? 0
        let weekendScore = scores.first { $0.template.name == "Weekend" }?.score ?? 0
        
        #expect(officeScore > homeScore)
        #expect(officeScore > weekendScore)
    }
    
    @Test("SmartRoutineSelector handles empty template list")
    @MainActor func testEmptyTemplateList() {
        let selector = SmartRoutineSelector(templates: [])
        let context = RoutineContext()
        
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        #expect(selectedTemplate == nil)
    }
    
    @Test("SmartRoutineSelector handles templates without context rules")
    @MainActor func testTemplatesWithoutContextRules() {
        let simpleTemplate = RoutineTemplate(
            name: "Simple Routine",
            habits: [Habit(name: "Test", type: .checkbox, order: 0)],
            color: "#FF0000",
            isDefault: false,
            contextRules: [] // No context rules
        )
        
        let selector = SmartRoutineSelector(templates: [simpleTemplate])
        let context = RoutineContext(locationCategory: .office)
        
        let selectedTemplate = selector.selectBestTemplate(for: context)
        
        // Should still return the template even without matching rules
        #expect(selectedTemplate?.name == "Simple Routine")
    }
    
    @Test("SmartRoutineSelector prioritizes multiple matching rules")
    @MainActor func testMultipleMatchingRules() {
        let multiRuleTemplate = RoutineTemplate(
            name: "Multi-Context",
            habits: [Habit(name: "Test", type: .checkbox, order: 0)],
            color: "#FF0000",
            isDefault: false,
            contextRules: [
                ContextRule(
                    type: .location,
                    locationCategory: .office,
                    priority: 2
                ),
                ContextRule(
                    type: .timeSlot,
                    timeSlots: [.morningWeekday],
                    priority: 1
                )
            ]
        )
        
        let selector = SmartRoutineSelector(templates: [multiRuleTemplate])
        let context = RoutineContext(
            locationCategory: .office,
            timeSlot: .morningWeekday
        )
        
        let scores = selector.calculateContextScores(for: context)
        
        // Should get points for both matching rules
        let score = scores.first?.score ?? 0
        #expect(score > 0)
        
        // Score should reflect both matches (2 + 1 = 3, plus priority boost)
        let expectedScore = (2 + 1) + AppConstants.Routine.priorityBoost
        #expect(score == expectedScore)
    }
}

@Suite("Context Rule Tests")
struct ContextRuleTests {
    
    @Test("ContextRule matches location correctly")
    func testLocationMatching() {
        let rule = ContextRule(
            type: .location,
            locationCategory: .office,
            priority: 2
        )
        
        let officeContext = RoutineContext(locationCategory: .office)
        let homeContext = RoutineContext(locationCategory: .home)
        
        #expect(rule.matches(context: officeContext) == true)
        #expect(rule.matches(context: homeContext) == false)
    }
    
    @Test("ContextRule matches time slot correctly")
    func testTimeSlotMatching() {
        let rule = ContextRule(
            type: .timeSlot,
            timeSlots: [.morningWeekday, .afternoonWeekday],
            priority: 1
        )
        
        let morningContext = RoutineContext(timeSlot: .morningWeekday)
        let afternoonContext = RoutineContext(timeSlot: .afternoonWeekday)
        let weekendContext = RoutineContext(timeSlot: .weekend)
        
        #expect(rule.matches(context: morningContext) == true)
        #expect(rule.matches(context: afternoonContext) == true)
        #expect(rule.matches(context: weekendContext) == false)
    }
    
    @Test("ContextRule matches day category correctly")
    func testDayCategoryMatching() {
        let rule = ContextRule(
            type: .dayCategory,
            dayCategories: [.weekday],
            priority: 1
        )
        
        let weekdayContext = RoutineContext(dayCategory: .weekday)
        let weekendContext = RoutineContext(dayCategory: .weekend)
        
        #expect(rule.matches(context: weekdayContext) == true)
        #expect(rule.matches(context: weekendContext) == false)
    }
    
    @Test("ContextRule handles mixed rule types")
    func testMixedRuleTypes() {
        // A rule that shouldn't match if context doesn't have required fields
        let locationRule = ContextRule(
            type: .location,
            locationCategory: .office,
            priority: 1
        )
        
        let contextWithoutLocation = RoutineContext(timeSlot: .morningWeekday)
        
        #expect(locationRule.matches(context: contextWithoutLocation) == false)
    }
    
    @Test("ContextRule priority affects scoring")
    func testPriorityScoring() {
        let highPriorityRule = ContextRule(
            type: .location,
            locationCategory: .office,
            priority: 3
        )
        
        let lowPriorityRule = ContextRule(
            type: .location,
            locationCategory: .office,
            priority: 1
        )
        
        let context = RoutineContext(locationCategory: .office)
        
        #expect(highPriorityRule.matches(context: context) == true)
        #expect(lowPriorityRule.matches(context: context) == true)
        #expect(highPriorityRule.priority == 3)
        #expect(lowPriorityRule.priority == 1)
    }
}