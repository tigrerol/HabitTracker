import Foundation
import CoreLocation

// MARK: - Core Error Protocol

/// Base protocol for all app-specific errors with enhanced context
public protocol HabitTrackerError: LocalizedError, CustomStringConvertible {
    /// Error category for analytics and logging
    var category: ErrorCategory { get }
    
    /// User-friendly error message suitable for UI display
    var userMessage: String { get }
    
    /// Technical details for debugging (not shown to users)
    var technicalDetails: String { get }
    
    /// Suggested recovery actions for users
    var recoveryActions: [RecoveryAction] { get }
    
    /// Whether this error should be logged automatically
    var shouldLog: Bool { get }
    
    /// Error severity level
    var severity: ErrorSeverity { get }
}

// MARK: - Error Classification

/// Categories for organizing errors
public enum ErrorCategory: String, CaseIterable, Sendable {
    case location = "location"
    case network = "network"
    case data = "data"
    case validation = "validation"
    case configuration = "configuration"
    case synchronization = "synchronization"
    case technical = "technical"
}

/// Error severity levels
public enum ErrorSeverity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Recovery actions users can take
public enum RecoveryAction: String, CaseIterable, Sendable {
    case retry = "retry"
    case checkSettings = "check_settings"
    case enableLocation = "enable_location"
    case checkInternet = "check_internet"
    case restart = "restart"
    case contact = "contact"
    case ignore = "ignore"
}

// MARK: - Location Errors

/// Comprehensive location service errors
public enum LocationError: HabitTrackerError, Equatable {
    case permissionDenied
    case permissionRestricted
    case locationUnavailable
    case locationAccuracyReduced
    case timeout
    case invalidCoordinate(latitude: Double, longitude: Double)
    case distanceCalculationFailed
    case radiusValidationFailed(radius: CLLocationDistance)
    case savedLocationLimitExceeded(limit: Int)
    case locationServiceDisabled
    
    public var category: ErrorCategory { .location }
    public var shouldLog: Bool { true }
    
    public var severity: ErrorSeverity {
        switch self {
        case .permissionDenied, .locationServiceDisabled:
            return .high
        case .permissionRestricted, .locationUnavailable:
            return .medium
        case .timeout, .locationAccuracyReduced:
            return .low
        case .invalidCoordinate, .distanceCalculationFailed, .radiusValidationFailed, .savedLocationLimitExceeded:
            return .medium
        }
    }
    
    public var userMessage: String {
        switch self {
        case .permissionDenied:
            return "Location access is required for context-aware routines. Please enable location permissions in Settings."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Unable to determine your current location. Please try again."
        case .locationAccuracyReduced:
            return "Location accuracy is reduced. Some features may not work optimally."
        case .timeout:
            return "Location request timed out. Please try again."
        case .invalidCoordinate:
            return "Invalid location coordinates provided."
        case .distanceCalculationFailed:
            return "Unable to calculate distance between locations."
        case .radiusValidationFailed:
            return "Invalid radius value for location detection."
        case .savedLocationLimitExceeded(let limit):
            return "You can save up to \(limit) locations. Please remove some before adding new ones."
        case .locationServiceDisabled:
            return "Location services are disabled. Please enable them in System Settings."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .permissionDenied:
            return "CLLocationManager authorization status: denied"
        case .permissionRestricted:
            return "CLLocationManager authorization status: restricted"
        case .locationUnavailable:
            return "CLLocationManager failed to obtain location"
        case .locationAccuracyReduced:
            return "CLLocationManager accuracy reduced"
        case .timeout:
            return "Location request exceeded timeout limit"
        case .invalidCoordinate(let lat, let lng):
            return "Invalid coordinates: lat=\(lat), lng=\(lng)"
        case .distanceCalculationFailed:
            return "CLLocation distance calculation failed"
        case .radiusValidationFailed(let radius):
            return "Invalid radius: \(radius) meters"
        case .savedLocationLimitExceeded(let limit):
            return "Exceeded saved location limit: \(limit)"
        case .locationServiceDisabled:
            return "CLLocationManager.locationServicesEnabled() == false"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .permissionDenied, .locationServiceDisabled:
            return [.enableLocation, .checkSettings]
        case .permissionRestricted:
            return [.contact]
        case .locationUnavailable, .timeout:
            return [.retry, .checkSettings]
        case .locationAccuracyReduced:
            return [.checkSettings, .ignore]
        case .invalidCoordinate, .distanceCalculationFailed, .radiusValidationFailed:
            return [.retry, .contact]
        case .savedLocationLimitExceeded:
            return [.checkSettings]
        }
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}

// MARK: - Routine Errors

/// Routine execution and management errors
public enum RoutineError: HabitTrackerError, Equatable {
    case noActiveSession
    case sessionAlreadyActive
    case templateNotFound(id: UUID)
    case habitNotFound(id: UUID)
    case invalidHabitIndex(index: Int, total: Int)
    case sessionCompletionFailed
    case contextEvaluationFailed
    case templateValidationFailed(reason: String)
    case habitExecutionFailed(habitName: String, reason: String)
    case conditionalOptionSelectionFailed
    case routineQueueCorrupted
    
