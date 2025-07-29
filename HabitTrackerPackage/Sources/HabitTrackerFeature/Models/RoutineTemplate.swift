import Foundation
import SwiftUI

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
    public var contextRule: RoutineContextRule?
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        habits: [Habit] = [],
        color: String = "#34C759",
        isDefault: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        contextRule: RoutineContextRule? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.habits = habits.sorted { $0.order < $1.order }
        self.color = color
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.contextRule = contextRule
    }
}

extension RoutineTemplate {
    /// Total estimated duration for the template
    public var estimatedDuration: TimeInterval {
        let total = habits.reduce(0) { accum, habit in
            let duration = habit.estimatedDuration
            guard duration.isFinite, !duration.isNaN else { return accum }
            return accum + duration
        }
        return max(0, total)
    }
    
    /// Number of active habits in the template
    public var activeHabitsCount: Int {
        habits.filter { $0.isActive }.count
    }
    
    /// Formatted duration string (e.g., "25 min")
    public var formattedDuration: String {
        let duration = estimatedDuration
        guard duration.isFinite, !duration.isNaN else {
            return "0 min"
        }
        let minutes = Int(max(0, duration / 60))
        return "\(minutes) min"
    }
    
    /// SwiftUI Color from hex string
    public var swiftUIColor: Color {
        Color(hex: color) ?? .green
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
        for (index, _) in habits.enumerated() {
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