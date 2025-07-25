import Foundation

/// Records a user's response to a conditional habit question
public struct ConditionalResponse: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    
    /// The ID of the conditional habit
    public let habitId: UUID
    
    /// The question that was asked
    public let question: String
    
    /// The ID of the selected option
    public let selectedOptionId: UUID
    
    /// The text of the selected option
    public let selectedOptionText: String
    
    /// When the response was recorded
    public let timestamp: Date
    
    /// The routine ID this response belongs to
    public let routineId: UUID
    
    /// Whether the question was skipped
    public let wasSkipped: Bool
    
    public init(
        id: UUID = UUID(),
        habitId: UUID,
        question: String,
        selectedOptionId: UUID,
        selectedOptionText: String,
        timestamp: Date = Date(),
        routineId: UUID,
        wasSkipped: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.question = question
        self.selectedOptionId = selectedOptionId
        self.selectedOptionText = selectedOptionText
        self.timestamp = timestamp
        self.routineId = routineId
        self.wasSkipped = wasSkipped
    }
    
    /// Create a skip response
    public static func skip(
        habitId: UUID,
        question: String,
        routineId: UUID
    ) -> ConditionalResponse {
        ConditionalResponse(
            habitId: habitId,
            question: question,
            selectedOptionId: UUID(),
            selectedOptionText: "Skipped",
            routineId: routineId,
            wasSkipped: true
        )
    }
}