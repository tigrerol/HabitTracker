import Foundation
import SwiftData

/// Configuration for the SwiftData model container
public enum DataModelConfiguration {
    
    /// Create the model container with all required models
    public static func createModelContainer() throws -> ModelContainer {
        let schema = Schema([
            PersistedHabit.self,
            PersistedRoutineTemplate.self,
            PersistedRoutineSession.self,
            PersistedHabitCompletion.self,
            PersistedMoodRating.self,
            PersistedSavedLocation.self,
            PersistedCustomLocation.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none // Can be changed to .automatic for CloudKit sync
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    /// Create a model container for testing (in-memory)
    public static func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema([
            PersistedHabit.self,
            PersistedRoutineTemplate.self,
            PersistedRoutineSession.self,
            PersistedHabitCompletion.self,
            PersistedMoodRating.self,
            PersistedSavedLocation.self,
            PersistedCustomLocation.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true // In-memory for testing
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    /// Migration helper for moving from UserDefaults to SwiftData
    @MainActor
    public static func migrateFromUserDefaults(
        to persistenceService: SwiftDataPersistenceService
    ) async throws {
        let userDefaultsService = UserDefaultsPersistenceService()
        
        // Migrate routine templates
        if let templates = try await userDefaultsService.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates) {
            try await persistenceService.save(templates, forKey: PersistenceKeys.routineTemplates)
            print("✅ Migrated \(templates.count) routine templates to SwiftData")
        }
        
        // Migrate location data (from UserDefaults keys used by LocationService)
        if let savedLocationsData = UserDefaults.standard.data(forKey: "SavedLocations"),
           let savedLocations = try? JSONDecoder().decode([LocationType: SavedLocation].self, from: savedLocationsData) {
            
            var customLocations: [UUID: CustomLocation] = [:]
            if let customLocationsData = UserDefaults.standard.data(forKey: "CustomLocations") {
                customLocations = (try? JSONDecoder().decode([UUID: CustomLocation].self, from: customLocationsData)) ?? [:]
            }
            
            try await persistenceService.saveLocationData(
                savedLocations: savedLocations,
                customLocations: customLocations
            )
            print("✅ Migrated location data to SwiftData")
        }
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "HasMigratedToSwiftData")
        print("✅ Migration to SwiftData completed")
    }
    
    /// Check if migration from UserDefaults has been completed
    public static func hasMigratedFromUserDefaults() -> Bool {
        UserDefaults.standard.bool(forKey: "HasMigratedToSwiftData")
    }
}

/// Extension to help with CloudKit setup if needed in the future
extension DataModelConfiguration {
    
    /// Create model container with CloudKit support
    public static func createCloudKitModelContainer() throws -> ModelContainer {
        let schema = Schema([
            PersistedHabit.self,
            PersistedRoutineTemplate.self,
            PersistedRoutineSession.self,
            PersistedHabitCompletion.self,
            PersistedMoodRating.self,
            PersistedSavedLocation.self,
            PersistedCustomLocation.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic // Enable CloudKit sync
        )
        
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}