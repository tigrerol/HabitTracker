import Foundation
import SwiftUI

/// Flexible day category that users can customize
public struct DayCategory: Categorizable {
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
    public static let weekday = DayCategory(
        id: "weekday",
        name: "Weekday",
        icon: "briefcase",
        color: .blue,
        isBuiltIn: true
    )
    
    public static let weekend = DayCategory(
        id: "weekend", 
        name: "Weekend",
        icon: "house",
        color: .green,
        isBuiltIn: true
    )
    
    /// Default categories
    public static let defaults: [DayCategory] = [weekday, weekend]
}