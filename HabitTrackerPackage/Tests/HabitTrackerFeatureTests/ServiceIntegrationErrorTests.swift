import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Service Integration Error Tests")
struct ServiceIntegrationErrorTests {
    
    @Test("Multiple errors are tracked correctly across services")
    @MainActor func testMultipleServiceErrorTracking() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationCoordinator = LocationCoordinator()
        let routineService = RoutineService()
        
        // Generate multiple errors from different services
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        do {
            try await locationCoordinator.saveLocation(invalidLocation, as: .office)
        } catch {
            // Expected to fail
        }
        
        do {
            try routineService.completeCurrentSession()
        } catch {
            // Expected to fail
        }
        
        let history = errorService.getErrorHistory()
        #expect(history.count == 2)
        
        let stats = errorService.getErrorStatistics()
        #expect(stats.totalErrors == 2)
        #expect(stats.categoryCounts[.location] == 1)
        #expect(stats.categoryCounts[.technical] == 1)
    }
    
    @Test("Error recovery suggestions are contextual across services")
    @MainActor func testServiceErrorRecoverySuggestions() {
        let errorService = ErrorHandlingService.shared
        
        // Location permission error
        let locationError = LocationError.permissionDenied
        let locationActions = errorService.suggestRecovery(for: locationError)
        #expect(locationActions.contains(.enableLocation))
        #expect(locationActions.contains(.checkSettings))
        
        // Routine no session error
        let routineError = RoutineError.noActiveSession
        let routineActions = errorService.suggestRecovery(for: routineError)
        #expect(routineActions.contains(.retry))
        
        // Data corruption error
        let dataError = DataError.corruptedData(key: "test")
        let dataActions = errorService.suggestRecovery(for: dataError)
        #expect(dataActions.contains(.restart))
        #expect(dataActions.contains(.contact))
    }
    
    @Test("Error severity determines logging behavior across services")
    @MainActor func testServiceErrorSeverityLogging() {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // High severity error
        let highSeverityError = LocationError.permissionDenied
        #expect(highSeverityError.severity == .high)
        #expect(highSeverityError.shouldLog == true)
        
        // Low severity error
        let lowSeverityError = ValidationError.invalidHabitName(name: "")
        #expect(lowSeverityError.severity == .low)
        #expect(lowSeverityError.shouldLog == false)
        
        errorService.handle(highSeverityError)
        errorService.handle(lowSeverityError)
        
        let history = errorService.getErrorHistory()
        #expect(history.count == 2)
    }
    
    @Test("Error callbacks work with service integrations")
    @MainActor func testServiceErrorCallbacksIntegration() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        var callbackErrors: [any HabitTrackerError] = []
        
        errorService.registerErrorCallback { error in
            callbackErrors.append(error)
        }
        
        let locationCoordinator = LocationCoordinator()
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        do {
            try await locationCoordinator.saveLocation(invalidLocation, as: .office)
        } catch {
            // Expected to fail
        }
        
        #expect(callbackErrors.count == 1)
        #expect(callbackErrors.first?.category == .location)
    }
    
    @Test("Error handling maintains app stability under load")
    @MainActor func testServiceErrorHandlingStability() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationCoordinator = LocationCoordinator()
        let routineService = RoutineService()
        
        // Simulate a series of errors that could destabilize the app
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        // This should not crash the app
        for _ in 0..<10 {
            do {
                try await locationCoordinator.saveLocation(invalidLocation, as: .office)
            } catch {
                // Expected errors
            }
            
            do {
                try routineService.completeCurrentSession()
            } catch {
                // Expected errors
            }
        }
        
        let stats = errorService.getErrorStatistics()
        #expect(stats.totalErrors == 20) // 10 location + 10 routine errors
        
        // App should still be functional
        #expect(locationCoordinator.currentLocationType == .unknown)
        #expect(routineService.currentSession == nil)
        #expect(routineService.templates.count > 0)
    }
}

@Suite("Persistence Error Integration Tests")
struct PersistenceErrorIntegrationTests {
    
