import SwiftUI

/// View that handles different types of habit interactions
public struct HabitInteractionView: View {
    let habit: Habit
    let onComplete: (TimeInterval?, String?) -> Void
    
    public init(habit: Habit, onComplete: @escaping (TimeInterval?, String?) -> Void) {
        self.habit = habit
        self.onComplete = onComplete
    }
    
    public var body: some View {
        Group {
            switch habit.type {
            case .checkbox:
                CheckboxHabitView(habit: habit, onComplete: onComplete)
                
            case .checkboxWithSubtasks(let subtasks):
                SubtasksHabitView(habit: habit, subtasks: subtasks, onComplete: onComplete)
                
            case .timer(let defaultDuration):
                TimerHabitView(habit: habit, defaultDuration: defaultDuration, onComplete: onComplete)
                
            case .restTimer(let targetDuration):
                RestTimerHabitView(habit: habit, targetDuration: targetDuration, onComplete: onComplete)
                
            case .appLaunch(let bundleId, let appName):
                AppLaunchHabitView(habit: habit, bundleId: bundleId, appName: appName, onComplete: onComplete)
                
            case .website(let url, let title):
                WebsiteHabitView(habit: habit, url: url, title: title, onComplete: onComplete)
                
            case .counter(let items):
                CounterHabitView(habit: habit, items: items, onComplete: onComplete)
                
            case .measurement(let unit, let targetValue):
                MeasurementHabitView(habit: habit, unit: unit, targetValue: targetValue, onComplete: onComplete)
                
            case .guidedSequence(let steps):
                GuidedSequenceHabitView(habit: habit, steps: steps, onComplete: onComplete)
                
            case .conditional(let info):
                ConditionalHabitInteractionView(
                    habit: habit,
                    conditionalInfo: info,
                    onOptionSelected: { option in
                        // Note: The actual path injection is handled by RoutineService
                        // This just marks the conditional habit as complete
                        onComplete(nil, String(localized: "HabitInteractionView.Question.Selected", bundle: .module).replacingOccurrences(of: "%@", with: option.text))
                    },
                    onSkip: {
                        onComplete(nil, String(localized: "HabitInteractionView.Question.Skipped", bundle: .module))
                    }
                )
            }
        }
    }
}

/// Simple checkbox habit interaction with quick actions
struct CheckboxHabitView: View {
    let habit: Habit
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var isCompleting = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Large tap target for quick completion
            Button {
                completeHabit()
            } label: {
                VStack(spacing: 16) {
                    Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 80))
                        .foregroundStyle(isCompleting ? .green : habit.swiftUIColor)
                        .scaleEffect(isCompleting ? 1.2 : 1.0)
                    
