import SwiftUI

/// Navigation controls for routine execution (previous, skip, etc.)
struct RoutineNavigationControlsView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onPrevious: () -> Void
    let onSkip: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: AppConstants.Spacing.large) {
            // Previous habit button
            Button(action: onPrevious) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text(String(localized: "RoutineExecutionView.Previous", bundle: .module))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .tint(.primary)
            .disabled(data.currentHabitIndex <= 0)
            .accessibilityHint("Returns to the previous habit and clears its completion")

            Spacer()

            // Skip current habit button
            Button(action: onSkip) {
                HStack(spacing: 6) {
                    Text(String(localized: "RoutineExecutionView.Skip", bundle: .module))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                    Image(systemName: "forward.fill")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .tint(.orange)
            .accessibilityHint("Skips the current habit without completing it")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
