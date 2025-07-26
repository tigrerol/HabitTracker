import Foundation

/// Represents a weekday
public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    /// Display name for the weekday
    public var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    /// Short display name
    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    /// Icon for the weekday
    public var icon: String {
        switch self {
        case .sunday: return "sun.max"
        case .monday: return "briefcase"
        case .tuesday: return "briefcase"
        case .wednesday: return "briefcase"
        case .thursday: return "briefcase"
        case .friday: return "briefcase"
        case .saturday: return "sun.max"
        }
    }
    
    /// Create from Calendar weekday component
    public static func from(calendarWeekday: Int) -> Weekday {
        Weekday(rawValue: calendarWeekday) ?? .sunday
    }
    
    /// Get current weekday
    public static func current() -> Weekday {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return from(calendarWeekday: weekday)
    }
}