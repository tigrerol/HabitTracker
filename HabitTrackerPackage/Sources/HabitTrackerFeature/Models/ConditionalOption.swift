import Foundation

/// Represents an answer option in a conditional habit
public struct ConditionalOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    
    /// The text displayed for this option
    public let text: String
    
    /// The habits to execute when this option is selected
    public let habits: [Habit]
    
    public init(id: UUID = UUID(), text: String, habits: [Habit] = []) {
        self.id = id
        self.text = text
        self.habits = habits
    }
}