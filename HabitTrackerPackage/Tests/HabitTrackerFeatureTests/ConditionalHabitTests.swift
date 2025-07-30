import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Conditional Habits Tests")
struct ConditionalHabitTests {
    
    @Test("ConditionalHabitInfo can be created with question and options")
    func testConditionalHabitInfoCreation() {
        let option1 = ConditionalOption(text: "Option A", habits: [])
        let option2 = ConditionalOption(text: "Option B", habits: [])
        
        let info = ConditionalHabitInfo(
            question: "Test question?",
            options: [option1, option2]
        )
        
        #expect(info.question == "Test question?")
        #expect(info.options.count == 2)
        #expect(info.options[0].text == "Option A")
        #expect(info.options[1].text == "Option B")
    }
    
    @Test("ConditionalHabitInfo limits options to maximum of 4")
    func testOptionLimit() {
        let options = (1...6).map { ConditionalOption(text: "Option \($0)", habits: []) }
        
        let info = ConditionalHabitInfo(question: "Test?", options: options)
        
        #expect(info.options.count == 4)
        #expect(info.options[0].text == "Option 1")
        #expect(info.options[3].text == "Option 4")
    }
    
    @Test("ConditionalOption can contain habits")
    func testOptionWithHabits() {
        let habit1 = Habit(name: "Stretch", type: .timer(defaultDuration: 300))
        let habit2 = Habit(name: "Rest", type: .task(subtasks: []))
        
        let option = ConditionalOption(
            text: "Shoulder",
            habits: [habit1, habit2]
        )
        
        #expect(option.text == "Shoulder")
        #expect(option.habits.count == 2)
        #expect(option.habits[0].name == "Stretch")
        #expect(option.habits[1].name == "Rest")
    }
    
    @Test("ConditionalResponse can be created for regular selection")
    func testConditionalResponseCreation() {
        let habitId = UUID()
        let optionId = UUID()
        let routineId = UUID()
        
        let response = ConditionalResponse(
            habitId: habitId,
            question: "Test question?",
            selectedOptionId: optionId,
            selectedOptionText: "Option A",
            routineId: routineId
        )
        
        #expect(response.habitId == habitId)
        #expect(response.question == "Test question?")
        #expect(response.selectedOptionId == optionId)
        #expect(response.selectedOptionText == "Option A")
        #expect(response.routineId == routineId)
        #expect(response.wasSkipped == false)
    }
    
    @Test("ConditionalResponse can be created for skip")
    func testConditionalResponseSkip() {
        let habitId = UUID()
        let routineId = UUID()
        
        let response = ConditionalResponse.skip(
            habitId: habitId,
            question: "Test question?",
            routineId: routineId
        )
        
        #expect(response.habitId == habitId)
        #expect(response.question == "Test question?")
        #expect(response.selectedOptionText == "Skipped")
        #expect(response.routineId == routineId)
        #expect(response.wasSkipped == true)
    }
    
    @Test("HabitType conditional case works correctly")
    func testHabitTypeConditional() {
        let info = ConditionalHabitInfo(
            question: "Test?",
            options: [ConditionalOption(text: "Yes", habits: [])]
        )
        
        let habitType = HabitType.conditional(info)
        
        #expect(habitType.description == "1 options")
        #expect(habitType.iconName == "questionmark.circle")
        
        // Test pattern matching
        if case .conditional(let extractedInfo) = habitType {
            #expect(extractedInfo.question == "Test?")
            #expect(extractedInfo.options.count == 1)
        } else {
            Issue.record("HabitType.conditional pattern matching failed")
        }
    }
    
    @Test("Habit with conditional type can be created")
    func testHabitWithConditionalType() {
        let option = ConditionalOption(text: "Option", habits: [])
        let info = ConditionalHabitInfo(question: "Question?", options: [option])
        
        let habit = Habit(
            name: "Pain Assessment",
            type: .conditional(info),
            color: "#007AFF"
        )
        
        #expect(habit.name == "Pain Assessment")
        #expect(habit.color == "#007AFF")
        
        if case .conditional(let habitInfo) = habit.type {
            #expect(habitInfo.question == "Question?")
            #expect(habitInfo.options.count == 1)
        } else {
            Issue.record("Habit conditional type not set correctly")
        }
    }
}

@Suite("ResponseLoggingService Tests")
struct ResponseLoggingServiceTests {
    
    @Test("ResponseLoggingService can log and retrieve responses")
    @MainActor func testLoggingAndRetrieval() async {
        let service = ResponseLoggingService.shared
        
        // Clear existing data
        service.clearAllResponses()
        
        let habitId = UUID()
        let routineId = UUID()
        
        let response = ConditionalResponse(
            habitId: habitId,
            question: "Test question?",
            selectedOptionId: UUID(),
            selectedOptionText: "Option A",
            routineId: routineId
        )
        
        await service.logResponse(response)
        
        let allResponses = await service.getAllResponses()
        #expect(allResponses.count == 1)
        #expect(allResponses.first?.question == "Test question?")
        
        let habitResponses = await service.getResponses(for: habitId)
        #expect(habitResponses.count == 1)
        #expect(habitResponses.first?.selectedOptionText == "Option A")
        
        let routineResponses = await service.getResponsesForRoutine(routineId)
        #expect(routineResponses.count == 1)
    }
    
    @Test("ResponseLoggingService calculates skip rate correctly")
    @MainActor func testSkipRateCalculation() async {
        let service = ResponseLoggingService.shared
        service.clearAllResponses()
        
        let habitId = UUID()
        let routineId = UUID()
        
        // Log 3 responses: 2 regular, 1 skip
        let response1 = ConditionalResponse(
            habitId: habitId,
            question: "Test?",
            selectedOptionId: UUID(),
            selectedOptionText: "Option A",
            routineId: routineId,
            wasSkipped: false
        )
        
        let response2 = ConditionalResponse(
            habitId: habitId,
            question: "Test?",
            selectedOptionId: UUID(),
            selectedOptionText: "Option B",
            routineId: routineId,
            wasSkipped: false
        )
        
        let response3 = ConditionalResponse.skip(
            habitId: habitId,
            question: "Test?",
            routineId: routineId
        )
        
        await service.logResponse(response1)
        await service.logResponse(response2)
        await service.logResponse(response3)
        
        let skipRate = await service.getSkipRate(for: habitId)
        #expect(skipRate == 1.0/3.0) // 1 skip out of 3 total
        
        // Test response counts (should exclude skipped)
        let responseCounts = await service.getResponseCounts(for: habitId)
        #expect(responseCounts.count == 2)
        #expect(responseCounts["Option A"] == 1)
        #expect(responseCounts["Option B"] == 1)
        #expect(responseCounts["Skipped"] == nil) // Skipped responses not counted
    }
    
    @Test("ResponseLoggingService handles empty data correctly")
    @MainActor func testEmptyDataHandling() async {
        let service = ResponseLoggingService.shared
        service.clearAllResponses()
        
        let randomHabitId = UUID()
        
        let skipRate = await service.getSkipRate(for: randomHabitId)
        #expect(skipRate == 0.0)
        
        let responses = await service.getResponses(for: randomHabitId)
        #expect(responses.isEmpty)
        
        let counts = await service.getResponseCounts(for: randomHabitId)
        #expect(counts.isEmpty)
    }
}