import Foundation

/// Represents different types of habits in the morning routine
public enum HabitType: Codable, Hashable, Sendable {
    /// Task completion with optional subtasks
    case task(subtasks: [Subtask])
    
    /// Timer-based habit with flexible timing modes
    case timer(style: TimerStyle, duration: TimeInterval, target: TimeInterval? = nil, steps: [SequenceStep] = [])
    
    /// External action (app launch, website, shortcut)
    case action(type: ActionType, identifier: String, displayName: String)
    
    /// Tracking-based habit (measurements, counters, supplements)
    case tracking(TrackingType)
    
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

/// Represents different external action types
public enum ActionType: Codable, Hashable, Sendable {
    /// Launch native app using bundle identifier
    case app
    /// Open website URL
    case website  
    /// Run Shortcuts app shortcut
    case shortcut
}

/// Represents different tracking types
public enum TrackingType: Codable, Hashable, Sendable {
    /// Count multiple items (e.g., supplements, vitamins)
    case counter(items: [String])
    /// Single measurement with unit (e.g., weight, HRV score)
    case measurement(unit: String, targetValue: Double?)
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
        case .timer(let style, let duration, let target, let steps):
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
                if !steps.isEmpty {
                    let totalTime = steps.reduce(0) { $0 + $1.duration }
                    return "\(steps.count) intervals (\(Int(totalTime/60))min)"
                } else {
                    return "Multiple timers (\(Int(duration/60))min)"
                }
            }
        case .action(let type, _, let displayName):
            switch type {
            case .app:
                return "Launch \(displayName)"
            case .website:
                return "Open \(displayName)"
            case .shortcut:
                return "Run \(displayName)"
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter(let items):
                return "\(items.count) items"
            case .measurement(let unit, let target):
                if let target {
                    return "Measure \(unit) (target: \(target))"
                } else {
                    return "Measure \(unit)"
                }
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
        case .timer(let style, _, _, _):
            switch style {
            case .down:
                return "timer"
            case .up:
                return "pause.circle"
            case .multiple:
                return "timer.circle"
            }
        case .action(let type, _, _):
            switch type {
            case .app:
                return "app.badge"
            case .website:
                return "safari"
            case .shortcut:
                return "gear.circle"
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "list.bullet"
            case .measurement:
                return "chart.line.uptrend.xyaxis"
            }
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
        case .timer(let style, _, _, _):
            switch style {
            case .down:
                return "New Timer"
            case .up:
                return "Count Up"
            case .multiple:
                return "Multiple Timers"
            }
        case .action(let type, _, _):
            switch type {
            case .app:
                return "Launch App"
            case .website:
                return "Open Website"
            case .shortcut:
                return "Run Shortcut"
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "New Counter"
            case .measurement:
                return "New Measurement"
            }
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