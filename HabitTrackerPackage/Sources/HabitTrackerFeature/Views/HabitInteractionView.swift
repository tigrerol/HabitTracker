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
                
            case .timer(let defaultDuration):
                TimerHabitView(habit: habit, defaultDuration: defaultDuration, onComplete: onComplete)
                
            case .appLaunch(let bundleId, let appName):
                AppLaunchHabitView(habit: habit, bundleId: bundleId, appName: appName, onComplete: onComplete)
                
            case .website(let url, let title):
                WebsiteHabitView(habit: habit, url: url, title: title, onComplete: onComplete)
                
            case .counter(let items):
                CounterHabitView(habit: habit, items: items, onComplete: onComplete)
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
                    
                    Text(isCompleting ? "Completed!" : "Tap to Complete")
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
                
                ProgressView(value: 1.0 - (timeRemaining / defaultDuration))
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
                                Text("Start")
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
                                Text(isPaused ? "Resume" : "Pause")
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
                    Text("Mark Complete Early")
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
            onComplete(seconds, "Quick \(label) completion")
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
        onComplete(elapsed, "Stopped early")
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
    let bundleId: String
    let appName: String
    let onComplete: (TimeInterval?, String?) -> Void
    
    @State private var hasLaunchedApp = false
    @State private var startTime: Date?
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "app.badge")
                    .font(.system(size: 60))
                    .foregroundStyle(habit.swiftUIColor)
                
                if hasLaunchedApp {
                    Text("Return here when finished with \(appName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap to launch \(appName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !hasLaunchedApp {
                Button {
                    launchApp()
                } label: {
                    Text("Launch \(appName)")
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
                    Text("I'm Done")
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
        guard let url = URL(string: bundleId) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            hasLaunchedApp = true
            startTime = Date()
            UIApplication.shared.open(url)
        } else {
            // Fallback to App Store or show error
            // For now, just mark as launched
            hasLaunchedApp = true
            startTime = Date()
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
                    Text("Return here when finished with \(title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Tap to open \(title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !hasOpenedWebsite {
                Button {
                    openWebsite()
                } label: {
                    Text("Open \(title)")
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
                    Text("I'm Done")
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
                Text("\(completedItems.count) of \(items.count) completed")
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
                let notes = completedItems.isEmpty ? "No items completed" : "Completed: \(Array(completedItems).joined(separator: ", "))"
                onComplete(nil, notes)
            } label: {
                Text("Complete")
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