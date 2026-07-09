import Testing
import CoreLocation
@testable import HabitTrackerFeature

@Suite("LocationCoordinator Tests")
struct LocationCoordinatorTests {

    /// Coordinator on an isolated UserDefaults suite so parallel tests don't
    /// clobber each other's persisted locations.
    @MainActor
    private func makeIsolatedCoordinator() -> LocationCoordinator {
        let suiteName = "test-location-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return LocationCoordinator(persistenceService: UserDefaultsPersistenceService(userDefaults: defaults))
    }

    
    @Test("SavedLocation initializes correctly")
    func testSavedLocationInitialization() {
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let savedLocation = SavedLocation(
            location: testLocation,
            name: "Test Office",
            radius: AppConstants.Location.defaultRadius
        )
        
        #expect(savedLocation.coordinate.latitude == 37.7749)
        #expect(savedLocation.coordinate.longitude == -122.4194)
        #expect(savedLocation.name == "Test Office")
        #expect(savedLocation.radius == AppConstants.Location.defaultRadius)
        #expect(savedLocation.clLocation.coordinate.latitude == 37.7749)
        #expect(savedLocation.clLocation.coordinate.longitude == -122.4194)
    }
    
    @Test("SavedLocation uses default radius when none provided")
    func testSavedLocationDefaultRadius() {
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let savedLocation = SavedLocation(location: testLocation, name: "Test")
        
        #expect(savedLocation.radius == AppConstants.Location.defaultRadius)
    }
    
    @Test("LocationCoordinate stores coordinates correctly")
    func testLocationCoordinate() {
        let coordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        #expect(coordinate.latitude == 40.7128)
        #expect(coordinate.longitude == -74.0060)
    }
    
    @Test("LocationCoordinator initializes with correct state")
    @MainActor func testLocationCoordinatorInitialization() {
        let coordinator = makeIsolatedCoordinator()
        
        #expect(coordinator.currentLocation == nil)
        #expect(coordinator.currentLocationType == .unknown)
        #expect(coordinator.currentExtendedLocationType == .builtin(.unknown))
        #expect(coordinator.getSavedLocations().isEmpty)
    }
    
    @Test("LocationCoordinator can save and retrieve locations")
    @MainActor func testLocationCoordinatorSaveRetrieve() async {
        let coordinator = makeIsolatedCoordinator()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        try? await coordinator.saveLocation(testLocation, as: .office, name: "Test Office")
        
        let savedLocations = coordinator.getSavedLocations()
        #expect(savedLocations.count == 1)
        #expect(savedLocations[.office] != nil)
        #expect(savedLocations[.office]?.name == "Test Office")
        #expect(coordinator.hasLocation(for: .office))
    }
    
    @Test("LocationCoordinator can remove saved locations")
    @MainActor func testLocationCoordinatorRemove() async {
        let coordinator = makeIsolatedCoordinator()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        try? await coordinator.saveLocation(testLocation, as: .office, name: "Test Office")
        #expect(coordinator.hasLocation(for: .office))
        
        await coordinator.removeLocation(for: .office)
        #expect(!coordinator.hasLocation(for: .office))
        #expect(coordinator.getSavedLocations().isEmpty)
    }
    
    @Test("LocationCoordinator calculates distance correctly")
    @MainActor func testLocationCoordinatorDistance() async {
        let coordinator = makeIsolatedCoordinator()
        let officeLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let homeLocation = CLLocation(latitude: 37.7849, longitude: -122.4094)
        
        try? await coordinator.saveLocation(officeLocation, as: .office, name: "Office")
        try? await coordinator.saveLocation(homeLocation, as: .home, name: "Home")
        
        let savedLocations = coordinator.getSavedLocations()
        let office = savedLocations[.office]?.clLocation
        let home = savedLocations[.home]?.clLocation
        
        #expect(office != nil)
        #expect(home != nil)
        
        if let office = office, let home = home {
            let distance = office.distance(from: home)
            #expect(distance > 0)
            #expect(distance < 2000) // Should be less than 2km for these close coordinates
        }
    }
    
    @Test("LocationCoordinator handles custom locations")
    @MainActor func testLocationCoordinatorCustomLocations() async {
        let coordinator = makeIsolatedCoordinator()
        
        // Create custom location
        let customLocation = await coordinator.createCustomLocation(name: "Gym", icon: "dumbbell.fill")
        #expect(customLocation.name == "Gym")
        #expect(customLocation.icon == "dumbbell.fill")
        
        // Set coordinates
        let gymLocation = CLLocation(latitude: 37.7849, longitude: -122.4094)
        await coordinator.setCustomLocationCoordinates(for: customLocation.id, location: gymLocation)
        
        // Retrieve and verify
        let retrievedLocation = coordinator.getCustomLocation(id: customLocation.id)
        #expect(retrievedLocation != nil)
        #expect(retrievedLocation?.coordinate?.latitude == 37.7849)
        
        // Get all custom locations
        let allCustom = coordinator.getAllCustomLocations()
        #expect(allCustom.count == 1)
        #expect(allCustom.first?.name == "Gym")
    }
    
