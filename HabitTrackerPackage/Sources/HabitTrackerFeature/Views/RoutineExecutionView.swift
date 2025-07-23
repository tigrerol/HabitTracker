import SwiftUI

/// Main view for executing a morning routine
public struct RoutineExecutionView: View {
    @Environment(RoutineService.self) private var routineService
    @State private var showingMoodRating = false
    
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
            .sheet(isPresented: $showingMoodRating) {
                if let session {
                    MoodRatingView(sessionId: session.id)
                }
            }
        }
    }
    
    @ViewBuilder
    private func activeRoutineView(_ session: RoutineSession) -> some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader(session)
            
            // Current habit
            if let currentHabit = session.currentHabit {
                currentHabitView(currentHabit, session: session)
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
                session.completeCurrentHabit(duration: duration, notes: notes)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func navigationControls(_ session: RoutineSession) -> some View {
        VStack(spacing: 16) {
            // Primary actions
            HStack(spacing: 16) {
                // Skip button
                Button {
                    session.skipCurrentHabit()
                } label: {
                    Text("Skip")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.orange, lineWidth: 2)
                        )
                }
                
                // Back button (if not first habit)
                if session.currentHabitIndex > 0 {
                    Button {
                        session.goToPreviousHabit()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(width: 50, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.blue, lineWidth: 2)
                            )
                    }
                }
            }
            
            // Habit overview
            habitOverview(session)
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
        VStack(spacing: 32) {
            Spacer()
            
            // Celebration
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 80))
                
                Text("Routine Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You completed \(session.completions.filter { !$0.isSkipped }.count) of \(session.activeHabits.count) habits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("Duration: \(session.duration.formattedDuration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button {
                    showingMoodRating = true
                } label: {
                    Text("Rate Your Mood")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: session.template.color) ?? .blue, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    routineService.completeCurrentSession()
                } label: {
                    Text("Finish")
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue, lineWidth: 2)
                        )
                }
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