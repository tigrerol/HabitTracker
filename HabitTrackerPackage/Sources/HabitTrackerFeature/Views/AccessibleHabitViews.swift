import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Example enhanced habit views with comprehensive accessibility support
/// These demonstrate how to implement accessibility across different habit types

// MARK: - Accessible Checkbox Habit View

struct AccessibleCheckboxHabitView: View {
    let habit: Habit
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    var body: some View {
        ModernCard(style: isCompleted ? .elevated : .standard) {
            VStack(spacing: 16) {
                // Habit Info Header
                HStack {
                    Image(systemName: habit.type.iconName)
                        .font(.title2)
                        .foregroundColor(habit.swiftUIColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(habit.swiftUIColor.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .customHeadline()
                            .lineLimit(2)
                        
                        Text(habit.type.description)
                            .customCaption()
                    }
                    
                    Spacer()
                }
                
                // Checkbox Button
                Button {
                    HapticManager.trigger(isCompleted ? .success : .medium)
                    onComplete(habit.id, nil, nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundStyle(isCompleted ? Theme.Colors.accentGreen : Theme.secondaryText)
                        
                        Text(isCompleted ?
                             String(localized: "HabitInteractionView.Checkbox.Completed", bundle: .module) :
                             String(localized: "HabitInteractionView.Checkbox.TapToComplete", bundle: .module))
                            .customSubheadline()
                            .foregroundColor(isCompleted ? Theme.Colors.accentGreen : Theme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCompleted ? Theme.Colors.accentGreen.opacity(0.1) : Color.gray.opacity(0.05))
                    )
                }
                .accessibilityButton(
                    identifier: AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: habit.id),
                    label: AccessibilityConfiguration.Labels.checkboxHabit(
                        habitName: habit.name,
                        isCompleted: isCompleted
                    ),
                    hint: AccessibilityConfiguration.Hints.doubleTapToComplete,
                    traits: AccessibilityConfiguration.habitCardTraits
                )
                .disabled(isCompleted)
                .buttonStyle(ScaleButtonStyle())
                .sensoryFeedback(.selection, trigger: isCompleted)
            }
        }
    }
}

// MARK: - Accessible Timer Habit View

struct AccessibleTimerHabitView: View {
    let habit: Habit
    let defaultDuration: TimeInterval
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    
    @State private var timeRemaining: TimeInterval
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var startTime: Date?
    
    init(habit: Habit, defaultDuration: TimeInterval, onComplete: @escaping (UUID, TimeInterval?, String?) -> Void) {
        self.habit = habit
        self.defaultDuration = defaultDuration
        self.onComplete = onComplete
        self._timeRemaining = State(initialValue: defaultDuration)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Timer display
            Text(timeRemaining.formattedDuration)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(timeRemaining <= 30 ? .red : .primary)
                .accessibilityLabel("Time remaining: \(timeRemaining.formattedAccessibleDuration)")
                .accessibilityAddTraits(.updatesFrequently)
            
            // Timer controls
            HStack(spacing: 20) {
                // Start/Pause button
                Button {
                    if isRunning {
                        pauseTimer()
                    } else {
                        startTimer()
                    }
                } label: {
                    Label(
                        isRunning ? "Pause" : "Start",
                        systemImage: isRunning ? "pause.fill" : "play.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(isRunning ? Color.orange : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityButton(
                    identifier: isRunning ? 
                        AccessibilityConfiguration.Identifiers.timerStopButton(habitId: habit.id) :
                        AccessibilityConfiguration.Identifiers.timerStartButton(habitId: habit.id),
                    label: AccessibilityConfiguration.Labels.timerButton(
                        habitName: habit.name,
                        isRunning: isRunning
                    ),
                    hint: isRunning ? 
                        AccessibilityConfiguration.Hints.doubleTapToStopTimer :
                        AccessibilityConfiguration.Hints.doubleTapToStartTimer,
                    traits: AccessibilityConfiguration.timerButtonTraits
                )
                
                    
                    // Complete early button (only show when running)
                    if isRunning {
                        IconButton(
                            icon: "checkmark.circle.fill",
                            title: "Complete",
                            style: .secondary
                        ) {
                            completeEarly()
                        }
                        .accessibilityButton(
                            identifier: AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: habit.id),
                            label: AccessibilityConfiguration.Labels.completeHabitButton(habitName: habit.name),
                            hint: AccessibilityConfiguration.Hints.doubleTapToComplete
                        )
                    }
            }
        }
        .padding()
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        isRunning = true
        startTime = Date()
        
        // Haptic feedback for timer start
        HapticManager.trigger(.medium)
        