    public var category: ErrorCategory { .technical }
    public var shouldLog: Bool { true }
    
    public var severity: ErrorSeverity {
        switch self {
        case .routineQueueCorrupted, .sessionCompletionFailed:
            return .high
        case .templateNotFound, .habitNotFound, .templateValidationFailed:
            return .medium
        case .noActiveSession, .sessionAlreadyActive, .invalidHabitIndex, .contextEvaluationFailed, .habitExecutionFailed, .conditionalOptionSelectionFailed:
            return .low
        }
    }
    
    public var userMessage: String {
        switch self {
        case .noActiveSession:
            return "No routine is currently active. Please start a routine first."
        case .sessionAlreadyActive:
            return "A routine is already in progress. Please complete or cancel it first."
        case .templateNotFound:
            return "The selected routine template could not be found."
        case .habitNotFound:
            return "The habit could not be found in the current routine."
        case .invalidHabitIndex:
            return "Invalid habit position in routine."
        case .sessionCompletionFailed:
            return "Failed to complete the routine session. Your progress has been saved."
        case .contextEvaluationFailed:
            return "Unable to determine the best routine for your current context."
        case .templateValidationFailed:
            return "The routine template contains invalid data."
        case .habitExecutionFailed(let habitName, _):
            return "Failed to execute habit: \(habitName)"
        case .conditionalOptionSelectionFailed:
            return "Failed to process your conditional habit selection."
        case .routineQueueCorrupted:
            return "Routine data is corrupted. Please restart the app."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .noActiveSession:
            return "RoutineService.currentSession is nil"
        case .sessionAlreadyActive:
            return "RoutineService.currentSession is not nil"
        case .templateNotFound(let id):
            return "Template ID not found: \(id)"
        case .habitNotFound(let id):
            return "Habit ID not found: \(id)"
        case .invalidHabitIndex(let index, let total):
            return "Index \(index) out of bounds for \(total) habits"
        case .sessionCompletionFailed:
            return "RoutineSession completion failed"
        case .contextEvaluationFailed:
            return "SmartRoutineSelector.selectBestTemplate failed"
        case .templateValidationFailed(let reason):
            return "Template validation failed: \(reason)"
        case .habitExecutionFailed(let habitName, let reason):
            return "Habit '\(habitName)' execution failed: \(reason)"
        case .conditionalOptionSelectionFailed:
            return "ConditionalHabitHandler.handleOptionSelection failed"
        case .routineQueueCorrupted:
            return "RoutineSession.activeHabits queue is corrupted"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .noActiveSession:
            return [.retry]
        case .sessionAlreadyActive:
            return [.checkSettings]
        case .templateNotFound, .habitNotFound:
            return [.restart, .contact]
        case .invalidHabitIndex, .routineQueueCorrupted:
            return [.restart]
        case .sessionCompletionFailed, .habitExecutionFailed:
            return [.retry, .restart]
        case .contextEvaluationFailed:
            return [.checkSettings, .retry]
        case .templateValidationFailed, .conditionalOptionSelectionFailed:
            return [.contact]
        }
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}

// MARK: - Data Persistence Errors

/// Enhanced persistence errors with more context
public enum DataError: HabitTrackerError, Equatable {
    public static func == (lhs: DataError, rhs: DataError) -> Bool {
        switch (lhs, rhs) {
        case (.encodingFailed(let lType, _), .encodingFailed(let rType, _)):
            return lType == rType
        case (.decodingFailed(let lType, _), .decodingFailed(let rType, _)):
            return lType == rType
        case (.keyNotFound(let lKey), .keyNotFound(let rKey)):
            return lKey == rKey
        case (.corruptedData(let lKey), .corruptedData(let rKey)):
            return lKey == rKey
        case (.storageFull, .storageFull):
            return true
        case (.permissionDenied, .permissionDenied):
            return true
        case (.migrationFailed(let lFrom, let lTo), .migrationFailed(let rFrom, let rTo)):
            return lFrom == rFrom && lTo == rTo
        case (.dataValidationFailed(let lReason), .dataValidationFailed(let rReason)):
            return lReason == rReason
        case (.swiftDataContextFailed, .swiftDataContextFailed):
            return true
        case (.modelConflict(let lModel), .modelConflict(let rModel)):
            return lModel == rModel
        default:
            return false
        }
    }
    case encodingFailed(type: String, underlyingError: Error)
    case decodingFailed(type: String, underlyingError: Error)
    case keyNotFound(key: String)
    case corruptedData(key: String)
    case storageFull
    case permissionDenied
    case migrationFailed(fromVersion: String, toVersion: String)
    case dataValidationFailed(reason: String)
    case swiftDataContextFailed
    case modelConflict(modelName: String)
    
