import SwiftUI

/// Navigation controls for routine execution (previous, skip, etc.)
struct RoutineNavigationControlsView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onPrevious: () -> Void
    let onSkip: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: AppConstants.Spacing.large) {
            // Previous habit button
            Button(action: onPrevious) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                    Text(String(localized: "RoutineExecutionView.Previous", bundle: .module))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .foregroundStyle(data.currentHabitIndex > 0 ? .primary : .tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.regularMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    data.currentHabitIndex > 0 ?
                                    Color.primary.opacity(0.1) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                )
            }
            .disabled(data.currentHabitIndex <= 0)
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            // Skip current habit button
            Button(action: onSkip) {
                HStack(spacing: 6) {
                    Text(String(localized: "RoutineExecutionView.Skip", bundle: .module))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                    Image(systemName: "forward.fill")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
