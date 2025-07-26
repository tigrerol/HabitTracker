import Foundation
import SwiftUI

/// Flexible location category that users can customize
public struct LocationCategory: Categorizable {
    public let id: String
    public var name: String
    public var icon: String
    public var colorData: Data
    public let isBuiltIn: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        color: Color = .blue,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorData = ColorUtils.encodeColor(color)
        self.isBuiltIn = isBuiltIn
    }
    
    /// Built-in categories for backwards compatibility
    public static let home = LocationCategory(
        id: "home",
        name: "Home",
        icon: "house.fill",
        color: .green,
        isBuiltIn: true
    )
    
    public static let office = LocationCategory(
        id: "office",
        name: "Office", 
        icon: "building.2.fill",
        color: .blue,
        isBuiltIn: true
    )
    
    public static let unknown = LocationCategory(
        id: "unknown",
        name: "Unknown",
        icon: "location.slash",
        color: .gray,
        isBuiltIn: true
    )
    
    /// Default categories
    public static let defaults: [LocationCategory] = [home, office, unknown]
}