import Testing
import Foundation
import CoreLocation
@testable import HabitTrackerFeature

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("ErrorHandlingService initializes correctly")
    @MainActor func testErrorHandlingServiceInitialization() {
        let service = ErrorHandlingService.shared
        
        #expect(service.getErrorHistory().isEmpty)
        #expect(service.getErrorStatistics().totalErrors == 0)
    }
    
    @Test("ErrorHandlingService handles errors correctly")
    @MainActor func testErrorHandling() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        let error = LocationError.permissionDenied
        service.handle(error, context: ["test": "true"])
        
        let history = service.getErrorHistory()
        #expect(history.count == 1)
        #expect(history.first?.error.category == .location)
        #expect(history.first?.wasHandled == true)
        #expect(history.first?.context["test"] == "true")
    }
    
    @Test("ErrorHandlingService reports errors correctly")
    @MainActor func testErrorReporting() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        let error = RoutineError.noActiveSession
        service.report(error)
        
        let history = service.getErrorHistory()
        #expect(history.count == 1)
        #expect(history.first?.wasHandled == false)
    }
    
    @Test("ErrorHandlingService filters errors by category")
    @MainActor func testErrorFiltering() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        service.handle(LocationError.permissionDenied)
        service.handle(RoutineError.noActiveSession)
        service.handle(DataError.keyNotFound(key: "test"))
        
        let locationErrors = service.getErrors(for: .location)
        let routineErrors = service.getErrors(for: .routine)
        let dataErrors = service.getErrors(for: .persistence)
        
        #expect(locationErrors.count == 1)
        #expect(routineErrors.count == 1)
        #expect(dataErrors.count == 1)
    }
    
    @Test("ErrorHandlingService filters errors by severity")
    @MainActor func testSeverityFiltering() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        service.handle(LocationError.permissionDenied) // high
        service.handle(ValidationError.invalidHabitName(name: "")) // low
        
        let highSeverityErrors = service.getErrors(with: .high)
        let lowSeverityErrors = service.getErrors(with: .low)
        
        #expect(highSeverityErrors.count == 1)
        #expect(lowSeverityErrors.count == 1)
    }
    
    @Test("ErrorHandlingService provides error statistics")
    @MainActor func testErrorStatistics() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        service.handle(LocationError.permissionDenied)
        service.handle(LocationError.locationUnavailable)
        service.handle(RoutineError.noActiveSession)
        
        let stats = service.getErrorStatistics()
        #expect(stats.totalErrors == 3)
        #expect(stats.categoryCounts[.location] == 2)
        #expect(stats.categoryCounts[.routine] == 1)
        #expect(stats.severityCounts[.high] == 1)
        #expect(stats.severityCounts[.medium] == 1)
        #expect(stats.severityCounts[.low] == 1)
    }
    
    @Test("ErrorHandlingService suggests recovery actions")
    @MainActor func testRecoveryActions() {
        let service = ErrorHandlingService.shared
        
        let locationError = LocationError.permissionDenied
        let actions = service.suggestRecovery(for: locationError)
        
        #expect(actions.contains(.enableLocation))
        #expect(actions.contains(.checkSettings))
    }
    
    @Test("ErrorHandlingService registers callbacks")
    @MainActor func testErrorCallbacks() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        var callbackCalled = false
        var receivedError: (any HabitTrackerError)?
        
        service.registerErrorCallback { error in
            callbackCalled = true
            receivedError = error
        }
        
        let testError = LocationError.permissionDenied
        service.handle(testError)
        
        #expect(callbackCalled == true)
        #expect(receivedError?.category == .location)
    }
}

@Suite("Location Error Tests")
struct LocationErrorTests {
    
    @Test("LocationError has correct properties")
    func testLocationErrorProperties() {
        let error = LocationError.permissionDenied
        
        #expect(error.category == .location)
        #expect(error.severity == .high)
        #expect(error.shouldLog == true)
        #expect(error.userMessage.contains("location"))
        #expect(error.recoveryActions.contains(.enableLocation))
    }
    
    @Test("LocationError invalid coordinate includes coordinates")
    func testInvalidCoordinateError() {
        let error = LocationError.invalidCoordinate(latitude: 999.0, longitude: -999.0)
        
        #expect(error.technicalDetails.contains("999.0"))
        #expect(error.technicalDetails.contains("-999.0"))
        #expect(error.severity == .medium)
    }
    
