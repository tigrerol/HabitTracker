import Foundation

/// Represents a time of day with hour and minute
public struct TimeOfDay: Codable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int
    
    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
    
    /// Create from a Date object
    public static func from(date: Date) -> TimeOfDay {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return TimeOfDay(hour: hour, minute: minute)
    }
    
    /// Convert to a Date object (using today as the base date)
    public var date: Date {
        let calendar = Calendar.current
        let today = Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }
    
    /// Get total minutes since midnight
    public var totalMinutes: Int {
        hour * 60 + minute
    }
    
    /// Create from total minutes since midnight
    public static func from(totalMinutes: Int) -> TimeOfDay {
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        return TimeOfDay(hour: hours, minute: minutes)
    }
    
    /// Format as string (e.g., "7:30 AM")
    public var formatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Customizable time slot definition
public struct TimeSlotDefinition: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var startTime: TimeOfDay
    public var endTime: TimeOfDay
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        startTime: TimeOfDay,
        endTime: TimeOfDay,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.startTime = startTime
        self.endTime = endTime
        self.isBuiltIn = isBuiltIn
    }
    
    /// Create from TimeSlot enum (for backwards compatibility)
    public init(type: TimeSlot, startTime: TimeOfDay, endTime: TimeOfDay) {
        self.id = type.rawValue
        self.name = type.displayName
        self.icon = type.icon
        self.startTime = startTime
        self.endTime = endTime
        self.isBuiltIn = true
    }
    
    /// Display name
    public var displayName: String {
        name
    }
    
    /// Formatted time range string
    public var timeRange: String {
        "\(startTime.formatted) - \(endTime.formatted)"
    }
    
    /// Check if a given time falls within this slot
    public func contains(time: TimeOfDay) -> Bool {
        let timeMinutes = time.totalMinutes
        let startMinutes = startTime.totalMinutes
        let endMinutes = endTime.totalMinutes
        
        if startMinutes <= endMinutes {
            // Normal case: doesn't cross midnight
            return timeMinutes >= startMinutes && timeMinutes < endMinutes
        } else {
            // Crosses midnight (e.g., 22:00 - 06:00)
            return timeMinutes >= startMinutes || timeMinutes < endMinutes
        }
    }
    
    /// Default time slot definitions
    public static let defaults: [TimeSlotDefinition] = [
        TimeSlotDefinition(
            type: .earlyMorning,
            startTime: TimeOfDay(hour: 5, minute: 0),
            endTime: TimeOfDay(hour: 7, minute: 0)
        ),
        TimeSlotDefinition(
            type: .morning,
            startTime: TimeOfDay(hour: 7, minute: 0),
            endTime: TimeOfDay(hour: 9, minute: 0)
        ),
        TimeSlotDefinition(
            type: .lateMorning,
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 11, minute: 0)
        ),
        TimeSlotDefinition(
            type: .afternoon,
            startTime: TimeOfDay(hour: 11, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0)
        ),
        TimeSlotDefinition(
            type: .evening,
            startTime: TimeOfDay(hour: 17, minute: 0),
            endTime: TimeOfDay(hour: 21, minute: 0)
        ),
        TimeSlotDefinition(
            type: .night,
            startTime: TimeOfDay(hour: 21, minute: 0),
            endTime: TimeOfDay(hour: 5, minute: 0)
        )
    ]
}

/// Manager for customizable time slot definitions
@MainActor
@Observable
public final class TimeSlotManager {
    public static let shared = TimeSlotManager()

    private var timeSlots: [TimeSlotDefinition] = []
    private let persistenceService: any PersistenceServiceProtocol
    private let timeSlotsKey = "CustomTimeSlots"

    /// Initialize with dependency injection
    public init(persistenceService: (any PersistenceServiceProtocol)? = nil) {
        self.persistenceService = persistenceService ?? UserDefaultsPersistenceService()
        loadTimeSlots()
    }

    /// Get all time slot definitions
    public func getAllTimeSlots() -> [TimeSlotDefinition] {
        timeSlots
    }

    /// Update time slot definitions
    public func updateTimeSlots(_ newTimeSlots: [TimeSlotDefinition]) {
        timeSlots = newTimeSlots
        persistTimeSlots()
    }

    /// Get the current time slot definition based on current time
    public func getCurrentTimeSlotDefinition() -> TimeSlotDefinition? {
        let now = TimeOfDay.from(date: Date())
        return timeSlots.first { $0.contains(time: now) }
    }

    /// Get the current time slot enum (for backwards compatibility)
    public func getCurrentTimeSlot() -> TimeSlot {
        if let definition = getCurrentTimeSlotDefinition(),
           let timeSlot = TimeSlot.allCases.first(where: { definition.id == $0.rawValue }) {
            return timeSlot
        }

        // Fallback to default logic if no custom slots match
        return TimeSlot.from(date: Date())
    }

    /// Add a new custom time slot
    public func addTimeSlot(_ timeSlot: TimeSlotDefinition) {
        timeSlots.append(timeSlot)
        persistTimeSlots()
    }

    /// Update an existing time slot
    public func updateTimeSlot(_ updatedTimeSlot: TimeSlotDefinition) {
        if let index = timeSlots.firstIndex(where: { $0.id == updatedTimeSlot.id }) {
            timeSlots[index] = updatedTimeSlot
        }
        persistTimeSlots()
    }

    /// Delete a time slot (only custom ones can be deleted)
    public func deleteTimeSlot(withId id: String) {
        timeSlots.removeAll { $0.id == id && !$0.isBuiltIn }
        persistTimeSlots()
    }

    /// Reset to default time slots
    public func resetToDefaults() {
        timeSlots = TimeSlotDefinition.defaults
        persistTimeSlots()
    }

    // MARK: - Persistence

    private func loadTimeSlots() {
        Task { @MainActor in
            do {
                timeSlots = try await persistenceService.load([TimeSlotDefinition].self, forKey: timeSlotsKey) ?? TimeSlotDefinition.defaults
            } catch {
                LoggingService.shared.error("Failed to load custom time slots: \(error.localizedDescription)", category: .app)
                timeSlots = TimeSlotDefinition.defaults
            }
        }
    }

    private func persistTimeSlots() {
        let slotsToSave = timeSlots
        Task { @MainActor in
            do {
                try await persistenceService.save(slotsToSave, forKey: timeSlotsKey)
            } catch {
                LoggingService.shared.error("Failed to save custom time slots: \(error.localizedDescription)", category: .app)
            }
        }
    }
}