                    Text(isCompleting ? String(localized: "HabitInteractionView.Checkbox.Completed", bundle: .module) : String(localized: "HabitInteractionView.Checkbox.TapToComplete", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(isCompleting ? .green : .primary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .stroke(isCompleting ? .green : habit.swiftUIColor.opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .disabled(isCompleting)
            
            if let notes = habit.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private func completeHabit() {
        withAnimation(.bouncy) {
            isCompleting = true
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Complete after brief delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete(nil, nil)
        }
    }
}

/// Timer-based habit interaction
struct TimerHabitView: View {
    let habit: Habit
    let defaultDuration: TimeInterval
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var timeRemaining: TimeInterval
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?
    
    init(habit: Habit, defaultDuration: TimeInterval, onComplete: @escaping (TimeInterval?, String?) -> Void) {
        self.habit = habit
        self.defaultDuration = defaultDuration
        self.onComplete = onComplete
        self._timeRemaining = State(initialValue: defaultDuration)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Timer display
            VStack(spacing: 8) {
                Text(timeRemaining.formattedMinutesSeconds)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(habit.swiftUIColor)
                
                ProgressView(value: defaultDuration > 0 ? max(0, min(1, 1.0 - (timeRemaining / defaultDuration))) : 0)
                    .tint(habit.swiftUIColor)
                    .scaleEffect(y: 3)
            }
            
            // Timer controls with quick actions
            VStack(spacing: 16) {
                if !isRunning {
                    HStack(spacing: 12) {
                        Button {
                            startTimer()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(String(localized: "HabitInteractionView.Timer.Start", bundle: .module))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Quick timer shortcuts
                    HStack(spacing: 8) {
                        quickTimerButton(seconds: 30, label: "30s")
                        quickTimerButton(seconds: 60, label: "1m")
                        quickTimerButton(seconds: 120, label: "2m")
                    }
                    .opacity(0.8)
                } else {
                    HStack(spacing: 12) {
                        Button {
                            if isPaused {
                                resumeTimer()
                            } else {
                                pauseTimer()
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                Text(isPaused ? String(localized: "HabitInteractionView.Timer.Resume", bundle: .module) : String(localized: "HabitInteractionView.Timer.Pause", bundle: .module))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            stopTimer()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(.red, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            
            // Manual completion
            if timeRemaining > 0 {
                Button {
                    let elapsed = defaultDuration - timeRemaining
                    onComplete(elapsed, nil)
                } label: {
                    Text(String(localized: "HabitInteractionView.Timer.MarkCompleteEarly", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    @ViewBuilder
    private func quickTimerButton(seconds: TimeInterval, label: String) -> some View {
        Button {
            onComplete(seconds, String(localized: "HabitInteractionView.Timer.QuickCompletion", bundle: .module).replacingOccurrences(of: "%@", with: label))
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private func startTimer() {
        isRunning = true
        isPaused = false
        createTimer()
    }
    
    private func pauseTimer() {
        isPaused = true
        timer?.invalidate()
    }
    
    private func resumeTimer() {
        isPaused = false
        createTimer()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        let elapsed = defaultDuration - timeRemaining
        onComplete(elapsed, String(localized: "HabitInteractionView.Timer.StoppedEarly", bundle: .module))
    }
    
    private func createTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    timer?.invalidate()
                    onComplete(defaultDuration, nil)
                }
            }
        }
    }
}

/// App launch habit interaction
struct AppLaunchHabitView: View {
    let habit: Habit
    let bundleId: String  // This will now be either a shortcut name or URL scheme
    let appName: String
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var hasLaunchedApp = false
    @State private var startTime: Date?
    
    private var isShortcut: Bool {
        // Check if this is a shortcut (doesn't contain :// URL scheme format)
        !bundleId.contains("://")
    }
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: isShortcut ? "shortcuts" : "app.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(habit.swiftUIColor)
                
                if hasLaunchedApp {
                    Text(String(localized: "HabitInteractionView.AppLaunch.ReturnWhenFinished", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(isShortcut ? String(localized: "HabitInteractionView.AppLaunch.TapToRunShortcut", bundle: .module) : String(localized: "HabitInteractionView.AppLaunch.TapToLaunch", bundle: .module).replacingOccurrences(of: "%@", with: appName))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !hasLaunchedApp {
                Button {
                    launchApp()
                } label: {
                    Text(isShortcut ? String(localized: "HabitInteractionView.AppLaunch.RunShortcut", bundle: .module) : String(localized: "HabitInteractionView.AppLaunch.Launch", bundle: .module).replacingOccurrences(of: "%@", with: appName))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    let duration = startTime.map { Date().timeIntervalSince($0) }
                    onComplete(duration, nil)
                } label: {
                    Text(String(localized: "HabitInteractionView.AppLaunch.ImDone", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func launchApp() {
        let urlString: String
        
        if isShortcut {
            // Format as shortcuts URL scheme
            let encodedShortcutName = bundleId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bundleId
            urlString = "shortcuts://run-shortcut?name=\(encodedShortcutName)"
        } else {
            // Use the provided URL scheme directly
            urlString = bundleId
        }
        
        guard let url = URL(string: urlString) else {
            print("Failed to create URL from: \(urlString)")
            return
        }
        
        hasLaunchedApp = true
        startTime = Date()
        UIApplication.shared.open(url) { success in
            if !success {
                print("Failed to open URL: \(urlString)")
            }
        }
    }
}

/// Website habit interaction
struct WebsiteHabitView: View {
    let habit: Habit
    let url: URL
    let title: String
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var hasOpenedWebsite = false
    @State private var startTime: Date?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "safari")
                    .font(.system(size: 60))
                    .foregroundStyle(habit.swiftUIColor)
                
                if hasOpenedWebsite {
                    Text(String(localized: "HabitInteractionView.Website.ReturnWhenFinished", bundle: .module).replacingOccurrences(of: "%@", with: title))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(String(localized: "HabitInteractionView.Website.TapToOpen", bundle: .module).replacingOccurrences(of: "%@", with: title))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !hasOpenedWebsite {
                Button {
                    openWebsite()
                } label: {
                    Text(String(localized: "HabitInteractionView.Website.Open", bundle: .module).replacingOccurrences(of: "%@", with: title))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    let duration = startTime.map { Date().timeIntervalSince($0) }
                    onComplete(duration, nil)
                } label: {
                    Text(String(localized: "HabitInteractionView.AppLaunch.ImDone", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func openWebsite() {
        hasOpenedWebsite = true
        startTime = Date()
        UIApplication.shared.open(url)
    }
}

/// Counter habit interaction (e.g., supplements)
struct CounterHabitView: View {
    let habit: Habit
    let items: [String]
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var completedItems: Set<String> = []
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text(String(format: String(localized: "HabitInteractionView.Counter.CompletedItems", bundle: .module), completedItems.count, items.count))
                    .font(.headline)
                    .foregroundStyle(habit.swiftUIColor)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            if completedItems.contains(item) {
                                completedItems.remove(item)
                            } else {
                                completedItems.insert(item)
                            }
                        } label: {
                            HStack {
                                Image(systemName: completedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completedItems.contains(item) ? .green : .secondary)
                                
                                Text(item)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.regularMaterial)
                                    .stroke(
                                        completedItems.contains(item) ? .green : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Button {
                let notes = completedItems.isEmpty ? String(localized: "HabitInteractionView.Counter.NoItemsCompleted", bundle: .module) : String(localized: "HabitInteractionView.Counter.CompletedList", bundle: .module).replacingOccurrences(of: "%@", with: Array(completedItems).joined(separator: ", "))
                onComplete(nil, notes)
            } label: {
                Text(String(localized: "HabitInteractionView.Complete.Button", bundle: .module))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (completedItems.count == items.count ? habit.swiftUIColor : .gray),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
        }
    }
}

// Helper extension for time formatting
extension TimeInterval {
    var formattedMinutesSeconds: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Subtasks habit interaction
struct SubtasksHabitView: View {
    let habit: Habit
    let subtasks: [Subtask]
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var completedSubtasks: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(subtasks) { subtask in
                    Button {
                        withAnimation(.easeInOut) {
                            if completedSubtasks.contains(subtask.id) {
                                completedSubtasks.remove(subtask.id)
                            } else {
                                completedSubtasks.insert(subtask.id)
                                
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: completedSubtasks.contains(subtask.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(completedSubtasks.contains(subtask.id) ? .green : .secondary)
                            
                            Text(subtask.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .strikethrough(completedSubtasks.contains(subtask.id))
                            
                            Spacer()
                            
                            if subtask.isOptional {
                                Text(String(localized: "HabitInteractionView.Optional.Label", bundle: .module))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.regularMaterial, in: Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.regularMaterial)
                                .stroke(completedSubtasks.contains(subtask.id) ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button {
                let notes = "Completed \(completedSubtasks.count) of \(subtasks.count) subtasks"
                onComplete(nil, notes)
            } label: {
                Text(String(localized: "HabitInteractionView.Complete.Button", bundle: .module))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (completedSubtasks.count == subtasks.filter { !$0.isOptional }.count ? habit.swiftUIColor : .gray),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(completedSubtasks.count < subtasks.filter { !$0.isOptional }.count)
        }
    }
}

/// Rest timer habit interaction (counts up)
struct RestTimerHabitView: View {
    let habit: Habit
    let targetDuration: TimeInterval?
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            // Timer display
            VStack(spacing: 8) {
                Text(elapsedTime.formattedMinutesSeconds)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(habit.swiftUIColor)
                
                if let target = targetDuration {
                    ProgressView(value: target > 0 ? max(0, min(1, elapsedTime / target)) : 0)
                        .tint(habit.swiftUIColor)
                        .scaleEffect(y: 3)
                    
                    Text(String(localized: "HabitInteractionView.RestTimer.Target", bundle: .module).replacingOccurrences(of: "%@", with: target.formattedMinutesSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Controls
            HStack(spacing: 12) {
                if !isRunning {
                    Button {
                        startTimer()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(String(localized: "HabitInteractionView.RestTimer.StartRest", bundle: .module))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button {
                        stopTimer()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text(String(localized: "HabitInteractionView.RestTimer.EndRest", bundle: .module))
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedTime += 1
                
                // Auto-complete at target if set
                if let target = targetDuration, elapsedTime >= target {
                    stopTimer()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        isRunning = false
        onComplete(elapsedTime, targetDuration != nil ? "Target \(elapsedTime >= targetDuration! ? "reached" : "not reached")" : nil)
    }
}

/// Measurement input habit
struct MeasurementHabitView: View {
    let habit: Habit
    let unit: String
    let targetValue: Double?
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var inputValue: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(String(localized: "HabitInteractionView.Measurement.Enter", bundle: .module).replacingOccurrences(of: "%@", with: unit))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("0", text: $inputValue)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .focused($isInputFocused)
                    
                    Text(unit)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                
                if let target = targetValue {
                    Text("Target: \(target, specifier: "%.1f") \(unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                if let value = Double(inputValue) {
                    let notes = targetValue != nil ? "Measured: \(value) \(unit) (target: \(targetValue!))" : "Measured: \(value) \(unit)"
                    onComplete(nil, notes)
                }
            } label: {
                Text(String(localized: "HabitInteractionView.Measurement.Record", bundle: .module))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        inputValue.isEmpty ? .gray : habit.swiftUIColor,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .disabled(inputValue.isEmpty)
        }
        .onAppear {
            isInputFocused = true
        }
    }
}


/// Guided sequence habit
struct GuidedSequenceHabitView: View {
    let habit: Habit
    let steps: [SequenceStep]
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var currentStepIndex = 0
    @State private var timeRemaining: TimeInterval = 0
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var totalElapsed: TimeInterval = 0
    
    private var currentStep: SequenceStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if let step = currentStep {
                // Step info
                VStack(spacing: 8) {
                    Text(String(format: String(localized: "HabitInteractionView.Sequence.StepProgress", bundle: .module), currentStepIndex + 1, steps.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(step.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    if let instructions = step.instructions {
                        Text(instructions)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Timer display
                VStack(spacing: 8) {
                    Text(timeRemaining.formattedMinutesSeconds)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(habit.swiftUIColor)
                    
                    ProgressView(value: step.duration > 0 ? max(0, min(1, 1.0 - (timeRemaining / step.duration))) : 0)
                        .tint(habit.swiftUIColor)
                        .scaleEffect(y: 3)
                }
                
                // Controls
                HStack(spacing: 12) {
                    if !isRunning {
                        Button {
                            startStep()
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(String(localized: "HabitInteractionView.Timer.Start", bundle: .module))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button {
                            if isPaused {
                                resumeStep()
                            } else {
                                pauseStep()
                            }
                        } label: {
                            HStack {
                                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                Text(isPaused ? String(localized: "HabitInteractionView.Timer.Resume", bundle: .module) : String(localized: "HabitInteractionView.Timer.Pause", bundle: .module))
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(habit.swiftUIColor, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button {
                        nextStep()
                    } label: {
                        Text(String(localized: "HabitInteractionView.Sequence.Skip", bundle: .module))
                            .font(.headline)
                            .foregroundStyle(.orange)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                // Completion view
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    
                    Text(String(localized: "HabitInteractionView.Sequence.Complete", bundle: .module))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(String(localized: "HabitInteractionView.Sequence.TotalTime", bundle: .module).replacingOccurrences(of: "%@", with: totalElapsed.formattedMinutesSeconds))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        onComplete(totalElapsed, "Completed all \(steps.count) steps")
                    } label: {
                        Text(String(localized: "HabitInteractionView.Sequence.Done", bundle: .module))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .onAppear {
            if let firstStep = currentStep {
                timeRemaining = firstStep.duration
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startStep() {
        isRunning = true
        isPaused = false
        createTimer()
    }
    
    private func pauseStep() {
        isPaused = true
        timer?.invalidate()
    }
    
    private func resumeStep() {
        isPaused = false
        createTimer()
    }
    
    private func nextStep() {
        timer?.invalidate()
        
        // Add elapsed time
        if let step = currentStep {
            totalElapsed += step.duration - timeRemaining
        }
        
        // Move to next
        currentStepIndex += 1
        if let nextStep = currentStep {
            timeRemaining = nextStep.duration
            isRunning = false
            isPaused = false
        }
    }
    
    private func createTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    // Auto advance to next step
                    nextStep()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        HabitInteractionView(
            habit: Habit(name: "Test Timer", type: .timer(defaultDuration: 300))
        ) { _, _ in }
        
        HabitInteractionView(
            habit: Habit(name: "Test Counter", type: .counter(items: ["Item 1", "Item 2", "Item 3"]))
        ) { _, _ in }
    }
}