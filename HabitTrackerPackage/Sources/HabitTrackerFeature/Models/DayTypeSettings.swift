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

/// Custom day type definition
public struct DayTypeDefinition: Codable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBuiltIn = isBuiltIn
    }
    
    /// Create from DayType enum (for backwards compatibility)
    public init(type: DayType) {
        self.id = type.rawValue
        self.name = type.displayName
        self.icon = type.icon
        self.isBuiltIn = true
    }
    
    /// Display name
    public var displayName: String {
        name
    }
    
    /// Default day type definitions
    public static let defaults: [DayTypeDefinition] = [
        DayTypeDefinition(type: .weekday),
        DayTypeDefinition(type: .weekend)
    ]
}

/// Customizable day type settings
public struct DayTypeSettings: Codable, Sendable {
    private var weekdayTypes: [Weekday: DayType]
    private var customDayTypes: [DayTypeDefinition]
    
    public init() {
        weekdayTypes = [:]
        customDayTypes = []
    }
    
    /// Get the day type for a specific weekday
    public func dayType(for weekday: Weekday) -> DayType {
        weekdayTypes[weekday] ?? Self.defaultDayType(for: weekday)
    }
    
    /// Set the day type for a specific weekday
    public mutating func setDayType(_ dayType: DayType, for weekday: Weekday) {
        weekdayTypes[weekday] = dayType
    }
    
    /// Get all custom day types
    public func getAllCustomDayTypes() -> [DayTypeDefinition] {
        customDayTypes
    }
    
    /// Add a custom day type
    public mutating func addCustomDayType(_ dayType: DayTypeDefinition) {
        customDayTypes.append(dayType)
    }
    
    /// Update a custom day type
    public mutating func updateCustomDayType(_ updatedDayType: DayTypeDefinition) {
        if let index = customDayTypes.firstIndex(where: { $0.id == updatedDayType.id }) {
            customDayTypes[index] = updatedDayType
        }
    }
    
    /// Delete a custom day type
    public mutating func deleteCustomDayType(withId id: String) {
        customDayTypes.removeAll { $0.id == id && !$0.isBuiltIn }
    }
    
    /// Get day type for current day
    public func getCurrentDayType() -> DayType {
        dayType(for: Weekday.current())
    }
    
    /// Get day type for a specific date
    public func dayType(for date: Date) -> DayType {
        let weekday = Calendar.current.component(.weekday, from: date)
        let weekdayEnum = Weekday.from(calendarWeekday: weekday)
        return dayType(for: weekdayEnum)
    }
    
    /// Summary of current settings
    public var summary: String {
        let weekdays = Weekday.allCases.filter { dayType(for: $0) == .weekday }
        let weekends = Weekday.allCases.filter { dayType(for: $0) == .weekend }
        
        if weekdays.isEmpty {
            return "All days are weekends"
        } else if weekends.isEmpty {
            return "All days are weekdays"
        } else {
            let weekdayNames = weekdays.map(\.shortName).joined(separator: ", ")
            let weekendNames = weekends.map(\.shortName).joined(separator: ", ")
            return "Work: \(weekdayNames) • Rest: \(weekendNames)"
        }
    }
    
    /// Default day type for a weekday (standard Mon-Fri work schedule)
    private static func defaultDayType(for weekday: Weekday) -> DayType {
        switch weekday {
        case .sunday, .saturday:
            return .weekend
        case .monday, .tuesday, .wednesday, .thursday, .friday:
            return .weekday
        }
    }
    
    /// Standard settings (Mon-Fri weekdays, Sat-Sun weekend)
    public static let `default` = DayTypeSettings()
}

/// Manager for customizable day type settings
public final class DayTypeManager: ObservableObject, @unchecked Sendable {
    public static let shared = DayTypeManager()
    
    @Published private var settings: DayTypeSettings = .default
    private let queue = DispatchQueue(label: "DayTypeManager", qos: .userInitiated)
    
    private init() {
        loadSettings()
    }
    
    /// Get current day type settings
    public func getDayTypeSettings() -> DayTypeSettings {
        queue.sync { settings }
    }
    
    /// Update day type settings
    public func updateDayTypeSettings(_ newSettings: DayTypeSettings) {
        queue.sync {
            settings = newSettings
        }
        DispatchQueue.main.async {
            self.persistSettings()
        }
    }
    
    /// Get the current day type based on current date
    public func getCurrentDayType() -> DayType {
        let currentSettings = queue.sync { settings }
        return currentSettings.getCurrentDayType()
    }
    
    /// Get day type for a specific date
    public func dayType(for date: Date) -> DayType {
        let currentSettings = queue.sync { settings }
        return currentSettings.dayType(for: date)
    }
    
    /// Get all custom day types
    public func getAllCustomDayTypes() -> [DayTypeDefinition] {
        let currentSettings = queue.sync { settings }
        return currentSettings.getAllCustomDayTypes()
    }
    
    /// Add a custom day type
    public func addCustomDayType(_ dayType: DayTypeDefinition) {
        queue.sync {
            settings.addCustomDayType(dayType)
        }
        DispatchQueue.main.async {
            self.persistSettings()
        }
    }
    
    /// Update a custom day type
    public func updateCustomDayType(_ updatedDayType: DayTypeDefinition) {
        queue.sync {
            settings.updateCustomDayType(updatedDayType)
        }
        DispatchQueue.main.async {
            self.persistSettings()
        }
    }
    
    /// Delete a custom day type
    public func deleteCustomDayType(withId id: String) {
        queue.sync {
            settings.deleteCustomDayType(withId: id)
        }
        DispatchQueue.main.async {
            self.persistSettings()
        }
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        queue.sync {
            settings = .default
        }
        DispatchQueue.main.async {
            self.persistSettings()
        }
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "CustomDayTypeSettings") else {
            queue.sync {
                settings = .default
            }
            return
        }
        
        do {
            let loadedSettings = try JSONDecoder().decode(DayTypeSettings.self, from: data)
            queue.sync {
                settings = loadedSettings
            }
        } catch {
            print("Failed to load custom day type settings: \(error)")
            queue.sync {
                settings = .default
            }
        }
    }
    
    private func persistSettings() {
        let settingsToSave = queue.sync { settings }
        do {
            let data = try JSONEncoder().encode(settingsToSave)
            UserDefaults.standard.set(data, forKey: "CustomDayTypeSettings")
        } catch {
            print("Failed to save custom day type settings: \(error)")
        }
    }
}