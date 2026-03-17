import Foundation
import SwiftData

// MARK: - Schema Versioning

/// Baseline schema version (v1) — all current @Model types
public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            PersistedHabit.self,
            PersistedRoutineTemplate.self,
            PersistedRoutineSession.self,
            PersistedHabitCompletion.self,
            PersistedMoodRating.self,
            PersistedSavedLocation.self,
            PersistedCustomLocation.self
        ]
    }
}

/// Migration plan — add new schema versions and migration stages here
public enum HabitTrackerMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        [] // No migrations yet — SchemaV1 is the baseline
    }
}

/// Configuration for the SwiftData model container
public enum DataModelConfiguration {

    /// All model types used in the schema
    static let allModelTypes: [any PersistentModel.Type] = [
        PersistedHabit.self,
        PersistedRoutineTemplate.self,
        PersistedRoutineSession.self,
        PersistedHabitCompletion.self,
        PersistedMoodRating.self,
        PersistedSavedLocation.self,
        PersistedCustomLocation.self
    ]

    /// Create the model container with schema versioning and migration plan
    public static func createModelContainer() throws -> ModelContainer {
        let schema = Schema(allModelTypes)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: HabitTrackerMigrationPlan.self,
            configurations: [modelConfiguration]
        )
    }

    /// Create a model container for testing (in-memory)
    public static func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema(allModelTypes)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
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
            LoggingService.shared.info("Migrated \(templates.count) routine templates to SwiftData", category: .app)
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
            LoggingService.shared.info("Migrated location data to SwiftData", category: .app)
        }
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "HasMigratedToSwiftData")
        LoggingService.shared.info("Migration to SwiftData completed", category: .app)
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