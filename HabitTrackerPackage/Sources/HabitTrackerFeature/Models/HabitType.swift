import Foundation

/// Represents different types of habits in the morning routine
public enum HabitType: Codable, Hashable, Sendable {
    /// Simple checkbox completion
    case checkbox
    
    /// Timer-based habit with custom duration
    case timer(defaultDuration: TimeInterval)
    
    /// Launch external app and wait for confirmation
    case appLaunch(bundleId: String, appName: String)
    
    /// Open website or use Shortcuts
    case website(url: URL, title: String)
    
    /// Counter-based habit (e.g., supplements)
    case counter(items: [String])
}

extension HabitType {
    /// Human-readable description of the habit type
    public var description: String {
        switch self {
        case .checkbox:
            return "Simple task"
        case .timer(let duration):
            return "Timer (\(Int(duration/60))min)"
        case .appLaunch(_, let appName):
            return "Launch \(appName)"
        case .website(_, let title):
            return "Open \(title)"
        case .counter(let items):
            return "\(items.count) items"
        }
    }
    
    /// Icon name for the habit type
    public var iconName: String {
        switch self {
        case .checkbox:
            return "checkmark.square"
        case .timer:
            return "timer"
        case .appLaunch:
            return "app.badge"
        case .website:
            return "safari"
        case .counter:
            return "list.bullet"
        }
    }
}