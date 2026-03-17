import SwiftUI

/// Header view showing routine progress, completion counts, and duration
struct RoutineProgressHeaderView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 12) {
            // Custom progress bar + step dots
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.primary.opacity(0.08))

                        // Filled portion
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentAccentColor,
                                        themeManager.currentAccentColor.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(data.progress) * geometry.size.width)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: data.progress)
                    }
                }
                .frame(height: 5)
                .clipShape(Capsule())

                // Step indicator dots (only for manageable habit counts)
                if data.totalCount > 1 && data.totalCount <= 20 {
                    HStack(spacing: 0) {
                        ForEach(0..<data.totalCount, id: \.self) { index in
                            let isCompleted = index < data.completedCount
                            let isCurrent = index == data.currentHabitIndex

                            Circle()
                                .fill(
                                    isCompleted ? themeManager.currentAccentColor :
                                    (isCurrent ? themeManager.currentAccentColor.opacity(0.5) :
                                    Color.primary.opacity(0.12))
                                )
                                .frame(
                                    width: isCurrent ? 7 : 5,
                                    height: isCurrent ? 7 : 5
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrent)

                            if index < data.totalCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .matchedGeometry(id: .routineProgress, in: namespace)
            .accessibilityProgress(
                identifier: AccessibilityConfiguration.Identifiers.progressBar,
                label: AccessibilityConfiguration.Labels.progressBar(
                    completed: data.completedCount,
                    total: data.totalCount
                ),
                value: data.progress
            )

            // Info row
            HStack {
                Text(String(format: String(localized: "RoutineExecutionView.CompletedOfTotal", bundle: .module), data.completedCount, data.totalCount))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.progressText)
                    .accessibilityHidden(true)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(data.durationString)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.durationText)
                        .accessibilityLabel("Duration: \(data.durationString)")
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            themeManager.currentAccentColor.opacity(0.15),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    @Previewable @Namespace var namespace
    return RoutineProgressHeaderView(
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
        ),
        namespace: namespace
    )
}
