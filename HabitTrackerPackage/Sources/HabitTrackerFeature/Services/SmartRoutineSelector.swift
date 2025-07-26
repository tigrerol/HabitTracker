import Foundation
import CoreLocation

/// Represents a saved location with metadata
public struct SavedLocation: Codable {
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

/// Service responsible for intelligently selecting routines based on context
@MainActor
@Observable
public final class SmartRoutineSelector {
    /// Current detected context
    public private(set) var currentContext: RoutineContext
    
    /// Location manager for detecting user location
    public let locationManager = LocationManager()
    
    /// Reason for the last selection
    public private(set) var selectionReason: String = ""
    
    public init() {
        self.currentContext = RoutineContext.current()
        
        // Update location when it changes
        Task {
            await startLocationUpdates()
        }
    }
    
    /// Update the current context
    public func updateContext() {
        let location = locationManager.currentLocationType
        let timeSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        let dayType = DayTypeManager.shared.getCurrentDayType()
        
        self.currentContext = RoutineContext(
            timeSlot: timeSlot,
            dayType: dayType,
            location: location
        )
    }
    
    /// Select the best routine template based on current context
    public func selectBestTemplate(from templates: [RoutineTemplate]) -> (template: RoutineTemplate?, reason: String) {
        updateContext()
        
        // Filter templates with context rules and calculate scores
        let scoredTemplates = templates.compactMap { template -> (template: RoutineTemplate, score: Int)? in
            guard let rule = template.contextRule else {
                // Templates without rules get a base score of 1
                return (template, 1)
            }
            
            let score = rule.matchScore(for: currentContext)
            return score > 0 ? (template, score) : nil
        }
        
        // Sort by score (highest first)
        let sorted = scoredTemplates.sorted { $0.score > $1.score }
        
        // Get the best match
        guard let best = sorted.first else {
            // Fallback to default or most recently used
            if let defaultTemplate = templates.first(where: { $0.isDefault }) {
                selectionReason = "Using default routine"
                return (defaultTemplate, selectionReason)
            }
            
            let lastUsed = templates
                .filter { $0.lastUsedAt != nil }
                .max { ($0.lastUsedAt ?? Date.distantPast) < ($1.lastUsedAt ?? Date.distantPast) }
            if let lastUsed = lastUsed {
                selectionReason = "Using most recently used routine"
                return (lastUsed, selectionReason)
            }
            
            selectionReason = "No matching routine found"
            return (templates.first, selectionReason)
        }
        
        // Build selection reason
        selectionReason = buildSelectionReason(for: best.template, context: currentContext)
        return (best.template, selectionReason)
    }
    
    /// Build a human-readable reason for the selection
    private func buildSelectionReason(for template: RoutineTemplate, context: RoutineContext) -> String {
        var reasons: [String] = []
        
        // Time-based reason
        reasons.append("It's \(context.timeSlot.displayName.lowercased())")
        
        // Day-based reason
        if context.dayType == .weekend {
            reasons.append("it's the weekend")
        } else if context.dayType == .weekday {
            reasons.append("it's a weekday")
        }
        
        // Location-based reason
        if context.location != .unknown {
            reasons.append("you're at \(context.location.displayName.lowercased())")
        }
        
        // Combine reasons
        if reasons.isEmpty {
            return "Selected '\(template.name)' as your routine"
        } else {
            let reasonText = reasons.joined(separator: " and ")
            return "Selected '\(template.name)' because \(reasonText)"
        }
    }
    
    /// Start monitoring location updates
    private func startLocationUpdates() async {
        await locationManager.startUpdatingLocation()
    }
}

/// Manager for handling location services
@MainActor
@Observable
public final class LocationManager: NSObject {
    private var locationManager: CLLocationManager?
    public private(set) var currentLocation: CLLocation?
    
    /// Current location type based on detected location
    public var currentLocationType: LocationType = .unknown
    
    /// Current detected location (including custom locations)
    public var currentExtendedLocationType: ExtendedLocationType = .builtin(.unknown)
    
    /// Known built-in locations (to be configured by user)
    private var knownLocations: [LocationType: SavedLocation] = [:]
    
    /// Custom user-defined locations
    private var customLocations: [UUID: CustomLocation] = [:]
    
    /// Detection radius in meters
    private let detectionRadius: CLLocationDistance = 150 // 150 meters
    
    public override init() {
        super.init()
        setupLocationManager()
        loadKnownLocations()
        loadCustomLocations()
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager?.distanceFilter = 100 // Update every 100 meters
    }
    
    public func startUpdatingLocation() async {
        guard let locationManager else { return }
        
        // Request permission if needed
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdatingLocation() {
        locationManager?.stopUpdatingLocation()
    }
    
    /// Determine location type from current location using geofencing
    private func determineLocationType(from location: CLLocation) -> LocationType {
        // Check against all saved locations
        for (locationType, savedLocation) in knownLocations {
            let distance = location.distance(from: savedLocation.clLocation)
            
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
            currentLocationType = determineLocationType(from: currentLocation)
        }
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) {
        knownLocations.removeValue(forKey: type)
        persistKnownLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            currentLocationType = determineLocationType(from: currentLocation)
        }
    }
    
    /// Get all saved locations
    public var savedLocations: [LocationType: SavedLocation] {
        knownLocations
    }
    
    /// Get all custom locations
    public var allCustomLocations: [CustomLocation] {
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
            currentExtendedLocationType = determineExtendedLocationType(from: currentLocation)
            currentLocationType = determineLocationType(from: currentLocation)
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
            currentExtendedLocationType = determineExtendedLocationType(from: currentLocation)
            currentLocationType = determineLocationType(from: currentLocation)
        }
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) {
        customLocations.removeValue(forKey: id)
        persistCustomLocations()
        
        // Update current location type
        if let currentLocation = currentLocation {
            currentExtendedLocationType = determineExtendedLocationType(from: currentLocation)
            currentLocationType = determineLocationType(from: currentLocation)
        }
    }
    
    /// Get a specific custom location
    public func getCustomLocation(id: UUID) -> CustomLocation? {
        customLocations[id]
    }
    
    // MARK: - Persistence
    
    private func persistKnownLocations() {
        do {
            let data = try JSONEncoder().encode(knownLocations)
            UserDefaults.standard.set(data, forKey: "SavedLocations")
        } catch {
            print("Failed to save locations: \(error)")
        }
    }
    
    private func loadKnownLocations() {
        guard let data = UserDefaults.standard.data(forKey: "SavedLocations") else { return }
        
        do {
            knownLocations = try JSONDecoder().decode([LocationType: SavedLocation].self, from: data)
        } catch {
            print("Failed to load locations: \(error)")
            knownLocations = [:]
        }
    }
    
    private func persistCustomLocations() {
        do {
            let data = try JSONEncoder().encode(customLocations)
            UserDefaults.standard.set(data, forKey: "CustomLocations")
        } catch {
            print("Failed to save custom locations: \(error)")
        }
    }
    
    private func loadCustomLocations() {
        guard let data = UserDefaults.standard.data(forKey: "CustomLocations") else { return }
        
        do {
            customLocations = try JSONDecoder().decode([UUID: CustomLocation].self, from: data)
        } catch {
            print("Failed to load custom locations: \(error)")
            customLocations = [:]
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            self.currentLocationType = determineLocationType(from: location)
            self.currentExtendedLocationType = determineExtendedLocationType(from: location)
        }
    }
    
    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in
                self.locationManager?.startUpdatingLocation()
            }
        }
    }
}