import Foundation

/// Represents a mood rating after completing a routine
public struct MoodRating: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sessionId: UUID
    public let rating: Mood
    public let recordedAt: Date
    public let notes: String?
    
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        rating: Mood,
        recordedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.rating = rating
        self.recordedAt = recordedAt
        self.notes = notes
    }
}

/// Simple emoji-based mood scale
public enum Mood: String, CaseIterable, Codable, Hashable, Sendable {
    case terrible = "😵"
    case bad = "😴"
    case neutral = "😐"
    case good = "😊"
    case excellent = "😄"
    
    public var description: String {
        switch self {
        case .terrible:
            return "Terrible"
        case .bad:
            return "Tired"
        case .neutral:
            return "Okay"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        }
    }
    
    public var value: Int {
        switch self {
        case .terrible: return 1
        case .bad: return 2
        case .neutral: return 3
        case .good: return 4
        case .excellent: return 5
        }
    }
}