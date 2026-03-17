import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("HabitType Exhaustive Coverage Tests")
struct HabitTypeExhaustiveTests {

    // MARK: - Test Helpers

    /// All habit type variants for exhaustive testing
    static let allHabitTypeVariants: [HabitType] = [
        .task(subtasks: []),
        .task(subtasks: [Subtask(name: "Sub 1"), Subtask(name: "Sub 2")]),
        .timer(style: .down, duration: 300),
        .timer(style: .up, duration: 0, target: 600),
        .timer(style: .multiple, duration: 0, steps: [
            SequenceStep(name: "Inhale", duration: 4),
            SequenceStep(name: "Hold", duration: 7),
            SequenceStep(name: "Exhale", duration: 8)
        ], repeatCount: 3),
        .action(type: .app, identifier: "com.apple.Health", displayName: "Health"),
        .action(type: .website, identifier: "https://example.com", displayName: "Example"),
        .action(type: .shortcut, identifier: "my-shortcut", displayName: "My Shortcut"),
        .tracking(.counter(items: ["Vitamin D", "Omega 3", "Magnesium"])),
        .tracking(.measurement(unit: "bpm", targetValue: 65.0)),
        .tracking(.measurement(unit: "kg", targetValue: nil)),
        .guidedSequence(steps: [
            SequenceStep(name: "Step 1", duration: 30),
            SequenceStep(name: "Step 2", duration: 60)
        ]),
        .conditional(ConditionalHabitInfo(
            question: "How do you feel?",
            options: [
                ConditionalOption(text: "Energized", habits: []),
                ConditionalOption(text: "Tired", habits: [])
            ]
        ))
    ]

    // MARK: - Exhaustive Property Coverage

    @Test("Every HabitType variant has a non-empty description",
          arguments: allHabitTypeVariants)
    func testDescriptionNonEmpty(type: HabitType) {
        #expect(!type.description.isEmpty)
    }

    @Test("Every HabitType variant has a non-empty icon name",
          arguments: allHabitTypeVariants)
    func testIconNameNonEmpty(type: HabitType) {
        #expect(!type.iconName.isEmpty)
    }

    @Test("Every HabitType variant has a non-empty quick name",
          arguments: allHabitTypeVariants)
    func testQuickNameNonEmpty(type: HabitType) {
        #expect(!type.quickName.isEmpty)
    }

    // MARK: - Estimated Duration

    @Test("Every HabitType variant produces a valid estimated duration",
          arguments: allHabitTypeVariants)
    func testEstimatedDuration(type: HabitType) {
        let habit = Habit(name: "Test", type: type)
        let duration = habit.estimatedDuration

        #expect(duration > 0, "Duration should be positive for \(type.description)")
        #expect(duration.isFinite, "Duration should be finite")
        #expect(!duration.isNaN, "Duration should not be NaN")
    }

    @Test("Task with no subtasks has 60 second estimated duration")
    func testEmptyTaskDuration() {
        let habit = Habit(name: "Simple Task", type: .task(subtasks: []))
        #expect(habit.estimatedDuration == 60)
    }

    @Test("Task with subtasks has 45 seconds per subtask")
    func testSubtaskDuration() {
        let subtasks = [Subtask(name: "A"), Subtask(name: "B"), Subtask(name: "C")]
        let habit = Habit(name: "Task", type: .task(subtasks: subtasks))
        #expect(habit.estimatedDuration == 135) // 3 * 45
    }

    @Test("Countdown timer uses duration")
    func testCountdownTimerDuration() {
        let habit = Habit(name: "Timer", type: .timer(style: .down, duration: 300))
        #expect(habit.estimatedDuration == 300)
    }

    @Test("Count-up timer uses target when available")
    func testCountUpTimerWithTarget() {
        let habit = Habit(name: "Timer", type: .timer(style: .up, duration: 0, target: 600))
        #expect(habit.estimatedDuration == 600)
    }

    @Test("Multiple timer sums steps and multiplies by repeat count")
    func testMultipleTimerDuration() {
        let steps = [
            SequenceStep(name: "Work", duration: 30),
            SequenceStep(name: "Rest", duration: 10)
        ]
        let habit = Habit(name: "Intervals", type: .timer(style: .multiple, duration: 0, steps: steps, repeatCount: 4))
        #expect(habit.estimatedDuration == 160) // (30+10) * 4
    }

    @Test("Counter tracking estimates 30 seconds per item")
    func testCounterDuration() {
        let habit = Habit(name: "Supplements", type: .tracking(.counter(items: ["A", "B", "C", "D"])))
        #expect(habit.estimatedDuration == 120) // 4 * 30
    }

