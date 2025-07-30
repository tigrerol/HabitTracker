import Foundation

/// Represents different types of habits in the morning routine
public enum HabitType: Codable, Hashable, Sendable {
    /// Task completion with optional subtasks
    case task(subtasks: [Subtask])
    
    /// Timer-based habit with flexible timing modes
    case timer(style: TimerStyle, duration: TimeInterval, target: TimeInterval? = nil)
    
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
    
    /// Conditional habit with branching logic
    case conditional(ConditionalHabitInfo)
}

/// Represents different timer styles
public enum TimerStyle: Codable, Hashable, Sendable {
    /// Countdown timer (traditional)
    case down
    /// Count-up timer (rest/open-ended activities)
    case up
    /// Sequence of multiple timers
    case multiple
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
        case .task(let subtasks):
            return subtasks.isEmpty ? "Simple task" : "\(subtasks.count) subtasks"
        case .timer(let style, let duration, let target):
            switch style {
            case .down:
                return "Timer (\(Int(duration/60))min)"
            case .up:
                if let target {
                    return "Count up (\(Int(target/60))min target)"
                } else {
                    return "Count up"
                }
            case .multiple:
                return "Multiple timers (\(Int(duration/60))min)"
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
        case .conditional(let info):
            return "\(info.options.count) options"
        }
    }
    
    /// Icon name for the habit type
    public var iconName: String {
        switch self {
        case .task(let subtasks):
            return subtasks.isEmpty ? "checkmark.square" : "list.bullet.rectangle"
        case .timer(let style, _, _):
            switch style {
            case .down:
                return "timer"
            case .up:
                return "pause.circle"
            case .multiple:
                return "timer.circle"
            }
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
        case .conditional:
            return "questionmark.circle"
        }
    }
    
    /// Quick default name for creating habits fast
    public var quickName: String {
        switch self {
        case .task:
            return "New Task"
        case .timer(let style, _, _):
            switch style {
            case .down:
                return "New Timer"
            case .up:
                return "Count Up"
            case .multiple:
                return "Multiple Timers"
            }
        case .appLaunch:
            return "New App"
        case .website:
            return "New Website"
        case .counter:
            return "New Counter"
        case .measurement:
            return "New Measurement"
        case .guidedSequence:
            return "New Sequence"
        case .conditional:
            return "New Question"
        }
    }
    
    /// Whether this is a task-type habit
    public var isTask: Bool {
        switch self {
        case .task:
            return true
        default:
            return false
        }
    }
    
    /// Whether this is a timer-type habit
    public var isTimer: Bool {
        switch self {
        case .timer:
            return true
        default:
            return false
        }
    }
    
    /// Whether this is a conditional habit
    public var isConditional: Bool {
        switch self {
        case .conditional:
            return true
        default:
            return false
        }
    }
}