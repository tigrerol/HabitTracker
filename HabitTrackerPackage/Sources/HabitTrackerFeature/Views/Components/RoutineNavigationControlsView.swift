import SwiftUI

/// Navigation controls for routine execution (previous, skip, etc.)
struct RoutineNavigationControlsView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onPrevious: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        HStack(spacing: AppConstants.Spacing.large) {
            // Previous habit
            Button(action: onPrevious) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text(String(localized: "RoutineExecutionView.Previous", bundle: .module))
                }
                .font(.caption)
                .foregroundStyle(data.currentHabitIndex > 0 ? .blue : .gray)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
            .disabled(data.currentHabitIndex <= 0)
            .buttonStyle(.plain)
            
            Spacer()
            
            // Skip current habit
            Button(action: onSkip) {
                HStack {
                    Image(systemName: "forward.fill")
                    Text(String(localized: "RoutineExecutionView.Skip", bundle: .module))
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    RoutineNavigationControlsView(
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
        onPrevious: {},
        onSkip: {}
    )
}