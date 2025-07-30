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
        case .task(let subtasks):
            return subtasks.isEmpty ? 60 : TimeInterval(subtasks.count * 45) // 1 minute or 45 seconds per subtask
        case .timer(let style, let duration, let target, let steps):
            // For multiple timers, sum all steps; otherwise use target or duration
            switch style {
            case .multiple:
                return !steps.isEmpty ? steps.reduce(0) { $0 + $1.duration } : duration
            case .down, .up:
                return target ?? duration
            }
        case .action(let type, _, _):
            switch type {
            case .app:
                return 300 // 5 minutes default for app launch
            case .website:
                return 180 // 3 minutes default for website
            case .shortcut:
                return 120 // 2 minutes default for shortcut
            }
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