    @Test("LocationError radius validation includes radius value")
    func testRadiusValidationError() {
        let error = LocationError.radiusValidationFailed(radius: 5000.0)
        
        #expect(error.technicalDetails.contains("5000.0"))
        #expect(error.userMessage.contains("radius"))
    }
    
    @Test("LocationError saved location limit includes limit")
    func testSavedLocationLimitError() {
        let error = LocationError.savedLocationLimitExceeded(limit: 10)
        
        #expect(error.userMessage.contains("10"))
        #expect(error.severity == .medium)
    }
}

@Suite("Routine Error Tests")
struct RoutineErrorTests {
    
    @Test("RoutineError has correct properties")
    func testRoutineErrorProperties() {
        let error = RoutineError.noActiveSession
        
        #expect(error.category == .routine)
        #expect(error.severity == .low)
        #expect(error.shouldLog == true)
        #expect(error.recoveryActions.contains(.retry))
    }
    
    @Test("RoutineError template not found includes ID")
    func testTemplateNotFoundError() {
        let templateId = UUID()
        let error = RoutineError.templateNotFound(id: templateId)
        
        #expect(error.technicalDetails.contains(templateId.uuidString))
        #expect(error.severity == .medium)
    }
    
    @Test("RoutineError habit execution failure includes context")
    func testHabitExecutionFailure() {
        let error = RoutineError.habitExecutionFailed(habitName: "Morning Stretch", reason: "Timer failed")
        
        #expect(error.userMessage.contains("Morning Stretch"))
        #expect(error.technicalDetails.contains("Timer failed"))
        #expect(error.recoveryActions.contains(.retry))
    }
    
    @Test("RoutineError invalid habit index includes bounds")
    func testInvalidHabitIndex() {
        let error = RoutineError.invalidHabitIndex(index: 5, total: 3)
        
        #expect(error.technicalDetails.contains("5"))
        #expect(error.technicalDetails.contains("3"))
        #expect(error.severity == .low)
    }
}

@Suite("Data Error Tests")
struct DataErrorTests {
    
    @Test("DataError has correct properties")
    func testDataErrorProperties() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let error = DataError.encodingFailed(type: "TestModel", underlyingError: underlyingError)
        
        #expect(error.category == .persistence)
        #expect(error.severity == .medium)
        #expect(error.shouldLog == true)
        #expect(error.technicalDetails.contains("TestModel"))
    }
    
    @Test("DataError key not found includes key")
    func testKeyNotFoundError() {
        let error = DataError.keyNotFound(key: "MissingKey")
        
        #expect(error.technicalDetails.contains("MissingKey"))
        #expect(error.severity == .low)
        #expect(error.recoveryActions.contains(.ignore))
    }
    
    @Test("DataError migration failure includes versions")
    func testMigrationFailureError() {
        let error = DataError.migrationFailed(fromVersion: "1.0", toVersion: "2.0")
        
        #expect(error.technicalDetails.contains("1.0"))
        #expect(error.technicalDetails.contains("2.0"))
        #expect(error.severity == .high)
        #expect(error.recoveryActions.contains(.contact))
    }
}

@Suite("Validation Error Tests")
struct ValidationErrorTests {
    
    @Test("ValidationError has correct properties")
    func testValidationErrorProperties() {
        let error = ValidationError.invalidHabitName(name: "")
        
        #expect(error.category == .validation)
        #expect(error.severity == .low)
        #expect(error.shouldLog == false)
        #expect(error.recoveryActions == [.retry])
    }
    
    @Test("ValidationError invalid duration messages")
    func testInvalidDurationError() {
        let error = ValidationError.invalidDuration(duration: -5.0)
        
        #expect(error.userMessage.contains("Duration"))
        #expect(error.technicalDetails.contains("-5.0"))
    }
    
    @Test("ValidationError duplicate habit name includes name")
    func testDuplicateHabitNameError() {
        let error = ValidationError.duplicateHabitName(name: "Coffee")
        
        #expect(error.userMessage.contains("Coffee"))
        #expect(error.technicalDetails.contains("Coffee"))
    }
    
