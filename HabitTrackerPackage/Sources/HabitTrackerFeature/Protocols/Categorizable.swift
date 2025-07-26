import Foundation
import SwiftUI

/// Protocol for categorizable items that have common properties and behavior
public protocol Categorizable: Codable, Identifiable, Hashable, Sendable {
    var id: String { get }
    var name: String { get set }
    var icon: String { get set }
    var colorData: Data { get set }
    var isBuiltIn: Bool { get }
    
    /// Display name for the category
    var displayName: String { get }
    
    /// Color property computed from colorData
    var color: Color { get }
    
    /// Update color and persist to colorData
    mutating func setColor(_ color: Color)
}

/// Default implementations for Categorizable protocol
public extension Categorizable {
    
    /// Default display name is the name
    var displayName: String {
        name
    }
    
    /// Default color decoding implementation
    var color: Color {
        ColorUtils.decodeColor(from: colorData)
    }
    
    /// Default color setting implementation
    mutating func setColor(_ color: Color) {
        colorData = ColorUtils.encodeColor(color)
    }
}