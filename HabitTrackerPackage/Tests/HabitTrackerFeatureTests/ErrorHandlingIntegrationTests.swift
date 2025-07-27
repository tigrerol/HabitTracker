import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Error Handling Integration Tests")
struct ErrorHandlingIntegrationTests {
    
    @Test("LocationService handles invalid coordinates correctly")
    @MainActor func testLocationServiceInvalidCoordinates() async {
        let service = LocationService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        do {
            try await service.saveLocation(invalidLocation, as: .office)
            Issue.record("Expected error for invalid coordinates")
        } catch let error as LocationError {
            #expect(error.category == .location)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected LocationError but got \(error)")
        }
    }
    
    @Test("LocationService handles invalid radius correctly")
    @MainActor func testLocationServiceInvalidRadius() async {
        let service = LocationService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        
        do {
            try await service.saveLocation(validLocation, as: .office, radius: 5000.0) // Too large
            Issue.record("Expected error for invalid radius")
        } catch let error as LocationError {
            #expect(error.category == .location)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected LocationError but got \(error)")
        }
    }
    
    @Test("LocationService handles invalid name correctly")
    @MainActor func testLocationServiceInvalidName() async {
        let service = LocationService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let validLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let invalidName = String(repeating: "a", count: 50) // Too long
        
        do {
            try await service.saveLocation(validLocation, as: .office, name: invalidName)
            Issue.record("Expected error for invalid name")
        } catch let error as ValidationError {
            #expect(error.category == .validation)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected ValidationError but got \(error)")
        }
    }
    
    @Test("RoutineService handles session already active correctly")
    @MainActor func testRoutineServiceSessionAlreadyActive() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        guard let template = service.templates.first else {
            Issue.record("No templates available for testing")
            return
        }
        
        do {
            // Start first session
            try service.startSession(with: template)
            #expect(service.currentSession != nil)
            
            // Try to start another session
            try service.startSession(with: template)
            Issue.record("Expected error for session already active")
        } catch let error as RoutineError {
            #expect(error.category == .routine)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles template not found correctly")
    @MainActor func testRoutineServiceTemplateNotFound() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create a template that's not in the service
        let fakeTemplate = RoutineTemplate(
            name: "Fake Template",
            habits: [Habit(name: "Fake Habit", type: .checkbox, order: 0)]
        )
        
        do {
            try service.startSession(with: fakeTemplate)
            Issue.record("Expected error for template not found")
        } catch let error as RoutineError {
            #expect(error.category == .routine)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles empty template correctly")
    @MainActor func testRoutineServiceEmptyTemplate() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Create an empty template
        let emptyTemplate = RoutineTemplate(
            name: "Empty Template",
            habits: [] // No habits
        )
        
        // Add it to the service templates for validation to pass
        service.templates.append(emptyTemplate)
        
        do {
            try service.startSession(with: emptyTemplate)
            Issue.record("Expected error for empty template")
        } catch let error as RoutineError {
            #expect(error.category == .routine)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("RoutineService handles no active session for completion")
    @MainActor func testRoutineServiceNoActiveSessionCompletion() {
        let service = RoutineService()
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        // Ensure no session is active
        #expect(service.currentSession == nil)
        
        do {
            try service.completeCurrentSession()
            Issue.record("Expected error for no active session")
        } catch let error as RoutineError {
            #expect(error.category == .routine)
            #expect(errorService.getErrorHistory().count == 1)
        } catch {
            Issue.record("Expected RoutineError but got \(error)")
        }
    }
    
    @Test("Multiple errors are tracked correctly")
    @MainActor func testMultipleErrorTracking() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationService = LocationService()
        let routineService = RoutineService()
        
        // Generate multiple errors
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        do {
            try await locationService.saveLocation(invalidLocation, as: .office)
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
        #expect(stats.categoryCounts[.routine] == 1)
    }
    
    @Test("Error recovery suggestions are contextual")
    @MainActor func testErrorRecoverySuggestions() {
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
    
    @Test("Error severity determines logging behavior")
    @MainActor func testErrorSeverityLogging() {
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
    @MainActor func testErrorCallbacksIntegration() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        var callbackErrors: [any HabitTrackerError] = []
        
        errorService.registerErrorCallback { error in
            callbackErrors.append(error)
        }
        
        let locationService = LocationService()
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        do {
            try await locationService.saveLocation(invalidLocation, as: .office)
        } catch {
            // Expected to fail
        }
        
        #expect(callbackErrors.count == 1)
        #expect(callbackErrors.first?.category == .location)
    }
    
    @Test("Error handling maintains app stability")
    @MainActor func testErrorHandlingStability() async {
        let errorService = ErrorHandlingService.shared
        errorService.clearHistory()
        
        let locationService = LocationService()
        let routineService = RoutineService()
        
        // Simulate a series of errors that could destabilize the app
        let invalidLocation = CLLocation(latitude: 999.0, longitude: -999.0)
        
        // This should not crash the app
        for _ in 0..<10 {
            do {
                try await locationService.saveLocation(invalidLocation, as: .office)
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
        #expect(locationService.currentLocationCategory == nil)
        #expect(routineService.currentSession == nil)
        #expect(routineService.templates.count > 0)
    }
}