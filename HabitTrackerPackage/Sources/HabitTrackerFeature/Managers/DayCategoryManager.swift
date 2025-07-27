import Foundation
import SwiftUI

/// Enhanced manager for flexible day categories
@Observable @MainActor
public final class DayCategoryManager: Sendable {
    public static let shared = DayCategoryManager()
    
    private var settings: DayCategorySettings = .default
    private let persistenceService: any PersistenceServiceProtocol
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
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
        Task { @MainActor in
            do {
                if let loadedSettings = try await persistenceService.load(DayCategorySettings.self, forKey: PersistenceKeys.dayCategorySettings) {
                    settings = loadedSettings
                    print("✅ Loaded day category settings from persistence")
                    return
                }
            } catch {
                print("❌ Failed to load day category settings: \(error)")
            }
            
            // Fallback to defaults
            settings = .default
            print("🆕 Using default day category settings")
        }
    }
    
    private func persistSettings() {
        Task { @MainActor in
            do {
                try await persistenceService.save(settings, forKey: PersistenceKeys.dayCategorySettings)
            } catch {
                print("❌ Failed to save day category settings: \(error)")
            }
        }
    }
}