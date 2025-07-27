import Foundation
import os.log

// MARK: - Error Handling Service

/// Centralized error handling and reporting service
@MainActor
public final class ErrorHandlingService: @unchecked Sendable {
    public static let shared = ErrorHandlingService()
    
    private let logger: Logger
    private var errorCallbacks: [(HabitTrackerError) -> Void] = []
    private var errorHistory: [ErrorRecord] = []
    private let maxHistoryCount = 100
    
    private init() {
        self.logger = Logger(subsystem: "com.habittracker.errorhandling", category: "errors")
    }
    
    // MARK: - Error Recording
    
    /// Record representing an error occurrence
    public struct ErrorRecord: Identifiable, Sendable {
        public let id = UUID()
        public let error: any HabitTrackerError
        public let timestamp: Date
        public let context: [String: String]
        public let wasHandled: Bool
        
        public init(error: any HabitTrackerError, context: [String: String] = [:], wasHandled: Bool = false) {
            self.error = error
            self.timestamp = Date()
            self.context = context
            self.wasHandled = wasHandled
        }
    }
    
    // MARK: - Public Interface
    
    /// Handle an error with optional context
    public func handle(_ error: any HabitTrackerError, context: [String: String] = [:]) {
        let record = ErrorRecord(error: error, context: context, wasHandled: true)
        recordError(record)
        
        if error.shouldLog {
            logError(error, context: context)
        }
        
        // Notify registered callbacks
        errorCallbacks.forEach { callback in
            callback(error)
        }
    }
    
    /// Report an error without handling (for fire-and-forget scenarios)
    public func report(_ error: any HabitTrackerError, context: [String: String] = [:]) {
        let record = ErrorRecord(error: error, context: context, wasHandled: false)
        recordError(record)
        
        if error.shouldLog {
            logError(error, context: context)
        }
    }
    
    /// Register a callback for error notifications
    public func registerErrorCallback(_ callback: @escaping (HabitTrackerError) -> Void) {
        errorCallbacks.append(callback)
    }
    
    /// Get recent error history
    public func getErrorHistory() -> [ErrorRecord] {
        return Array(errorHistory.prefix(maxHistoryCount))
    }
    
    /// Get errors by category
    public func getErrors(for category: ErrorCategory) -> [ErrorRecord] {
        return errorHistory.filter { $0.error.category == category }
    }
    
    /// Get errors by severity
    public func getErrors(with severity: ErrorSeverity) -> [ErrorRecord] {
        return errorHistory.filter { $0.error.severity == severity }
    }
    
    /// Clear error history (useful for testing)
    public func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Error Statistics
    
    /// Get error statistics for analytics
    public func getErrorStatistics() -> ErrorStatistics {
        let totalErrors = errorHistory.count
        let categoryCounts = Dictionary(grouping: errorHistory, by: { $0.error.category })
            .mapValues { $0.count }
        let severityCounts = Dictionary(grouping: errorHistory, by: { $0.error.severity })
            .mapValues { $0.count }
        
        return ErrorStatistics(
            totalErrors: totalErrors,
            categoryCounts: categoryCounts,
            severityCounts: severityCounts,
            mostRecentError: errorHistory.last?.timestamp
        )
    }
    
    public struct ErrorStatistics: Sendable {
        public let totalErrors: Int
        public let categoryCounts: [ErrorCategory: Int]
        public let severityCounts: [ErrorSeverity: Int]
        public let mostRecentError: Date?
    }
    
    // MARK: - Error Recovery
    
    /// Suggest recovery actions for an error
    public func suggestRecovery(for error: any HabitTrackerError) -> [RecoveryAction] {
        return error.recoveryActions
    }
    
    /// Execute a recovery action
    public func executeRecovery(_ action: RecoveryAction, for error: any HabitTrackerError) {
        logRecoveryAttempt(action, for: error)
        
        switch action {
        case .retry:
            // Implementation would depend on the specific context
            LoggingService.shared.info("Recovery action executed: Retry", category: .error)
        case .checkSettings:
            LoggingService.shared.info("Recovery action executed: Check settings", category: .error)
        case .enableLocation:
            LoggingService.shared.info("Recovery action executed: Enable location", category: .error)
        case .checkInternet:
            LoggingService.shared.info("Recovery action executed: Check internet", category: .error)
        case .restart:
            LoggingService.shared.info("Recovery action executed: Restart", category: .error)
        case .contact:
            LoggingService.shared.info("Recovery action executed: Contact support", category: .error)
        case .ignore:
            LoggingService.shared.info("Recovery action executed: Ignore error", category: .error)
        }
    }
    
    // MARK: - Private Methods
    
    private func recordError(_ record: ErrorRecord) {
        errorHistory.append(record)
        
        // Keep only recent errors
        if errorHistory.count > maxHistoryCount {
            errorHistory.removeFirst(errorHistory.count - maxHistoryCount)
        }
    }
    
