import Foundation
import CoreLocation

/// Routine context with flexible day categories
public struct RoutineContext: Codable, Hashable, Sendable {
    public let timeSlot: TimeSlot
    public let dayCategory: DayCategory
    public let location: LocationType
    public let timestamp: Date
    
    public init(
        timeSlot: TimeSlot,
        dayCategory: DayCategory,
        location: LocationType,
        timestamp: Date = Date()
    ) {
        self.timeSlot = timeSlot
        self.dayCategory = dayCategory
        self.location = location
        self.timestamp = timestamp
    }
    
    /// Create context from current conditions (main actor required)
    @MainActor
    public static func current(location: LocationType = .unknown) -> RoutineContext {
        let now = Date()
        let categoryManager = DayCategoryManager.shared
        let dayCategory = categoryManager.category(for: now)
        
        return RoutineContext(
            timeSlot: TimeSlot.from(date: now),
            dayCategory: dayCategory,
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
    public func matches(_ context: RoutineContext, locationManager: LocationManager) -> Bool {
        let timeMatch = timeSlots.isEmpty || timeSlots.contains(context.timeSlot)
        let dayMatch = dayCategoryIds.isEmpty || dayCategoryIds.contains(context.dayCategory.id)
        
        // Enhanced location matching that handles custom locations
        let locationMatch: Bool
        if locationIds.isEmpty {
            locationMatch = true
        } else {
            // Check current extended location type
            switch locationManager.currentExtendedLocationType {
            case .builtin(let locationType):
                locationMatch = locationIds.contains(locationType.rawValue)
            case .custom(let uuid):
                locationMatch = locationIds.contains(uuid.uuidString)
            }
        }
        
        return timeMatch && dayMatch && locationMatch
    }
    
    /// Calculate match score (higher is better)
    @MainActor
    public func matchScore(for context: RoutineContext, locationManager: LocationManager) -> Int {
        guard matches(context, locationManager: locationManager) else { 
            print("   ❌ No match for timeSlots:\(timeSlots), dayCategories:\(dayCategoryIds), locations:\(locationIds)")
            return 0 
        }
        
        var score = priority * 1000 // Base score from priority
        print("   ✅ Base score (priority \(priority) * 1000): \(score)")
        
        // Add points for specific matches (not empty sets)
        if !timeSlots.isEmpty && timeSlots.contains(context.timeSlot) {
            score += 100
            print("   ✅ Time slot match (\(context.timeSlot)): +100, total: \(score)")
        }
        if !dayCategoryIds.isEmpty && dayCategoryIds.contains(context.dayCategory.id) {
            score += 100
            print("   ✅ Day category match (\(context.dayCategory.id)): +100, total: \(score)")
        }
        if !locationIds.isEmpty {
            // Check if current location matches
            switch locationManager.currentExtendedLocationType {
            case .builtin(let locationType):
                if locationIds.contains(locationType.rawValue) {
                    score += 100
                    print("   ✅ Location match (\(locationType.rawValue)): +100, total: \(score)")
                }
            case .custom(let uuid):
                if locationIds.contains(uuid.uuidString) {
                    score += 100
                    print("   ✅ Custom location match (\(uuid)): +100, total: \(score)")
                }
            }
        } else {
            print("   ⚪ Location any (empty set): +0, total: \(score)")
        }
        
        return score
    }
}