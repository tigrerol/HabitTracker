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
        case .task where Self.supportedHabitType == HabitType.self:
            return true
        case .timer where Self.supportedHabitType == HabitType.self:
            return true
        case .action where Self.supportedHabitType == HabitType.self:
            return true
        case .tracking where Self.supportedHabitType == HabitType.self:
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
        if case .task(let subtasks) = habit.type, subtasks.isEmpty {
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
        case .task(let subtasks):
            return AnyView(SubtasksHabitView(habit: habit, subtasks: subtasks, onComplete: onComplete, isCompleted: isCompleted))
        default:
            return AnyView(Text("Invalid habit type for SubtasksHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .task(let subtasks) = habit.type, !subtasks.isEmpty {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .task(let subtasks) = habit.type else { return 60 }
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
        case .timer(let style, let duration, let target, let steps):
            return AnyView(TimerHabitView(habit: habit, style: style, duration: duration, target: target, steps: steps, onComplete: onComplete, isCompleted: isCompleted))
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
        guard case .timer(let style, let duration, let target, let steps) = habit.type else { return 300 }
        
        switch style {
        case .down, .up:
            return target ?? duration
        case .multiple:
            if !steps.isEmpty {
                return steps.reduce(0) { $0 + $1.duration }
            } else {
                return duration
            }
        }
    }
}


/// Handler for external action habits (app launch, website, shortcut)
public struct ActionHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .action(let type, let identifier, let displayName):
            return AnyView(ActionHabitView(habit: habit, actionType: type, identifier: identifier, displayName: displayName, onComplete: onComplete))
        default:
            return AnyView(Text("Invalid habit type for ActionHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .action = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .action(let type, _, _) = habit.type else { return 300 }
        switch type {
        case .app:
            return 300 // 5 minutes default for app launch
        case .website:
            return 180 // 3 minutes default for website
        case .shortcut:
            return 120 // 2 minutes default for shortcut
        }
    }
}


/// Handler for tracking habits (counter and measurement)
public struct TrackingHabitHandler: HabitInteractionHandler {
    public static let supportedHabitType: HabitType.Type = HabitType.self
    
    @MainActor
    public func createInteractionView(
        habit: Habit,
        onComplete: @escaping (UUID, TimeInterval?, String?) -> Void,
        isCompleted: Bool
    ) -> AnyView {
        switch habit.type {
        case .tracking(let trackingType):
            switch trackingType {
            case .counter(let items):
                return AnyView(AccessibleCounterHabitView(
                    habit: habit,
                    items: items,
                    onComplete: onComplete,
                    isCompleted: isCompleted
                ))
            case .measurement(let unit, let targetValue):
                return AnyView(MeasurementHabitView(
                    habit: habit,
                    unit: unit,
                    targetValue: targetValue,
                    onComplete: onComplete,
                    isCompleted: isCompleted
                ))
            }
        default:
            return AnyView(Text("Invalid habit type for TrackingHabitHandler"))
        }
    }
    
    public func canHandle(habit: Habit) -> Bool {
        if case .tracking = habit.type {
            return true
        }
        return false
    }
    
    public func estimatedDuration(for habit: Habit) -> TimeInterval {
        guard case .tracking(let trackingType) = habit.type else { return 60 }
        switch trackingType {
        case .counter(let items):
            return TimeInterval(items.count * 30) // 30 seconds per item
        case .measurement:
            return 60 // 1 minute to measure and record
        }
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