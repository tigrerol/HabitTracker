import Foundation

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