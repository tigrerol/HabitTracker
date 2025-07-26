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
    
    private static func encodeColor(_ color: Color) -> Data {
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
    
    private static func decodeColor(from data: Data) -> Color {
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

/// Legacy day type definition for backwards compatibility
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

/// Legacy day type settings for backwards compatibility
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
    
    // MARK: - Legacy support for DayType
    
    /// Get legacy day type for backwards compatibility
    public func getDayType(for date: Date) -> DayType {
        let category = settings.category(for: date)
        switch category.id {
        case "weekday":
            return .weekday
        case "weekend":
            return .weekend
        default:
            // For custom categories, map based on traditional workday pattern
            let weekday = Calendar.current.component(.weekday, from: date)
            return (weekday == 1 || weekday == 7) ? .weekend : .weekday
        }
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
        
        // Try to migrate from old format
        if let data = UserDefaults.standard.data(forKey: "CustomDayTypeSettings") {
            do {
                let oldSettings = try JSONDecoder().decode(DayTypeSettings.self, from: data)
                settings = migrateLegacySettings(oldSettings)
                persistSettings() // Save migrated data
                return
            } catch {
                print("Failed to migrate legacy day type settings: \(error)")
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
    
    private func migrateLegacySettings(_ legacySettings: DayTypeSettings) -> DayCategorySettings {
        var newSettings = DayCategorySettings.default
        
        // Map legacy day type assignments to new categories
        for weekday in Weekday.allCases {
            let dayType = legacySettings.dayType(for: weekday)
            let categoryId = dayType == .weekday ? "weekday" : "weekend"
            newSettings.setCategory(categoryId, for: weekday)
        }
        
        return newSettings
    }
}

/// Legacy manager for backwards compatibility
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