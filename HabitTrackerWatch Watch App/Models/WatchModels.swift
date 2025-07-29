import Foundation
import SwiftUI
import SwiftData

// MARK: - Domain Model Type Definitions for Watch
// These are simple copies of the domain models from HabitTrackerFeature for the watch app

/// Represents different types of habits in the morning routine
public enum HabitType: Codable, Hashable, Sendable {
    case checkbox
    case checkboxWithSubtasks(subtasks: [Subtask])
    case timer(defaultDuration: TimeInterval)
    case restTimer(targetDuration: TimeInterval?)
    case appLaunch(bundleId: String, appName: String)
    case website(url: URL, title: String)
    case counter(items: [String])
    case measurement(unit: String, targetValue: Double?)
    case guidedSequence(steps: [SequenceStep])
    case conditional(ConditionalHabitInfo)
}

public struct Subtask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var isOptional: Bool
    
    public init(id: UUID = UUID(), name: String, isOptional: Bool = false) {
        self.id = id
        self.name = name
        self.isOptional = isOptional
    }
}

public struct SequenceStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var duration: TimeInterval
    public var instructions: String?
    
    public init(id: UUID = UUID(), name: String, duration: TimeInterval, instructions: String? = nil) {
        self.id = id
        self.name = name
        self.duration = max(1, duration)
        self.instructions = instructions
    }
}

public struct ConditionalHabitInfo: Codable, Hashable, Sendable {
    public let id: UUID
    public var question: String
    public var options: [ConditionalOption]
    
    public init(id: UUID = UUID(), question: String, options: [ConditionalOption] = []) {
        self.id = id
        self.question = question
        self.options = options
    }
}

public struct ConditionalOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var text: String
    public var followUpHabits: [Habit]
    
    public init(id: UUID = UUID(), text: String, followUpHabits: [Habit] = []) {
        self.id = id
        self.text = text
        self.followUpHabits = followUpHabits
    }
}

/// Represents a single habit in the morning routine
public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var type: HabitType
    public var isOptional: Bool
    public var notes: String?
    public var color: String
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
    public var estimatedDuration: TimeInterval {
        switch type {
        case .checkbox: return 60
        case .checkboxWithSubtasks(let subtasks): return TimeInterval(subtasks.count * 45)
        case .timer(let duration): return duration
        case .restTimer(let target): return target ?? 180
        case .appLaunch: return 300
        case .website: return 180
        case .counter(let items): return TimeInterval(items.count * 30)
        case .measurement: return 60
        case .guidedSequence(let steps): return steps.reduce(0) { $0 + $1.duration }
        case .conditional: return 30
        }
    }
    
    public var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
    
    public var iconName: String {
        switch type {
        case .checkbox: return "checkmark.square"
        case .checkboxWithSubtasks: return "checklist"
        case .timer: return "timer"
        case .restTimer: return "pause.circle"
        case .appLaunch: return "app.badge"
        case .website: return "safari"
        case .counter: return "list.bullet"
        case .measurement: return "chart.line.uptrend.xyaxis"
        case .guidedSequence: return "list.number"
        case .conditional: return "questionmark.circle"
        }
    }
}

/// Represents a morning routine template
public struct RoutineTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var habits: [Habit]
    public var color: String
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
    public var estimatedDuration: TimeInterval {
        habits.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    public var activeHabitsCount: Int {
        habits.filter { $0.isActive }.count
    }
    
    public var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        return "\(minutes) min"
    }
    
    public var swiftUIColor: Color {
        Color(hex: color) ?? .green
    }
}

/// Represents an active routine session
public struct RoutineSession: Identifiable, Codable, Sendable {
    public var id: UUID
    public var routineId: UUID
    public var routineName: String
    public var startedAt: Date
    public var completedAt: Date?
    public var currentHabitIndex: Int
    public var habitCompletions: [HabitCompletion]
    public var isCompleted: Bool
    
    public init(
        id: UUID = UUID(),
        routineId: UUID,
        routineName: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        currentHabitIndex: Int = 0,
        habitCompletions: [HabitCompletion] = [],
        isCompleted: Bool = false
    ) {
        self.id = id
        self.routineId = routineId
        self.routineName = routineName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.currentHabitIndex = currentHabitIndex
        self.habitCompletions = habitCompletions
        self.isCompleted = isCompleted
    }
}

/// Represents the completion of a single habit
public struct HabitCompletion: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let habitId: UUID
    public var habitName: String
    public var completedAt: Date
    public var timeTaken: TimeInterval?
    public var notes: String?
    public var wasSkipped: Bool
    
    public init(
        id: UUID = UUID(),
        habitId: UUID,
        habitName: String,
        completedAt: Date = Date(),
        timeTaken: TimeInterval? = nil,
        notes: String? = nil,
        wasSkipped: Bool = false
    ) {
        self.id = id
        self.habitId = habitId
        self.habitName = habitName
        self.completedAt = completedAt
        self.timeTaken = timeTaken
        self.notes = notes
        self.wasSkipped = wasSkipped
    }
}

// MARK: - Persistent Models for SwiftData

@Model
public final class PersistedRoutineTemplate {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var templateDescription: String?
    public var colorHex: String
    public var isDefault: Bool
    public var createdAt: Date
    public var lastUsedAt: Date?
    public var habitsData: Data // Encoded [Habit]
    
    public init(from template: RoutineTemplate) {
        self.id = template.id
        self.name = template.name
        self.templateDescription = template.description
        self.colorHex = template.color
        self.isDefault = template.isDefault
        self.createdAt = template.createdAt
        self.lastUsedAt = template.lastUsedAt
        self.habitsData = (try? JSONEncoder().encode(template.habits)) ?? Data()
    }
    
    public func toDomainModel() -> RoutineTemplate {
        let habits: [Habit]
        if let decodedHabits = try? JSONDecoder().decode([Habit].self, from: habitsData) {
            habits = decodedHabits
        } else {
            habits = []
        }
        
        return RoutineTemplate(
            id: id,
            name: name,
            description: templateDescription,
            habits: habits,
            color: colorHex,
            isDefault: isDefault,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt
        )
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}