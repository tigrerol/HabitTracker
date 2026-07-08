import Foundation
import SwiftData

/// SwiftData-based implementation of PersistenceService.
///
/// Storage split (deliberate): routine templates (with habits) and session
/// history live in SwiftData; every other key — paused/interrupted session
/// snapshots, day/location/time-slot settings, conditional responses — is
/// simple preference-style data and stays in UserDefaults via the fallback
/// branches below.
@MainActor
public final class SwiftDataPersistenceService: PersistenceServiceProtocol {
    private let modelContext: ModelContext
    private let userDefaults: UserDefaults
    private let migratesLegacyUserDefaults: Bool

    private static let legacyMigrationFlagKey = "HasMigratedToSwiftData"

    /// - Parameters:
    ///   - modelContext: the SwiftData context to store relational data in.
    ///   - migratesLegacyUserDefaults: when true, the first templates load
    ///     performs a one-shot import of templates and session history from
    ///     UserDefaults (the pre-SwiftData store). Enable only for the live
    ///     app instance, never for tests or previews.
    ///   - userDefaults: store for non-relational keys and the migration flag.
    public init(
        modelContext: ModelContext,
        migratesLegacyUserDefaults: Bool = false,
        userDefaults: UserDefaults = .standard
    ) {
        self.modelContext = modelContext
        self.migratesLegacyUserDefaults = migratesLegacyUserDefaults
        self.userDefaults = userDefaults
    }