    @Test("ValidationError insufficient conditional options includes count")
    func testInsufficientConditionalOptionsError() {
        let error = ValidationError.insufficientConditionalOptions(count: 1)
        
        #expect(error.userMessage.contains("2"))
        #expect(error.technicalDetails.contains("1"))
    }
}

@Suite("UI Error Tests")
struct UIErrorTests {
    
    @Test("UIError has correct properties")
    func testUIErrorProperties() {
        let error = UIError.viewRenderingFailed(viewName: "RoutineView")
        
        #expect(error.category == .ui)
        #expect(error.severity == .low)
        #expect(error.shouldLog == true)
        #expect(error.technicalDetails.contains("RoutineView"))
    }
    
    @Test("UIError navigation failure includes destination")
    func testNavigationFailureError() {
        let error = UIError.navigationFailed(destination: "SettingsView")
        
        #expect(error.userMessage.contains("Navigation"))
        #expect(error.technicalDetails.contains("SettingsView"))
        #expect(error.recoveryActions.contains(.retry))
    }
    
    @Test("UIError image loading failure includes image name")
    func testImageLoadingFailureError() {
        let error = UIError.imageLoadingFailed(imageName: "habit-icon")
        
        #expect(error.technicalDetails.contains("habit-icon"))
        #expect(error.recoveryActions.contains(.ignore))
    }
}

@Suite("Result Extension Tests")
struct ResultExtensionTests {
    
    @Test("Result handleResult processes success correctly")
    @MainActor func testResultSuccess() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        var successCalled = false
        let result: Result<String, LocationError> = .success("test")
        
        result.handleResult(
            onSuccess: { value in
                successCalled = true
                #expect(value == "test")
            }
        )
        
        #expect(successCalled == true)
        #expect(service.getErrorHistory().isEmpty)
    }
    
    @Test("Result handleResult processes failure correctly")
    @MainActor func testResultFailure() {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        var errorCalled = false
        let testError = LocationError.permissionDenied
        let result: Result<String, LocationError> = .failure(testError)
        
        result.handleResult(
            onError: { error in
                errorCalled = true
                #expect(error.category == .location)
            }
        )
        
        #expect(errorCalled == true)
        #expect(service.getErrorHistory().count == 1)
    }
}

@Suite("Async Error Handling Tests")
struct AsyncErrorHandlingTests {
    
    @Test("ErrorHandlingService safely executes successful operations")
    @MainActor func testSafelySuccess() async {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        let result = await service.safely {
            return "success"
        }
        
        switch result {
        case .success(let value):
            #expect(value == "success")
        case .failure:
            Issue.record("Expected success but got failure")
        }
        
        #expect(service.getErrorHistory().isEmpty)
    }
    
    @Test("ErrorHandlingService safely handles thrown errors")
    @MainActor func testSafelyFailure() async {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        let result = await service.safely {
            throw ValidationError.invalidHabitName(name: "")
        }
        
        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            #expect(error.category == .validation)
        }
        
        #expect(service.getErrorHistory().count == 1)
    }
    
    @Test("ErrorHandlingService retry mechanism works")
    @MainActor func testRetryMechanism() async {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        var attemptCount = 0
        
        let result = await service.withRetry(maxAttempts: 3, delay: 0.1) {
            attemptCount += 1
            if attemptCount < 3 {
                throw ValidationError.invalidHabitName(name: "")
            }
            return "success on attempt \(attemptCount)"
        }
        
        switch result {
        case .success(let value):
            #expect(value.contains("3"))
        case .failure:
            Issue.record("Expected success after retries")
        }
        
        #expect(attemptCount == 3)
    }
    
    @Test("ErrorHandlingService retry fails after max attempts")
    @MainActor func testRetryFailsAfterMaxAttempts() async {
        let service = ErrorHandlingService.shared
        service.clearHistory()
        
        var attemptCount = 0
        
        let result = await service.withRetry(maxAttempts: 2, delay: 0.1) {
            attemptCount += 1
            throw ValidationError.invalidHabitName(name: "")
        }
        
        switch result {
        case .success:
            Issue.record("Expected failure after max attempts")
        case .failure(let error):
            #expect(error.category == .validation)
        }
        
        #expect(attemptCount == 2)
    }
}