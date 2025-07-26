import Foundation
import SwiftUI

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

/// Flexible day category that users can customize
public struct DayCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var colorData: Data
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        color: Color = .blue,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorData = Self.encodeColor(color)
        self.isBuiltIn = isBuiltIn
    }
    
    /// Color property computed from colorData
    public var color: Color {
        Self.decodeColor(from: colorData)
    }
    
    /// Update color
    public mutating func setColor(_ color: Color) {
        colorData = Self.encodeColor(color)
    }
    
    /// Display name
    public var displayName: String {
        name
    }
    
    /// Built-in categories for backwards compatibility
    public static let weekday = DayCategory(
        id: "weekday",
        name: "Weekday",
        icon: "briefcase",
        color: .blue,
        isBuiltIn: true
    )
    
    public static let weekend = DayCategory(
        id: "weekend", 
        name: "Weekend",
        icon: "house",
        color: .green,
        isBuiltIn: true
    )
    
    /// Default categories
    public static let defaults: [DayCategory] = [weekday, weekend]
    
    // MARK: - Color Encoding/Decoding
    
    internal static func encodeColor(_ color: Color) -> Data {
        do {
            let resolved = color.resolve(in: .init())
            let colorInfo = ColorInfo(
                red: resolved.red,
                green: resolved.green,
                blue: resolved.blue,
                opacity: resolved.opacity
            )
            return try JSONEncoder().encode(colorInfo)
        } catch {
            // Fallback to blue
            let fallback = ColorInfo(red: 0.0, green: 0.5, blue: 1.0, opacity: 1.0)
            return (try? JSONEncoder().encode(fallback)) ?? Data()
        }
    }
    
    internal static func decodeColor(from data: Data) -> Color {
        do {
            let colorInfo = try JSONDecoder().decode(ColorInfo.self, from: data)
            return Color(
                red: Double(colorInfo.red),
                green: Double(colorInfo.green),
                blue: Double(colorInfo.blue),
                opacity: Double(colorInfo.opacity)
            )
        } catch {
            return .blue
        }
    }
    
    private struct ColorInfo: Codable {
        let red: Float
        let green: Float
        let blue: Float
        let opacity: Float
    }
}


/// Enhanced day category settings with flexible categories
public struct DayCategorySettings: Codable, Sendable {
    private var weekdayCategories: [Weekday: String] // Maps to category ID
    private var customCategories: [DayCategory]
    
    public init() {
        weekdayCategories = [:]
        customCategories = DayCategory.defaults
    }
    
    /// Get all available categories (built-in + custom)
    public func getAllCategories() -> [DayCategory] {
        customCategories
    }
    
    /// Get the category for a specific weekday
    public func category(for weekday: Weekday) -> DayCategory {
        guard let categoryId = weekdayCategories[weekday],
              let category = customCategories.first(where: { $0.id == categoryId }) else {
            return Self.defaultCategory(for: weekday)
        }
        return category
    }
    
    /// Set the category for a specific weekday
    public mutating func setCategory(_ categoryId: String, for weekday: Weekday) {
        weekdayCategories[weekday] = categoryId
    }
    
    /// Add a custom category
    public mutating func addCustomCategory(_ category: DayCategory) {
        // Prevent duplicate IDs
        if !customCategories.contains(where: { $0.id == category.id }) {
            customCategories.append(category)
        }
    }
    
