import Foundation
import SwiftUI

/// A reusable collection of habits that can be saved and reused across routines
public struct HabitSnippet: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public let habits: [Habit]
    public let createdDate: Date
    
    public init(name: String, habits: [Habit]) {
        self.id = UUID()
        self.name = name
        self.habits = habits
        self.createdDate = Date()
    }
    
    /// Total estimated duration of all habits in this snippet
    public var estimatedDuration: TimeInterval {
        let total = habits.reduce(0) { accum, habit in
            let duration = habit.estimatedDuration
            guard duration.isFinite, !duration.isNaN else { return accum }
            return accum + duration
        }
        return max(0, total)
    }
    
    /// Icon representing this snippet (use first habit's icon or default)
    public var icon: String {
        return habits.first?.type.iconName ?? "square.stack.3d.up"
    }
    
    /// Number of habits in this snippet
    public var habitCount: Int {
        return habits.count
    }
    
    /// SwiftUI Color for the snippet (use first habit's color or default)
    public var swiftUIColor: Color {
        if let firstHabit = habits.first {
            return Color(hex: firstHabit.color) ?? .blue
        }
        return .blue
    }
}