    private func logError(_ error: any HabitTrackerError, context: [String: String]) {
        var metadata = context
        metadata["error_category"] = error.category.rawValue
        metadata["error_severity"] = error.severity.rawValue
        metadata["user_message"] = error.userMessage
        
        let logCategory: LoggingService.LogCategory = .error
        
        switch error.severity {
        case .low:
            LoggingService.shared.info(error.technicalDetails, category: logCategory, metadata: metadata)
        case .medium:
            LoggingService.shared.notice(error.technicalDetails, category: logCategory, metadata: metadata)
        case .high:
            LoggingService.shared.error(error.technicalDetails, category: logCategory, metadata: metadata)
        case .critical:
            LoggingService.shared.fault(error.technicalDetails, category: logCategory, metadata: metadata)
        }
    }
    
    private func logRecoveryAttempt(_ action: RecoveryAction, for error: any HabitTrackerError) {
        LoggingService.shared.info(
            "Recovery attempt: \(action.rawValue)",
            category: .error,
            metadata: [
                "recovery_action": action.rawValue,
                "error_category": error.category.rawValue,
                "error_severity": error.severity.rawValue
            ]
        )
    }
}

// MARK: - Error Handling Extensions

extension ErrorHandlingService {
    /// Handle location-specific errors with enhanced context
    public func handleLocationError(_ error: LocationError, currentLocation: String? = nil) {
        var context: [String: String] = [:]
        if let location = currentLocation {
            context["current_location"] = location
        }
        handle(error, context: context)
    }
    
    /// Handle routine-specific errors with session context
    public func handleRoutineError(_ error: RoutineError, sessionId: UUID? = nil, templateId: UUID? = nil) {
        var context: [String: String] = [:]
        if let sessionId = sessionId {
            context["session_id"] = sessionId.uuidString
        }
        if let templateId = templateId {
            context["template_id"] = templateId.uuidString
        }
        handle(error, context: context)
    }
    
    /// Handle data errors with key context
    public func handleDataError(_ error: DataError, key: String? = nil, operation: String? = nil) {
        var context: [String: String] = [:]
        if let key = key {
            context["key"] = key
        }
        if let operation = operation {
            context["operation"] = operation
        }
        handle(error, context: context)
    }
}

// MARK: - Result Extensions for Error Handling

extension Result where Failure: HabitTrackerError {
    /// Handle the result, automatically managing errors through ErrorHandlingService
    @MainActor
    public func handleResult(
        onSuccess: (Success) -> Void = { _ in },
        onError: ((Failure) -> Void)? = nil,
        context: [String: String] = [:]
    ) {
        switch self {
        case .success(let value):
            onSuccess(value)
        case .failure(let error):
            ErrorHandlingService.shared.handle(error, context: context)
            onError?(error)
        }
    }
}

// MARK: - Async Error Handling

extension ErrorHandlingService {
    /// Safely execute an async operation with error handling
    public func safely<T: Sendable>(
        operation: @Sendable () async throws -> T,
        context: [String: String] = [:]
    ) async -> Result<T, DataError> {
        do {
            let result = try await operation()
            return .success(result)
        } catch let error as DataError {
            handle(error, context: context)
            return .failure(error)
        } catch let error as any HabitTrackerError {
            handle(error, context: context)
            // Convert to DataError for return type consistency
            let dataError = DataError.dataValidationFailed(reason: error.technicalDetails)
            return .failure(dataError)
        } catch {
            let wrappedError = DataError.dataValidationFailed(reason: error.localizedDescription)
            handle(wrappedError, context: context)
            return .failure(wrappedError)
        }
    }
    
    /// Execute an operation with automatic retry on failure
    public func withRetry<T: Sendable>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @Sendable () async throws -> T,
        context: [String: String] = [:]
    ) async -> Result<T, DataError> {
        var lastError: DataError = DataError.dataValidationFailed(reason: "Unknown error")
        
        for attempt in 1...maxAttempts {
            let result = await safely(operation: operation, context: context)
            
            switch result {
            case .success(let value):
                if attempt > 1 {
                    LoggingService.shared.info(
                        "Operation succeeded after retry",
                        category: .error,
                        metadata: ["attempt": String(attempt)]
                    )
                }
                return .success(value)
            case .failure(let error):
                lastError = error
                if attempt < maxAttempts {
                    LoggingService.shared.info(
                        "Operation failed, retrying",
                        category: .error,
                        metadata: [
                            "attempt": String(attempt),
                            "delay": String(delay),
                            "max_attempts": String(maxAttempts)
                        ]
                    )
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
        }
        
        LoggingService.shared.error(
            "Operation failed after all retry attempts",
            category: .error,
            metadata: ["max_attempts": String(maxAttempts)]
        )
        return .failure(lastError)
    }
}

// MARK: - Testing Support

#if DEBUG
extension ErrorHandlingService {
    /// Test helper to simulate errors
    public func simulateError(_ error: any HabitTrackerError) {
        handle(error, context: ["simulated": "true"])
    }
    
    /// Test helper to get callback count
    public func getCallbackCount() -> Int {
        return errorCallbacks.count
    }
}
#endif