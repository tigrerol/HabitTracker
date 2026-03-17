import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Accessibility Configuration Tests")
struct AccessibilityConfigurationTests {

    // MARK: - Labels with Multiple Parameters

    @Test("progressBar label shows correct completed and total values")
    func testProgressBarLabel() {
        let label = AccessibilityConfiguration.Labels.progressBar(completed: 3, total: 7)

        #expect(label.contains("3"))
        #expect(label.contains("7"))
        // The bug: both %d get replaced with the first value
        // After fix, "3" and "7" should appear separately
        #expect(!label.contains("%d"), "Format specifier should be replaced")

        // Verify the two values are distinct
        // This will FAIL before the fix (both become "3")
        #expect(label != AccessibilityConfiguration.Labels.progressBar(completed: 3, total: 3),
               "Different total should produce different label")
    }

    @Test("progressBar label with different values produces distinct output")
    func testProgressBarDistinctValues() {
        let label1 = AccessibilityConfiguration.Labels.progressBar(completed: 1, total: 10)
        let label2 = AccessibilityConfiguration.Labels.progressBar(completed: 5, total: 10)
        let label3 = AccessibilityConfiguration.Labels.progressBar(completed: 1, total: 5)

        #expect(label1 != label2, "Different completed counts should produce different labels")
        #expect(label1 != label3, "Different totals should produce different labels")
    }

    @Test("habitCard label contains both habit name and type")
    func testHabitCardLabel() {
        let label = AccessibilityConfiguration.Labels.habitCard(
            habitName: "Meditation",
            habitType: "Timer"
        )

        #expect(label.contains("Meditation"))
        #expect(label.contains("Timer"))
        #expect(!label.contains("%@"), "Format specifier should be replaced")
    }

    @Test("habitCard label with different name and type are both present")
    func testHabitCardDistinctValues() {
        let label = AccessibilityConfiguration.Labels.habitCard(
            habitName: "Push-ups",
            habitType: "Counter"
        )

        // This will FAIL before fix if both %@ become "Push-ups"
        #expect(label.contains("Counter"),
               "Habit type should appear in label, not be replaced by name")
    }

    @Test("checkboxHabit label contains name and status")
    func testCheckboxHabitLabel() {
        let completedLabel = AccessibilityConfiguration.Labels.checkboxHabit(
            habitName: "Shower",
            isCompleted: true
        )
        let notCompletedLabel = AccessibilityConfiguration.Labels.checkboxHabit(
            habitName: "Shower",
            isCompleted: false
        )

        #expect(completedLabel.contains("Shower"))
        #expect(notCompletedLabel.contains("Shower"))
        #expect(completedLabel != notCompletedLabel,
               "Completed and not-completed should produce different labels")
    }

    @Test("counterHabit label contains name, item name, and count")
    func testCounterHabitLabel() {
        let label = AccessibilityConfiguration.Labels.counterHabit(
            habitName: "Supplements",
            itemName: "Vitamin D",
            count: 3
        )

        #expect(label.contains("Supplements"))
        #expect(label.contains("Vitamin D"))
        #expect(label.contains("3"))
        #expect(!label.contains("%@"), "Format specifiers should be replaced")
        #expect(!label.contains("%d"), "Format specifiers should be replaced")
    }

    @Test("routineTemplate label contains name, count, and duration")
    func testRoutineTemplateLabel() {
        let label = AccessibilityConfiguration.Labels.routineTemplate(
            templateName: "Morning Office",
            habitsCount: 5,
            duration: "25 min"
        )

        #expect(label.contains("Morning Office"))
        #expect(label.contains("5"))
        #expect(label.contains("25 min"))
        #expect(!label.contains("%@"), "Format specifiers should be replaced")
        #expect(!label.contains("%d"), "Format specifiers should be replaced")
    }

    @Test("conditionalOption label contains text and result count")
    func testConditionalOptionLabel() {
        let label = AccessibilityConfiguration.Labels.conditionalOption(
            optionText: "Yes, energized",
            resultCount: 3
        )

        #expect(label.contains("Yes, energized"))
        #expect(label.contains("3"))
        #expect(!label.contains("%@"), "Format specifiers should be replaced")
        #expect(!label.contains("%d"), "Format specifiers should be replaced")
    }

    // MARK: - Labels with Single Parameter

    @Test("completeHabitButton label contains habit name")
    func testCompleteHabitButtonLabel() {
        let label = AccessibilityConfiguration.Labels.completeHabitButton(habitName: "Meditation")

        #expect(label.contains("Meditation"))
        #expect(!label.contains("%@"))
    }

    @Test("skipHabitButton label contains habit name")
    func testSkipHabitButtonLabel() {
        let label = AccessibilityConfiguration.Labels.skipHabitButton(habitName: "Stretching")

        #expect(label.contains("Stretching"))
        #expect(!label.contains("%@"))
    }

    @Test("timerButton label differs based on running state")
    func testTimerButtonLabel() {
        let runningLabel = AccessibilityConfiguration.Labels.timerButton(
            habitName: "Breathing",
            isRunning: true
        )
        let stoppedLabel = AccessibilityConfiguration.Labels.timerButton(
            habitName: "Breathing",
            isRunning: false
        )

        #expect(runningLabel.contains("Breathing"))
        #expect(stoppedLabel.contains("Breathing"))
        #expect(runningLabel != stoppedLabel, "Running and stopped should have different labels")
    }

    // MARK: - Announcements with Multiple Parameters

    @Test("routineCompleted announcement contains name and duration")
    func testRoutineCompletedAnnouncement() {
        let announcement = AccessibilityConfiguration.Announcements.routineCompleted(
            templateName: "Morning Office",
            duration: "25 minutes"
        )

        #expect(announcement.contains("Morning Office"))
        #expect(announcement.contains("25 minutes"))
        #expect(!announcement.contains("%@"))
    }

    @Test("timerStopped announcement contains name and duration")
    func testTimerStoppedAnnouncement() {
        let announcement = AccessibilityConfiguration.Announcements.timerStopped(
            habitName: "Meditation",
            duration: "10 minutes"
        )

        #expect(announcement.contains("Meditation"))
        #expect(announcement.contains("10 minutes"))
        #expect(!announcement.contains("%@"))
    }

    // MARK: - Announcements with Single Parameter

    @Test("habitCompleted announcement contains habit name")
    func testHabitCompletedAnnouncement() {
        let announcement = AccessibilityConfiguration.Announcements.habitCompleted(habitName: "Shower")

        #expect(announcement.contains("Shower"))
        #expect(!announcement.contains("%@"))
    }

    @Test("habitSkipped announcement contains habit name")
    func testHabitSkippedAnnouncement() {
        let announcement = AccessibilityConfiguration.Announcements.habitSkipped(habitName: "Coffee")

        #expect(announcement.contains("Coffee"))
        #expect(!announcement.contains("%@"))
    }

    @Test("timerStarted announcement contains habit name")
    func testTimerStartedAnnouncement() {
        let announcement = AccessibilityConfiguration.Announcements.timerStarted(habitName: "Breathing")

        #expect(announcement.contains("Breathing"))
        #expect(!announcement.contains("%@"))
    }

    // MARK: - Identifiers

    @Test("identifiers include UUID in string")
    func testIdentifiersContainUUID() {
        let uuid = UUID()
        let uuidString = uuid.uuidString

        #expect(AccessibilityConfiguration.Identifiers.habitInteractionView(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.skipHabitButton(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.habitCheckbox(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.timerStartButton(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.timerStopButton(habitId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.templateCard(templateId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.editTemplateButton(templateId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.deleteTemplateButton(templateId: uuid).contains(uuidString))
        #expect(AccessibilityConfiguration.Identifiers.conditionalOption(optionId: uuid).contains(uuidString))
    }

    @Test("counter identifiers include index")
    func testCounterIdentifiers() {
        #expect(AccessibilityConfiguration.Identifiers.counterItem(index: 0).contains("0"))
        #expect(AccessibilityConfiguration.Identifiers.counterItem(index: 5).contains("5"))
        #expect(AccessibilityConfiguration.Identifiers.counterIncrement(index: 3).contains("3"))
        #expect(AccessibilityConfiguration.Identifiers.counterDecrement(index: 3).contains("3"))
    }
}
