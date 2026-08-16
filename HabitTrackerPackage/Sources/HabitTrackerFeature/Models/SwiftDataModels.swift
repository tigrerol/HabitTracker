import Foundation
import SwiftData
import CoreLocation

// MARK: - SwiftData Models
//
// CloudKit shapes these declarations: it rejects `@Attribute(.unique)`, and
// every non-optional attribute needs a default value so a record synced from
// another device can always be materialized. Identity is therefore enforced in
// code — SwiftDataPersistenceService does diff-based upserts keyed by `id`,
// which is what `.unique` was doing for us before.

/// Persistent habit model for SwiftData
@Model
public final class PersistedHabit {
    public var id: UUID = UUID()
    public var name: String = ""
    public var typeData: Data = Data() // Encoded HabitType
    public var isOptional: Bool = false
    public var notes: String?
    public var colorHex: String = "#000000"
    public var order: Int = 0
    public var isActive: Bool = true
    public var createdAt: Date = Date()
    public var modifiedAt: Date = Date()

    // Relationships
    public var template: PersistedRoutineTemplate?

    public init(from habit: Habit) {
        self.id = habit.id
        self.name = habit.name
        self.typeData = (try? JSONEncoder().encode(habit.type)) ?? Data()
        self.isOptional = habit.isOptional
        self.notes = habit.notes
        self.colorHex = habit.color
        self.order = habit.order
        self.isActive = habit.isActive
        self.createdAt = habit.createdAt
        self.modifiedAt = Date()
    }
    
    /// Convert back to domain model
    @MainActor
    public func toDomainModel() -> Habit {
        let habitType: HabitType
        if let decodedType = try? JSONDecoder().decode(HabitType.self, from: typeData) {
            habitType = decodedType
        } else {
            habitType = .task(subtasks: []) // Fallback
            LoggingService.shared.error(
                "Failed to decode HabitType — falling back to empty task",
                category: .app,
                metadata: ["habitId": id.uuidString, "habitName": name]
            )
        }

        return Habit(
            id: id,
            name: name,
            type: habitType,
            isOptional: isOptional,
            notes: notes,
            color: colorHex,
            order: order,
            isActive: isActive,
            createdAt: createdAt
        )
    }
    
    /// Update from domain model
    public func update(from habit: Habit) {
        self.name = habit.name
        self.typeData = (try? JSONEncoder().encode(habit.type)) ?? Data()
        self.isOptional = habit.isOptional
        self.notes = habit.notes
        self.colorHex = habit.color
        self.order = habit.order
        self.isActive = habit.isActive
        self.modifiedAt = Date()
    }
}

