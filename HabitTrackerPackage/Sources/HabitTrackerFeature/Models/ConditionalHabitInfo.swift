import Foundation

/// Information about a conditional habit with branching logic
public struct ConditionalHabitInfo: Codable, Hashable, Sendable {
    /// The question to ask the user
    public let question: String
    
    /// Available answer options (max 4)
    public let options: [ConditionalOption]
    
    public init(question: String, options: [ConditionalOption]) {
        self.question = question
        // Ensure we have at most 4 options
        self.options = Array(options.prefix(4))
    }
}