    /// Update a custom category
    public mutating func updateCustomCategory(_ updatedCategory: DayCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == updatedCategory.id }) {
            customCategories[index] = updatedCategory
        }
    }
    
    /// Delete a custom category and reassign days to default
    public mutating func deleteCustomCategory(withId id: String) {
        // Don't delete built-in categories
        guard let categoryIndex = customCategories.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) else {
            return
        }
        
        customCategories.remove(at: categoryIndex)
        
        // Reassign any weekdays using this category to default
        for weekday in Weekday.allCases {
            if weekdayCategories[weekday] == id {
                weekdayCategories[weekday] = Self.defaultCategory(for: weekday).id
            }
        }
    }
    
    /// Get category for current day
    public func getCurrentCategory() -> DayCategory {
        category(for: Weekday.current())
    }
    
    /// Get category for a specific date
    public func category(for date: Date) -> DayCategory {
        let weekday = Calendar.current.component(.weekday, from: date)
        let weekdayEnum = Weekday.from(calendarWeekday: weekday)
        return category(for: weekdayEnum)
    }
    
    /// Summary of current settings
    public var summary: String {
        let categoryGroups = Dictionary(grouping: Weekday.allCases) { weekday in
            category(for: weekday).name
        }
        
        if categoryGroups.count == 1, let categoryName = categoryGroups.keys.first {
            return "All days: \(categoryName)"
        }
        
        let summaryParts = categoryGroups.map { categoryName, weekdays in
            let dayNames = weekdays.map(\.shortName).joined(separator: ", ")
            return "\(categoryName): \(dayNames)"
        }
        
        return summaryParts.joined(separator: " • ")
    }
    
    /// Default category for a weekday (standard Mon-Fri work schedule)
    private static func defaultCategory(for weekday: Weekday) -> DayCategory {
        switch weekday {
        case .sunday, .saturday:
            return .weekend
        case .monday, .tuesday, .wednesday, .thursday, .friday:
            return .weekday
        }
    }
    
    /// Standard settings (Mon-Fri weekdays, Sat-Sun weekend)
    public static let `default` = DayCategorySettings()
}


/// Flexible location category that users can customize
public struct LocationCategory: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var icon: String
    public var colorData: Data
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        color: Color = .blue,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorData = DayCategory.encodeColor(color)
        self.isBuiltIn = isBuiltIn
    }
    
    /// Color property computed from colorData
    public var color: Color {
        DayCategory.decodeColor(from: colorData)
    }
    
    /// Update color
    public mutating func setColor(_ color: Color) {
        colorData = DayCategory.encodeColor(color)
    }
    
    /// Display name
    public var displayName: String {
        name
    }
    
    /// Built-in categories for backwards compatibility
    public static let home = LocationCategory(
        id: "home",
        name: "Home",
        icon: "house.fill",
        color: .green,
        isBuiltIn: true
    )
    
    public static let office = LocationCategory(
        id: "office",
        name: "Office", 
        icon: "building.2.fill",
        color: .blue,
        isBuiltIn: true
    )
    
    public static let unknown = LocationCategory(
        id: "unknown",
        name: "Unknown",
        icon: "location.slash",
        color: .gray,
        isBuiltIn: true
    )
    
    /// Default categories
    public static let defaults: [LocationCategory] = [home, office, unknown]
}

/// Enhanced location category settings with flexible categories
public struct LocationCategorySettings: Codable, Sendable {
    private var customCategories: [LocationCategory]
    
    public init() {
        customCategories = LocationCategory.defaults
    }
    
    /// Get all available categories (built-in + custom)
    public func getAllCategories() -> [LocationCategory] {
        customCategories
    }
    
    /// Add a custom category
    public mutating func addCustomCategory(_ category: LocationCategory) {
        // Prevent duplicate IDs
        if !customCategories.contains(where: { $0.id == category.id }) {
            customCategories.append(category)
        }
    }
    
    /// Update a custom category
    public mutating func updateCustomCategory(_ updatedCategory: LocationCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == updatedCategory.id }) {
            customCategories[index] = updatedCategory
        }
    }
    
    /// Delete a custom category
    public mutating func deleteCustomCategory(withId id: String) {
        // Don't delete built-in categories
        customCategories.removeAll { $0.id == id && !$0.isBuiltIn }
    }
    
    /// Get category by ID
    public func category(withId id: String) -> LocationCategory? {
        customCategories.first { $0.id == id }
    }
    
    /// Standard settings (Home, Office, Unknown)
    public static let `default` = LocationCategorySettings()
}

/// Enhanced manager for flexible location categories
@Observable @MainActor
public final class LocationCategoryManager: Sendable {
    public static let shared = LocationCategoryManager()
    