    @Test("Measurement tracking estimates 60 seconds")
    func testMeasurementDuration() {
        let habit = Habit(name: "Weight", type: .tracking(.measurement(unit: "kg", targetValue: 75.0)))
        #expect(habit.estimatedDuration == 60)
    }

    @Test("Guided sequence sums step durations")
    func testGuidedSequenceDuration() {
        let steps = [
            SequenceStep(name: "Step 1", duration: 30),
            SequenceStep(name: "Step 2", duration: 45),
            SequenceStep(name: "Step 3", duration: 60)
        ]
        let habit = Habit(name: "Sequence", type: .guidedSequence(steps: steps))
        #expect(habit.estimatedDuration == 135)
    }

    @Test("Conditional habit estimates 30 seconds")
    func testConditionalDuration() {
        let habit = Habit(name: "Question", type: .conditional(ConditionalHabitInfo(
            question: "How?", options: []
        )))
        #expect(habit.estimatedDuration == 30)
    }

    // MARK: - Codable Round-Trip

    @Test("Every HabitType variant survives JSON encode/decode round-trip",
          arguments: allHabitTypeVariants)
    func testCodableRoundTrip(type: HabitType) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(type)
        let decoded = try decoder.decode(HabitType.self, from: data)

        #expect(decoded == type, "Round-trip should preserve equality for \(type.description)")
    }

    @Test("Habit with every type variant survives JSON round-trip",
          arguments: allHabitTypeVariants)
    func testHabitCodableRoundTrip(type: HabitType) throws {
        let original = Habit(
            name: "Test Habit",
            type: type,
            isOptional: true,
            notes: "Some notes",
            color: "#FF0000",
            order: 5
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Habit.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.type == original.type)
        #expect(decoded.isOptional == original.isOptional)
        #expect(decoded.notes == original.notes)
        #expect(decoded.color == original.color)
        #expect(decoded.order == original.order)
    }

    // MARK: - Type Predicates

    @Test("isTask returns true only for task types")
    func testIsTask() {
        #expect(HabitType.task(subtasks: []).isTask)
        #expect(HabitType.task(subtasks: [Subtask(name: "A")]).isTask)
        #expect(!HabitType.timer(style: .down, duration: 60).isTask)
        #expect(!HabitType.tracking(.counter(items: [])).isTask)
        #expect(!HabitType.conditional(ConditionalHabitInfo(question: "?", options: [])).isTask)
    }

    @Test("isTimer returns true only for timer types")
    func testIsTimer() {
        #expect(HabitType.timer(style: .down, duration: 60).isTimer)
        #expect(HabitType.timer(style: .up, duration: 0).isTimer)
        #expect(HabitType.timer(style: .multiple, duration: 0).isTimer)
        #expect(!HabitType.task(subtasks: []).isTimer)
        #expect(!HabitType.tracking(.counter(items: [])).isTimer)
    }

    @Test("isConditional returns true only for conditional types")
    func testIsConditional() {
        #expect(HabitType.conditional(ConditionalHabitInfo(question: "?", options: [])).isConditional)
        #expect(!HabitType.task(subtasks: []).isConditional)
        #expect(!HabitType.timer(style: .down, duration: 60).isConditional)
    }

    // MARK: - SequenceStep Edge Cases

    @Test("SequenceStep clamps duration to minimum of 1")
    func testSequenceStepMinDuration() {
        let step = SequenceStep(name: "Zero", duration: 0)
        #expect(step.duration == 1)

        let negativeStep = SequenceStep(name: "Negative", duration: -10)
        #expect(negativeStep.duration == 1)
    }

    // MARK: - RoutineTemplate Duration

    @Test("RoutineTemplate estimatedDuration sums habit durations")
    func testTemplateDuration() {
        let habits = [
            Habit(name: "Task", type: .task(subtasks: []), order: 0),
            Habit(name: "Timer", type: .timer(style: .down, duration: 300), order: 1),
            Habit(name: "Counter", type: .tracking(.counter(items: ["A", "B"])), order: 2)
        ]
        let template = RoutineTemplate(name: "Test", habits: habits)

        // 60 (task) + 300 (timer) + 60 (2 items * 30s)
        #expect(template.estimatedDuration == 420)
    }

    @Test("RoutineTemplate formattedDuration returns minutes string")
    func testTemplateFormattedDuration() {
        let habits = [
            Habit(name: "Timer", type: .timer(style: .down, duration: 600), order: 0)
        ]
        let template = RoutineTemplate(name: "Test", habits: habits)

        #expect(template.formattedDuration == "10 min")
    }

    @Test("RoutineTemplate with no habits has zero duration")
    func testEmptyTemplateDuration() {
        let template = RoutineTemplate(name: "Empty")
        #expect(template.estimatedDuration == 0)
        #expect(template.formattedDuration == "0 min")
    }
}
