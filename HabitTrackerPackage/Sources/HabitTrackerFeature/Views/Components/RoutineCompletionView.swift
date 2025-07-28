import SwiftUI

/// View displayed when a routine is completed, showing celebration and completion options
struct RoutineCompletionView: View {
    let data: RoutineExecutionView.SessionDisplayData
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            Spacer()
            
            // Celebration
            VStack(spacing: AppConstants.Spacing.large) {
                Text("🎉")
                    .font(.system(size: AppConstants.FontSizes.largeIcon))
                
                Text(String(localized: "RoutineExecutionView.RoutineComplete", bundle: .module))
                    .font(.title)
                    .fontWeight(.bold)
                
                // Use simple string interpolation to avoid String.format issues
                Text("You completed \(data.completedCount) of \(data.totalCount) habits in \(data.durationString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Inline Mood Rating
            InlineMoodRatingView(sessionId: data.id)
            
            Spacer()
            
            // Complete Button
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(String(localized: "RoutineExecutionView.AllDone", bundle: .module))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: data.templateColor) ?? .blue, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
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