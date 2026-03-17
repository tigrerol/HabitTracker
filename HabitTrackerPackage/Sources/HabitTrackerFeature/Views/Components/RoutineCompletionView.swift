import SwiftUI

/// View displayed when a routine is completed, showing celebration and completion options
struct RoutineCompletionView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onComplete: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            Spacer()

            // Celebration header
            VStack(spacing: AppConstants.Spacing.large) {
                // Completion ring with emoji
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 3)
                        .frame(width: 96, height: 96)

                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentAccentColor,
                                    themeManager.currentAccentColor.opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)

                    Text("🎉")
                        .font(.system(size: 40))
                }

                VStack(spacing: 6) {
                    Text(String(localized: "RoutineExecutionView.RoutineComplete", bundle: .module))
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text("You completed \(data.completedCount) of \(data.totalCount) habits in \(data.durationString)")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(data.completedCount)",
                    label: "Completed",
                    color: themeManager.currentAccentColor
                )

                Divider()
                    .frame(height: 36)

                statBadge(
                    icon: "timer",
                    value: data.durationString,
                    label: "Duration",
                    color: .secondary
                )
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            )

            // Inline Mood Rating
            InlineMoodRatingView(sessionId: data.id)

            Spacer()

            // Complete Button
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                    Text(String(localized: "RoutineExecutionView.AllDone", bundle: .module))
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentAccentColor,
                                    themeManager.currentAccentColor.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding()
    }

    @ViewBuilder
    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RoutineCompletionView(
        data: RoutineExecutionView.SessionDisplayData(
            id: UUID(),
            templateName: "Morning Routine",
            templateColor: "#007AFF",
            isCompleted: true,
            currentHabit: nil,
            activeHabits: [],
            completions: [],
            progress: 1.0,
            durationString: "5:30",
            completedCount: 3,
            totalCount: 3,
            currentHabitIndex: 3
        ),
        onComplete: {}
    )
}
