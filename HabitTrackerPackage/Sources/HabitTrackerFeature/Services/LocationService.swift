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
    
    public init(location: CLLocation, name: String? = nil, radius: CLLocationDistance = 150) {
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

/// Service responsible for location management and geofencing
public actor LocationService {
    @MainActor private var locationManager: CLLocationManager?
    @MainActor private var locationDelegate: LocationManagerDelegate?
    private(set) var currentLocation: CLLocation?
    
    /// Current location type based on detected location
    private(set) var currentLocationType: LocationType = .unknown
    
    /// Current detected location (including custom locations)
    private(set) var currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    /// Known built-in locations (to be configured by user)
    private var knownLocations: [LocationType: SavedLocation] = [:]
    
    /// Custom user-defined locations
    private var customLocations: [UUID: CustomLocation] = [:]
    
    /// Detection radius in meters
    private let detectionRadius: CLLocationDistance = 150 // 150 meters
    
    /// Callback for location updates
    private var locationUpdateCallback: (@MainActor (LocationType, ExtendedLocationType) async -> Void)?
    
    public init() {
        // Note: Data loading will happen asynchronously when first accessed
    }
    
    /// Set up location manager (must be called from main actor)
    @MainActor
    public func setupLocationManager() {
        Task {
            await self.internalSetupLocationManager()
        }
    }
    
    private func internalSetupLocationManager() async {
        let delegate = LocationManagerDelegate(service: self)
        
        await MainActor.run {
            locationManager = CLLocationManager()
            locationDelegate = delegate
            locationManager?.delegate = locationDelegate
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.distanceFilter = 100 // Update every 100 meters
        }
    }
    
    /// Set callback for location updates
    public func setLocationUpdateCallback(_ callback: @escaping @MainActor (LocationType, ExtendedLocationType) async -> Void) {
        self.locationUpdateCallback = callback
    }
    
    public func startUpdatingLocation() async {
        await MainActor.run {
            guard let locationManager = self.locationManager else { return }
            let status = locationManager.authorizationStatus
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        }
    }
    
    func stopUpdatingLocation() async {
        await MainActor.run {
            guard let locationManager = self.locationManager else { return }
            locationManager.stopUpdatingLocation()
        }
    }
    
    /// Get current location types
    public func getCurrentLocationTypes() -> (LocationType, ExtendedLocationType) {
        return (currentLocationType, currentExtendedLocationType)
    }
    
    /// Get current location
    public func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    /// Update location internally (called by delegate)
    func updateLocation(_ location: CLLocation) async {
        self.currentLocation = location
        self.currentLocationType = determineLocationType(from: location)
        self.currentExtendedLocationType = determineExtendedLocationType(from: location)
        
        // Notify observers
        if let callback = locationUpdateCallback {
            await callback(currentLocationType, currentExtendedLocationType)
        }
    }
    
    /// Determine location type from current location using geofencing
    private func determineLocationType(from location: CLLocation) -> LocationType {
        // Ensure data is loaded
        if knownLocations.isEmpty {
            loadKnownLocations()
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
    
    /// Determine extended location type (including custom locations)
    private func determineExtendedLocationType(from location: CLLocation) -> ExtendedLocationType {
        // Ensure data is loaded
        if customLocations.isEmpty {
            loadCustomLocations()
        }
        
        // First check built-in locations
        let builtinType = determineLocationType(from: location)
        if builtinType != .unknown {
            return .builtin(builtinType)
        }
        
        // Then check custom locations
        for (id, customLocation) in customLocations {
            guard let customCLLocation = customLocation.clLocation else { continue }
            
            let distance = location.distance(from: customCLLocation)
            let radius = customLocation.radius > 0 ? customLocation.radius : detectionRadius
            
            if distance <= radius {
                return .custom(id)
            }
        }
        
        return .builtin(.unknown)
    }
    
    /// Save a location as a known type
    public func saveLocation(_ location: CLLocation, as type: LocationType, name: String? = nil, radius: CLLocationDistance? = nil) {
        let savedLocation = SavedLocation(
            location: location,
            name: name ?? type.displayName,
            radius: radius ?? detectionRadius
        )
        knownLocations[type] = savedLocation
        
        // Persist to UserDefaults
        persistKnownLocations()
        
        // Update current location type immediately
        if let currentLocation = currentLocation {
            Task {
                await updateLocation(currentLocation)
            }
        }
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) {
        knownLocations.removeValue(forKey: type)
        persistKnownLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            Task {
                await updateLocation(currentLocation)
            }
        }
    }
    
    /// Get all saved locations
    public func getSavedLocations() -> [LocationType: SavedLocation] {
        knownLocations
    }
    
    /// Get all custom locations
    public func getAllCustomLocations() -> [CustomLocation] {
        Array(customLocations.values).sorted { $0.dateCreated < $1.dateCreated }
    }
    
    /// Check if a location type has been saved
    public func hasLocation(for type: LocationType) -> Bool {
        knownLocations[type] != nil
    }
    
    // MARK: - Custom Location Management
    
    /// Create a new custom location
    public func createCustomLocation(name: String, icon: String = "location.fill") -> CustomLocation {
        let customLocation = CustomLocation(name: name, icon: icon)
        customLocations[customLocation.id] = customLocation
        persistCustomLocations()
        return customLocation
    }
    
    /// Update an existing custom location
    public func updateCustomLocation(_ customLocation: CustomLocation) {
        customLocations[customLocation.id] = customLocation
        persistCustomLocations()
        
        // Update current location type if needed
        if let currentLocation = currentLocation {
            Task {
                await updateLocation(currentLocation)
            }
        }
    }
    
    /// Set coordinates for a custom location
    public func setCustomLocationCoordinates(
        for id: UUID,
        location: CLLocation,
        radius: CLLocationDistance? = nil
    ) {
        guard var customLocation = customLocations[id] else { return }
        
        customLocation.coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        if let radius = radius {
            customLocation.radius = radius
        }
        
        customLocations[id] = customLocation
        persistCustomLocations()
        
        // Update current location type immediately
        if let currentLocation = currentLocation {
            Task {
                await updateLocation(currentLocation)
            }
        }
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) {
        customLocations.removeValue(forKey: id)
        persistCustomLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            Task {
                await updateLocation(currentLocation)
            }
        }
    }
    
    /// Get a specific custom location
    public func getCustomLocation(id: UUID) -> CustomLocation? {
        customLocations[id]
    }
    
    // MARK: - Persistence
    
    /// Set persistence service (optional, defaults to UserDefaults)
    private var persistenceService: SwiftDataPersistenceService?
    
    public func setPersistenceService(_ service: SwiftDataPersistenceService) {
        self.persistenceService = service
        Task {
            await loadFromPersistence()
        }
    }
    
    private func persistLocations() {
        if let persistenceService = persistenceService {
            Task {
                try? await persistenceService.saveLocationData(
                    savedLocations: knownLocations,
                    customLocations: customLocations
                )
            }
        } else {
            // Fallback to UserDefaults
            persistKnownLocationsToUserDefaults()
            persistCustomLocationsToUserDefaults()
        }
    }
    
    private func loadFromPersistence() async {
        if let persistenceService = persistenceService {
            let locationData = await persistenceService.loadLocationData()
            self.knownLocations = locationData.savedLocations
            self.customLocations = locationData.customLocations
        } else {
            // Fallback to UserDefaults
            loadKnownLocationsFromUserDefaults()
            loadCustomLocationsFromUserDefaults()
        }
    }
    
    // MARK: - UserDefaults Fallback Methods
    
    private func persistKnownLocationsToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(knownLocations)
            UserDefaults.standard.set(data, forKey: "SavedLocations")
        } catch {
            print("Failed to save locations: \(error)")
        }
    }
    
    private func loadKnownLocationsFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "SavedLocations") else { return }
        
        do {
            knownLocations = try JSONDecoder().decode([LocationType: SavedLocation].self, from: data)
        } catch {
            print("Failed to load locations: \(error)")
            knownLocations = [:]
        }
    }
    
    private func persistCustomLocationsToUserDefaults() {
        do {
            let data = try JSONEncoder().encode(customLocations)
            UserDefaults.standard.set(data, forKey: "CustomLocations")
        } catch {
            print("Failed to save custom locations: \(error)")
        }
    }
    
    private func loadCustomLocationsFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "CustomLocations") else { return }
        
        do {
            customLocations = try JSONDecoder().decode([UUID: CustomLocation].self, from: data)
        } catch {
            print("Failed to load custom locations: \(error)")
            customLocations = [:]
        }
    }
    
    // Update method calls to use the new persistence method
    private func persistKnownLocations() {
        persistLocations()
    }
    
    private func loadKnownLocations() {
        Task {
            await loadFromPersistence()
        }
    }
    
    private func persistCustomLocations() {
        persistLocations()
    }
    
    private func loadCustomLocations() {
        Task {
            await loadFromPersistence()
        }
    }
}

/// Internal delegate class for CLLocationManager
private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let service: LocationService
    
    init(service: LocationService) {
        self.service = service
        super.init()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task {
            await service.updateLocation(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task {
                await service.startUpdatingLocation()
            }
        }
    }
}