    public func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        switch key {
        case PersistenceKeys.routineTemplates:
            if let templates = object as? [RoutineTemplate] {
                try saveRoutineTemplates(templates)
            } else {
                throw PersistenceError.encodingFailed(NSError(domain: "Invalid type for routine templates", code: 1))
            }

        case PersistenceKeys.savedLocations:
            if let locations = object as? [LocationType: SavedLocation] {
                try saveSavedLocations(locations)
            } else {
                throw PersistenceError.encodingFailed(NSError(domain: "Invalid type for saved locations", code: 1))
            }

        case PersistenceKeys.customLocations:
            if let locations = object as? [UUID: CustomLocation] {
                try saveCustomLocations(locations)
            } else {
                throw PersistenceError.encodingFailed(NSError(domain: "Invalid type for custom locations", code: 1))
            }

        default:
            let data = try JSONEncoder().encode(object)
            userDefaults.set(data, forKey: key)
        }
    }

    public func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        switch key {
        case PersistenceKeys.routineTemplates:
            guard type == [RoutineTemplate].self else { return nil }
            guard let templates = try await loadTemplatesMigratingIfNeeded() else { return nil }
            return templates as? T

        case PersistenceKeys.savedLocations:
            guard type == [LocationType: SavedLocation].self else { return nil }
            await migrateLegacyLocationsIfNeeded()
            let locations = loadSavedLocations()
            return locations.isEmpty ? nil : locations as? T

        case PersistenceKeys.customLocations:
            guard type == [UUID: CustomLocation].self else { return nil }
            await migrateLegacyLocationsIfNeeded()
            let locations = loadCustomLocations()
            return locations.isEmpty ? nil : locations as? T

        default:
            guard let data = userDefaults.data(forKey: key) else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
    }

    public func delete(forKey key: String) async {
        switch key {
        case PersistenceKeys.routineTemplates:
            deleteAllRoutineTemplates()

        case PersistenceKeys.savedLocations:
            try? saveSavedLocations([:])

        case PersistenceKeys.customLocations:
            try? saveCustomLocations([:])

        default:
            userDefaults.removeObject(forKey: key)
        }
    }

    public func exists(forKey key: String) async -> Bool {
        switch key {
        case PersistenceKeys.routineTemplates:
            return !getAllPersistedTemplates().isEmpty

        case PersistenceKeys.savedLocations:
            return !loadSavedLocations().isEmpty

        case PersistenceKeys.customLocations:
            return !loadCustomLocations().isEmpty

        default:
            return userDefaults.object(forKey: key) != nil
        }
    }

    // MARK: - Legacy UserDefaults Migration

    /// Load templates, first running the one-shot legacy import when enabled.
    ///
    /// Returns `nil` (instead of an empty array) when the store is empty right
    /// after the migration check — that signals a fresh install so the caller
    /// creates sample templates. Once the flag is set, an empty store is a
    /// deliberate user state and loads as `[]`.
    private func loadTemplatesMigratingIfNeeded() async throws -> [RoutineTemplate]? {
        if migratesLegacyUserDefaults && !userDefaults.bool(forKey: Self.legacyMigrationFlagKey) {
            try await migrateLegacyUserDefaultsData()
            userDefaults.set(true, forKey: Self.legacyMigrationFlagKey)
            let templates = try loadRoutineTemplates()
            return templates.isEmpty ? nil : templates
        }
        return try loadRoutineTemplates()
    }

    /// One-shot import of the pre-SwiftData store: routine templates plus each
    /// template's session history (streaks read it). The UserDefaults keys are
    /// intentionally left in place as a rollback safety net.
    private func migrateLegacyUserDefaultsData() async throws {
        let legacy = UserDefaultsPersistenceService(userDefaults: userDefaults)
        guard let templates = try? await legacy.load([RoutineTemplate].self, forKey: PersistenceKeys.routineTemplates),
              !templates.isEmpty else { return }

        try saveRoutineTemplates(templates)

        var migratedSessions = 0
        for template in templates {
            for session in await legacy.loadRoutineSessions(for: template.id) {
                await saveRoutineSession(session, for: template.id)
                migratedSessions += 1
            }
        }

        LoggingService.shared.info(
            "Migrated legacy UserDefaults data to SwiftData",
            category: .app,
            metadata: [
                "templates": String(templates.count),
                "sessions": String(migratedSessions)
            ]
        )
    }

    // MARK: - Routine Template Operations

    private func saveRoutineTemplates(_ templates: [RoutineTemplate]) throws {
        // Get existing persisted templates
        let existingTemplates = getAllPersistedTemplates()

        // Remove templates that no longer exist
        for existingTemplate in existingTemplates {
            if !templates.contains(where: { $0.id == existingTemplate.id }) {
                modelContext.delete(existingTemplate)
            }
        }

        // Update or create templates
        for template in templates {
            if let existingTemplate = existingTemplates.first(where: { $0.id == template.id }) {
                existingTemplate.update(from: template)
            } else {
                // Insert before establishing relationships — wiring them on a
                // model that is not yet in a context crashes SwiftData.
                let persistedTemplate = PersistedRoutineTemplate(from: template)
                modelContext.insert(persistedTemplate)
                for habit in template.habits {
                    let persistedHabit = PersistedHabit(from: habit)
                    modelContext.insert(persistedHabit)
                    persistedHabit.template = persistedTemplate
                }
            }
        }

        try modelContext.save()
    }

    private func loadRoutineTemplates() throws -> [RoutineTemplate] {
        let persistedTemplates = getAllPersistedTemplates()
        return persistedTemplates.map { $0.toDomainModel() }
    }

    private func deleteAllRoutineTemplates() {
        let templates = getAllPersistedTemplates()
        for template in templates {
            modelContext.delete(template)
        }

        try? modelContext.save()
    }

    private func getAllPersistedTemplates() -> [PersistedRoutineTemplate] {
        let descriptor = FetchDescriptor<PersistedRoutineTemplate>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    // MARK: - Session Operations

    /// Load routine sessions for a specific template.
    /// Fetches sessions directly by template id — reading the template's
    /// `sessions` inverse array is not reliably materialized right after inserts.
    public func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData] {
        let descriptor = FetchDescriptor<PersistedRoutineSession>(
            predicate: #Predicate { $0.template?.id == templateId },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        let persistedSessions = (try? modelContext.fetch(descriptor)) ?? []

        return persistedSessions.map { persistedSession in
            let modifications: [SessionModification]
            if let decoded = try? JSONDecoder().decode([SessionModification].self, from: persistedSession.modificationsData) {
                modifications = decoded
            } else {
                modifications = []
            }

            let completions = persistedSession.completions.map { $0.toDomainModel() }

            return RoutineSessionData(
                id: persistedSession.id,
                startedAt: persistedSession.startedAt,
                completedAt: persistedSession.completedAt,
                currentHabitIndex: persistedSession.currentHabitIndex,
                completions: completions,
                modifications: modifications
            )
        }
    }

    /// Append a session record to the template's session list.
    public func saveRoutineSession(_ session: RoutineSessionData, for templateId: UUID) async {
        guard let persistedTemplate = getPersistedTemplate(id: templateId) else { return }

        if let existing = getPersistedSession(id: session.id) {
            existing.completedAt = session.completedAt
            existing.currentHabitIndex = session.currentHabitIndex
            if let data = try? JSONEncoder().encode(session.modifications) {
                existing.modificationsData = data
            }
        } else {
            let persisted = PersistedRoutineSession(
                id: session.id,
                startedAt: session.startedAt,
                completedAt: session.completedAt,
                currentHabitIndex: session.currentHabitIndex
            )
            if let data = try? JSONEncoder().encode(session.modifications) {
                persisted.modificationsData = data
            }
            modelContext.insert(persisted)
            persisted.template = persistedTemplate
            for completion in session.completions {
                let persistedCompletion = PersistedHabitCompletion(from: completion)
                modelContext.insert(persistedCompletion)
                persistedCompletion.session = persisted
            }
        }

        do {
            try modelContext.save()
        } catch {
            LoggingService.shared.error(
                "Failed to save routine session",
                category: .app,
                metadata: ["sessionId": session.id.uuidString, "error": String(describing: error)]
            )
        }
    }

    private func getPersistedTemplate(id: UUID) -> PersistedRoutineTemplate? {
        let descriptor = FetchDescriptor<PersistedRoutineTemplate>(
            predicate: #Predicate { $0.id == id }
        )

        return try? modelContext.fetch(descriptor).first
    }

    private func getPersistedSession(id: UUID) -> PersistedRoutineSession? {
        let descriptor = FetchDescriptor<PersistedRoutineSession>(
            predicate: #Predicate { $0.id == id }
        )

        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Location Operations

    private static let legacyLocationMigrationFlagKey = "HasMigratedLocationsToSwiftData"

    /// One-shot import of locations from the pre-SwiftData UserDefaults store.
    /// Gated on the same opt-in as the template migration so tests and
    /// previews never touch real UserDefaults.
    private func migrateLegacyLocationsIfNeeded() async {
        guard migratesLegacyUserDefaults,
              !userDefaults.bool(forKey: Self.legacyLocationMigrationFlagKey) else { return }
        userDefaults.set(true, forKey: Self.legacyLocationMigrationFlagKey)

        let legacy = UserDefaultsPersistenceService(userDefaults: userDefaults)
        let saved = (try? await legacy.load([LocationType: SavedLocation].self, forKey: PersistenceKeys.savedLocations)) ?? [:]
        let custom = (try? await legacy.load([UUID: CustomLocation].self, forKey: PersistenceKeys.customLocations)) ?? [:]
        guard !saved.isEmpty || !custom.isEmpty else { return }

        try? saveSavedLocations(saved)
        try? saveCustomLocations(custom)
        LoggingService.shared.info(
            "Migrated legacy locations to SwiftData",
            category: .app,
            metadata: ["saved": String(saved.count), "custom": String(custom.count)]
        )
    }

    private func saveSavedLocations(_ locations: [LocationType: SavedLocation]) throws {
        let existing = (try? modelContext.fetch(FetchDescriptor<PersistedSavedLocation>())) ?? []
        for location in existing {
            modelContext.delete(location)
        }
        for (type, location) in locations {
            modelContext.insert(PersistedSavedLocation(from: location, locationType: type))
        }
        try modelContext.save()
    }

    private func loadSavedLocations() -> [LocationType: SavedLocation] {
        let persisted = (try? modelContext.fetch(FetchDescriptor<PersistedSavedLocation>())) ?? []
        var result: [LocationType: SavedLocation] = [:]
        for entry in persisted {
            if let (location, type) = entry.toDomainModel() {
                result[type] = location
            }
        }
        return result
    }

    private func saveCustomLocations(_ locations: [UUID: CustomLocation]) throws {
        let existing = (try? modelContext.fetch(FetchDescriptor<PersistedCustomLocation>())) ?? []
        for location in existing {
            modelContext.delete(location)
        }
        for (_, location) in locations {
            modelContext.insert(PersistedCustomLocation(from: location))
        }
        try modelContext.save()
    }

    private func loadCustomLocations() -> [UUID: CustomLocation] {
        let persisted = (try? modelContext.fetch(FetchDescriptor<PersistedCustomLocation>())) ?? []
        var result: [UUID: CustomLocation] = [:]
        for entry in persisted {
            let location = entry.toDomainModel()
            result[location.id] = location
        }
        return result
    }

    // MARK: - Mood Rating Operations

    /// Save mood ratings (replace semantics), stored as PersistedMoodRating rows.
    public func saveMoodRatings(_ ratings: [MoodRating]) async {
        // Remove existing ratings and replace with new ones
        let existingRatings = getAllPersistedMoodRatings()
        for rating in existingRatings {
            modelContext.delete(rating)
        }

        // Insert new ratings
        for rating in ratings {
            let persistedRating = PersistedMoodRating(from: rating)
            modelContext.insert(persistedRating)
        }

        do {
            try modelContext.save()
        } catch {
            LoggingService.shared.error(
                "Failed to save mood ratings",
                category: .app,
                metadata: ["error": String(describing: error)]
            )
        }
    }

    /// Load mood ratings
    public func loadMoodRatings() async -> [MoodRating] {
        let persistedRatings = getAllPersistedMoodRatings()
        return persistedRatings.compactMap { $0.toDomainModel() }
    }

    private func getAllPersistedMoodRatings() -> [PersistedMoodRating] {
        let descriptor = FetchDescriptor<PersistedMoodRating>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }
}

/// Data structure for transferring session data
public struct RoutineSessionData: Codable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date?
    public let currentHabitIndex: Int
    public let completions: [HabitCompletion]
    public let modifications: [SessionModification]

    public init(
        id: UUID,
        startedAt: Date,
        completedAt: Date?,
        currentHabitIndex: Int,
        completions: [HabitCompletion],
        modifications: [SessionModification]
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.currentHabitIndex = currentHabitIndex
        self.completions = completions
        self.modifications = modifications
    }
}
