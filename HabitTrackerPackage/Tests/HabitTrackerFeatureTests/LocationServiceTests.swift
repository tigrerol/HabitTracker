import Testing
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Location Service Tests")
struct LocationServiceTests {
    
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
    
    @Test("LocationService initializes with correct state")
    @MainActor func testLocationServiceInitialization() {
        let service = LocationService()
        
        #expect(service.currentLocation == nil)
        #expect(service.isAuthorized == false)
        #expect(service.savedLocations.isEmpty)
        #expect(service.currentLocationCategory == nil)
    }
    
    @Test("LocationService can save and retrieve locations")
    @MainActor func testSaveAndRetrieveLocations() {
        let service = LocationService()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        #expect(service.savedLocations.isEmpty)
        
        service.saveLocation(testLocation, name: "Test Office")
        
        #expect(service.savedLocations.count == 1)
        #expect(service.savedLocations.first?.name == "Test Office")
        #expect(service.savedLocations.first?.coordinate.latitude == 37.7749)
    }
    
    @Test("LocationService can remove saved locations")
    @MainActor func testRemoveLocation() {
        let service = LocationService()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        service.saveLocation(testLocation, name: "Test Office")
        #expect(service.savedLocations.count == 1)
        
        if let savedLocation = service.savedLocations.first {
            service.removeSavedLocation(savedLocation)
            #expect(service.savedLocations.isEmpty)
        } else {
            Issue.record("Failed to save location for removal test")
        }
    }
    
    @Test("LocationService calculates distance correctly")
    @MainActor func testLocationDistance() {
        let service = LocationService()
        let location1 = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let location2 = CLLocation(latitude: 40.7128, longitude: -74.0060)  // New York
        
        let distance = service.distance(from: location1, to: location2)
        
        // Distance between SF and NYC is approximately 4,100 km
        #expect(distance > 4_000_000) // 4,000 km in meters
        #expect(distance < 5_000_000) // 5,000 km in meters
    }
    
    @Test("LocationService determines location vicinity correctly")
    @MainActor func testLocationVicinity() {
        let service = LocationService()
        let baseLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Save a location
        service.saveLocation(baseLocation, name: "Office")
        
        // Test location within radius (100m away)
        let nearbyLocation = CLLocation(latitude: 37.7750, longitude: -122.4195)
        let isNearby = service.isLocation(nearbyLocation, withinRadiusOf: service.savedLocations.first!)
        #expect(isNearby == true)
        
        // Test location outside radius (1km away)
        let farLocation = CLLocation(latitude: 37.7849, longitude: -122.4294)
        let isFar = service.isLocation(farLocation, withinRadiusOf: service.savedLocations.first!)
        #expect(isFar == false)
    }
    
    @Test("LocationService handles permission states correctly")
    @MainActor func testPermissionHandling() {
        let service = LocationService()
        
        // Initial state
        #expect(service.isAuthorized == false)
        
        // Simulate authorization granted
        service.handleAuthorizationChange(.authorizedWhenInUse)
        #expect(service.isAuthorized == true)
        
        // Simulate authorization denied
        service.handleAuthorizationChange(.denied)
        #expect(service.isAuthorized == false)
        
        // Test other permission states
        service.handleAuthorizationChange(.authorizedAlways)
        #expect(service.isAuthorized == true)
        
        service.handleAuthorizationChange(.restricted)
        #expect(service.isAuthorized == false)
        
        service.handleAuthorizationChange(.notDetermined)
        #expect(service.isAuthorized == false)
    }
    
    @Test("LocationService categorizes locations correctly")
    @MainActor func testLocationCategorization() {
        let service = LocationService()
        let officeLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let homeLocation = CLLocation(latitude: 37.7849, longitude: -122.4294)
        
        // Save locations with categories
        service.saveLocation(officeLocation, name: "Office")
        service.saveLocation(homeLocation, name: "Home")
        
        // Set current location near office
        service.updateCurrentLocation(officeLocation)
        
        // The service should categorize based on proximity
        let category = service.determineLocationCategory(for: officeLocation)
        #expect(category != nil)
    }
}

@Suite("Location Manager Integration Tests")
struct LocationManagerIntegrationTests {
    
    @Test("LocationService handles location updates")
    @MainActor func testLocationUpdates() {
        let service = LocationService()
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        #expect(service.currentLocation == nil)
        
        service.updateCurrentLocation(testLocation)
        
        #expect(service.currentLocation != nil)
        #expect(service.currentLocation?.coordinate.latitude == 37.7749)
        #expect(service.currentLocation?.coordinate.longitude == -122.4194)
    }
    
    @Test("LocationService handles location errors gracefully")
    @MainActor func testLocationErrors() {
        let service = LocationService()
        
        // Test various error scenarios
        service.handleLocationError(CLError(.locationUnknown))
        #expect(service.currentLocation == nil)
        
        service.handleLocationError(CLError(.denied))
        #expect(service.isAuthorized == false)
        
        service.handleLocationError(CLError(.network))
        // Should not crash and maintain previous state
        #expect(service.currentLocation == nil)
    }
    
    @Test("LocationService manages background location updates")
    @MainActor func testBackgroundLocationHandling() {
        let service = LocationService()
        
        // Test that service can handle being initialized in background
        service.pauseLocationUpdates()
        #expect(service.currentLocation == nil)
        
        service.resumeLocationUpdates()
        // Should attempt to restart location services
    }
}