import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("RoutineImportService")
struct RoutineImportServiceTests {
    let service = RoutineImportService()

    // MARK: - Top-level validation

    @Test("Empty input throws emptyInput")
    func emptyInputThrows() {
        #expect(throws: RoutineImportError.emptyInput) {
            _ = try service.importRoutine(fromJSON: "   \n\t  ", existingTemplateNames: [])
        }
    }

    @Test("Missing routine name throws missingRoutineName")
    func missingNameThrows() {
        let json = """
        { "name": "  ", "habits": [{"name": "X", "type": "task"}] }
        """
        #expect(throws: RoutineImportError.missingRoutineName) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Empty habits array throws emptyHabits")
    func emptyHabitsThrows() {
        let json = #"{ "name": "Wind Down", "habits": [] }"#
        #expect(throws: RoutineImportError.emptyHabits) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Garbage JSON throws invalidJSON")
    func garbageJSONThrows() {
        #expect(throws: (any Error).self) {
            _ = try service.importRoutine(fromJSON: "{ not json", existingTemplateNames: [])
        }
    }

    @Test("Payload above max size throws payloadTooLarge")
    func payloadTooLargeThrows() {
        let big = String(repeating: "a", count: RoutineImportService.maxImportPayloadBytes + 10)
        let json = "{ \"name\": \"X\", \"description\": \"\(big)\", \"habits\": [] }"
        #expect(throws: RoutineImportError.payloadTooLarge) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    // MARK: - Habit translations

    @Test("Translates task habit with subtasks")
    func translatesTask() throws {
        let json = """
        {
          "name": "Morning",
          "habits": [
            {
              "name": "Stretch",
              "type": "task",
              "subtasks": ["Neck", "Shoulders"],
              "estimatedSeconds": 120
            }
          ]
        }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        #expect(template.habits.count == 1)
        guard case .task(let subtasks, _, let duration) = template.habits[0].type else {
            Issue.record("Expected task type"); return
        }
        #expect(subtasks.map(\.name) == ["Neck", "Shoulders"])
        #expect(duration == 120)
    }

    @Test("Translates countdown timer")
    func translatesCountdownTimer() throws {
        let json = """
        {
          "name": "Focus",
          "habits": [{
            "name": "Pomodoro",
            "type": "timer",
            "timer": { "style": "down", "durationSeconds": 1500 }
          }]
        }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .timer(let style, let duration, _, _, _) = template.habits[0].type else {
            Issue.record("Expected timer type"); return
        }
        #expect(style == .down)
        #expect(duration == 1500)
    }

    @Test("Countdown timer without durationSeconds throws")
    func countdownWithoutDurationThrows() {
        let json = """
        {
          "name": "X",
          "habits": [{
            "name": "T",
            "type": "timer",
            "timer": { "style": "down" }
          }]
        }
        """
        #expect(throws: RoutineImportError.self) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Translates multiple timer with steps and repeat")
    func translatesMultipleTimer() throws {
        let json = """
        {
          "name": "Breathing",
          "habits": [{
            "name": "Box",
            "type": "timer",
            "timer": {
              "style": "multiple",
              "steps": [
                { "name": "Inhale", "durationSeconds": 4 },
                { "name": "Hold",   "durationSeconds": 4 },
                { "name": "Exhale", "durationSeconds": 4 },
                { "name": "Hold",   "durationSeconds": 4 }
              ],
              "repeatCount": 4
            }
          }]
        }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .timer(let style, _, _, let steps, let repeatCount) = template.habits[0].type else {
            Issue.record("Expected timer type"); return
        }
        #expect(style == .multiple)
        #expect(steps.count == 4)
        #expect(steps[0].name == "Inhale")
        #expect(steps[0].duration == 4)
        #expect(repeatCount == 4)
    }

    @Test("Translates counter tracking")
    func translatesCounterTracking() throws {
        let json = """
        {
          "name": "Supps",
          "habits": [{
            "name": "Vitamins",
            "type": "tracking",
            "tracking": { "kind": "counter", "items": ["D3", "Mg"] }
          }]
        }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .tracking(.counter(let items)) = template.habits[0].type else {
            Issue.record("Expected counter tracking"); return
        }
        #expect(items == ["D3", "Mg"])
    }

    @Test("Counter tracking without items throws")
    func counterWithoutItemsThrows() {
        let json = """
        { "name": "X", "habits": [{
          "name": "Y", "type": "tracking",
          "tracking": { "kind": "counter" }
        }]}
        """
        #expect(throws: RoutineImportError.self) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Translates measurement tracking")
    func translatesMeasurementTracking() throws {
        let json = """
        { "name": "Body", "habits": [{
          "name": "Weight", "type": "tracking",
          "tracking": { "kind": "measurement", "unit": "kg", "targetValue": 75.0 }
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .tracking(.measurement(let unit, let target)) = template.habits[0].type else {
            Issue.record("Expected measurement"); return
        }
        #expect(unit == "kg")
        #expect(target == 75.0)
    }

    @Test("Translates guided sequence")
    func translatesGuidedSequence() throws {
        let json = """
        { "name": "Cool", "habits": [{
          "name": "Cooldown", "type": "guidedSequence",
          "steps": [
            { "name": "Stretch", "durationSeconds": 60, "instructions": "Hold" }
          ]
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .guidedSequence(let steps) = template.habits[0].type else {
            Issue.record("Expected guided sequence"); return
        }
        #expect(steps.count == 1)
        #expect(steps[0].instructions == "Hold")
    }

    @Test("Guided sequence without steps throws")
    func guidedSequenceWithoutStepsThrows() {
        let json = """
        { "name": "X", "habits": [{ "name": "Y", "type": "guidedSequence" }] }
        """
        #expect(throws: RoutineImportError.self) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Translates website action and uses host as display name fallback")
    func translatesWebsite() throws {
        let json = """
        { "name": "Browse", "habits": [{
          "name": "Open Calm", "type": "website", "url": "https://www.calm.com/page"
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .action(let type, let identifier, let displayName, _) = template.habits[0].type else {
            Issue.record("Expected action"); return
        }
        #expect(type == .website)
        #expect(identifier == "https://www.calm.com/page")
        #expect(displayName == "www.calm.com")
    }

    @Test("Website with invalid URL throws")
    func invalidWebsiteThrows() {
        let json = """
        { "name": "X", "habits": [{ "name": "Y", "type": "website", "url": "no scheme" }] }
        """
        #expect(throws: RoutineImportError.self) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }

    @Test("Translates shortcut action")
    func translatesShortcut() throws {
        let json = """
        { "name": "Auto", "habits": [{
          "name": "Run wind down", "type": "shortcut", "shortcutName": "Wind Down"
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .action(let type, let identifier, let displayName, _) = template.habits[0].type else {
            Issue.record("Expected action"); return
        }
        #expect(type == .shortcut)
        #expect(identifier == "Wind Down")
        #expect(displayName == "Wind Down")
    }

    // MARK: - Naming & color

    @Test("Existing name gets (Imported) suffix")
    func namingCollisionAddsSuffix() throws {
        let json = #"{ "name": "Morning", "habits": [{"name": "X", "type": "task"}] }"#
        let template = try service.importRoutine(
            fromJSON: json,
            existingTemplateNames: ["Morning"]
        )
        #expect(template.name == "Morning (Imported)")
    }

    @Test("Second collision uses numeric counter")
    func namingCollisionAddsCounter() throws {
        let json = #"{ "name": "Morning", "habits": [{"name": "X", "type": "task"}] }"#
        let template = try service.importRoutine(
            fromJSON: json,
            existingTemplateNames: ["Morning", "Morning (Imported)"]
        )
        #expect(template.name == "Morning (Imported 2)")
    }

    @Test("Invalid color is replaced by default")
    func invalidColorReplaced() throws {
        let json = """
        { "name": "X", "color": "not-a-color", "habits": [{"name": "Y", "type": "task"}] }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        #expect(template.color == "#34C759")
    }

    @Test("Valid hex color without # is accepted")
    func hexColorWithoutHashAccepted() throws {
        let json = """
        { "name": "X", "color": "abcdef", "habits": [{"name": "Y", "type": "task"}] }
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        #expect(template.color == "#ABCDEF")
    }

    @Test("Habit order matches array index")
    func habitOrderPreserved() throws {
        let json = """
        { "name": "Many", "habits": [
          {"name": "One", "type": "task"},
          {"name": "Two", "type": "task"},
          {"name": "Three", "type": "task"}
        ]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        #expect(template.habits.map(\.name) == ["One", "Two", "Three"])
        #expect(template.habits.map(\.order) == [0, 1, 2])
    }

    // MARK: - Subtask optional + minRequired

    @Test("Subtask object form preserves isOptional")
    func subtaskObjectFormPreservesOptional() throws {
        let json = """
        { "name": "Stretch", "habits": [{
          "name": "Mobility", "type": "task",
          "subtasks": [
            { "name": "Neck",  "isOptional": false },
            { "name": "Wrist", "isOptional": true }
          ]
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(let subtasks, _, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        #expect(subtasks.count == 2)
        #expect(subtasks[0].name == "Neck")
        #expect(subtasks[0].isOptional == false)
        #expect(subtasks[1].name == "Wrist")
        #expect(subtasks[1].isOptional == true)
    }

    @Test("Subtask plain-string form defaults isOptional to false")
    func subtaskStringFormDefaultsOptional() throws {
        let json = """
        { "name": "Stretch", "habits": [{
          "name": "Mobility", "type": "task",
          "subtasks": ["Neck", "Wrist"]
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(let subtasks, _, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        #expect(subtasks.allSatisfy { $0.isOptional == false })
    }

    @Test("Mixed string and object subtasks both accepted")
    func subtaskMixedFormAccepted() throws {
        let json = """
        { "name": "Stretch", "habits": [{
          "name": "Mobility", "type": "task",
          "subtasks": [
            "Neck",
            { "name": "Wrist", "isOptional": true }
          ]
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(let subtasks, _, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        #expect(subtasks.map(\.name) == ["Neck", "Wrist"])
        #expect(subtasks.map(\.isOptional) == [false, true])
    }

    @Test("Valid minRequired round-trips")
    func minRequiredRoundTrips() throws {
        let json = """
        { "name": "Pick 2", "habits": [{
          "name": "Any 2 of 3", "type": "task",
          "subtasks": ["A", "B", "C"],
          "minRequired": 2
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(_, let minRequired, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        #expect(minRequired == 2)
    }

    @Test("minRequired equal to subtask count is dropped to nil")
    func minRequiredAtMaxIsDropped() throws {
        let json = """
        { "name": "X", "habits": [{
          "name": "Y", "type": "task",
          "subtasks": ["A", "B"],
          "minRequired": 2
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(_, let minRequired, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        // 2 of 2 is the same as all-required; we normalize to nil
        #expect(minRequired == nil)
    }

    @Test("minRequired of 0 is dropped to nil")
    func minRequiredZeroDropped() throws {
        let json = """
        { "name": "X", "habits": [{
          "name": "Y", "type": "task",
          "subtasks": ["A", "B"],
          "minRequired": 0
        }]}
        """
        let template = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        guard case .task(_, let minRequired, _) = template.habits[0].type else {
            Issue.record("Expected task"); return
        }
        #expect(minRequired == nil)
    }

    @Test("Too many habits throws tooManyHabits")
    func tooManyHabitsThrows() {
        let habits = (0..<(RoutineImportService.maxHabitsPerRoutine + 1))
            .map { #"{"name":"H\#($0)","type":"task"}"# }
            .joined(separator: ",")
        let json = #"{"name":"X","habits":[\#(habits)]}"#
        #expect(throws: RoutineImportError.self) {
            _ = try service.importRoutine(fromJSON: json, existingTemplateNames: [])
        }
    }
}