    @Test("LocationCoordinator handles custom location management")
    @MainActor func testLocationCoordinatorCustomLocationManagement() async {
        let coordinator = makeIsolatedCoordinator()
        
        // Create custom location
        var customLocation = await coordinator.createCustomLocation(name: "Library", icon: "book.fill")
        
        // Update the location
        customLocation.name = "Public Library"
        customLocation.icon = "books.vertical.fill"
        await coordinator.updateCustomLocation(customLocation)
        
        // Verify update
        let updated = coordinator.getCustomLocation(id: customLocation.id)
        #expect(updated?.name == "Public Library")
        #expect(updated?.icon == "books.vertical.fill")
        
        // Delete the location
        await coordinator.deleteCustomLocation(id: customLocation.id)
        
        // Verify deletion
        let deleted = coordinator.getCustomLocation(id: customLocation.id)
        #expect(deleted == nil)
        #expect(coordinator.getAllCustomLocations().isEmpty)
    }
    
    @Test("LocationCoordinator handles location updates")
    @MainActor func testLocationCoordinatorLocationUpdates() async {
        let coordinator = makeIsolatedCoordinator()
        var updateReceived = false
        var receivedLocationType: LocationType?
        var receivedExtendedType: ExtendedLocationType?
        
        // Set up callback
        coordinator.addLocationUpdateCallback { locationType, extendedType in
            updateReceived = true
            receivedLocationType = locationType
            receivedExtendedType = extendedType
        }
        
        // Save a location first
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        try? await coordinator.saveLocation(testLocation, as: .office, name: "Test Office")

        // Callbacks fire when a GPS fix is processed, not on save — with no GPS
        // in the test environment, no update should have been delivered.
        #expect(updateReceived == false)
        #expect(receivedLocationType == nil)
        #expect(receivedExtendedType == nil)
    }
    
    @Test("LocationCoordinator handles permission states correctly")
    @MainActor func testLocationCoordinatorPermissions() async {
        let coordinator = makeIsolatedCoordinator()
        
        // Initial state should be unknown
        #expect(coordinator.currentLocationType == .unknown)
        
        // Start location tracking
        await coordinator.startUpdatingLocation()
        
        // In test environment, permissions won't be granted, but should handle gracefully
        #expect(coordinator.currentLocationType == .unknown)
        
        // Stop tracking
        await coordinator.stopUpdatingLocation()
    }
    
    @Test("LocationCoordinator manages background location updates")
    @MainActor func testLocationCoordinatorBackgroundUpdates() async {
        let coordinator = makeIsolatedCoordinator()
        
        // Start location updates
        await coordinator.startUpdatingLocation()
        
        // Get current location (will be nil in test environment)
        let currentLocation = await coordinator.getCurrentLocation()
        #expect(currentLocation == nil) // Expected in test environment
        
        // Get current types
        let (locationType, extendedType) = await coordinator.getCurrentLocationTypes()
        #expect(locationType == .unknown)
        #expect(extendedType == .builtin(.unknown))
        
        // Stop updates
        await coordinator.stopUpdatingLocation()
    }
}


// MARK: - Load/Mutation Sequencing

@Suite("Location Load Sequencing Tests")
struct LocationLoadSequencingTests {

    /// Persistence whose loads are artificially slow, to widen the init-load window.
    private final class SlowLoadPersistenceService: @unchecked Sendable, PersistenceServiceProtocol {
        let wrapped: UserDefaultsPersistenceService
        init(wrapped: UserDefaultsPersistenceService) { self.wrapped = wrapped }

        func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
            try await wrapped.save(object, forKey: key)
        }

        func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
            try? await Task.sleep(for: .milliseconds(150))
            return try await wrapped.load(type, forKey: key)
        }

        func delete(forKey key: String) async { await wrapped.delete(forKey: key) }
        func exists(forKey key: String) async -> Bool { await wrapped.exists(forKey: key) }
        func loadRoutineSessions(for templateId: UUID) async -> [RoutineSessionData] { [] }
        func saveRoutineSession(_ session: RoutineSessionData, for templateId: UUID) async { }
    }

    @Test("A mutation during the init load does not wipe previously saved locations")
    @MainActor func mutationDuringLoadPreservesDiskData() async throws {
        let suiteName = "test-seq-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Seed disk with an existing saved location
        let plain = UserDefaultsPersistenceService(userDefaults: defaults)
        let seeded: [LocationType: SavedLocation] = [
            .office: SavedLocation(location: CLLocation(latitude: 48.2, longitude: 16.3), name: "Office", radius: 150)
        ]
        try await plain.save(seeded, forKey: PersistenceKeys.savedLocations)

        // Storage with slow loads; mutate immediately, inside the load window
        let storage = LocationStorageService(persistenceService: SlowLoadPersistenceService(wrapped: plain))
        _ = await storage.createCustomLocation(name: "Gym")

        await storage.ensureLoaded()

        // Both the seeded location AND the new custom location must survive
        #expect(storage.hasLocation(for: .office))
        #expect(storage.getAllCustomLocations().contains { $0.name == "Gym" })

        // ...and on disk too
        let onDisk = try await plain.load([LocationType: SavedLocation].self, forKey: PersistenceKeys.savedLocations)
        #expect(onDisk?[.office] != nil)
    }
}
