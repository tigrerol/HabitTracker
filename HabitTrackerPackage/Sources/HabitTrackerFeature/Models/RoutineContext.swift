import Foundation
import CoreLocation

/// Represents the current context for smart routine selection
public struct RoutineContext: Codable, Hashable, Sendable {
    public let timeSlot: TimeSlot
    public let dayType: DayType
    public let location: LocationType
    public let timestamp: Date
    
    public init(
        timeSlot: TimeSlot,
        dayType: DayType,
        location: LocationType,
        timestamp: Date = Date()
    ) {
        self.timeSlot = timeSlot
        self.dayType = dayType
        self.location = location
        self.timestamp = timestamp
    }
    
    /// Create context from current conditions
    public static func current(location: LocationType = .unknown) -> RoutineContext {
        let now = Date()
        // Use fallback methods for non-async context
        return RoutineContext(
            timeSlot: TimeSlot.from(date: now),
            dayType: DayType.from(date: now),
            location: location,
            timestamp: now
        )
    }
}

/// Time slots for routine scheduling
public enum TimeSlot: String, Codable, CaseIterable, Sendable {
    case earlyMorning = "early_morning"    // 5:00 - 7:00
    case morning = "morning"               // 7:00 - 9:00
    case lateMorning = "late_morning"      // 9:00 - 11:00
    case afternoon = "afternoon"           // 11:00 - 17:00
    case evening = "evening"               // 17:00 - 21:00
    case night = "night"                   // 21:00 - 5:00
    
    /// Display name for the time slot
    public var displayName: String {
        switch self {
        case .earlyMorning: return "Early Morning"
        case .morning: return "Morning"
        case .lateMorning: return "Late Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
    
    /// Time range for the slot
    public var timeRange: String {
        switch self {
        case .earlyMorning: return "5:00 AM - 7:00 AM"
        case .morning: return "7:00 AM - 9:00 AM"
        case .lateMorning: return "9:00 AM - 11:00 AM"
        case .afternoon: return "11:00 AM - 5:00 PM"
        case .evening: return "5:00 PM - 9:00 PM"
        case .night: return "9:00 PM - 5:00 AM"
        }
    }
    
    /// Icon for the time slot
    public var icon: String {
        switch self {
        case .earlyMorning: return "sunrise"
        case .morning: return "sun.min"
        case .lateMorning: return "sun.max"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset"
        case .night: return "moon.stars"
        }
    }
    
    /// Determine time slot from a date
    public static func from(date: Date) -> TimeSlot {
        // Try to use custom settings if available on main actor
        if Thread.isMainThread,
           let timeSlotManager = try? MainActor.assumeIsolated({ TimeSlotManager.shared }) {
            return timeSlotManager.getCurrentTimeSlot()
        }
        
        // Fallback to standard logic
        let hour = Calendar.current.component(.hour, from: date)
        
        switch hour {
        case 5..<7: return .earlyMorning
        case 7..<9: return .morning
        case 9..<11: return .lateMorning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

/// Day types for routine scheduling
public enum DayType: String, Codable, CaseIterable, Sendable {
    case weekday = "weekday"
    case weekend = "weekend"
    
    /// Display name for the day type
    public var displayName: String {
        switch self {
        case .weekday: return "Weekday"
        case .weekend: return "Weekend"
        }
    }
    
    /// Icon for the day type
    public var icon: String {
        switch self {
        case .weekday: return "briefcase"
        case .weekend: return "house"
        }
    }
    
    /// Determine day type from a date
    public static func from(date: Date) -> DayType {
        // Try to use custom settings if available on main actor
        if Thread.isMainThread,
           let dayTypeManager = try? MainActor.assumeIsolated({ DayTypeManager.shared }) {
            return dayTypeManager.dayType(for: date)
        }
        
        // Fallback to standard logic
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if weekend (Saturday = 7, Sunday = 1)
        if weekday == 1 || weekday == 7 {
            return .weekend
        }
        
        return .weekday
    }
}

/// Location types for routine scheduling
public enum LocationType: String, Codable, CaseIterable, Sendable {
    case home = "home"
    case office = "office"
    case unknown = "unknown"
    
    /// Display name for the location type
    public var displayName: String {
        switch self {
        case .home: return "Home"
        case .office: return "Office"
        case .unknown: return "Unknown"
        }
    }
    
    /// Icon for the location type
    public var icon: String {
        switch self {
        case .home: return "house.fill"
        case .office: return "building.2.fill"
        case .unknown: return "location.slash"
        }
    }
}

/// Rules for when a routine template should be selected
public struct RoutineContextRule: Codable, Hashable, Sendable {
    public var timeSlots: Set<TimeSlot>
    public var dayTypes: Set<DayType>
    public var locations: Set<LocationType>
    public var priority: Int // Higher priority wins in conflicts
    
    public init(
        timeSlots: Set<TimeSlot> = [],
        dayTypes: Set<DayType> = [],
        locations: Set<LocationType> = [],
        priority: Int = 0
    ) {
        self.timeSlots = timeSlots
        self.dayTypes = dayTypes
        self.locations = locations
        self.priority = priority
    }
    
    /// Check if this rule matches the given context
    public func matches(_ context: RoutineContext) -> Bool {
        let timeMatch = timeSlots.isEmpty || timeSlots.contains(context.timeSlot)
        let dayMatch = dayTypes.isEmpty || dayTypes.contains(context.dayType)
        let locationMatch = locations.isEmpty || locations.contains(context.location)
        
        return timeMatch && dayMatch && locationMatch
    }
    
    /// Calculate match score (higher is better)
    public func matchScore(for context: RoutineContext) -> Int {
        guard matches(context) else { return 0 }
        
        var score = priority * 1000 // Base score from priority
        
        // Add points for specific matches (not empty sets)
        if !timeSlots.isEmpty && timeSlots.contains(context.timeSlot) {
            score += 100
        }
        if !dayTypes.isEmpty && dayTypes.contains(context.dayType) {
            score += 100
        }
        if !locations.isEmpty && locations.contains(context.location) {
            score += 100
        }
        
        return score
    }
}