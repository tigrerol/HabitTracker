import SwiftUI

/// Horizontal scrollable overview of all habits in the routine with status indicators
struct HabitOverviewView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onHabitTap: (Int) -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(data.activeHabits.enumerated()), id: \.element.id) { index, habit in
                    let isCompleted = data.completions.contains(where: { $0.habitId == habit.id })
                    let isCurrent = data.currentHabit?.id == habit.id

                    Button {
                        onHabitTap(index)
                    } label: {
                        HStack(spacing: 5) {
                            // Status icon
                            Image(systemName: isCompleted ? "checkmark" : habit.type.iconName)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(
                                    isCompleted ? .white :
                                    (isCurrent ? themeManager.currentAccentColor : .secondary)
                                )
                                .frame(width: 16, height: 16)
                                .background(
                                    Circle()
                                        .fill(
                                            isCompleted ? themeManager.currentAccentColor :
                                            (isCurrent ? themeManager.currentAccentColor.opacity(0.15) :
                                            Color.primary.opacity(0.06))
                                        )
                                )

                            Text(habit.name)
                                .font(.system(.caption2, design: .rounded, weight: isCurrent ? .semibold : .regular))
                                .foregroundStyle(isCurrent ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(
                                    isCurrent ?
                                    themeManager.currentAccentColor.opacity(0.08) :
                                    Color.primary.opacity(0.04)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isCurrent ? themeManager.currentAccentColor.opacity(0.25) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .id(habit.id)
                    .accessibilityLabel("\(habit.name), \(habitStatusLabel(for: habit))")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    private func habitStatusLabel(for habit: Habit) -> String {
        let isCompleted = data.completions.contains(where: { $0.habitId == habit.id })
        let isCurrent = data.currentHabit?.id == habit.id

        if isCompleted {
            return String(localized: "HabitOverviewView.Status.Completed", bundle: .module)
        } else if isCurrent {
            return String(localized: "HabitOverviewView.Status.Current", bundle: .module)
        } else {
            return String(localized: "HabitOverviewView.Status.Pending", bundle: .module)
        }
    }
}

#Preview {
    HabitOverviewView(
        data: RoutineExecutionView.SessionDisplayData(
            id: UUID(),
            templateName: "Morning Routine",
            templateColor: "#007AFF",
            isCompleted: false,
            currentHabit: Habit(id: UUID(), name: "Current", type: .task(subtasks: []), color: "#007AFF", order: 2),
            activeHabits: [
                Habit(id: UUID(), name: "Meditation", type: .timer(style: .down, duration: 300), color: "#007AFF", order: 1),
                Habit(id: UUID(), name: "Exercise", type: .task(subtasks: []), color: "#FF3B30", order: 2),
                Habit(id: UUID(), name: "Journal", type: .task(subtasks: []), color: "#34C759", order: 3)
            ],
            completions: [
                HabitCompletion(habitId: UUID(), completedAt: Date(), duration: 300, isSkipped: false, notes: nil)
            ],
            progress: 0.33,
            durationString: "5:00",
            completedCount: 1,
            totalCount: 3,
            currentHabitIndex: 1
        ),
        onHabitTap: { _ in }
    )
}
