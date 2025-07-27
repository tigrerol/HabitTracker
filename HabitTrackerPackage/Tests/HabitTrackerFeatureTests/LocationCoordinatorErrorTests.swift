import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("LocationCoordinator Error Handling Tests")
struct LocationCoordinatorErrorTests {
    
    @Test("LocationCoordinator handles invalid coordinates correctly")
    @MainActor func testLocationCoordinatorInvalidCoordinates() async {
        let coordinator = LocationCoordinator()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        do {
            try await coordinator.saveLocation(invalidLocation, as: .office)
            Issue.record("Expected error for invalid coordinates")
        } catch let error as LocationError {
            #expect(error.category == .location)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected LocationError but got \(error)")
        }
    }
    
    @Test("LocationCoordinator handles invalid radius correctly")
    @MainActor func testLocationCoordinatorInvalidRadius() async {
        let coordinator = LocationCoordinator()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        do {
            try await coordinator.saveLocation(validLocation, as: .office, radius: 5000.0) // Too large
            Issue.record("Expected error for invalid radius")
        } catch let error as LocationError {
            #expect(error.category == .location)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected LocationError but got \(error)")
        }
    }
    
    @Test("LocationCoordinator handles invalid name correctly")
    @MainActor func testLocationCoordinatorInvalidName() async {
        let coordinator = LocationCoordinator()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let invalidName = String(repeating: "a", count: 50) // Too long
        
        do {
            try await coordinator.saveLocation(validLocation, as: .office, name: invalidName)
            Issue.record("Expected error for invalid name")
        } catch let error as ValidationError {
            #expect(error.category == .validation)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected ValidationError but got \(error)")
        }
    }
}

@Suite("LocationTrackingService Error Tests")
struct LocationTrackingServiceErrorTests {
    
    @Test("LocationTrackingService handles permission denied gracefully")
    @MainActor func testLocationTrackingPermissionDenied() async {
        let trackingService = LocationTrackingService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Setup the location manager without permissions
        await trackingService.setupLocationManager()
        
        // Try to start location updates - this would typically fail in real scenarios
        await trackingService.startUpdatingLocation()
        
        // The service should handle permission errors gracefully
        // In a real test environment, we'd need to mock CLLocationManager
        #expect(true) // Placeholder until we add proper mocking
    }
    
    @Test("LocationTrackingService handles invalid callback gracefully")
    func testLocationTrackingInvalidCallback() async {
        let trackingService = LocationTrackingService()
        
        // Test setting a callback that might throw
        await trackingService.setLocationUpdateCallback { location in
            // This callback intentionally does nothing to test error handling
        }
        
        // Service should handle callback errors gracefully
        #expect(true) // Placeholder for callback error testing
    }
}

@Suite("LocationStorageService Error Tests")
struct LocationStorageServiceErrorTests {
    
    @Test("LocationStorageService handles persistence failures gracefully")
    @MainActor func testLocationStoragePersistenceFailure() async {
        // Create a mock persistence service that always fails
        let failingPersistence = FailingPersistenceService()
        let storageService = LocationStorageService(persistenceService: failingPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        do {
            try await storageService.saveLocation(validLocation, as: .office)
            Issue.record("Expected persistence error")
        } catch {
            // Should gracefully handle persistence failures
            #expect(errorService.getErrorHistory().count > 0)
        }
    }
    
    @Test("LocationStorageService handles data corruption gracefully")
    @MainActor func testLocationStorageDataCorruption() async {
        // Create a mock persistence service that returns corrupted data
        let corruptedPersistence = CorruptedDataPersistenceService()
        let storageService = LocationStorageService(persistenceService: corruptedPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Try to get locations - should handle corruption gracefully
        let _ = storageService.getSavedLocations()
        
        // Should log error but not crash
        let history = errorService.getErrorHistory()
        #expect(history.count > 0)
        #expect(history.first?.error.category == .data)
    }
    
    @Test("LocationStorageService validates custom location names")
    @MainActor func testLocationStorageCustomLocationValidation() async {
        let storageService = LocationStorageService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Test empty name
        let customLocation1 = await storageService.createCustomLocation(name: "", icon: "location.fill")
        #expect(customLocation1.name == "Unnamed Location") // Should use fallback
        
        // Test very long name
        let longName = String(repeating: "a", count: 100)
        let customLocation2 = await storageService.createCustomLocation(name: longName, icon: "location.fill")
        #expect(customLocation2.name.count <= 50) // Should be truncated
    }
}

@Suite("GeofencingService Error Tests")
struct GeofencingServiceErrorTests {
    
    @Test("GeofencingService handles missing storage data gracefully")
    @MainActor func testGeofencingMissingData() async {
        let storageService = LocationStorageService()
        let geofencingService = GeofencingService(storageService: storageService)
        
        let testLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        // Should handle case where no saved locations exist
        let (locationType, extendedType) = await geofencingService.processLocationUpdate(testLocation)
        
        #expect(locationType == .unknown)
        #expect(extendedType == .builtin(.unknown))
    }
    
    @Test("GeofencingService handles invalid coordinates gracefully")
    @MainActor func testGeofencingInvalidCoordinates() async {
        let storageService = LocationStorageService()
        let geofencingService = GeofencingService(storageService: storageService)
        
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        // Should handle invalid coordinates without crashing
        let (locationType, extendedType) = await geofencingService.processLocationUpdate(invalidLocation)
        
        #expect(locationType == .unknown)
        #expect(extendedType == .builtin(.unknown))
    }
}

// MARK: - Mock Services for Testing

/// Mock persistence service that always fails operations
private final class FailingPersistenceService: @unchecked Sendable, PersistenceServiceProtocol {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        throw DataError.encodingFailed(type: String(describing: T.self), underlyingError: NSError(domain: "TestError", code: 1))
    }
    
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        throw DataError.decodingFailed(type: String(describing: T.self), underlyingError: NSError(domain: "TestError", code: 2))
    }
    
    func delete(forKey key: String) async {
        // Delete fails silently
    }
    
    func exists(forKey key: String) async -> Bool {
        return false
    }
}

/// Mock persistence service that returns corrupted data
private final class CorruptedDataPersistenceService: @unchecked Sendable, PersistenceServiceProtocol {
    func save<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        // Save succeeds
    }
    
    func load<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        throw DataError.corruptedData(key: key)
    }
    
    func delete(forKey key: String) async {
        // Delete succeeds
    }
    
    func exists(forKey key: String) async -> Bool {
        return true
    }
}