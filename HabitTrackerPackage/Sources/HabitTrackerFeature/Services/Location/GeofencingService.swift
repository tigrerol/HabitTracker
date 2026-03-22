import Foundation
import CoreLocation

/// Service responsible for determining location types based on geofencing
public actor GeofencingService {
    private let storageService: LocationStorageService
    private let detectionRadius: CLLocationDistance = AppConstants.Location.defaultRadius
    
    /// Current location type
    private var _currentLocationType: LocationType = .unknown
    private var _currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    /// Thread-safe getters for current state
    private(set) var currentLocationType: LocationType {
        get { _currentLocationType }
        set { _currentLocationType = newValue }
    }
    
    private(set) var currentExtendedLocationType: ExtendedLocationType {
        get { _currentExtendedLocationType }
        set { _currentExtendedLocationType = newValue }
    }
    
    /// Initialize with storage service
    public init(storageService: LocationStorageService) {
        self.storageService = storageService
    }
    
    /// Get current location types
    public func getCurrentLocationTypes() -> (LocationType, ExtendedLocationType) {
        return (currentLocationType, currentExtendedLocationType)
    }
    
    /// Process location update and determine types
    public func processLocationUpdate(_ location: CLLocation) async -> (LocationType, ExtendedLocationType) {
        let (newLocationType, newExtendedLocationType) = await determineLocationTypes(from: location)

        let changed = newLocationType != currentLocationType || newExtendedLocationType != currentExtendedLocationType

        // Update state
        self.currentLocationType = newLocationType
        self.currentExtendedLocationType = newExtendedLocationType

        // Only log when location type actually changes
        if changed && newLocationType != .unknown {
            Task {
                await LoggingService.shared.logLocationEvent(
                    .locationDetected,
                    metadata: [
                        "location_type": newLocationType.rawValue,
                        "detection_method": "geofence"
                    ]
                )
            }
        }

        return (newLocationType, newExtendedLocationType)
    }
    
    /// Determine both location types in a single pass (avoids duplicate geofence checks)
    private func determineLocationTypes(from location: CLLocation) async -> (LocationType, ExtendedLocationType) {
        let builtinType = await determineLocationType(from: location)
        if builtinType != .unknown {
            return (builtinType, .builtin(builtinType))
        }

        // Built-in didn't match — check custom locations
        let customLocations = await MainActor.run {
            storageService.getAllCustomLocations()
        }
        for customLocation in customLocations {
            guard let customCLLocation = customLocation.clLocation else { continue }
            let distance = location.distance(from: customCLLocation)
            let radius = customLocation.radius > 0 ? customLocation.radius : detectionRadius
            if distance <= radius {
                return (.unknown, .custom(customLocation.id))
            }
        }

        return (.unknown, .builtin(.unknown))
    }
    
    /// Determine location type from current location using geofencing
    private func determineLocationType(from location: CLLocation) async -> LocationType {
        let knownLocations = await MainActor.run {
            storageService.getSavedLocations()
        }
        // Check against all saved locations
        for (locationType, savedLocation) in knownLocations {
            let savedCLLocation = savedLocation.clLocation
            let distance = location.distance(from: savedCLLocation)

            // Use the specific radius for this location, or the default detection radius
            let radius = savedLocation.radius > 0 ? savedLocation.radius : detectionRadius

            if distance <= radius {
                return locationType
            }
        }
        return .unknown
    }
    
}