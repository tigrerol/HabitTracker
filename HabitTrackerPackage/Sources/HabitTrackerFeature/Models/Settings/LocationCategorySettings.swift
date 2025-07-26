import Foundation

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