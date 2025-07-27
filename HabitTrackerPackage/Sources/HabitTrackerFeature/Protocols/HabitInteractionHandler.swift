import SwiftUI

/// Protocol for handling different types of habit interactions
public protocol HabitInteractionHandler {
    typealias ViewType = AnyView
    
    /// The habit type this handler supports
    static var supportedHabitType: HabitType.Type { get }
    
    /// Create the interaction view for this habit type
    @MainActor
    func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> ViewType
    
    /// Estimate the duration for this habit type (optional override)
    func estimatedDuration(for habit: Habit) -> TimeInterval
    
    /// Validate if this handler can handle the given habit
    func canHandle(habit: Habit) -> Bool
}

// MARK: - Default Implementations

extension HabitInteractionHandler {
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return habit.estimatedDuration
    }
    
    public func canHandle(habit: Habit) -> Bool {
        // Default implementation checks if the habit type matches
        switch habit.type {
        case .checkbox where Self.supportedHabitType == HabitType.self:
            return true
        case .checkboxWithSubtasks where Self.supportedHabitType == HabitType.self:
            return true
        case .timer where Self.supportedHabitType == HabitType.self:
            return true
        case .restTimer where Self.supportedHabitType == HabitType.self:
            return true
        case .appLaunch where Self.supportedHabitType == HabitType.self:
            return true
        case .website where Self.supportedHabitType == HabitType.self:
            return true
        case .counter where Self.supportedHabitType == HabitType.self:
            return true
        case .measurement where Self.supportedHabitType == HabitType.self:
            return true
        case .guidedSequence where Self.supportedHabitType == HabitType.self:
            return true
        case .conditional where Self.supportedHabitType == HabitType.self:
            return true
        default:
            return false
        }
    }
}

// MARK: - Concrete Handler Implementations

/// Handler for checkbox habits
public struct CheckboxHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        AnyView(AccessibleCheckboxHabitView(habit: habit, onComplete: onComplete, isCompleted: isCompleted))
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .checkbox = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return 60 // 1 minute for checkbox
    }
}

/// Handler for checkbox with subtasks habits
public struct SubtasksHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .checkboxWithSubtasks(let subtasks):
            return AnyView(SubtasksHabitView(habit: habit, subtasks: subtasks, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for SubtasksHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .checkboxWithSubtasks = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .checkboxWithSubtasks(let subtasks) = habit.type else { return 60 }
        return TimeInterval(subtasks.count * 45) // 45 seconds per subtask
    }
}

/// Handler for timer habits
public struct TimerHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .timer(let defaultDuration):
            return AnyView(TimerHabitView(habit: habit, defaultDuration: defaultDuration, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for TimerHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .timer = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .timer(let duration) = habit.type else { return 300 }
        return duration
    }
}

/// Handler for rest timer habits
public struct RestTimerHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .restTimer(let targetDuration):
            return AnyView(RestTimerHabitView(habit: habit, targetDuration: targetDuration, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for RestTimerHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .restTimer = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .restTimer(let target) = habit.type else { return 180 }
        return target ?? 180 // Use target or default 3 minutes
    }
}

/// Handler for app launch habits
public struct AppLaunchHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        AnyView(AccessibleCheckboxHabitView(habit: habit, onComplete: onComplete, isCompleted: isCompleted))
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .appLaunch = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return 300 // 5 minutes default for app launch
    }
}

/// Handler for website habits
public struct WebsiteHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .website(let url, let title):
            return AnyView(WebsiteHabitView(habit: habit, url: url, title: title, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for WebsiteHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .website = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return 180 // 3 minutes default for website
    }
}

/// Handler for counter habits
public struct CounterHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .counter(let items):
            return AnyView(AccessibleCounterHabitView(
                habit: habit,
                items: items,
                onComplete: onComplete,
                isCompleted: isCompleted
            ))
        default:
            return AnyView(Text("Invalid habit type for CounterHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .counter = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .counter(let items) = habit.type else { return 60 }
        return TimeInterval(items.count * 30) // 30 seconds per item
    }
}

/// Handler for measurement habits
public struct MeasurementHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .measurement(let unit, let targetValue):
            return AnyView(MeasurementHabitView(habit: habit, unit: unit, targetValue: targetValue, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for MeasurementHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .measurement = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return 60 // 1 minute to measure and record
    }
}

/// Handler for guided sequence habits
public struct GuidedSequenceHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .guidedSequence(let steps):
            return AnyView(GuidedSequenceHabitView(habit: habit, steps: steps, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for GuidedSequenceHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .guidedSequence = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .guidedSequence(let steps) = habit.type else { return 300 }
        return steps.reduce(0) { $0 + $1.duration }
    }
}

/// Handler for conditional habits
public struct ConditionalHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .conditional(let info):
            return AnyView(ConditionalHabitInteractionView(
                habit: habit,
                conditionalInfo: info,
                onOptionSelected: { option in
                    onComplete(habit.id, nil, String(localized: "HabitInteractionView.Question.Selected", bundle: .module).replacingOccurrences(of: "%@", with: option.text))
                },
                onSkip: {
                    onComplete(habit.id, nil, String(localized: "HabitInteractionView.Question.Skipped", bundle: .module))
                }
            ))
        default:
            return AnyView(Text("Invalid habit type for ConditionalHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .conditional = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        return 30 // Quick question, 30 seconds estimated
    }
}

// MARK: - Note: Actual view implementations are in HabitInteractionView.swift
// The protocol handlers above delegate to the existing comprehensive implementations