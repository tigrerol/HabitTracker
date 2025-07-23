import Foundation

/// Represents a morning routine template (Office, Home Office, etc.)
public struct RoutineTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var habits: [Habit]
    public var color: String // Color hex string
    public var isDefault: Bool
    public let createdAt: Date
    public var lastUsedAt: Date?
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        habits: [Habit] = [],
        color: String = "#34C759",
        isDefault: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.habits = habits.sorted { $0.order < $1.order }
        self.color = color
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

extension RoutineTemplate {
    /// Total estimated duration for the template
    public var estimatedDuration: TimeInterval {
        habits.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    /// Number of active habits in the template
    public var activeHabitsCount: Int {
        habits.filter { $0.isActive }.count
    }
    
    /// Formatted duration string (e.g., "25 min")
    public var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        return "\(minutes) min"
    }
    
    /// Add a habit to the template
    public mutating func addHabit(_ habit: Habit) {
        var newHabit = habit
        newHabit.order = habits.count
        habits.append(newHabit)
        habits.sort { $0.order < $1.order }
    }
    
    /// Remove a habit from the template
    public mutating func removeHabit(withId id: UUID) {
        habits.removeAll { $0.id == id }
        // Reorder remaining habits
        for (index, habit) in habits.enumerated() {
            habits[index].order = index
        }
    }
    
    /// Reorder habits in the template
    public mutating func reorderHabits(_ newOrder: [Habit]) {
        for (index, habit) in newOrder.enumerated() {
            if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[habitIndex].order = index
            }
        }
        habits.sort { $0.order < $1.order }
    }
}