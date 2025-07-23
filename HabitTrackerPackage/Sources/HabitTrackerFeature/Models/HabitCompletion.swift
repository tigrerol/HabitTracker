import Foundation

/// Represents the completion of a habit within a session
public struct HabitCompletion: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let habitId: UUID
    public let completedAt: Date
    public let duration: TimeInterval?
    public let isSkipped: Bool
    public let notes: String?
    
    public init(
        id: UUID = UUID(),
        habitId: UUID,
        completedAt: Date,
        duration: TimeInterval? = nil,
        isSkipped: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.habitId = habitId
        self.completedAt = completedAt
        self.duration = duration
        self.isSkipped = isSkipped
        self.notes = notes
    }
}

/// Represents modifications made to a session during execution
public struct SessionModification: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let type: ModificationType
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        type: ModificationType,
        timestamp: Date
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
    }
}

/// Types of modifications that can be made to a session
public enum ModificationType: Codable, Hashable, Sendable {
    case added(Habit)
    case removed(UUID)
    case modified(UUID, Habit)
    case reordered([Habit])
}