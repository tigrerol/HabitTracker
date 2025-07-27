import Foundation
import CoreLocation

/// Service responsible for storing and retrieving saved locations
@MainActor
public final class LocationStorageService: ObservableObject {
    @Published private(set) var knownLocations: [LocationType: SavedLocation] = [:]
    @Published private(set) var customLocations: [UUID: CustomLocation] = [:]
    
    private let persistenceService: any PersistenceServiceProtocol
    private let savedLocationsKey = "SavedLocations"
    private let customLocationsKey = "CustomLocations"
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        Task {
            await loadFromPersistence()
        }
    }
    
    // MARK: - Known Locations Management
    
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
        let finalRadius = radius ?? AppConstants.Location.defaultRadius
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
        
        // Persist to storage
        await persistLocations()
    }
    
    /// Remove a saved location
    public func removeLocation(for type: LocationType) async {
        knownLocations.removeValue(forKey: type)
        await persistLocations()
    }
    
    /// Get all saved locations
    public func getSavedLocations() -> [LocationType: SavedLocation] {
        knownLocations
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
    }
    
    /// Delete a custom location
    public func deleteCustomLocation(id: UUID) async {
        customLocations.removeValue(forKey: id)
        await persistLocations()
    }
    
    /// Get a specific custom location
    public func getCustomLocation(id: UUID) -> CustomLocation? {
        customLocations[id]
    }
    
    /// Get all custom locations
    public func getAllCustomLocations() -> [CustomLocation] {
        Array(customLocations.values).sorted { $0.dateCreated < $1.dateCreated }
    }
    
    // MARK: - Persistence
    
    private func persistLocations() async {
        do {
            try await persistenceService.save(knownLocations, forKey: savedLocationsKey)
            try await persistenceService.save(customLocations, forKey: customLocationsKey)
        } catch {
            await ErrorHandlingService.shared.handleDataError(
                .encodingFailed(type: "LocationData", underlyingError: error),
                key: "LocationStoragePersistence",
                operation: "save"
            )
        }
    }
    
    private func loadFromPersistence() async {
        // Load known locations
        do {
            if let known = try await persistenceService.load([LocationType: SavedLocation].self, forKey: savedLocationsKey) {
                knownLocations = known
            }
        } catch {
            await ErrorHandlingService.shared.handleDataError(
                .decodingFailed(type: "SavedLocation", underlyingError: error),
                key: savedLocationsKey,
                operation: "load"
            )
        }
        
        // Load custom locations
        do {
            if let custom = try await persistenceService.load([UUID: CustomLocation].self, forKey: customLocationsKey) {
                customLocations = custom
            }
        } catch {
            await ErrorHandlingService.shared.handleDataError(
                .decodingFailed(type: "CustomLocation", underlyingError: error),
                key: customLocationsKey,
                operation: "load"
            )
        }
    }
}