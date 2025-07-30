import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// View that handles different types of habit interactions using protocol-based handlers
public struct HabitInteractionView: View {
    let habit: Habit
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @Environment(RoutineService.self) private var routineService
    
    public init(habit: Habit, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.onComplete = onComplete
        self.isCompleted = isCompleted
    }
    
    public var body: some View {
        // Use protocol-based handlers for better maintainability
        switch habit.type {
            case .task(let subtasks):
                if subtasks.isEmpty {
                    AnyView(CheckboxHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                } else {
                    AnyView(SubtasksHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                }
                
            case .timer:
                AnyView(TimerHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .appLaunch:
                AnyView(AppLaunchHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .website:
                AnyView(WebsiteHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .counter:
                AnyView(CounterHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .measurement:
                AnyView(MeasurementHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .guidedSequence:
                AnyView(GuidedSequenceHabitHandler().createInteractionView(habit: habit, onComplete: self.onComplete, isCompleted: isCompleted))
                
            case .conditional(let info):
                AnyView(ConditionalHabitInteractionView(
                    habit: habit,
                    conditionalInfo: info,
                    onOptionSelected: { option in
                        routineService.handleConditionalOptionSelection(
                            option: option,
                            for: habit.id,
                            question: info.question
                        )
                    },
                    onSkip: {
                        routineService.skipConditionalHabit(habitId: habit.id, question: info.question)
                        routineService.currentSession?.completeCurrentHabit(
                            duration: nil,
                            notes: String(localized: "HabitInteractionView.Question.Skipped", bundle: .module)
                        )
                    }
                ))
            }
    }
}

/// Simple checkbox habit interaction with quick actions
struct CheckboxHabitView: View {
    let habit: Habit
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var isCompleting = false
    
    init(habit: Habit, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.onComplete = onComplete
        self.isCompleted = isCompleted
    }
    
    var body: some View {
        VStack(spacing: AppConstants.Spacing.extraLarge) {
            // Large tap target for quick completion
            Button {
                completeHabit()
            } label: {
                VStack(spacing: AppConstants.Spacing.large) {
                    Image(systemName: isCompleting ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: AppConstants.FontSizes.extraLargeIcon))
                        .foregroundStyle(isCompleting ? .green : habit.swiftUIColor)
                        .scaleEffect(isCompleting ? 1.2 : 1.0)
                    
                    Text(isCompleting ? String(localized: "HabitInteractionView.Checkbox.Completed", bundle: .module) : String(localized: "HabitInteractionView.Checkbox.TapToComplete", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(isCompleting ? .green : .primary)
                }
                .padding(.vertical, AppConstants.Padding.extraLarge)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.CornerRadius.large)
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
        .onAppear {
            // Reset completion state when view appears for a new habit
            isCompleting = false
        }
        .onChange(of: habit.id) { _, newHabitId in
            // Reset completion state when habit changes (critical for injection scenarios)
            isCompleting = false
        }
    }
    
    private func completeHabit() {
        withAnimation(.bouncy) {
            isCompleting = true
        }
        
        // Haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
        
        // Complete after brief delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.AnimationDurations.habitCompletion) {
            onComplete(habit.id, nil, nil)
        }
    }
}

/// Timer-based habit interaction
struct TimerHabitView: View {
    let habit: Habit
    let style: TimerStyle
    let duration: TimeInterval
    let target: TimeInterval?
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var timeRemaining: TimeInterval
    @State private var timeElapsed: TimeInterval = 0
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?
    
    init(habit: Habit, style: TimerStyle, duration: TimeInterval, target: TimeInterval? = nil, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.style = style
        self.duration = duration
        self.target = target
        self.onComplete = onComplete
        self.isCompleted = isCompleted
        
        // Initialize timer state based on style
        switch style {
        case .down:
            self._timeRemaining = State(initialValue: duration)
        case .up:
            self._timeRemaining = State(initialValue: 0)
        case .multiple:
            self._timeRemaining = State(initialValue: duration)
        }
    }
    
    // Computed properties for display
    private var displayTime: TimeInterval {
        switch style {
        case .down, .multiple:
            return timeRemaining
        case .up:
            return timeElapsed
        }
    }
    
    private var progressValue: Double {
        switch style {
        case .down:
            return duration > 0 ? max(0, min(1, 1.0 - (timeRemaining / duration))) : 0
        case .up:
            if let target = target {
                return target > 0 ? max(0, min(1, timeElapsed / target)) : 0
            } else {
                return 0 // No progress for open-ended count up
            }
        case .multiple:
            return duration > 0 ? max(0, min(1, 1.0 - (timeRemaining / duration))) : 0
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Timer display
            VStack(spacing: 8) {
                Text(displayTime.formattedMinutesSeconds)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(habit.swiftUIColor)
                
                ProgressView(value: progressValue)
                    .tint(habit.swiftUIColor)
                    .scaleEffect(y: 3)
                
                if let target = target, style == .up {
                    Text("Target: \(target.formattedMinutesSeconds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                    onComplete(habit.id, elapsed, nil)
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
            onComplete(habit.id, seconds, String(localized: "HabitInteractionView.Timer.QuickCompletion", bundle: .module).replacingOccurrences(of: "%@", with: label))
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
        
        let completedDuration: TimeInterval
        switch style {
        case .down, .multiple:
            completedDuration = duration - timeRemaining
        case .up:
            completedDuration = timeElapsed
        }
        
        onComplete(habit.id, completedDuration, String(localized: "HabitInteractionView.Timer.StoppedEarly", bundle: .module))
    }
    
    private func createTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                switch style {
                case .down, .multiple:
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    } else {
                        timer?.invalidate()
                        onComplete(habit.id, duration, nil)
                    }
                case .up:
                    timeElapsed += 1
                    timeRemaining = timeElapsed // For display consistency
                    
                    // Check if we've reached the target (if set)
                    if let target = target, timeElapsed >= target {
                        timer?.invalidate()
                        onComplete(habit.id, timeElapsed, nil)
                    }
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
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    
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
                    onComplete(habit.id, duration, nil)
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
        #if canImport(UIKit)
        UIApplication.shared.open(url) { success in
            if !success {
                print("Failed to open URL: \(urlString)")
            }
        }
        #endif
    }
}

/// Website habit interaction
struct WebsiteHabitView: View {
    let habit: Habit
    let url: URL
    let title: String
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var hasOpenedWebsite = false
    @State private var startTime: Date?
    
    init(habit: Habit, url: URL, title: String, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.url = url
        self.title = title
        self.onComplete = onComplete
        self.isCompleted = isCompleted
    }
    
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
                    onComplete(habit.id, duration, nil)
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
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

/// Counter habit interaction (e.g., supplements)
struct CounterHabitView: View {
    let habit: Habit
    let items: [String]
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    
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
                onComplete(habit.id, nil, notes)
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
        guard self.isFinite, !self.isNaN else {
            return "0:00"
        }
        let duration = max(0, self)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Subtasks habit interaction
struct SubtasksHabitView: View {
    let habit: Habit
    let subtasks: [Subtask]
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var completedSubtasks: Set<UUID> = []
    
    init(habit: Habit, subtasks: [Subtask], onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.subtasks = subtasks
        self.onComplete = onComplete
        self.isCompleted = isCompleted
    }
    
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
                                #if canImport(UIKit)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                #endif
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
            
            VStack(spacing: 12) {
                // Progress indicator
                if !subtasks.isEmpty {
                    let requiredCount = subtasks.filter { !$0.isOptional }.count
                    let completedRequiredCount = completedSubtasks.filter { id in 
                        subtasks.first { $0.id == id && !$0.isOptional } != nil 
                    }.count
                    
                    Text("Progress: \(completedRequiredCount)/\(requiredCount) required completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Complete button - enabled when all required subtasks are done
                Button {
                    let notes = "Completed \(completedSubtasks.count) of \(subtasks.count) subtasks"
                    onComplete(habit.id, nil, notes)
                } label: {
                    Text(String(localized: "HabitInteractionView.Complete.Button", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            (completedSubtasks.count >= subtasks.filter { !$0.isOptional }.count ? habit.swiftUIColor : .gray),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .disabled(completedSubtasks.count < subtasks.filter { !$0.isOptional }.count)
                
                // Skip option if user wants to complete without finishing all optional subtasks
                if (completedSubtasks.count >= subtasks.filter { !$0.isOptional }.count) && 
                   (completedSubtasks.count < subtasks.count) {
                    Button {
                        let notes = "Completed \(completedSubtasks.count) of \(subtasks.count) subtasks (skipped optional)"
                        onComplete(habit.id, nil, notes)
                    } label: {
                        Text("Complete with \(completedSubtasks.count) tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Rest timer habit interaction (counts up)
struct RestTimerHabitView: View {
    let habit: Habit
    let targetDuration: TimeInterval?
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    
    init(habit: Habit, targetDuration: TimeInterval?, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void, isCompleted: Bool) {
        self.habit = habit
        self.targetDuration = targetDuration
        self.onComplete = onComplete
        self.isCompleted = isCompleted
    }
    
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
        onComplete(habit.id, elapsedTime, targetDuration != nil ? "Target \(elapsedTime >= targetDuration! ? "reached" : "not reached")" : nil)
    }
}

/// Measurement input habit
struct MeasurementHabitView: View {
    let habit: Habit
    let unit: String
    let targetValue: Double?
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
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
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif
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
                    onComplete(habit.id, nil, notes)
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
            .disabled(inputValue.isEmpty || isCompleted)
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
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
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
                        onComplete(habit.id, totalElapsed, "Completed all \(steps.count) steps")
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
            habit: Habit(name: "Test Timer", type: .timer(style: .down, duration: 300)),
            onComplete: { habitId, duration, notes in },
            isCompleted: false
        )
        
        HabitInteractionView(
            habit: Habit(name: "Test Counter", type: .counter(items: ["Item 1", "Item 2", "Item 3"])),
            onComplete: { habitId, duration, notes in },
            isCompleted: false
        )
    }
}