/// Persistent routine template model for SwiftData
@Model
public final class PersistedRoutineTemplate {
    public var id: UUID = UUID()
    public var name: String = ""
    public var templateDescription: String?
    public var colorHex: String = "#000000"
    public var isDefault: Bool = false
    public var createdAt: Date = Date()
    public var lastUsedAt: Date?
    public var modifiedAt: Date = Date()
    public var contextRuleData: Data? // Encoded RoutineContextRule
    public var weeklyTarget: Int?
    public var includesData: Data? // Encoded [RoutineInclude]

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \PersistedHabit.template)
    public var habits: [PersistedHabit] = []

    /// Nullify, not cascade: deleting a routine has always left its session
    /// history behind. The inverse is spelled out because CloudKit requires
    /// every relationship to have one.
    @Relationship(deleteRule: .nullify, inverse: \PersistedRoutineSession.template)
    public var sessions: [PersistedRoutineSession] = []
    
    public init(from template: RoutineTemplate) {
        self.id = template.id
        self.name = template.name
        self.templateDescription = template.description
        self.colorHex = template.color
        self.isDefault = template.isDefault
        self.createdAt = template.createdAt
        self.lastUsedAt = template.lastUsedAt
        self.modifiedAt = Date()
        self.contextRuleData = template.contextRule.flatMap { try? JSONEncoder().encode($0) }
        self.weeklyTarget = template.weeklyTarget
        self.includesData = template.includes.isEmpty ? nil : try? JSONEncoder().encode(template.includes)
        // NOTE: habits are NOT converted here — relationships must only be
        // established after the model is inserted into a ModelContext
        // (SwiftDataPersistenceService.saveRoutineTemplates does this).
    }

    /// Convert back to domain model
    @MainActor
    public func toDomainModel() -> RoutineTemplate {
        let contextRule: RoutineContextRule?
        if let ruleData = contextRuleData {
            contextRule = try? JSONDecoder().decode(RoutineContextRule.self, from: ruleData)
            if contextRule == nil {
                LoggingService.shared.error(
                    "Failed to decode RoutineContextRule — template loses its context rule",
                    category: .app,
                    metadata: ["templateId": id.uuidString, "templateName": name]
                )
            }
        } else {
            contextRule = nil
        }

        let domainHabits = habits.map { $0.toDomainModel() }.sorted { $0.order < $1.order }

        let includes: [RoutineInclude]
        if let includesData {
            includes = (try? JSONDecoder().decode([RoutineInclude].self, from: includesData)) ?? []
            if includes.isEmpty {
                LoggingService.shared.error(
                    "Failed to decode routine includes — wrapper routine loses its blocks",
                    category: .app,
                    metadata: ["templateId": id.uuidString, "templateName": name]
                )
            }
        } else {
            includes = []
        }

        return RoutineTemplate(
            id: id,
            name: name,
            description: templateDescription,
            habits: domainHabits,
            color: colorHex,
            isDefault: isDefault,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            contextRule: contextRule,
            weeklyTarget: weeklyTarget,
            includes: includes
        )
    }
    
    /// Update from domain model
    public func update(from template: RoutineTemplate) {
        self.name = template.name
        self.templateDescription = template.description
        self.colorHex = template.color
        self.isDefault = template.isDefault
        self.lastUsedAt = template.lastUsedAt
        self.modifiedAt = Date()
self.contextRuleData = template.contextRule.flatMap { try? JSONEncoder().encode($0) }
        self.includesData = template.includes.isEmpty ? nil : try? JSONEncoder().encode(template.includes)
        self.weeklyTarget = template.weeklyTarget

        // Update habits
        updateHabits(from: template.habits)
    }
    
    private func updateHabits(from newHabits: [Habit]) {
        // Remove habits that no longer exist
        habits.removeAll { persistedHabit in
            !newHabits.contains { $0.id == persistedHabit.id }
        }
        
        // Update or add habits
        for habit in newHabits {
            if let existingHabit = habits.first(where: { $0.id == habit.id }) {
                existingHabit.update(from: habit)
            } else {
                let newPersistedHabit = PersistedHabit(from: habit)
                newPersistedHabit.template = self
                habits.append(newPersistedHabit)
            }
        }
    }
}

/// Persistent routine session model for SwiftData
@Model
public final class PersistedRoutineSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var completedAt: Date?
    public var currentHabitIndex: Int = 0
    public var modificationsData: Data = Data() // Encoded [SessionModification]
    
    // Relationships
    public var template: PersistedRoutineTemplate?

    @Relationship(deleteRule: .cascade, inverse: \PersistedHabitCompletion.session)
    public var completions: [PersistedHabitCompletion] = []
    
    /// NOTE: the `template` relationship is deliberately not an init parameter —
    /// set it only after the session is inserted into a ModelContext.
    public init(
        id: UUID,
        startedAt: Date,
        completedAt: Date?,
        currentHabitIndex: Int
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.currentHabitIndex = currentHabitIndex
        self.modificationsData = Data()
    }
    
    /// Update from domain model
    @MainActor
    public func update(from session: RoutineSession) {
        self.completedAt = session.completedAt
        self.currentHabitIndex = session.currentHabitIndex
        self.modificationsData = (try? JSONEncoder().encode(session.modifications)) ?? Data()
        
        // Update completions
        updateCompletions(from: session.completions)
    }
    
    private func updateCompletions(from newCompletions: [HabitCompletion]) {
        // Remove completions that no longer exist
        completions.removeAll { persistedCompletion in
            !newCompletions.contains { $0.id == persistedCompletion.id }
        }
        
        // Add new completions
        for completion in newCompletions {
            if !completions.contains(where: { $0.id == completion.id }) {
                let persistedCompletion = PersistedHabitCompletion(from: completion)
                persistedCompletion.session = self
                completions.append(persistedCompletion)
            }
        }
    }
}

/// Persistent habit completion model for SwiftData
@Model
public final class PersistedHabitCompletion {
    public var id: UUID = UUID()
    public var habitId: UUID = UUID()
    public var completedAt: Date = Date()
    public var duration: TimeInterval?
    public var isSkipped: Bool = false
    public var notes: String?
    
