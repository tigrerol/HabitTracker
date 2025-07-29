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
        ScrollView {
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
                if let currentHabit = currentHabit {
                    HabitView(
                        habit: currentHabit,
                        isCompleted: completedHabits.contains(currentHabit.id),
                        onComplete: {
                            completeHabit(currentHabit)
                            WKInterfaceDevice.current().play(.success) // Haptic feedback
                        },
                        onSkip: {
                            skipHabit(currentHabit)
                            WKInterfaceDevice.current().play(.failure) // Haptic feedback
                        }
                    )
                    .gesture(DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width < 0 { // Swipe left
                                if currentHabitIndex < routine.habits.count - 1 {
                                    withAnimation {
                                        currentHabitIndex += 1
                                    }
                                    WKInterfaceDevice.current().play(.click)
                                }
                            } else if value.translation.width > 0 { // Swipe right
                                if currentHabitIndex > 0 {
                                    withAnimation {
                                        currentHabitIndex -= 1
                                    }
                                    WKInterfaceDevice.current().play(.click)
                                }
                            }
                        }
                    )
                } else {
                    VStack {
                        Text("All habits completed!")
                            .font(.footnote)
                            .fontWeight(.semibold)
                        Text("Tap Finish to complete the routine")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer() // Pushes content to top
                
                // Navigation Controls
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation {
                                currentHabitIndex = max(0, currentHabitIndex - 1)
                            }
                            WKInterfaceDevice.current().play(.click) // Haptic feedback
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title)
                        }
                        .disabled(currentHabitIndex <= 0)
                        .buttonStyle(.bordered)
                        .opacity(currentHabitIndex <= 0 ? 0.3 : 1.0)
                        
                        Spacer()
                        
                        if currentHabitIndex >= routine.habits.count - 1 {
                            Button("Finish") {
                                finishRoutine()
                                WKInterfaceDevice.current().play(.success) // Haptic feedback for completion
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.caption)
                            .frame(height: 24)
                        } else {
                            Button {
                                withAnimation {
                                    currentHabitIndex = min(routine.habits.count - 1, currentHabitIndex + 1)
                                }
                                WKInterfaceDevice.current().play(.click) // Haptic feedback
                            } label: {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    
                    // Cancel button at the bottom
                    Button("Cancel") {
                        showingCancelAlert = true
                    }
                    .font(.caption2)
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
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
    
    @State private var showAllSubtasks: Bool = false
    @State private var showAllCounterItems: Bool = false
    @State private var scrollAmount: Double = 0.0
    
    var body: some View {
        VStack(spacing: 12) {
            // Habit Header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: habit.iconName)
                        .font(.body)
                        .foregroundColor(habit.swiftUIColor)
                    
                    Spacer()
                    
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                }
                
                Text(habit.name)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let notes = habit.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Habit-specific content
            ScrollView {
                habitSpecificContent
            }
            .focusable()
            .digitalCrownRotation($scrollAmount, from: 0, through: 100000, by: 1, sensitivity: .low, isContinuous: false)
            
            Spacer()
            
            // Action Buttons
            if !isCompleted {
                VStack(spacing: 6) {
                    Button("Complete") {
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    
                    if habit.isOptional {
                        Button("Skip") {
                            onSkip()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var habitSpecificContent: some View {
        switch habit.type {
        case .checkbox:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 24))
                    .foregroundColor(habit.swiftUIColor)
                
                Text("Tap Complete when done")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
        case .timer(let duration):
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 24))
                    .foregroundColor(habit.swiftUIColor)
                
                Text("\(Int(duration / 60)) minutes")
                    .font(.footnote)
                    .fontWeight(.medium)
                
                Text("Set a timer and complete when done")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
        case .checkboxWithSubtasks(let subtasks):
            VStack(alignment: .leading, spacing: 6) {
                Text("Complete these tasks:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                ForEach(showAllSubtasks ? subtasks : Array(subtasks.prefix(3))) { subtask in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundColor(habit.swiftUIColor)
                        Text(subtask.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                
                if subtasks.count > 3 {
                    Button(action: {
                        showAllSubtasks.toggle()
                    }) {
                        Text(showAllSubtasks ? "Show Less" : "... and \(subtasks.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                    }
                }
            }
            
        case .counter(let items):
            VStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 24))
                    .foregroundColor(habit.swiftUIColor)
                
                Text("\(items.count) items to track")
                    .font(.footnote)
                    .fontWeight(.medium)
                
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(showAllCounterItems ? items : Array(items.prefix(2)), id: \.self) { item in
                            Text("- \(item)")
                                .font(.caption2)
                                .foregroundColor(habit.swiftUIColor) // Ensure consistent coloring
                        }
                        
                        if items.count > 2 {
                            Button(action: {
                                showAllCounterItems.toggle()
                            }) {
                                Text(showAllCounterItems ? "Show Less" : "... and \(items.count - 2) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
            }
            
        default:
            VStack(spacing: 8) {
                Image(systemName: habit.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(habit.swiftUIColor)
                
                Text("Complete this habit")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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