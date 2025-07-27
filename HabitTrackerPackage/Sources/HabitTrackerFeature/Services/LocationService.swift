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

/// Service responsible for location management and geofencing
public actor LocationService {
    @MainActor private var locationManager: CLLocationManager?
    @MainActor private var locationDelegate: LocationManagerDelegate?
    
    // MARK: - Atomic State Management
    
    /// Current location with atomic updates
    private var _currentLocation: CLLocation?
    private var _currentLocationType: LocationType = .unknown
    private var _currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    /// Thread-safe getters for current state
    private(set) var currentLocation: CLLocation? {
        get { _currentLocation }
        set { _currentLocation = newValue }
    }
    
    private(set) var currentLocationType: LocationType {
        get { _currentLocationType }
        set { _currentLocationType = newValue }
    }
    
    private(set) var currentExtendedLocationType: ExtendedLocationType {
        get { _currentExtendedLocationType }
        set { _currentExtendedLocationType = newValue }
    }
    
    /// Atomic operations for location data collections
    private var _knownLocations: [LocationType: SavedLocation] = [:]
    private var _customLocations: [UUID: CustomLocation] = [:]
    
    /// Thread-safe accessors with defensive copying
    private var knownLocations: [LocationType: SavedLocation] {
        get { _knownLocations }
        set { _knownLocations = newValue }
    }
    
    private var customLocations: [UUID: CustomLocation] {
        get { _customLocations }
        set { _customLocations = newValue }
    }
    
    /// Detection radius in meters
    private let detectionRadius: CLLocationDistance = AppConstants.Location.defaultRadius
    
    /// Callback for location updates with atomic access
    private var _locationUpdateCallback: (@MainActor (LocationType, ExtendedLocationType) async -> Void)?
    
    /// Thread-safe callback accessor
    private var locationUpdateCallback: (@MainActor (LocationType, ExtendedLocationType) async -> Void)? {
        get { _locationUpdateCallback }
        set { _locationUpdateCallback = newValue }
    }
    
    /// Flag to prevent concurrent data loading
    private var isLoadingData = false
    
    /// Flag to prevent concurrent persistence operations
    private var isPersisting = false
    
    public init() {
        // Note: Data loading will happen asynchronously when first accessed
    }
    
    /// Set up location manager (must be called from main actor)
    @MainActor
    public func setupLocationManager() {
        Task { [weak self] in
            await self?.internalSetupLocationManager()
        }
    }
    
    private func internalSetupLocationManager() async {
        let delegate = LocationManagerDelegate(service: self)
        
        await MainActor.run {
            locationManager = CLLocationManager()
            locationDelegate = delegate
            locationManager?.delegate = locationDelegate
            locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            locationManager?.distanceFilter = AppConstants.Location.distanceFilter
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
                #if os(iOS)
                locationManager.requestWhenInUseAuthorization()
                #elseif os(macOS)
                locationManager.requestAlwaysAuthorization()
                #endif
            } else {
                #if os(iOS)
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    locationManager.startUpdatingLocation()
                }
                #elseif os(macOS)
                if status == .authorizedAlways {
                    locationManager.startUpdatingLocation()
                }
                #endif
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
    
    /// Update location internally (called by delegate) - Atomic operation
    func updateLocation(_ location: CLLocation) async {
        // Ensure data is loaded before processing location
        await ensureDataLoaded()
        
        // Atomic update of location state
        let (newLocationType, newExtendedLocationType) = await determineLocationTypes(from: location)
        
        // Update all state atomically
        self.currentLocation = location
        self.currentLocationType = newLocationType
        self.currentExtendedLocationType = newExtendedLocationType
        
        // Capture callback to avoid race conditions
        let callback = self.locationUpdateCallback
        
        // Notify observers outside of actor context to prevent deadlocks
        if let callback = callback {
            await callback(newLocationType, newExtendedLocationType)
        }
    }
    
    /// Atomic helper to determine both location types simultaneously
    private func determineLocationTypes(from location: CLLocation) async -> (LocationType, ExtendedLocationType) {
        let builtinType = await determineLocationType(from: location)
        let extendedType = await determineExtendedLocationType(from: location)
        return (builtinType, extendedType)
    }
    
    /// Ensure data is loaded atomically (prevents race conditions)
    private func ensureDataLoaded() async {
        // Prevent concurrent loading operations
        guard !isLoadingData else { return }
        
        if knownLocations.isEmpty || customLocations.isEmpty {
            isLoadingData = true
            await loadFromPersistence()
            isLoadingData = false
        }
    }
    
    /// Determine location type from current location using geofencing (async for atomic operations)
    private func determineLocationType(from location: CLLocation) async -> LocationType {
        // Use current snapshot of knownLocations to avoid race conditions
        let locationsSnapshot = knownLocations
        
        // Check against all saved locations
        for (locationType, savedLocation) in locationsSnapshot {
            let savedCLLocation = savedLocation.clLocation
            let distance = location.distance(from: savedCLLocation)
            
            // Use the specific radius for this location, or the default detection radius
            let radius = savedLocation.radius > 0 ? savedLocation.radius : detectionRadius
            
            if distance <= radius {
                Task {
                    await LoggingService.shared.logLocationEvent(
                        .locationDetected,
                        metadata: [
                            "location_type": locationType.rawValue,
                            "distance": String(format: "%.1f", distance),
                            "radius": String(radius),
                            "detection_method": "geofence"
                        ]
                    )
                }
                return locationType
            }
        }
        
        return .unknown
    }
    
    /// Determine extended location type (including custom locations) - Atomic operation
    private func determineExtendedLocationType(from location: CLLocation) async -> ExtendedLocationType {
        // First check built-in locations
        let builtinType = await determineLocationType(from: location)
        if builtinType != .unknown {
            return .builtin(builtinType)
        }
        
        // Use current snapshot of customLocations to avoid race conditions
        let customLocationsSnapshot = customLocations
        
        // Then check custom locations
        for (id, customLocation) in customLocationsSnapshot {
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
    public func saveLocation(_ location: CLLocation, as type: LocationType, name: String? = nil, radius: CLLocationDistance? = nil) async throws {
        // Validate location coordinates
        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            let error = LocationError.invalidCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            await ErrorHandlingService.shared.handleLocationError(error)
            throw error
        }
        
        // Validate radius if provided
        let finalRadius = radius ?? detectionRadius
        guard finalRadius >= 10 && finalRadius <= 1000 else {
            let error = LocationError.radiusValidationFailed(radius: finalRadius)
            await ErrorHandlingService.shared.handleLocationError(error)
            throw error
        }
        
        // Validate name if provided
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, trimmedName.count <= 30 else {
                let error = ValidationError.invalidLocationName(name: name)
                await ErrorHandlingService.shared.handle(error)
                throw error
            }
        }
        
        let savedLocation = SavedLocation(
            location: location,
            name: name ?? type.displayName,
            radius: finalRadius
        )
        knownLocations[type] = savedLocation
        
        // Log location save event
        await LoggingService.shared.logLocationEvent(
            .locationSaved,
            metadata: [
                "location_type": type.rawValue,
                "has_custom_name": String(name != nil),
                "radius": String(finalRadius),
                "latitude": String(format: "%.4f", location.coordinate.latitude),
                "longitude": String(format: "%.4f", location.coordinate.longitude)
            ]
        )
        
        // Persist to UserDefaults
        await persistLocations()
        
        // Update current location type immediately
        if let currentLocation = currentLocation {
            await updateLocation(currentLocation)
        }
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) async {
        knownLocations.removeValue(forKey: type)
        await persistLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            await updateLocation(currentLocation)
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
    public func createCustomLocation(name: String, icon: String = "location.fill") async -> CustomLocation {
        let customLocation = CustomLocation(name: name, icon: icon)
        customLocations[customLocation.id] = customLocation
        await persistLocations()
        return customLocation
    }
    
    /// Update an existing custom location
    public func updateCustomLocation(_ customLocation: CustomLocation) async {
        customLocations[customLocation.id] = customLocation
        await persistLocations()
        
        // Update current location type if needed
        if let currentLocation = currentLocation {
            await updateLocation(currentLocation)
        }
    }
    
    /// Set coordinates for a custom location
    public func setCustomLocationCoordinates(
        for id: UUID,
        location: CLLocation,
        radius: CLLocationDistance? = nil
    ) async {
        guard var customLocation = customLocations[id] else { return }
        
        customLocation.coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        if let radius = radius {
            customLocation.radius = radius
        }
        
        customLocations[id] = customLocation
        await persistLocations()
        
        // Update current location type immediately
        if let currentLocation = currentLocation {
            await updateLocation(currentLocation)
        }
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) async {
        customLocations.removeValue(forKey: id)
        await persistLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            await updateLocation(currentLocation)
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
        Task { [weak self] in
            await self?.loadFromPersistence()
        }
    }
    
    /// Atomic persistence operation to prevent race conditions
    private func persistLocations() async {
        // Prevent concurrent persistence operations
        guard !isPersisting else { return }
        isPersisting = true
        defer { isPersisting = false }
        
        // Create snapshots to avoid data races during persistence
        let knownSnapshot = knownLocations
        let customSnapshot = customLocations
        
        if let persistenceService = persistenceService {
            do {
                try await persistenceService.saveLocationData(
                    savedLocations: knownSnapshot,
                    customLocations: customSnapshot
                )
            } catch {
                await ErrorHandlingService.shared.handleDataError(
                    .encodingFailed(type: "LocationData", underlyingError: error),
                    key: "LocationPersistence",
                    operation: "save"
                )
            }
        } else {
            // Fallback to UserDefaults with snapshots
            await persistToUserDefaults(
                knownLocations: knownSnapshot,
                customLocations: customSnapshot
            )
        }
    }
    
    /// Atomic data loading operation
    private func loadFromPersistence() async {
        if let persistenceService = persistenceService {
            let locationData = await persistenceService.loadLocationData()
            // Atomic update of both collections
            self.knownLocations = locationData.savedLocations
            self.customLocations = locationData.customLocations
        } else {
            // Fallback to UserDefaults with atomic loading
            let (loadedKnown, loadedCustom) = await loadFromUserDefaults()
            // Atomic update of both collections
            self.knownLocations = loadedKnown
            self.customLocations = loadedCustom
        }
    }
    
    // MARK: - Atomic UserDefaults Operations
    
    /// Atomic UserDefaults persistence with snapshots
    private func persistToUserDefaults(
        knownLocations: [LocationType: SavedLocation],
        customLocations: [UUID: CustomLocation]
    ) async {
        do {
            let knownData = try JSONEncoder().encode(knownLocations)
            let customData = try JSONEncoder().encode(customLocations)
            
            // Perform UserDefaults operations on main thread to avoid race conditions
            await MainActor.run {
                UserDefaults.standard.set(knownData, forKey: "SavedLocations")
                UserDefaults.standard.set(customData, forKey: "CustomLocations")
            }
        } catch {
            await ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "LocationData", underlyingError: error),
                key: "UserDefaultsPersistence",
                operation: "save"
            )
        }
    }
    
    /// Atomic UserDefaults loading
    private func loadFromUserDefaults() async -> (known: [LocationType: SavedLocation], custom: [UUID: CustomLocation]) {
        return await MainActor.run {
            var loadedKnown: [LocationType: SavedLocation] = [:]
            var loadedCustom: [UUID: CustomLocation] = [:]
            
            // Load known locations
            if let knownData = UserDefaults.standard.data(forKey: "SavedLocations") {
                do {
                    loadedKnown = try JSONDecoder().decode([LocationType: SavedLocation].self, from: knownData)
                } catch {
                    Task {
                        ErrorHandlingService.shared.handleDataError(
                            .decodingFailed(type: "SavedLocation", underlyingError: error),
                            key: "SavedLocations",
                            operation: "load"
                        )
                    }
                }
            }
            
            // Load custom locations
            if let customData = UserDefaults.standard.data(forKey: "CustomLocations") {
                do {
                    loadedCustom = try JSONDecoder().decode([UUID: CustomLocation].self, from: customData)
                } catch {
                    Task {
                        ErrorHandlingService.shared.handleDataError(
                            .decodingFailed(type: "CustomLocation", underlyingError: error),
                            key: "CustomLocations",
                            operation: "load"
                        )
                    }
                }
            }
            
            return (known: loadedKnown, custom: loadedCustom)
        }
    }
    
    // MARK: - Debug Support
    
    /// Record timestamp for actor isolation testing
    public func recordOperationTimestamp() -> Date {
        return Date()
    }
}

/// Internal delegate class for CLLocationManager
private class LocationManagerDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private weak var service: LocationService?
    
    init(service: LocationService) {
        self.service = service
        super.init()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { [weak self] in
            await self?.service?.updateLocation(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let locationError: LocationError
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = .permissionDenied
                case .locationUnknown:
                    locationError = .locationUnavailable
                case .network:
                    locationError = .timeout
                default:
                    locationError = .locationUnavailable
                }
            } else {
                locationError = .locationUnavailable
            }
            
            await MainActor.run {
                ErrorHandlingService.shared.handleLocationError(locationError)
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        #if os(iOS)
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { [weak self] in
                await self?.service?.startUpdatingLocation()
            }
        }
        #elseif os(macOS)
        if status == .authorizedAlways {
            Task { [weak self] in
                await self?.service?.startUpdatingLocation()
            }
        }
        #endif
    }
}