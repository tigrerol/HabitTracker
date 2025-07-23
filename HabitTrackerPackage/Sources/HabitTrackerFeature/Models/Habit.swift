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
        case .timer(let duration):
            return duration
        case .appLaunch:
            return 300 // 5 minutes default
        case .website:
            return 180 // 3 minutes default
        case .counter(let items):
            return TimeInterval(items.count * 30) // 30 seconds per item
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
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}