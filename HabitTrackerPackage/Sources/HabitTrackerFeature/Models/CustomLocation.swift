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
    public var modifiedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        icon: String = "location.fill",
        coordinate: LocationCoordinate? = nil,
        radius: CLLocationDistance = 150,
        dateCreated: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.coordinate = coordinate
        self.radius = radius
        self.dateCreated = dateCreated
        self.modifiedAt = modifiedAt
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
    
    /// Icon for the location type
    public var icon: String {
        switch self {
        case .builtin(let locationType):
            return locationType.icon
        case .custom:
            return "location.fill"
        }
    }
    
    /// Display name for the location type
    public var displayName: String {
        switch self {
        case .builtin(let locationType):
            return locationType.displayName
        case .custom(let customLocationId):
            // Load custom location from storage to get name
            if let data = UserDefaults.standard.data(forKey: "CustomLocations"),
               let locations = try? JSONDecoder().decode([UUID: CustomLocation].self, from: data),
               let customLocation = locations[customLocationId] {
                return customLocation.name
            }
            return "Custom Location"
        }
    }
}