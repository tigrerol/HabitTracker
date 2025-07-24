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
        }
    }
    
    /// SwiftUI Color from hex string
    public var swiftUIColor: Color {
        Color(hex: color) ?? .blue
    }
}

// Helper extension for Color from hex
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        // Check if the scanner was successful
        guard Scanner(string: hex).scanHexInt64(&int) else {
            return nil
        }
        
        // Ensure hex string is not empty
        guard !hex.isEmpty else {
            return nil
        }
        
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
        
        // Ensure values are valid before converting to Double
        let red = Double(r) / 255.0
        let green = Double(g) / 255.0
        let blue = Double(b) / 255.0
        let opacity = Double(a) / 255.0
        
        // Validate that values are not NaN
        guard !red.isNaN && !green.isNaN && !blue.isNaN && !opacity.isNaN else {
            return nil
        }
        
        self.init(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: opacity
        )
    }
}