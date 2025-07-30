import SwiftUI

/// Horizontal scrollable overview of all habits in the routine with status indicators
struct HabitOverviewView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onHabitTap: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(data.activeHabits.enumerated()), id: \.element.id) { index, habit in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(habitStatusColor(for: habit))
                            .frame(width: 12, height: 12)
                        
                        Text(habit.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .id(habit.id) // Force unique view identity for entire VStack
                    .opacity(index == data.currentHabitIndex ? 1 : 0.6)
                    .onTapGesture {
                        onHabitTap(index)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func habitStatusColor(for habit: Habit) -> Color {
        let isCompleted = data.completions.contains(where: { $0.habitId == habit.id })
        let isCurrent = data.currentHabit?.id == habit.id
        
        if isCompleted {
            return .green
        } else if isCurrent {
            return habit.swiftUIColor
        } else {
            return .gray.opacity(0.3)
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
                Habit(id: UUID(), name: "Meditation", type: .timer(defaultDuration: 300), color: "#007AFF", order: 1),
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