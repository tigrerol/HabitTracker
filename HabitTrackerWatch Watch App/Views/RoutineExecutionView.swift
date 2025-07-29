import SwiftUI
import SwiftData

@MainActor
struct RoutineExecutionView: View {
    let routine: RoutineTemplate
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentHabitIndex: Int = 0
    @State private var routineSession: RoutineSession?
    @State private var completedHabits: Set<UUID> = []
    @State private var isCompleting = false
    @State private var showingCompletionView = false
    @State private var showingCancelAlert = false
    
    private var currentHabit: Habit? {
        guard currentHabitIndex < routine.habits.count else { return nil }
        return routine.habits[currentHabitIndex]
    }
    
    private var progress: Double {
        guard !routine.habits.isEmpty else { return 0 }
        return Double(completedHabits.count) / Double(routine.habits.count)
    }
    
    var body: some View {
        Group {
            if showingCompletionView {
                CompletionView(session: routineSession!) {
                    dismiss()
                }
            } else {
                executionView
            }
        }
        .onAppear {
            startRoutineSession()
        }
    }
    
    private var executionView: some View {
        VStack(spacing: 0) {
            // Progress Header
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(completedHabits.count) of \(routine.habits.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            // Current Habit Content
            if currentHabit != nil {
                TabView(selection: $currentHabitIndex) {
                    ForEach(Array(routine.habits.enumerated()), id: \.element.id) { index, habit in
                        HabitView(
                            habit: habit,
                            isCompleted: completedHabits.contains(habit.id),
                            onComplete: {
                                completeHabit(habit)
                            },
                            onSkip: {
                                skipHabit(habit)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle())
            } else {
                Spacer()
                Text("All habits completed!")
                    .font(.headline)
                Spacer()
            }
            
            // Navigation Controls
            VStack(spacing: 8) {
                HStack {
                    Button("Previous") {
                        withAnimation {
                            currentHabitIndex = max(0, currentHabitIndex - 1)
                        }
                    }
                    .disabled(currentHabitIndex <= 0)
                    
                    Spacer()
                    
                    if currentHabitIndex >= routine.habits.count - 1 {
                        Button("Finish") {
                            finishRoutine()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Next") {
                            withAnimation {
                                currentHabitIndex = min(routine.habits.count - 1, currentHabitIndex + 1)
                            }
                        }
                    }
                }
                
                // Cancel button at the bottom
                Button("Cancel Routine") {
                    showingCancelAlert = true
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding()
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Cancel Routine?", isPresented: $showingCancelAlert) {
            Button("Continue", role: .cancel) { }
            Button("Cancel Routine", role: .destructive) {
                cancelRoutine()
            }
        } message: {
            Text("Your progress will be lost.")
        }
    }
    
    private func startRoutineSession() {
        let session = RoutineSession(
            routineId: routine.id,
            routineName: routine.name
        )
        routineSession = session
        // Note: Session is not persisted to SwiftData in watch app - only sent to iOS
    }
    
    private func completeHabit(_ habit: Habit) {
        guard !completedHabits.contains(habit.id) else { return }
        
        completedHabits.insert(habit.id)
        
        let completion = HabitCompletion(
            habitId: habit.id,
            habitName: habit.name
        )
        
        if var session = routineSession {
            session.habitCompletions.append(completion)
            routineSession = session
        }
        
        // Auto-advance to next habit
        if currentHabitIndex < routine.habits.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    currentHabitIndex += 1
                }
            }
        }
    }
    
    private func skipHabit(_ habit: Habit) {
        guard !completedHabits.contains(habit.id) else { return }
        
        completedHabits.insert(habit.id)
        
        let completion = HabitCompletion(
            habitId: habit.id,
            habitName: habit.name,
            wasSkipped: true
        )
        
        if var session = routineSession {
            session.habitCompletions.append(completion)
            routineSession = session
        }
        
        // Auto-advance to next habit
        if currentHabitIndex < routine.habits.count - 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    currentHabitIndex += 1
                }
            }
        }
    }
    