    public var category: ErrorCategory { .data }
    public var shouldLog: Bool { true }
    
    public var severity: ErrorSeverity {
        switch self {
        case .storageFull, .migrationFailed, .swiftDataContextFailed:
            return .high
        case .corruptedData, .modelConflict:
            return .medium
        case .encodingFailed, .decodingFailed, .dataValidationFailed:
            return .medium
        case .keyNotFound, .permissionDenied:
            return .low
        }
    }
    
    public var userMessage: String {
        switch self {
        case .encodingFailed, .decodingFailed:
            return "Failed to save your data. Please try again."
        case .keyNotFound:
            return "The requested data was not found."
        case .corruptedData:
            return "Some data appears to be corrupted. Your settings may need to be reset."
        case .storageFull:
            return "Device storage is full. Please free up space and try again."
        case .permissionDenied:
            return "Permission denied to access stored data."
        case .migrationFailed:
            return "Failed to update your data format. Please contact support."
        case .dataValidationFailed:
            return "The data format is invalid and cannot be processed."
        case .swiftDataContextFailed:
            return "Database connection failed. Please restart the app."
        case .modelConflict:
            return "Data model conflict detected. Please restart the app."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .encodingFailed(let type, let error):
            return "JSON encoding failed for \(type): \(error)"
        case .decodingFailed(let type, let error):
            return "JSON decoding failed for \(type): \(error)"
        case .keyNotFound(let key):
            return "UserDefaults key not found: \(key)"
        case .corruptedData(let key):
            return "Corrupted data for key: \(key)"
        case .storageFull:
            return "NSFileManager reports insufficient storage"
        case .permissionDenied:
            return "File system permission denied"
        case .migrationFailed(let from, let to):
            return "Data migration failed: \(from) -> \(to)"
        case .dataValidationFailed(let reason):
            return "Data validation failed: \(reason)"
        case .swiftDataContextFailed:
            return "SwiftData ModelContext failed to initialize"
        case .modelConflict(let modelName):
            return "SwiftData model conflict: \(modelName)"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .encodingFailed, .decodingFailed:
            return [.retry, .restart]
        case .keyNotFound:
            return [.ignore]
        case .corruptedData, .dataValidationFailed:
            return [.restart, .contact]
        case .storageFull:
            return [.checkSettings]
        case .permissionDenied:
            return [.checkSettings, .restart]
        case .migrationFailed, .swiftDataContextFailed, .modelConflict:
            return [.restart, .contact]
        }
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}

// MARK: - Validation Errors

/// Input validation errors
public enum ValidationError: HabitTrackerError, Equatable {
    case invalidHabitName(name: String)
    case invalidDuration(duration: TimeInterval)
    case invalidColor(color: String)
    case invalidOrder(order: Int)
    case emptyTemplateHabits
    case invalidLocationRadius(radius: CLLocationDistance)
    case invalidLocationName(name: String)
    case duplicateHabitName(name: String)
    case invalidConditionalQuestion(question: String)
    case insufficientConditionalOptions(count: Int)
    case invalidOptionText(text: String)
    
    public var category: ErrorCategory { .validation }
    public var shouldLog: Bool { false }
    public var severity: ErrorSeverity { .low }
    