        // Start Live Activity if available
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                await LiveActivityManager.shared.startTimerActivity(
                    for: habit,
                    duration: defaultDuration,
                    startTime: Date()
                )
            }
        }
        #endif
        
        // Announce start to VoiceOver
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.timerStarted(habitName: habit.name)
        )
        #endif
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    
                    // Update Live Activity every 5 seconds or when near completion
                    let currentProgress = 1.0 - (timeRemaining / defaultDuration)
                    if Int(timeRemaining) % 5 == 0 || timeRemaining <= 30 {
                        #if canImport(ActivityKit)
                        if #available(iOS 16.1, *) {
                            await LiveActivityManager.shared.updateTimerActivity(
                                for: habit.id.uuidString,
                                currentProgress: currentProgress,
                                timeRemaining: timeRemaining,
                                isRunning: true
                            )
                        }
                        #endif
                    }
                } else {
                    timerFinished()
                }
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        // Haptic feedback for timer pause
        HapticManager.trigger(.light)
        
        // Update Live Activity to paused state
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                let currentProgress = 1.0 - (timeRemaining / defaultDuration)
                await LiveActivityManager.shared.updateTimerActivity(
                    for: habit.id.uuidString,
                    currentProgress: currentProgress,
                    timeRemaining: timeRemaining,
                    isRunning: false
                )
            }
        }
        #endif
        
        // Announce pause to VoiceOver
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.routinePaused
        )
        #endif
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerFinished() {
        stopTimer()
        isRunning = false
        
        // Calculate actual duration
        let actualDuration = startTime?.timeIntervalSinceNow.magnitude ?? defaultDuration
        
        // Provide completion feedback
        HapticManager.trigger(.success)
        
        // Complete Live Activity
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                await LiveActivityManager.shared.completeTimerActivity(
                    for: habit.id.uuidString,
                    actualDuration: actualDuration
                )
            }
        }
        #endif
        
        // Announce completion to VoiceOver
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.timerStopped(
                habitName: habit.name,
                duration: actualDuration.formattedDuration
            )
        )
        #endif
        
        onComplete(habit.id, actualDuration, nil)
    }
    
    private func completeEarly() {
        let actualDuration = startTime?.timeIntervalSinceNow.magnitude ?? (defaultDuration - timeRemaining)
        stopTimer()
        isRunning = false
        
        // Haptic feedback for early completion
        HapticManager.trigger(.success)
        
        // Complete Live Activity
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            Task {
                await LiveActivityManager.shared.completeTimerActivity(
                    for: habit.id.uuidString,
                    actualDuration: actualDuration
                )
            }
        }
        #endif
        
        // Announce early completion
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.habitCompleted(habitName: habit.name)
        )
        #endif
        
        onComplete(habit.id, actualDuration, "Completed early")
    }
}

// MARK: - Accessible Counter Habit View

struct AccessibleCounterHabitView: View {
    let habit: Habit
    let items: [String]
    let onComplete: (UUID, TimeInterval?, String?) -> Void
    let isCompleted: Bool
    
    @State private var completedItems: Set<Int> = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress summary
            Text(String(format: String(localized: "HabitInteractionView.Counter.CompletedItems", bundle: .module), 
                       completedItems.count, items.count))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Progress: \(completedItems.count) of \(items.count) items completed")
            
            // Items list
            LazyVStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Button {
                            toggleItem(index)
                        } label: {
                            HStack {
                                Image(systemName: completedItems.contains(index) ? 
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(completedItems.contains(index) ? .green : .secondary)
                                
                                Text(item)
                                    .strikethrough(completedItems.contains(index))
                                    .foregroundStyle(completedItems.contains(index) ? .secondary : .primary)
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityButton(
                            identifier: AccessibilityConfiguration.Identifiers.counterItem(index: index),
                            label: AccessibilityConfiguration.Labels.counterHabit(
                                habitName: habit.name,
                                itemName: item,
                                count: completedItems.contains(index) ? 1 : 0
                            ),
                            hint: completedItems.contains(index) ? 
                                "Double tap to mark as incomplete" :
                                "Double tap to mark as complete"
                        )
                    }
                }
            }
            
            // Complete button
            if completedItems.count == items.count && items.count > 0 {
                Button {
                    completeHabit()
                } label: {
                    Text(String(localized: "HabitInteractionView.Complete.Button", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityButton(
                    identifier: AccessibilityConfiguration.Identifiers.completeHabitButton(habitId: habit.id),
                    label: AccessibilityConfiguration.Labels.completeHabitButton(habitName: habit.name),
                    hint: AccessibilityConfiguration.Hints.doubleTapToComplete
                )
            }
        }
        .padding()
    }
    
    private func toggleItem(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if completedItems.contains(index) {
                completedItems.remove(index)
            } else {
                completedItems.insert(index)
            }
        }
        
        // Provide haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        // Announce the change
        let itemName = items[index]
        let isCompleted = completedItems.contains(index)
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: "\(itemName) marked as \(isCompleted ? "complete" : "incomplete")"
        )
        #endif
    }
    
    private func completeHabit() {
        let completedItemNames = completedItems.compactMap { index in
            index < items.count ? items[index] : nil
        }
        
        // Announce completion
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: AccessibilityConfiguration.Announcements.habitCompleted(habitName: habit.name)
        )
        #endif
        
        onComplete(habit.id, nil, "Completed items: \(completedItemNames.joined(separator: ", "))")
    }
}

// MARK: - Extensions for Formatted Duration

extension TimeInterval {
    var formattedAccessibleDuration: String {
        guard self.isFinite, !self.isNaN else {
            return "0 seconds"
        }
        let duration = max(0, self)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes) minutes and \(seconds) seconds"
        } else {
            return "\(seconds) seconds"
        }
    }
}