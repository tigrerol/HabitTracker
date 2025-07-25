import SwiftUI

/// Main view for executing a morning routine
public struct RoutineExecutionView: View {
    @Environment(RoutineService.self) private var routineService
    
    private var session: RoutineSession? {
        routineService.currentSession
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if session.isCompleted {
                        completionView(session)
                    } else {
                        activeRoutineView(session)
                    }
                } else {
                    Text("No active routine")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(session?.template.name ?? "Routine")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: .routineQueueDidChange)) { _ in
                // Force view refresh when routine queue changes (for conditional habits)
            }
        }
    }
    
    @ViewBuilder
    private func activeRoutineView(_ session: RoutineSession) -> some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader(session)
            
            // Current habit with swipe gestures
            if let currentHabit = session.currentHabit {
                currentHabitView(currentHabit, session: session)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                if value.translation.width > threshold && session.currentHabitIndex > 0 {
                                    // Swipe right = go back
                                    withAnimation(.bouncy) {
                                        session.goToPreviousHabit()
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                } else if value.translation.width < -threshold {
                                    // Swipe left = skip
                                    withAnimation(.easeInOut) {
                                        session.skipCurrentHabit()
                                    }
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                    impactFeedback.impactOccurred()
                                }
                            }
                    )
            }
            
            // Navigation controls
            navigationControls(session)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func progressHeader(_ session: RoutineSession) -> some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: session.progress)
                .tint(Color(hex: session.template.color) ?? .blue)
                .scaleEffect(y: 2)
            
            // Progress text
            HStack {
                Text("\(session.completions.count) of \(session.activeHabits.count) completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(session.duration.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func currentHabitView(_ habit: Habit, session: RoutineSession) -> some View {
        VStack(spacing: 24) {
            // Habit info
            VStack(spacing: 8) {
                Image(systemName: habit.type.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(habit.swiftUIColor)
                
                Text(habit.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(habit.type.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Habit-specific interaction
            HabitInteractionView(habit: habit) { duration, notes in
                // Handle conditional habits specially
                if case .conditional(let info) = habit.type,
                   let notes = notes,
                   notes.hasPrefix("Selected: ") {
                    // Extract selected option text
                    let optionText = String(notes.dropFirst("Selected: ".count))
                    
                    // Find the selected option
                    if let selectedOption = info.options.first(where: { $0.text == optionText }) {
                        // Handle the conditional option selection
                        routineService.handleConditionalOptionSelection(
                            option: selectedOption,
                            for: habit.id,
                            question: info.question
                        )
                    }
                } else if case .conditional(let info) = habit.type,
                          let notes = notes,
                          notes == "Skipped" {
                    // Handle conditional habit skip
                    routineService.skipConditionalHabit(habitId: habit.id, question: info.question)
                }
                
                session.completeCurrentHabit(duration: duration, notes: notes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func navigationControls(_ session: RoutineSession) -> some View {
        VStack(spacing: 12) {
            // Habit overview (moved to top for better visibility)
            habitOverview(session)
            
            // Streamlined actions
            HStack(spacing: 12) {
                // Back button
                if session.currentHabitIndex > 0 {
                    Button {
                        withAnimation(.bouncy) {
                            session.goToPreviousHabit()
                        }
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Skip button (more subtle)
                Button {
                    withAnimation(.easeInOut) {
                        session.skipCurrentHabit()
                    }
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.impactOccurred()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("Skip")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.regularMaterial)
    }
    
    private func habitOverview(_ session: RoutineSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(session.activeHabits.enumerated()), id: \.element.id) { index, habit in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(habitStatusColor(for: habit, in: session))
                            .frame(width: 12, height: 12)
                        
                        Text(habit.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .opacity(index == session.currentHabitIndex ? 1.0 : 0.6)
                    .onTapGesture {
                        session.goToHabit(at: index)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func habitStatusColor(for habit: Habit, in session: RoutineSession) -> Color {
        if session.completions.contains(where: { $0.habitId == habit.id }) {
            return .green
        } else if session.currentHabit?.id == habit.id {
            return habit.swiftUIColor
        } else {
            return .gray.opacity(0.3)
        }
    }
    
    @ViewBuilder
    private func completionView(_ session: RoutineSession) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Celebration
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 60))
                
                Text("Routine Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("You completed \(session.completions.filter { !$0.isSkipped }.count) of \(session.activeHabits.count) habits in \(session.duration.formattedDuration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Inline Mood Rating
            InlineMoodRatingView(sessionId: session.id)
            
            Spacer()
            
            // Quick Finish
            Button {
                routineService.completeCurrentSession()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("All Done!")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(hex: session.template.color) ?? .blue, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

// Helper extension for time formatting
extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RoutineExecutionView()
        .environment(RoutineService())
}