    public var userMessage: String {
        switch self {
        case .invalidHabitName:
            return "Habit name must be between 1 and 50 characters."
        case .invalidDuration:
            return "Duration must be between 1 second and 4 hours."
        case .invalidColor:
            return "Please select a valid color."
        case .invalidOrder:
            return "Habit order must be a positive number."
        case .emptyTemplateHabits:
            return "Routine template must contain at least one habit."
        case .invalidLocationRadius:
            return "Location radius must be between 10 and 1000 meters."
        case .invalidLocationName:
            return "Location name must be between 1 and 30 characters."
        case .duplicateHabitName:
            return "A habit with this name already exists in the routine."
        case .invalidConditionalQuestion:
            return "Question must be between 5 and 100 characters."
        case .insufficientConditionalOptions:
            return "Conditional habits must have at least 2 options."
        case .invalidOptionText:
            return "Option text must be between 1 and 30 characters."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .invalidHabitName(let name):
            return "Invalid habit name: '\(name)'"
        case .invalidDuration(let duration):
            return "Invalid duration: \(duration) seconds"
        case .invalidColor(let color):
            return "Invalid color format: '\(color)'"
        case .invalidOrder(let order):
            return "Invalid order: \(order)"
        case .emptyTemplateHabits:
            return "Template.habits.isEmpty == true"
        case .invalidLocationRadius(let radius):
            return "Invalid radius: \(radius) meters"
        case .invalidLocationName(let name):
            return "Invalid location name: '\(name)'"
        case .duplicateHabitName(let name):
            return "Duplicate habit name: '\(name)'"
        case .invalidConditionalQuestion(let question):
            return "Invalid question: '\(question)'"
        case .insufficientConditionalOptions(let count):
            return "Insufficient options: \(count)"
        case .invalidOptionText(let text):
            return "Invalid option text: '\(text)'"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        [.retry]
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}

// MARK: - Network Errors

/// Network connectivity and communication errors
public enum NetworkError: HabitTrackerError, Equatable {
    case connectionFailed
    case timeout
    case noInternetConnection
    case serverError(statusCode: Int)
    case invalidResponse
    case rateLimitExceeded
    case authenticationFailed
    case certificateError
    
    public var category: ErrorCategory { .network }
    public var shouldLog: Bool { true }
    
    public var severity: ErrorSeverity {
        switch self {
        case .noInternetConnection, .connectionFailed:
            return .high
        case .serverError, .authenticationFailed:
            return .medium
        case .timeout, .invalidResponse, .rateLimitExceeded, .certificateError:
            return .low
        }
    }
    
    public var userMessage: String {
        switch self {
        case .connectionFailed:
            return "Unable to connect to the server. Please check your internet connection."
        case .timeout:
            return "The connection timed out. Please try again."
        case .noInternetConnection:
            return "No internet connection available. Please check your network settings."
        case .serverError(let statusCode):
            return "Server error (\(statusCode)). Please try again later."
        case .invalidResponse:
            return "Received invalid response from server."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .certificateError:
            return "Security certificate error. Please check your connection."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .connectionFailed:
            return "Network connection failed"
        case .timeout:
            return "URLSession timeout exceeded"
        case .noInternetConnection:
            return "Network reachability status: not reachable"
        case .serverError(let statusCode):
            return "HTTP status code: \(statusCode)"
        case .invalidResponse:
            return "Response validation failed"
        case .rateLimitExceeded:
            return "Rate limit headers indicate limit exceeded"
        case .authenticationFailed:
            return "Authentication token invalid or expired"
        case .certificateError:
            return "SSL/TLS certificate validation failed"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .connectionFailed, .noInternetConnection:
            return [.checkInternet, .retry]
        case .timeout:
            return [.retry, .checkInternet]
        case .serverError:
            return [.retry, .contact]
        case .invalidResponse, .certificateError:
            return [.contact]
        case .rateLimitExceeded:
            return [.retry]
        case .authenticationFailed:
            return [.checkSettings, .contact]
        }
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}

// MARK: - UI Errors

/// User interface related errors
public enum UIError: HabitTrackerError, Equatable {
    case viewRenderingFailed(viewName: String)
    case navigationFailed(destination: String)
    case animationFailed(animation: String)
    case accessibilityConfigurationFailed
    case imageLoadingFailed(imageName: String)
    case fontLoadingFailed(fontName: String)
    
    public var category: ErrorCategory { .technical }
    public var shouldLog: Bool { true }
    public var severity: ErrorSeverity { .low }
    
    public var userMessage: String {
        switch self {
        case .viewRenderingFailed:
            return "Unable to display this screen. Please try again."
        case .navigationFailed:
            return "Navigation failed. Please try again."
        case .animationFailed:
            return "Animation failed to complete."
        case .accessibilityConfigurationFailed:
            return "Accessibility features may not work properly."
        case .imageLoadingFailed:
            return "Some images failed to load."
        case .fontLoadingFailed:
            return "Custom fonts failed to load."
        }
    }
    
    public var technicalDetails: String {
        switch self {
        case .viewRenderingFailed(let viewName):
            return "View rendering failed: \(viewName)"
        case .navigationFailed(let destination):
            return "Navigation failed to: \(destination)"
        case .animationFailed(let animation):
            return "Animation failed: \(animation)"
        case .accessibilityConfigurationFailed:
            return "AccessibilityConfiguration setup failed"
        case .imageLoadingFailed(let imageName):
            return "Image loading failed: \(imageName)"
        case .fontLoadingFailed(let fontName):
            return "Font loading failed: \(fontName)"
        }
    }
    
    public var recoveryActions: [RecoveryAction] {
        switch self {
        case .viewRenderingFailed, .navigationFailed:
            return [.retry, .restart]
        case .animationFailed, .accessibilityConfigurationFailed, .imageLoadingFailed, .fontLoadingFailed:
            return [.ignore, .restart]
        }
    }
    
    public var errorDescription: String? { userMessage }
    public var description: String { technicalDetails }
}