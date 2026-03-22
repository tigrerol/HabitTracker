import Foundation
import CoreLocation

/// Routine context with flexible day categories
/// Supports multiple day categories per context (e.g. "Weekday" + "Training Day")
public struct RoutineContext: Codable, Hashable, Sendable {
    public let timeSlot: TimeSlot
    public let dayCategories: [DayCategory]
    public let location: LocationType
    public let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case timeSlot
        case dayCategories
        case dayCategory // legacy key for migration
        case location
        case timestamp
    }

    public init(
        timeSlot: TimeSlot,
        dayCategories: [DayCategory],
        location: LocationType,
        timestamp: Date = Date()
    ) {
        self.timeSlot = timeSlot
        self.dayCategories = dayCategories
        self.location = location
        self.timestamp = timestamp
    }

    // MARK: - Codable Migration

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeSlot = try container.decode(TimeSlot.self, forKey: .timeSlot)
        location = try container.decode(LocationType.self, forKey: .location)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Try new format first: dayCategories array
        if let categories = try? container.decode([DayCategory].self, forKey: .dayCategories) {
            dayCategories = categories
        } else {
            // Fallback: decode old single dayCategory and wrap in array
            let single = try container.decode(DayCategory.self, forKey: .dayCategory)
            dayCategories = [single]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeSlot, forKey: .timeSlot)
        try container.encode(dayCategories, forKey: .dayCategories)
        try container.encode(location, forKey: .location)
        try container.encode(timestamp, forKey: .timestamp)
    }

    /// Create context from current conditions (main actor required)
    @MainActor
    public static func current(location: LocationType = .unknown) -> RoutineContext {
        let now = Date()
        let categoryManager = DayCategoryManager.shared
        let dayCategories = categoryManager.categories(for: now)

        return RoutineContext(
            timeSlot: TimeSlot.from(date: now),
            dayCategories: dayCategories,
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
        // Fallback to standard logic for now to avoid main actor complexity
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
        case .unknown: return "Other Location"
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
    public var dayCategoryIds: Set<String>
    public var locationIds: Set<String> // Changed to support both built-in and custom locations
    public var priority: Int // Higher priority wins in conflicts
    
    public init(
        timeSlots: Set<TimeSlot> = [],
        dayCategoryIds: Set<String> = [],
        locationIds: Set<String> = [],
        priority: Int = 0
    ) {
        self.timeSlots = timeSlots
        self.dayCategoryIds = dayCategoryIds
        self.locationIds = locationIds
        self.priority = priority
    }
    
    /// Check if this rule matches the given context
    @MainActor
    public func matches(_ context: RoutineContext, locationCoordinator: LocationCoordinator) -> Bool {
        let timeMatch = timeSlots.isEmpty || timeSlots.contains(context.timeSlot)
        let dayMatch = dayCategoryIds.isEmpty || context.dayCategories.contains(where: { dayCategoryIds.contains($0.id) })

        // Enhanced location matching that handles custom locations
        let locationMatch: Bool
        if locationIds.isEmpty {
            locationMatch = true
        } else {
            // Check current extended location type
            switch locationCoordinator.currentExtendedLocationType {
            case .builtin(let locationType):
                locationMatch = locationIds.contains(locationType.rawValue)
            case .custom(let uuid):
                locationMatch = locationIds.contains(uuid.uuidString)
            }
        }

        return timeMatch && dayMatch && locationMatch
    }

}