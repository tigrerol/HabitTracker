import SwiftUI

/// Accessibility configuration constants and helpers for the HabitTracker app
public enum AccessibilityConfiguration {
    
    // MARK: - Accessibility Identifiers
    
    public enum Identifiers {
        // Main Navigation
        public static let routineExecutionView = "routine_execution_view"
        public static let routineBuilderView = "routine_builder_view"
        public static let settingsView = "settings_view"
        
        // Progress Elements
        public static let progressBar = "progress_bar"
        public static let progressText = "progress_text"
        public static let durationText = "duration_text"
        
        // Habit Interactions
        public static func habitInteractionView(habitId: UUID) -> String {
            "habit_interaction_\(habitId.uuidString)"
        }
        
        public static func completeHabitButton(habitId: UUID) -> String {
            "complete_habit_button_\(habitId.uuidString)"
        }
        
        public static func skipHabitButton(habitId: UUID) -> String {
            "skip_habit_button_\(habitId.uuidString)"
        }
        
        public static func habitCheckbox(habitId: UUID) -> String {
            "habit_checkbox_\(habitId.uuidString)"
        }
        
        public static func timerStartButton(habitId: UUID) -> String {
            "timer_start_button_\(habitId.uuidString)"
        }
        
        public static func timerStopButton(habitId: UUID) -> String {
            "timer_stop_button_\(habitId.uuidString)"
        }
        
        // Navigation Controls
        public static let previousHabitButton = "previous_habit_button"
        public static let nextHabitButton = "next_habit_button"
        public static let pauseRoutineButton = "pause_routine_button"
        public static let resumeRoutineButton = "resume_routine_button"
        
        // Template Management
        public static func templateCard(templateId: UUID) -> String {
            "template_card_\(templateId.uuidString)"
        }
        
        public static func editTemplateButton(templateId: UUID) -> String {
            "edit_template_button_\(templateId.uuidString)"
        }
        
        public static func deleteTemplateButton(templateId: UUID) -> String {
            "delete_template_button_\(templateId.uuidString)"
        }
        
        // Habit Editor
        public static let addHabitButton = "add_habit_button"
        public static let habitNameField = "habit_name_field"
        public static let habitTypeSelector = "habit_type_selector"
        public static let habitColorPicker = "habit_color_picker"
        
        // Conditional Habits
        public static func conditionalOption(optionId: UUID) -> String {
            "conditional_option_\(optionId.uuidString)"
        }
        
        // Counter Habits
        public static func counterItem(index: Int) -> String {
            "counter_item_\(index)"
        }
        
        public static func counterIncrement(index: Int) -> String {
            "counter_increment_\(index)"
        }
        
        public static func counterDecrement(index: Int) -> String {
            "counter_decrement_\(index)"
        }
    }
    
    // MARK: - Accessibility Labels
    
    public enum Labels {
        public static func progressBar(completed: Int, total: Int) -> String {
            String(localized: "Accessibility.ProgressBar.Label", bundle: .module)
                .replacingOccurrences(of: "%d", with: "\(completed)")
                .replacingOccurrences(of: "%d", with: "\(total)")
        }
        