    // Relationships
    public var session: PersistedRoutineSession?
    
    public init(from completion: HabitCompletion) {
        self.id = completion.id
        self.habitId = completion.habitId
        self.completedAt = completion.completedAt
        self.duration = completion.duration
        self.isSkipped = completion.isSkipped
        self.notes = completion.notes
    }
    
    /// Convert back to domain model
    public func toDomainModel() -> HabitCompletion {
        HabitCompletion(
            id: id,
            habitId: habitId,
            completedAt: completedAt,
            duration: duration,
            isSkipped: isSkipped,
            notes: notes
        )
    }
}

/// Persistent mood rating model for SwiftData
@Model
public final class PersistedMoodRating {
    public var id: UUID = UUID()
    public var sessionId: UUID = UUID()
    public var ratingValue: String = "" // Mood.rawValue
    public var notes: String?
    public var createdAt: Date = Date()
    
    public init(from moodRating: MoodRating) {
        self.id = moodRating.id
        self.sessionId = moodRating.sessionId
        self.ratingValue = moodRating.rating.rawValue
        self.notes = moodRating.notes
        self.createdAt = moodRating.recordedAt
    }
    
    /// Convert back to domain model
    public func toDomainModel() -> MoodRating? {
        guard let mood = Mood(rawValue: ratingValue) else { return nil }
        return MoodRating(
            id: id,
            sessionId: sessionId,
            rating: mood,
            recordedAt: createdAt,
            notes: notes
        )
    }
}

/// Persistent location data for SwiftData
@Model
public final class PersistedSavedLocation {
    /// Identity, deduplicated by SwiftDataPersistenceService.saveSavedLocations
    /// rather than a unique constraint — so if two devices each create a row for
    /// the same type, the next save collapses them.
    public var locationTypeRawValue: String = ""
    public var coordinateData: Data = Data() // Encoded LocationCoordinate
    public var name: String?
    public var radius: Double = 0
    public var dateCreated: Date = Date()
    
    public init(from savedLocation: SavedLocation, locationType: LocationType) {
        self.locationTypeRawValue = locationType.rawValue
        self.coordinateData = (try? JSONEncoder().encode(savedLocation.coordinate)) ?? Data()
        self.name = savedLocation.name
        self.radius = savedLocation.radius
        self.dateCreated = savedLocation.dateCreated
    }
    
    /// Convert back to domain model with location type
    public func toDomainModel() -> (SavedLocation, LocationType)? {
        guard let locationType = LocationType(rawValue: locationTypeRawValue),
              let coordinate = try? JSONDecoder().decode(LocationCoordinate.self, from: coordinateData) else {
            return nil
        }
        
        let savedLocation = SavedLocation(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            name: name,
            radius: radius
        )
        
        return (savedLocation, locationType)
    }
}

/// Persistent custom location data for SwiftData
@Model
public final class PersistedCustomLocation {
    public var id: UUID = UUID()
    public var name: String = ""
    public var icon: String = ""
    public var coordinateData: Data? // Encoded LocationCoordinate?
    public var radius: Double = 0
    public var dateCreated: Date = Date()
    public var modifiedAt: Date = Date()
    
    public init(from customLocation: CustomLocation) {
        self.id = customLocation.id
        self.name = customLocation.name
        self.icon = customLocation.icon
        self.coordinateData = customLocation.coordinate.flatMap { try? JSONEncoder().encode($0) }
        self.radius = customLocation.radius
        self.dateCreated = customLocation.dateCreated
        self.modifiedAt = customLocation.modifiedAt
    }
    
    /// Convert back to domain model
    public func toDomainModel() -> CustomLocation {
        let coordinate: LocationCoordinate?
        if let data = coordinateData {
            coordinate = try? JSONDecoder().decode(LocationCoordinate.self, from: data)
        } else {
            coordinate = nil
        }
        
        return CustomLocation(
            id: id,
            name: name,
            icon: icon,
            coordinate: coordinate,
            radius: radius,
            dateCreated: dateCreated,
            modifiedAt: modifiedAt
        )
    }
    
    /// Update from domain model
    public func update(from customLocation: CustomLocation) {
        self.name = customLocation.name
        self.icon = customLocation.icon
        self.coordinateData = customLocation.coordinate.flatMap { try? JSONEncoder().encode($0) }
        self.radius = customLocation.radius
        self.modifiedAt = Date()
    }
}