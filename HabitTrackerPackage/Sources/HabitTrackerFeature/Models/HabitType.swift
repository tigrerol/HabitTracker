import Foundation

/// Represents different types of habits in the morning routine
public enum HabitType: Codable, Hashable, Sendable {
    /// Simple checkbox completion
    case checkbox
    
    /// Checkbox with subtasks
    case checkboxWithSubtasks(subtasks: [Subtask])
    
    /// Timer-based habit with custom duration
    case timer(defaultDuration: TimeInterval)
    
    
    /// Rest timer that counts up
    case restTimer(targetDuration: TimeInterval?)
    
    /// Launch external app and wait for confirmation
    case appLaunch(bundleId: String, appName: String)
    
    /// Open website or use Shortcuts
    case website(url: URL, title: String)
    
    /// Counter-based habit (e.g., supplements)
    case counter(items: [String])
    
    /// Measurement input (e.g., weight, HRV score)
    case measurement(unit: String, targetValue: Double?)
    
    /// Guided sequence with steps
    case guidedSequence(steps: [SequenceStep])
}

/// Represents a subtask within a checkbox habit
public struct Subtask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var isOptional: Bool
    
    public init(id: UUID = UUID(), name: String, isOptional: Bool = false) {
        self.id = id
        self.name = name
        self.isOptional = isOptional
    }
}


/// Represents a step in a guided sequence
public struct SequenceStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var duration: TimeInterval
    public var instructions: String?
    
    public init(id: UUID = UUID(), name: String, duration: TimeInterval, instructions: String? = nil) {
        self.id = id
        self.name = name
        // Ensure duration is never zero or negative to prevent NaN in calculations
        self.duration = max(1, duration)
        self.instructions = instructions
    }
}

extension HabitType {
    /// Human-readable description of the habit type
    public var description: String {
        switch self {
        case .checkbox:
            return "Simple task"
        case .checkboxWithSubtasks(let subtasks):
            return "\(subtasks.count) subtasks"
        case .timer(let duration):
            return "Timer (\(Int(duration/60))min)"
        case .restTimer(let target):
            if let target {
                return "Rest timer (\(Int(target/60))min)"
            } else {
                return "Rest timer"
            }
        case .appLaunch(_, let appName):
            return "Launch \(appName)"
        case .website(_, let title):
            return "Open \(title)"
        case .counter(let items):
            return "\(items.count) items"
        case .measurement(let unit, let target):
            if let target {
                return "Measure \(unit) (target: \(target))"
            } else {
                return "Measure \(unit)"
            }
        case .guidedSequence(let steps):
            let totalTime = steps.reduce(0) { $0 + $1.duration }
            return "\(steps.count) steps (\(Int(totalTime/60))min)"
        }
    }
    
    /// Icon name for the habit type
    public var iconName: String {
        switch self {
        case .checkbox:
            return "checkmark.square"
        case .checkboxWithSubtasks:
            return "checklist"
        case .timer:
            return "timer"
        case .restTimer:
            return "pause.circle"
        case .appLaunch:
            return "app.badge"
        case .website:
            return "safari"
        case .counter:
            return "list.bullet"
        case .measurement:
            return "chart.line.uptrend.xyaxis"
        case .guidedSequence:
            return "list.number"
        }
    }
}