        public static func habitCard(habitName: String, habitType: String) -> String {
            String(localized: "Accessibility.HabitCard.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
                .replacingOccurrences(of: "%@", with: habitType)
        }
        
        public static func completeHabitButton(habitName: String) -> String {
            String(localized: "Accessibility.CompleteHabit.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
        }
        
        public static func skipHabitButton(habitName: String) -> String {
            String(localized: "Accessibility.SkipHabit.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
        }
        
        public static func timerButton(habitName: String, isRunning: Bool) -> String {
            if isRunning {
                return String(localized: "Accessibility.StopTimer.Label", bundle: .module)
                    .replacingOccurrences(of: "%@", with: habitName)
            } else {
                return String(localized: "Accessibility.StartTimer.Label", bundle: .module)
                    .replacingOccurrences(of: "%@", with: habitName)
            }
        }
        
        public static func checkboxHabit(habitName: String, isCompleted: Bool) -> String {
            let status = isCompleted ? 
                String(localized: "Accessibility.Checkbox.Completed", bundle: .module) :
                String(localized: "Accessibility.Checkbox.NotCompleted", bundle: .module)
            
            return String(localized: "Accessibility.Checkbox.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
                .replacingOccurrences(of: "%@", with: status)
        }
        
        public static func counterHabit(habitName: String, itemName: String, count: Int) -> String {
            String(localized: "Accessibility.Counter.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
                .replacingOccurrences(of: "%@", with: itemName)
                .replacingOccurrences(of: "%d", with: "\(count)")
        }
        
        public static func routineTemplate(templateName: String, habitsCount: Int, duration: String) -> String {
            String(localized: "Accessibility.Template.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: templateName)
                .replacingOccurrences(of: "%d", with: "\(habitsCount)")
                .replacingOccurrences(of: "%@", with: duration)
        }
        
        public static func conditionalOption(optionText: String, resultCount: Int) -> String {
            String(localized: "Accessibility.ConditionalOption.Label", bundle: .module)
                .replacingOccurrences(of: "%@", with: optionText)
                .replacingOccurrences(of: "%d", with: "\(resultCount)")
        }
    }
    
    // MARK: - Accessibility Hints
    
    public enum Hints {
        public static let swipeToNavigate = String(localized: "Accessibility.Hint.SwipeToNavigate", bundle: .module)
        public static let doubleTapToComplete = String(localized: "Accessibility.Hint.DoubleTapToComplete", bundle: .module)
        public static let doubleTapToSkip = String(localized: "Accessibility.Hint.DoubleTapToSkip", bundle: .module)
        public static let doubleTapToStartTimer = String(localized: "Accessibility.Hint.DoubleTapToStartTimer", bundle: .module)
        public static let doubleTapToStopTimer = String(localized: "Accessibility.Hint.DoubleTapToStopTimer", bundle: .module)
        public static let doubleTapToEdit = String(localized: "Accessibility.Hint.DoubleTapToEdit", bundle: .module)
        public static let doubleTapToDelete = String(localized: "Accessibility.Hint.DoubleTapToDelete", bundle: .module)
        public static let incrementCounter = String(localized: "Accessibility.Hint.IncrementCounter", bundle: .module)
        public static let decrementCounter = String(localized: "Accessibility.Hint.DecrementCounter", bundle: .module)
        public static let selectOption = String(localized: "Accessibility.Hint.SelectOption", bundle: .module)
    }
    
    // MARK: - Accessibility Traits
    
    public static let habitCardTraits: AccessibilityTraits = [.isButton, .startsMediaSession]
    public static let timerButtonTraits: AccessibilityTraits = [.isButton, .playsSound]
    public static let navigationButtonTraits: AccessibilityTraits = [.isButton]
    public static let deleteButtonTraits: AccessibilityTraits = [.isButton]
    
    // MARK: - VoiceOver Announcements
    
    public enum Announcements {
        public static func habitCompleted(habitName: String) -> String {
            String(localized: "Accessibility.Announcement.HabitCompleted", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
        }
        
        public static func habitSkipped(habitName: String) -> String {
            String(localized: "Accessibility.Announcement.HabitSkipped", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
        }
        
        public static func routineCompleted(templateName: String, duration: String) -> String {
            String(localized: "Accessibility.Announcement.RoutineCompleted", bundle: .module)
                .replacingOccurrences(of: "%@", with: templateName)
                .replacingOccurrences(of: "%@", with: duration)
        }
        
        public static func timerStarted(habitName: String) -> String {
            String(localized: "Accessibility.Announcement.TimerStarted", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
        }
        
        public static func timerStopped(habitName: String, duration: String) -> String {
            String(localized: "Accessibility.Announcement.TimerStopped", bundle: .module)
                .replacingOccurrences(of: "%@", with: habitName)
                .replacingOccurrences(of: "%@", with: duration)
        }
        
        public static let routinePaused = String(localized: "Accessibility.Announcement.RoutinePaused", bundle: .module)
        public static let routineResumed = String(localized: "Accessibility.Announcement.RoutineResumed", bundle: .module)
    }
}

// MARK: - View Extensions for Accessibility

extension View {
    /// Apply standard accessibility configuration for habit interaction views
    public func accessibilityHabitInteraction(
        habit: Habit,
        customLabel: String? = nil,
        customHint: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityIdentifier(AccessibilityConfiguration.Identifiers.habitInteractionView(habitId: habit.id))
            .accessibilityLabel(customLabel ?? AccessibilityConfiguration.Labels.habitCard(
                habitName: habit.name,
                habitType: habit.type.description
            ))
            .accessibilityHint(customHint ?? AccessibilityConfiguration.Hints.doubleTapToComplete)
            .accessibilityAddTraits(traits.isEmpty ? AccessibilityConfiguration.habitCardTraits : traits)
    }
    
    /// Apply standard accessibility configuration for buttons
    public func accessibilityButton(
        identifier: String,
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = AccessibilityConfiguration.navigationButtonTraits
    ) -> some View {
        var view = self
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
            .accessibilityAddTraits(traits)
        
        if let hint = hint {
            view = view.accessibilityHint(hint)
        }
        
        return view
    }
    
    /// Apply accessibility configuration for progress indicators
    public func accessibilityProgress(
        identifier: String,
        label: String,
        value: Double
    ) -> some View {
        self
            .accessibilityIdentifier(identifier)
            .accessibilityLabel(label)
            .accessibilityValue(Text("\(Int(value * 100))%"))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Announce accessibility changes
    public func announceAccessibilityChange(_ announcement: String) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIAccessibility.announcementDidFinishNotification)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
    }
}

// MARK: - Accessibility String Extensions

extension String {
    /// Create localized accessibility string with fallback
    static func accessibilityString(key: String, defaultValue: String, _ arguments: CVarArg...) -> String {
        // For now, just return the default value since proper localization setup would require more work
        return String(format: defaultValue, arguments: arguments)
    }
}