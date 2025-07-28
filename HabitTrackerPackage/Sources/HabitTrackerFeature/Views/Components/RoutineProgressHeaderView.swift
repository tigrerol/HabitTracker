import SwiftUI

/// Header view showing routine progress, completion counts, and duration
struct RoutineProgressHeaderView: View {
    let data: RoutineExecutionView.SessionDisplayData
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: data.progress)
                .tint(Color(hex: data.templateColor) ?? .blue)
                .scaleEffect(y: 2)
                .accessibilityProgress(
                    identifier: AccessibilityConfiguration.Identifiers.progressBar,
                    label: AccessibilityConfiguration.Labels.progressBar(
                        completed: data.completedCount,
                        total: data.totalCount
                    ),
                    value: data.progress
                )
            
            // Progress text
            HStack {
                Text(String(format: String(localized: "RoutineExecutionView.CompletedOfTotal", bundle: .module), data.completedCount, data.totalCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.progressText)
                    .accessibilityHidden(true) // Hidden since progress bar provides the same info
                
                Spacer()
                
                Text(data.durationString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.durationText)
                    .accessibilityLabel("Duration: \(data.durationString)")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    RoutineProgressHeaderView(
        data: RoutineExecutionView.SessionDisplayData(
            id: UUID(),
            templateName: "Morning Routine",
            templateColor: "#007AFF",
            isCompleted: false,
            currentHabit: nil,
            activeHabits: [],
            completions: [],
            progress: 0.6,
            durationString: "3:45",
            completedCount: 3,
            totalCount: 5,
            currentHabitIndex: 3
        )
    )
}