import Foundation
import CoreLocation

/// Represents a custom user-defined location type
public struct CustomLocation: Codable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var icon: String
    public var coordinate: LocationCoordinate?
    public var radius: CLLocationDistance
    public let dateCreated: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "location.fill",
        coordinate: LocationCoordinate? = nil,
        radius: CLLocationDistance = 150,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.coordinate = coordinate
        self.radius = radius
        self.dateCreated = dateCreated
    }
    
    /// Get CLLocation if coordinate is set
    public var clLocation: CLLocation? {
        guard let coordinate = coordinate else { return nil }
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    /// Check if this location has geographic coordinates set
    public var hasCoordinates: Bool {
        coordinate != nil
    }
}

// MARK: - Hashable Conformance
extension CustomLocation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: CustomLocation, rhs: CustomLocation) -> Bool {
        lhs.id == rhs.id
    }
}

/// Extended location type that includes both built-in and custom locations
public enum ExtendedLocationType: Hashable, Sendable {
    case builtin(LocationType)
    case custom(UUID)
    
    public var isBuiltin: Bool {
        if case .builtin = self { return true }
        return false
    }
    
    public var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}