    private var settings: LocationCategorySettings = .default
    
    private init() {
        loadSettings()
    }
    
    /// Get current location category settings
    public func getLocationCategorySettings() -> LocationCategorySettings {
        settings
    }
    
    /// Update location category settings
    public func updateLocationCategorySettings(_ newSettings: LocationCategorySettings) {
        settings = newSettings
        persistSettings()
    }
    
    /// Get all available categories
    public func getAllCategories() -> [LocationCategory] {
        settings.getAllCategories()
    }
    
    /// Get category by ID
    public func category(withId id: String) -> LocationCategory? {
        settings.category(withId: id)
    }
    
    /// Add a custom category
    public func addCustomCategory(_ category: LocationCategory) {
        settings.addCustomCategory(category)
        persistSettings()
    }
    
    /// Update a custom category
    public func updateCustomCategory(_ updatedCategory: LocationCategory) {
        settings.updateCustomCategory(updatedCategory)
        persistSettings()
    }
    
    /// Delete a custom category
    public func deleteCustomCategory(withId id: String) {
        settings.deleteCustomCategory(withId: id)
        persistSettings()
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        settings = .default
        persistSettings()
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "LocationCategorySettings") {
            do {
                settings = try JSONDecoder().decode(LocationCategorySettings.self, from: data)
                return
            } catch {
                print("Failed to load location category settings: \(error)")
            }
        }
        
        // Fallback to defaults
        settings = .default
    }
    
    private func persistSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: "LocationCategorySettings")
        } catch {
            print("Failed to save location category settings: \(error)")
        }
    }
}

/// Enhanced manager for flexible day categories
@Observable @MainActor
public final class DayCategoryManager: Sendable {
    public static let shared = DayCategoryManager()
    
    private var settings: DayCategorySettings = .default
    
    private init() {
        loadSettings()
    }
    
    /// Get current day category settings
    public func getDayCategorySettings() -> DayCategorySettings {
        settings
    }
    
    /// Update day category settings
    public func updateDayCategorySettings(_ newSettings: DayCategorySettings) {
        settings = newSettings
        persistSettings()
    }
    
    /// Get all available categories
    public func getAllCategories() -> [DayCategory] {
        settings.getAllCategories()
    }
    
    /// Get the current day category based on current date
    public func getCurrentDayCategory() -> DayCategory {
        settings.getCurrentCategory()
    }
    
    /// Get category for a specific date
    public func category(for date: Date) -> DayCategory {
        settings.category(for: date)
    }
    
    /// Get category for a specific weekday
    public func category(for weekday: Weekday) -> DayCategory {
        settings.category(for: weekday)
    }
    
    /// Set category for a specific weekday
    public func setCategory(_ categoryId: String, for weekday: Weekday) {
        settings.setCategory(categoryId, for: weekday)
        persistSettings()
    }
    
    /// Add a custom category
    public func addCustomCategory(_ category: DayCategory) {
        settings.addCustomCategory(category)
        persistSettings()
    }
    
    /// Update a custom category
    public func updateCustomCategory(_ updatedCategory: DayCategory) {
        settings.updateCustomCategory(updatedCategory)
        persistSettings()
    }
    
    /// Delete a custom category
    public func deleteCustomCategory(withId id: String) {
        settings.deleteCustomCategory(withId: id)
        persistSettings()
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        settings = .default
        persistSettings()
    }
    
    
    // MARK: - Persistence
    
    private func loadSettings() {
        // Try to load new format first
        if let data = UserDefaults.standard.data(forKey: "DayCategorySettings") {
            do {
                settings = try JSONDecoder().decode(DayCategorySettings.self, from: data)
                return
            } catch {
                print("Failed to load day category settings: \(error)")
            }
        }
        
        
        // Fallback to defaults
        settings = .default
    }
    
    private func persistSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: "DayCategorySettings")
        } catch {
            print("Failed to save day category settings: \(error)")
        }
    }
    
}

