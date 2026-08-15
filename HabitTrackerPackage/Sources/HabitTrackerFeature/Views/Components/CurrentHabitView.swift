import SwiftUI

/// View for displaying the current habit being executed with interaction controls
struct CurrentHabitView: View {
    let habit: Habit
    let data: RoutineExecutionView.SessionDisplayData
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let initialTimerState: TimerHabitState?
    let onTimerStateChange: ((UUID, TimerHabitState) -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    /// Only worth naming the block when the routine actually has several.
    private var showsBlockName: Bool {
        Set(data.activeHabits.compactMap(\.blockName)).count > 1
    }

    init(
        habit: Habit,
        data: RoutineExecutionView.SessionDisplayData,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        initialTimerState: TimerHabitState? = nil,
        onTimerStateChange: ((UUID, TimerHabitState) -> Void)? = nil
    ) {
        self.habit = habit
        self.data = data
        self.onComplete = onComplete
        self.initialTimerState = initialTimerState
        self.onTimerStateChange = onTimerStateChange
    }

    var body: some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            // Habit identity
            VStack(spacing: 12) {
                // Layered icon with depth
                ZStack {
                    Circle()
                        .fill(themeManager.currentAccentColor.opacity(0.07))
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(themeManager.currentAccentColor.opacity(0.11))
                        .frame(width: 68, height: 68)

                    Image(systemName: habit.type.iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(themeManager.currentAccentColor)
                }

                VStack(spacing: 4) {
                    // Which included block this habit came from, when the
                    // routine is composed of several.
                    if let blockName = habit.blockName, showsBlockName {
                        Text(blockName)
                            .font(.system(size: 11, design: .rounded).weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .foregroundStyle(.tertiary)
                    }

                    TruncatableText(text: habit.name, lineLimit: 2)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(habit.type.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // Habit-specific interaction
            HabitInteractionView(
                habit: habit,
                onComplete: onComplete,
                isCompleted: data.completions.contains(where: { $0.habitId == habit.id }),
                initialTimerState: initialTimerState,
                onTimerStateChange: onTimerStateChange
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityHabitInteraction(
            habit: habit,
            customHint: AccessibilityConfiguration.Hints.swipeToNavigate
        )
    }
}

#Preview {
    CurrentHabitView(
        habit: Habit(
            id: UUID(),
            name: "Meditation",
            type: .timer(style: .down, duration: 300),
            color: "#007AFF",
            order: 1
        ),
        data: RoutineExecutionView.SessionDisplayData(
            id: UUID(),
            templateName: "Morning Routine",
            templateColor: "#007AFF",
            isCompleted: false,
            currentHabit: nil,
            activeHabits: [],
            completions: [],
            progress: 0.4,
            durationString: "2:30",
            completedCount: 2,
            totalCount: 5,
            currentHabitIndex: 2
        ),
        onComplete: { _, _, _ in }
    )
}
