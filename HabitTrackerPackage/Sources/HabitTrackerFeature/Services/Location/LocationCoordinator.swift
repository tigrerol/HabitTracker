import Foundation
import CoreLocation

/// Coordinator that orchestrates location services
@MainActor
public final class LocationCoordinator: ObservableObject {
    public static let shared = LocationCoordinator()
    
    /// Individual focused services
    private let trackingService: LocationTrackingService
    private let storageService: LocationStorageService
    private let geofencingService: GeofencingService
    
    /// Published properties for UI binding
    @Published public private(set) var currentLocationType: LocationType = .unknown
    @Published public private(set) var currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    @Published public private(set) var currentLocation: CLLocation?
    
    /// Callback for location updates
    private var locationUpdateCallback: (@MainActor (LocationType, ExtendedLocationType) async -> Void)?
    
    /// Storage service accessor for UI
    public var storage: LocationStorageService {
        storageService
    }
    
    /// Initialize with optional custom persistence
    public init(persistenceService: (any PersistenceServiceProtocol)? = nil) {
        let persistence = persistenceService ?? UserDefaultsPersistenceService()
        
        self.trackingService = LocationTrackingService()
        self.storageService = LocationStorageService(persistenceService: persistence)
        self.geofencingService = GeofencingService(storageService: storageService)
        
        Task {
            await setupLocationTracking()
        }
    }
    
    /// Private convenience init for shared instance
    private convenience init() {
        self.init(persistenceService: nil)
    }
    
    /// Set up location tracking
    private func setupLocationTracking() async {
        // Set up location manager
        await MainActor.run {
            trackingService.setupLocationManager()
        }
        
        // Set callback to process location updates
        await trackingService.setLocationUpdateCallback { [weak self] location in
            await self?.handleLocationUpdate(location)
        }
    }
    
    /// Handle location update from tracking service
    private func handleLocationUpdate(_ location: CLLocation) async {
        // Update current location
        self.currentLocation = location
        
        // Process through geofencing
        let (locationType, extendedType) = await geofencingService.processLocationUpdate(location)
        
        // Update published properties
        self.currentLocationType = locationType
        self.currentExtendedLocationType = extendedType
        
        // Notify callback if set
        if let callback = locationUpdateCallback {
            await callback(locationType, extendedType)
        }
    }
    
    // MARK: - Public API
    
    /// Set callback for location updates
    public func setLocationUpdateCallback(_ callback: @escaping @MainActor (LocationType, ExtendedLocationType) async -> Void) {
        self.locationUpdateCallback = callback
    }
    
    /// Start updating location
    public func startUpdatingLocation() async {
        await trackingService.startUpdatingLocation()
    }
    
    /// Stop updating location
    public func stopUpdatingLocation() async {
        await trackingService.stopUpdatingLocation()
    }
    
    /// Get current location types
    public func getCurrentLocationTypes() async -> (LocationType, ExtendedLocationType) {
        await geofencingService.getCurrentLocationTypes()
    }
    
    /// Get current location
    public func getCurrentLocation() async -> CLLocation? {
        await trackingService.getCurrentLocation()
    }
    
    // MARK: - Storage Operations (delegate to storage service)
    
    /// Save a location as a known type
    public func saveLocation(_ location: CLLocation, as type: LocationType, name: String? = nil, radius: CLLocationDistance? = nil) async throws {
        try await storageService.saveLocation(location, as: type, name: name, radius: radius)
        
        // Update current location type immediately
        if let currentLocation = self.currentLocation {
            await handleLocationUpdate(currentLocation)
        }
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) async {
        await storageService.removeLocation(for: type)
        
        // Update current location type
        if let currentLocation = self.currentLocation {
            await handleLocationUpdate(currentLocation)
        }
    }
    
    /// Get all saved locations
    public func getSavedLocations() -> [LocationType: SavedLocation] {
        storageService.getSavedLocations()
    }
    
    /// Check if a location type has been saved
    public func hasLocation(for type: LocationType) -> Bool {
        storageService.hasLocation(for: type)
    }
    
    // MARK: - Custom Location Management (delegate to storage service)
    
    /// Create a new custom location
    public func createCustomLocation(name: String, icon: String = "location.fill") async -> CustomLocation {
        await storageService.createCustomLocation(name: name, icon: icon)
    }
    
    /// Update an existing custom location
    public func updateCustomLocation(_ customLocation: CustomLocation) async {
        await storageService.updateCustomLocation(customLocation)
        
        // Update current location type if needed
        if let currentLocation = self.currentLocation {
            await handleLocationUpdate(currentLocation)
        }
    }
    
    /// Set coordinates for a custom location
    public func setCustomLocationCoordinates(
        for id: UUID,
        location: CLLocation,
        radius: CLLocationDistance? = nil
    ) async {
        await storageService.setCustomLocationCoordinates(for: id, location: location, radius: radius)
        
        // Update current location type immediately
        if let currentLocation = self.currentLocation {
            await handleLocationUpdate(currentLocation)
        }
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) async {
        await storageService.deleteCustomLocation(id: id)
        
        // Update current location type
        if let currentLocation = self.currentLocation {
            await handleLocationUpdate(currentLocation)
        }
    }
    
    /// Get a specific custom location
    public func getCustomLocation(id: UUID) -> CustomLocation? {
        storageService.getCustomLocation(id: id)
    }
    
    /// Get all custom locations
    public func getAllCustomLocations() -> [CustomLocation] {
        storageService.getAllCustomLocations()
    }
}