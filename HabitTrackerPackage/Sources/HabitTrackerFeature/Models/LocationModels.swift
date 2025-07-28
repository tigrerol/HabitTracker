import Foundation
import CoreLocation

/// Represents a saved location with metadata
public struct SavedLocation: Codable, Sendable {
    public let coordinate: LocationCoordinate
    public let name: String?
    public let radius: CLLocationDistance
    public let dateCreated: Date
    
    public var clLocation: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    public init(location: CLLocation, name: String? = nil, radius: CLLocationDistance = AppConstants.Location.defaultRadius) {
        self.coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        self.name = name
        self.radius = radius
        self.dateCreated = Date()
    }
}

/// Codable coordinate wrapper
public struct LocationCoordinate: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}