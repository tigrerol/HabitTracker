import Testing
import CoreLocation
@testable import HabitTrackerFeature

@Suite("LocationCoordinator Tests")
struct LocationCoordinatorTests {
    
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
        let coordinator = LocationCoordinator()
        
        #expect(coordinator.currentLocation == nil)
        #expect(coordinator.currentLocationType == .unknown)
        #expect(coordinator.currentExtendedLocationType == .builtin(.unknown))
        #expect(coordinator.getSavedLocations().isEmpty)
    }
    
    @Test("LocationCoordinator can save and retrieve locations")
    @MainActor func testLocationCoordinatorSaveRetrieve() async {
        let coordinator = LocationCoordinator()
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
        let coordinator = LocationCoordinator()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        try? await coordinator.saveLocation(testLocation, as: .office, name: "Test Office")
        #expect(coordinator.hasLocation(for: .office))
        
        await coordinator.removeLocation(for: .office)
        #expect(!coordinator.hasLocation(for: .office))
        #expect(coordinator.getSavedLocations().isEmpty)
    }
    
    @Test("LocationCoordinator calculates distance correctly")
    @MainActor func testLocationCoordinatorDistance() async {
        let coordinator = LocationCoordinator()
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
        let coordinator = LocationCoordinator()
        
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
        let coordinator = LocationCoordinator()
        
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
        let coordinator = LocationCoordinator()
        var updateReceived = false
        var receivedLocationType: LocationType?
        var receivedExtendedType: ExtendedLocationType?
        
        // Set up callback
        coordinator.setLocationUpdateCallback { locationType, extendedType in
            updateReceived = true
            receivedLocationType = locationType
            receivedExtendedType = extendedType
        }
        
        // Save a location first
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        try? await coordinator.saveLocation(testLocation, as: .office, name: "Test Office")
        
        // The callback should be triggered when location is saved and processed
        #expect(updateReceived == true)
        #expect(receivedLocationType != nil)
        #expect(receivedExtendedType != nil)
    }
    
    @Test("LocationCoordinator handles permission states correctly")
    @MainActor func testLocationCoordinatorPermissions() async {
        let coordinator = LocationCoordinator()
        
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
        let coordinator = LocationCoordinator()
        
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