import Foundation
import CoreLocation

/// Legacy compatibility wrapper for SmartRoutineSelector
/// This maintains the existing API while using the new focused services internally
@MainActor
@Observable
public final class SmartRoutineSelector {
    /// Current detected context
    public var currentContext: RoutineContext {
        routineSelector.currentContext
    }
    
    /// Legacy compatibility: provide a locationManager-like interface
    public var locationManager: LocationManagerAdapter
    
    /// Reason for the last selection
    public var selectionReason: String {
        routineSelector.selectionReason
    }
    
    /// Internal routine selector service
    private let routineSelector: RoutineSelector
    
    public init() {
        self.routineSelector = RoutineSelector()
        self.locationManager = LocationManagerAdapter(locationService: routineSelector.getLocationService())
    }
    
    /// Update the current context
    public func updateContext() async {
        await routineSelector.updateContext()
    }
    
    /// Select the best routine template based on current context
    public func selectBestTemplate(from templates: [RoutineTemplate]) async -> (template: RoutineTemplate?, reason: String) {
        return await routineSelector.selectBestTemplate(from: templates)
    }
}

/// Adapter to maintain backward compatibility with existing LocationManager API
@MainActor
@Observable
public final class LocationManagerAdapter {
    private let locationService: LocationService
    
    /// Current location type based on detected location
    public private(set) var currentLocationType: LocationType = .unknown
    
    /// Current detected location (including custom locations)
    public private(set) var currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    public init(locationService: LocationService) {
        self.locationService = locationService
        
        // Set up location updates
        Task {
            await locationService.setLocationUpdateCallback { [weak self] locationType, extendedLocationType in
                guard let self = self else { return }
                self.currentLocationType = locationType
                self.currentExtendedLocationType = extendedLocationType
            }
            
            // Get initial state
            let (locationType, extendedLocationType) = await locationService.getCurrentLocationTypes()
            self.currentLocationType = locationType
            self.currentExtendedLocationType = extendedLocationType
        }
    }
    
    /// Start updating location
    public func startUpdatingLocation() async {
        await locationService.startUpdatingLocation()
    }
    
    /// Stop updating location
    func stopUpdatingLocation() {
        Task {
            await locationService.stopUpdatingLocation()
        }
    }
    
    /// Save a location as a known type
    public func saveLocation(_ location: CLLocation, as type: LocationType, name: String? = nil, radius: CLLocationDistance? = nil) {
        Task {
            await locationService.saveLocation(location, as: type, name: name, radius: radius)
        }
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) {
        Task {
            await locationService.removeLocation(for: type)
        }
    }
    
    /// Get all saved locations
    public var savedLocations: [LocationType: SavedLocation] {
        get async {
            await locationService.getSavedLocations()
        }
    }
    
    /// Get all custom locations
    public var allCustomLocations: [CustomLocation] {
        get async {
            await locationService.getAllCustomLocations()
        }
    }
    
    /// Check if a location type has been saved
    public func hasLocation(for type: LocationType) async -> Bool {
        await locationService.hasLocation(for: type)
    }
    
    // MARK: - Custom Location Management
    
    /// Create a new custom location
    public func createCustomLocation(name: String, icon: String = "location.fill") async -> CustomLocation {
        await locationService.createCustomLocation(name: name, icon: icon)
    }
    
    /// Update an existing custom location
    public func updateCustomLocation(_ customLocation: CustomLocation) {
        Task {
            await locationService.updateCustomLocation(customLocation)
        }
    }
    
    /// Set coordinates for a custom location
    public func setCustomLocationCoordinates(
        for id: UUID,
        location: CLLocation,
        radius: CLLocationDistance? = nil
    ) {
        Task {
            await locationService.setCustomLocationCoordinates(for: id, location: location, radius: radius)
        }
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) {
        Task {
            await locationService.deleteCustomLocation(id: id)
        }
    }
    
    /// Get a specific custom location
    public func getCustomLocation(id: UUID) async -> CustomLocation? {
        await locationService.getCustomLocation(id: id)
    }
    
    /// Get current location
    public func getCurrentLocation() async -> CLLocation? {
        // Access the current location from the location service
        return await locationService.getCurrentLocation()
    }
}