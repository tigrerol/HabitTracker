import Foundation
import SwiftUI

/// Enhanced manager for flexible location categories
@Observable @MainActor
public final class LocationCategoryManager: Sendable {
    public static let shared = LocationCategoryManager()
    
    private var settings: LocationCategorySettings = .default
    private let persistenceService: any PersistenceServiceProtocol
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
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
        do {
            if let loadedSettings = try persistenceService.load(LocationCategorySettings.self, forKey: PersistenceKeys.locationCategorySettings) {
                settings = loadedSettings
                print("✅ Loaded location category settings from persistence")
                return
            }
        } catch {
            print("❌ Failed to load location category settings: \(error)")
        }
        
        // Fallback to defaults
        settings = .default
        print("🆕 Using default location category settings")
    }
    
    private func persistSettings() {
        do {
            try persistenceService.save(settings, forKey: PersistenceKeys.locationCategorySettings)
        } catch {
            print("❌ Failed to save location category settings: \(error)")
        }
    }
}