import Foundation
import SwiftData

/// SwiftData-based implementation of PersistenceService
@MainActor
public final class SwiftDataPersistenceService: PersistenceServiceProtocol {
    private let modelContext: ModelContext
    
    /// Initialize with a ModelContext
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Save routine templates
    public func save<T: Codable>(_ object: T, forKey key: String) throws {
        switch key {
        case PersistenceKeys.routineTemplates:
            if let templates = object as? [RoutineTemplate] {
                try saveRoutineTemplates(templates)
            } else {
                throw PersistenceError.encodingFailed(NSError(domain: "Invalid type for routine templates", code: 1))
            }
            
        case PersistenceKeys.dayCategorySettings:
            // For settings, we'll continue using UserDefaults as they're simple key-value data
            let data = try JSONEncoder().encode(object)
            UserDefaults.standard.set(data, forKey: key)
            
        case PersistenceKeys.locationCategorySettings:
            // For settings, we'll continue using UserDefaults as they're simple key-value data
            let data = try JSONEncoder().encode(object)
            UserDefaults.standard.set(data, forKey: key)
            
        default:
            // Unknown key, use UserDefaults as fallback
            let data = try JSONEncoder().encode(object)
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    /// Load routine templates or other data
    public func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        switch key {
        case PersistenceKeys.routineTemplates:
            if type == [RoutineTemplate].self {
                let templates = try loadRoutineTemplates()
                return templates as? T
            }
            
        case PersistenceKeys.dayCategorySettings, PersistenceKeys.locationCategorySettings:
            // Load from UserDefaults for settings
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try JSONDecoder().decode(type, from: data)
            
        default:
            // Unknown key, try UserDefaults
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try JSONDecoder().decode(type, from: data)
        }
        
        return nil
    }
    
    /// Delete data
    public func delete(forKey key: String) {
        switch key {
        case PersistenceKeys.routineTemplates:
            deleteAllRoutineTemplates()
            
        default:
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    /// Check if data exists
    public func exists(forKey key: String) -> Bool {
        switch key {
        case PersistenceKeys.routineTemplates:
            return !getAllPersistedTemplates().isEmpty
            
        default:
            return UserDefaults.standard.object(forKey: key) != nil
        }
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
                let persistedTemplate = PersistedRoutineTemplate(from: template)
                
                // Manually associate habits with the new template
                for habit in persistedTemplate.habits {
                    habit.template = persistedTemplate
                }
                
                modelContext.insert(persistedTemplate)
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
            print("Failed to fetch persisted templates: \(error)")
            return []
        }
    }
    
    // MARK: - Session Operations
    
    /// Save a routine session
    public func saveRoutineSession(_ session: RoutineSession, templateId: UUID) throws {
        // Find the persisted template
        guard let persistedTemplate = getPersistedTemplate(id: templateId) else {
            throw PersistenceError.keyNotFound("Template with id \(templateId) not found")
        }
        
        // Check if session already exists
        if let existingSession = getPersistedSession(id: session.id) {
            existingSession.update(from: session)
        } else {
            let persistedSession = PersistedRoutineSession(from: session, template: persistedTemplate)
            modelContext.insert(persistedSession)
        }
        
        try modelContext.save()
    }
    
    /// Load routine sessions for a specific template
    public func loadRoutineSessions(for templateId: UUID) -> [RoutineSessionData] {
        guard let persistedTemplate = getPersistedTemplate(id: templateId) else { return [] }
        
        return persistedTemplate.sessions.compactMap { persistedSession in
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
    
    // MARK: - Mood Rating Operations
    
    /// Save mood ratings
    public func saveMoodRatings(_ ratings: [MoodRating]) throws {
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
        
        try modelContext.save()
    }
    
    /// Load mood ratings
    public func loadMoodRatings() -> [MoodRating] {
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
            print("Failed to fetch persisted mood ratings: \(error)")
            return []
        }
    }
    
    // MARK: - Location Operations
    
    /// Save location data
    public func saveLocationData(
        savedLocations: [LocationType: SavedLocation],
        customLocations: [UUID: CustomLocation]
    ) throws {
        // Save saved locations
        let existingSavedLocations = getAllPersistedSavedLocations()
        for existingLocation in existingSavedLocations {
            modelContext.delete(existingLocation)
        }
        
        for (locationType, savedLocation) in savedLocations {
            let persistedLocation = PersistedSavedLocation(from: savedLocation, locationType: locationType)
            modelContext.insert(persistedLocation)
        }
        
        // Save custom locations
        let existingCustomLocations = getAllPersistedCustomLocations()
        for existingLocation in existingCustomLocations {
            if let customLocation = customLocations[existingLocation.id] {
                existingLocation.update(from: customLocation)
            } else {
                modelContext.delete(existingLocation)
            }
        }
        
        for (_, customLocation) in customLocations {
            if !existingCustomLocations.contains(where: { $0.id == customLocation.id }) {
                let persistedCustomLocation = PersistedCustomLocation(from: customLocation)
                modelContext.insert(persistedCustomLocation)
            }
        }
        
        try modelContext.save()
    }
    
    /// Load location data
    public func loadLocationData() -> (savedLocations: [LocationType: SavedLocation], customLocations: [UUID: CustomLocation]) {
        let persistedSavedLocations = getAllPersistedSavedLocations()
        let persistedCustomLocations = getAllPersistedCustomLocations()
        
        var savedLocations: [LocationType: SavedLocation] = [:]
        for persistedLocation in persistedSavedLocations {
            if let (savedLocation, locationType) = persistedLocation.toDomainModel() {
                savedLocations[locationType] = savedLocation
            }
        }
        
        var customLocations: [UUID: CustomLocation] = [:]
        for persistedCustomLocation in persistedCustomLocations {
            let customLocation = persistedCustomLocation.toDomainModel()
            customLocations[customLocation.id] = customLocation
        }
        
        return (savedLocations, customLocations)
    }
    
    private func getAllPersistedSavedLocations() -> [PersistedSavedLocation] {
        let descriptor = FetchDescriptor<PersistedSavedLocation>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    private func getAllPersistedCustomLocations() -> [PersistedCustomLocation] {
        let descriptor = FetchDescriptor<PersistedCustomLocation>(
            sortBy: [SortDescriptor(\.dateCreated)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

/// Data structure for transferring session data
public struct RoutineSessionData {
    public let id: UUID
    public let startedAt: Date
    public let completedAt: Date?
    public let currentHabitIndex: Int
    public let completions: [HabitCompletion]
    public let modifications: [SessionModification]
}