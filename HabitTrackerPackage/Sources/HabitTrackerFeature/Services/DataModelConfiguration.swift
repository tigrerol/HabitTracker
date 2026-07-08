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

    /// The app-wide container backing `RoutineService.shared` and the SwiftUI
    /// environment. Falls back to an in-memory store (with a logged error)
    /// rather than crashing if the persistent store cannot be opened.
    @MainActor
    public static let sharedContainer: ModelContainer = {
        do {
            return try createModelContainer()
        } catch {
            LoggingService.shared.error(
                "Failed to open persistent SwiftData store — falling back to in-memory (data will not persist this launch)",
                category: .app,
                metadata: ["error": String(describing: error)]
            )
            do {
                return try createTestModelContainer()
            } catch {
                fatalError("Unable to create any ModelContainer: \(error)")
            }
        }
    }()

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

    /// Create a model container for testing (in-memory).
    ///
    /// IMPORTANT: keep the returned container alive for as long as any of its
    /// contexts are in use — ModelContext does not retain its container, and
    /// fetching through a context whose container was deallocated crashes.
    public static func createTestModelContainer() throws -> ModelContainer {
        let schema = Schema(allModelTypes)

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
    
    // Legacy UserDefaults → SwiftData migration lives in
    // SwiftDataPersistenceService (one-shot, on first templates load).
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