    @Test("Services handle persistence failures gracefully")
    @MainActor func testServicePersistenceFailureHandling() async {
        let failingPersistence = FailingPersistenceService()
        
        // Test LocationCoordinator with failing persistence
        let locationCoordinator = LocationCoordinator(persistenceService: failingPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        do {
            try await locationCoordinator.saveLocation(validLocation, as: .office)
            Issue.record("Expected persistence error")
        } catch {
            // Should handle persistence failure gracefully
        }
        
        // Should have logged persistence error
        let history = errorService.getErrorHistory()
        #expect(history.count > 0)
        #expect(history.contains { $0.error.category == .data })
    }
    
    @Test("Services handle data corruption gracefully")
    @MainActor func testServiceDataCorruptionHandling() {
        let corruptedPersistence = CorruptedDataPersistenceService()
        
        // Test RoutineService with corrupted persistence
        let routineService = RoutineService(persistenceService: corruptedPersistence)
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Should fallback to sample templates when data is corrupted
        #expect(routineService.templates.count > 0)
        
        // Should log data corruption error
        #expect(errorService.getErrorHistory().count > 0)
    }
    
    @Test("Cross-service data consistency during errors")
    @MainActor func testCrossServiceDataConsistency() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationCoordinator = LocationCoordinator()
        let routineService = RoutineService()
        
        // Create valid data in both services
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        try? await locationCoordinator.saveLocation(validLocation, as: .office, name: "Office")
        
        guard let template = routineService.templates.first else {
            Issue.record("No templates available")
            return
        }
        
        try? routineService.startSession(with: template)
        
        // Verify both services have consistent state
        #expect(locationCoordinator.hasLocation(for: .office))
        #expect(routineService.currentSession != nil)
        
        // Generate errors and verify services maintain consistency
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        do {
            try await locationCoordinator.saveLocation(invalidLocation, as: .home)
        } catch {
            // Expected to fail
        }
        
        // Office location should still exist
        #expect(locationCoordinator.hasLocation(for: .office))
        // Session should still be active
        #expect(routineService.currentSession != nil)
    }
}

@Suite("Async Error Handling Integration Tests")
struct AsyncErrorHandlingIntegrationTests {
    
    @Test("Services safely execute operations concurrently")
    @MainActor func testServiceConcurrentOperationSafety() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationCoordinator = LocationCoordinator()
        
        // Execute multiple async operations concurrently
        async let result1 = errorService.safely {
            try await locationCoordinator.saveLocation(
                CLLocation(latitude: 37.7749, longitude: -122.4194),
                as: .office
            )
            return "Office saved"
        }
        
        async let result2 = errorService.safely {
            try await locationCoordinator.saveLocation(
                CLLocation(latitude: 37.7849, longitude: -122.4094),
                as: .home
            )
            return "Home saved"
        }
        
        let (officeResult, homeResult) = await (result1, result2)
        
        // Both operations should succeed
        switch officeResult {
        case .success(let value):
            #expect(value == "Office saved")
        case .failure:
            Issue.record("Office save should have succeeded")
        }
        
        switch homeResult {
        case .success(let value):
            #expect(value == "Home saved")
        case .failure:
            Issue.record("Home save should have succeeded")
        }
        
        // Verify both locations were saved
        #expect(locationCoordinator.hasLocation(for: .office))
        #expect(locationCoordinator.hasLocation(for: .home))
    }
    
    @Test("Services handle concurrent error scenarios")
    @MainActor func testServiceConcurrentErrorHandling() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationCoordinator = LocationCoordinator()
        
        // Execute operations that will fail concurrently
        async let result1 = errorService.safely {
            try await locationCoordinator.saveLocation(
                CLLocation(latitude: 999.0, longitude: -999.0), // Invalid
                as: .office
            )
            return "Office saved"
        }
        
        async let result2 = errorService.safely {
            try await locationCoordinator.saveLocation(
                CLLocation(latitude: 37.7849, longitude: -122.4094),
                as: .home,
                radius: 5000.0 // Invalid radius
            )
            return "Home saved"
        }
        
        let (officeResult, homeResult) = await (result1, result2)
        
        // Both operations should fail
        switch officeResult {
        case .success:
            Issue.record("Office save should have failed")
        case .failure(let error):
            #expect(error.category == .location)
        }
        
        switch homeResult {
        case .success:
            Issue.record("Home save should have failed")
        case .failure(let error):
            #expect(error.category == .location)
        }
        
        // Should have logged multiple errors
        let history = errorService.getErrorHistory()
        #expect(history.count >= 2)
    }
    
    @Test("Services handle retry mechanisms correctly")
    @MainActor func testServiceRetryMechanisms() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let attemptCounter = AtomicCounter()
        
        let result = await errorService.withRetry(maxAttempts: 3, delay: 0.1) {
            let count = attemptCounter.increment()
            if count < 3 {
                throw ValidationError.invalidHabitName(name: "")
            }
            return "Success on attempt \(count)"
        }
        
        switch result {
        case .success(let value):
            #expect(value.contains("3"))
        case .failure:
            Issue.record("Expected success after retries")
        }
        
        #expect(attemptCounter.value == 3)
    }
}

// MARK: - Test Utilities

/// Thread-safe counter for testing async operations
private final class AtomicCounter: @unchecked Sendable {
    private var _value = 0
    private let lock = NSLock()
    
    var value: Int {
        lock.withLock { _value }
    }
    
    @discardableResult
    func increment() -> Int {
        lock.withLock {
            _value += 1
            return _value
        }
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