import Foundation
import SwiftUI

/// Represents a single habit in the morning routine
public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var type: HabitType
    public var isOptional: Bool
    public var notes: String?
    public var color: String // Color hex string
    public var order: Int
    public var isActive: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        type: HabitType,
        isOptional: Bool = false,
        notes: String? = nil,
        color: String = "#007AFF",
        order: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isOptional = isOptional
        self.notes = notes
        self.color = color
        self.order = order
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

extension Habit {
    /// Estimated duration for the habit (for progress calculation)
    public var estimatedDuration: TimeInterval {
        switch type {
        case .checkbox:
            return 60 // 1 minute
        case .checkboxWithSubtasks(let subtasks):
            return TimeInterval(subtasks.count * 45) // 45 seconds per subtask
        case .timer(let duration):
            return duration
        case .restTimer(let target):
            return target ?? 180 // Use target or default 3 minutes
        case .appLaunch:
            return 300 // 5 minutes default
        case .website:
            return 180 // 3 minutes default
        case .counter(let items):
            return TimeInterval(items.count * 30) // 30 seconds per item
        case .measurement:
            return 60 // 1 minute to measure and record
        case .guidedSequence(let steps):
            return steps.reduce(0) { $0 + $1.duration }
        case .conditional:
            return 30 // Quick question, 30 seconds estimated
        }
    }
    
    /// SwiftUI Color from hex string
    public var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