    private func finishRoutine() {
        guard var session = routineSession else { return }
        
        session.completedAt = Date()
        session.isCompleted = true
        routineSession = session
        
        do {
            try modelContext.save()
            
            // Send completion to iOS
            WatchConnectivityManager.shared.sendCompletionToiOS(session)
            
            showingCompletionView = true
        } catch {
            print("Error saving routine session: \(error)")
        }
    }
    
    private func cancelRoutine() {
        // Clean up any partial session data
        if var session = routineSession {
            // Mark session as cancelled/incomplete
            session.completedAt = Date()
            session.isCompleted = false
            
            // Add a completion note indicating it was cancelled
            let cancelCompletion = HabitCompletion(
                habitId: UUID(),
                habitName: "Routine Cancelled",
                completedAt: Date(),
                notes: "User cancelled routine after \(completedHabits.count) of \(routine.habits.count) habits",
                wasSkipped: true
            )
            session.habitCompletions.append(cancelCompletion)
            routineSession = session
            
            do {
                try modelContext.save()
                print("Routine cancelled and session saved")
            } catch {
                print("Error saving cancelled session: \(error)")
            }
        }
        
        // Dismiss the view
        dismiss()
    }
}

struct HabitView: View {
    let habit: Habit
    let isCompleted: Bool
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Habit Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: habit.iconName)
                        .font(.title2)
                        .foregroundColor(habit.swiftUIColor)
                    
                    Spacer()
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                
                Text(habit.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let notes = habit.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Habit-specific content
            habitSpecificContent
            
            Spacer()
            
            // Action Buttons
            if !isCompleted {
                VStack(spacing: 8) {
                    Button("Complete") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if habit.isOptional {
                        Button("Skip") {
                            onSkip()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var habitSpecificContent: some View {
        switch habit.type {
        case .checkbox:
            Image(systemName: "checkmark.square")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
        case .timer(let duration):
            VStack {
                Image(systemName: "timer")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("\(Int(duration / 60)) min")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
        case .checkboxWithSubtasks(let subtasks):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(subtasks) { subtask in
                    HStack {
                        Image(systemName: "circle")
                            .font(.caption)
                        Text(subtask.name)
                            .font(.caption)
                    }
                }
            }
            
        case .counter(let items):
            VStack {
                Image(systemName: "list.bullet")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
        default:
            Image(systemName: habit.iconName)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
        }
    }
}

struct CompletionView: View {
    let session: RoutineSession
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Routine Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(session.routineName)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Completed:")
                    Spacer()
                    Text("\(session.habitCompletions.filter { !$0.wasSkipped }.count)")
                }
                
                HStack {
                    Text("Skipped:")
                    Spacer()
                    Text("\(session.habitCompletions.filter { $0.wasSkipped }.count)")
                }
                
                if let duration = session.completedAt?.timeIntervalSince(session.startedAt) {
                    HStack {
                        Text("Duration:")
                        Spacer()
                        Text("\(Int(duration / 60)) min")
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationBarHidden(true)
    }
}

#if DEBUG
struct RoutineExecutionView_Previews: PreviewProvider {
    static var previews: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: PersistedRoutineTemplate.self, configurations: config)
        
        let sampleRoutine = RoutineTemplate(
            name: "Morning Routine",
            description: "My daily morning habits",
            habits: [
                Habit(name: "Drink Water", type: .checkbox),
                Habit(name: "Meditation", type: .timer(defaultDuration: 600)),
                Habit(name: "Exercise", type: .checkboxWithSubtasks(subtasks: [
                    Subtask(name: "Warm up"),
                    Subtask(name: "Main workout"),
                    Subtask(name: "Cool down")
                ]))
            ]
        )
        
        return NavigationStack {
            RoutineExecutionView(routine: sampleRoutine)
        }
        .modelContainer(container)
    }
}
#endif