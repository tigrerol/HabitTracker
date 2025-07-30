import SwiftUI

/// View for displaying the current habit being executed with interaction controls
struct CurrentHabitView: View {
    let habit: Habit
    let data: RoutineExecutionView.SessionDisplayData
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            // Habit info
            VStack(spacing: 8) {
                Image(systemName: habit.type.iconName)
                    .font(.system(size: AppConstants.Spacing.page))
                    .foregroundStyle(habit.swiftUIColor)
                
                Text(habit.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(habit.type.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Habit-specific interaction
            HabitInteractionView(
                habit: habit,
                onComplete: onComplete,
                isCompleted: data.completions.contains(where: { $0.habitId == habit.id })
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