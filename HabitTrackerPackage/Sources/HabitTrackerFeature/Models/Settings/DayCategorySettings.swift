import Foundation

/// Enhanced day category settings with flexible categories
/// Supports multiple categories per weekday (e.g. Monday = "Weekday" + "Training Day")
public struct DayCategorySettings: Codable, Sendable {
    private var weekdayCategories: [Weekday: Set<String>] // Maps to category IDs (multiple per day)
    private var customCategories: [DayCategory]

    enum CodingKeys: String, CodingKey {
        case weekdayCategories
        case customCategories
    }

    public init() {
        weekdayCategories = [:]
        customCategories = DayCategory.defaults
    }

    // MARK: - Codable Migration

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customCategories = try container.decode([DayCategory].self, forKey: .customCategories)

        // Try new format first: [Weekday: Set<String>]
        if let newFormat = try? container.decode([Weekday: Set<String>].self, forKey: .weekdayCategories) {
            weekdayCategories = newFormat
        } else {
            // Fallback: decode old format [Weekday: String] and migrate to Set
            let oldFormat = try container.decode([Weekday: String].self, forKey: .weekdayCategories)
            weekdayCategories = oldFormat.mapValues { Set([$0]) }
        }
    }

    /// Get all available categories (built-in + custom)
    public func getAllCategories() -> [DayCategory] {
        customCategories
    }

    /// Get the categories for a specific weekday
    public func categories(for weekday: Weekday) -> [DayCategory] {
        guard let categoryIds = weekdayCategories[weekday], !categoryIds.isEmpty else {
            return Self.defaultCategories(for: weekday)
        }
        let resolved = categoryIds.compactMap { id in
            customCategories.first(where: { $0.id == id })
        }
        return resolved.isEmpty ? Self.defaultCategories(for: weekday) : resolved
    }

    /// Set the categories for a specific weekday
    public mutating func setCategories(_ categoryIds: Set<String>, for weekday: Weekday) {
        weekdayCategories[weekday] = categoryIds
    }

    /// Add or update a category (updates if ID already exists)
    public mutating func addCustomCategory(_ category: DayCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == category.id }) {
            customCategories[index] = category
        } else {
            customCategories.append(category)
        }
    }

    /// Update a custom category
    public mutating func updateCustomCategory(_ updatedCategory: DayCategory) {
        if let index = customCategories.firstIndex(where: { $0.id == updatedCategory.id }) {
            customCategories[index] = updatedCategory
        }
    }

    /// Delete a custom category and remove from weekday assignments
    public mutating func deleteCustomCategory(withId id: String) {
        // Don't delete built-in categories
        guard let categoryIndex = customCategories.firstIndex(where: { $0.id == id && !$0.isBuiltIn }) else {
            return
        }

        customCategories.remove(at: categoryIndex)

        // Remove this category ID from all weekday sets
        for weekday in Weekday.allCases {
            weekdayCategories[weekday]?.remove(id)
            // If set becomes empty, assign defaults
            if weekdayCategories[weekday]?.isEmpty ?? false {
                weekdayCategories[weekday] = Set(Self.defaultCategories(for: weekday).map(\.id))
            }
        }
    }

    /// Get categories for current day
    public func getCurrentCategories() -> [DayCategory] {
        categories(for: Weekday.current())
    }

    /// Get categories for a specific date
    public func categories(for date: Date) -> [DayCategory] {
        let weekday = Calendar.current.component(.weekday, from: date)
        let weekdayEnum = Weekday.from(calendarWeekday: weekday)
        return categories(for: weekdayEnum)
    }

    /// Summary of current settings
    public var summary: String {
        // Group weekdays by their category set (sorted for consistent comparison)
        let categoryGroups = Dictionary(grouping: Weekday.allCases) { weekday -> String in
            categories(for: weekday).map(\.name).sorted().joined(separator: " + ")
        }

        if categoryGroups.count == 1, let categoryName = categoryGroups.keys.first {
            return "All days: \(categoryName)"
        }

        let summaryParts = categoryGroups.map { categoryName, weekdays in
            let dayNames = weekdays.map(\.shortName).joined(separator: ", ")
            return "\(categoryName): \(dayNames)"
        }.sorted()

        return summaryParts.joined(separator: " • ")
    }

    /// Default categories for a weekday (standard Mon-Fri work schedule)
    private static func defaultCategories(for weekday: Weekday) -> [DayCategory] {
        switch weekday {
        case .sunday, .saturday:
            return [.weekend]
        case .monday, .tuesday, .wednesday, .thursday, .friday:
            return [.weekday]
        }
    }

    /// Standard settings (Mon-Fri weekdays, Sat-Sun weekend)
    public static let `default` = DayCategorySettings()
}
