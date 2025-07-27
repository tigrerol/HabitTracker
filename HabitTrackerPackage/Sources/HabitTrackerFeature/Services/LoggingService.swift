import Foundation
import os.log

// MARK: - Logging Configuration

/// Centralized logging service for structured application logging
@MainActor
public final class LoggingService: @unchecked Sendable {
    public static let shared = LoggingService()
    
    private let subsystem = "com.habittracker.app"
    private var loggers: [LogCategory: Logger] = [:]
    private var logLevel: LogLevel = .info
    private var logHistory: [LogEntry] = []
    private let maxHistoryCount = 500
    
    // MARK: - Log Categories
    
    /// Categories for organizing logs
    public enum LogCategory: String, CaseIterable, Sendable {
        case app = "app"
        case ui = "ui"
        case data = "data"
        case location = "location"
        case routine = "routine"
        case error = "error"
        case performance = "performance"
        case network = "network"
        case user = "user"
        case debug = "debug"
    }
    
    // MARK: - Log Levels
    
    /// Log severity levels
    public enum LogLevel: Int, CaseIterable, Sendable {
        case trace = 0
        case debug = 1
        case info = 2
        case notice = 3
        case warning = 4
        case error = 5
        case fault = 6
        
        public var description: String {
            switch self {
            case .trace: return "TRACE"
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .notice: return "NOTICE"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            case .fault: return "FAULT"
            }
        }
    }
    
    // MARK: - Log Entry
    
    /// Structured log entry
    public struct LogEntry: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp: Date
        public let level: LogLevel
        public let category: LogCategory
        public let message: String
        public let metadata: [String: String]
        public let file: String
        public let function: String
        public let line: Int
        
        public init(
            level: LogLevel,
            category: LogCategory,
            message: String,
            metadata: [String: String] = [:],
            file: String = #file,
            function: String = #function,
            line: Int = #line
        ) {
            self.timestamp = Date()
            self.level = level
            self.category = category
            self.message = message
            self.metadata = metadata
            self.file = URL(fileURLWithPath: file).lastPathComponent
            self.function = function
            self.line = line
        }
    }
    
    private init() {
        setupLoggers()
        configureLogLevel()
    }
    
    // MARK: - Setup
    
    private func setupLoggers() {
        for category in LogCategory.allCases {
            loggers[category] = Logger(subsystem: subsystem, category: category.rawValue)
        }
    }
    
    private func configureLogLevel() {
        #if DEBUG
        logLevel = .debug
        #else
        logLevel = .info
        #endif
    }
    
    // MARK: - Public Logging Interface
    
    /// Log a trace message (most verbose)
    public func trace(
        _ message: String,
        category: LogCategory = .debug,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .trace, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log a debug message
    public func debug(
        _ message: String,
        category: LogCategory = .debug,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log an info message
    public func info(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log a notice message
    public func notice(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .notice, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    public func warning(
        _ message: String,
        category: LogCategory = .app,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log an error message
    public func error(
        _ message: String,
        category: LogCategory = .error,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log a fault message (most severe)
    public func fault(
        _ message: String,
        category: LogCategory = .error,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .fault, category: category, message: message, metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Core Logging
    
    private func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String],
        file: String,
        function: String,
        line: Int
    ) {
        // Check if we should log this level
        guard level.rawValue >= logLevel.rawValue else { return }
        
        // Create log entry
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        // Add to history
        addToHistory(entry)
        
        // Log to system
        logToSystem(entry)
    }
    
    private func addToHistory(_ entry: LogEntry) {
        logHistory.append(entry)
        
        // Keep only recent entries
        if logHistory.count > maxHistoryCount {
            logHistory.removeFirst(logHistory.count - maxHistoryCount)
        }
    }
    
    private func logToSystem(_ entry: LogEntry) {
        guard let logger = loggers[entry.category] else { return }
        
        let metadataString = entry.metadata.isEmpty ? "" : " | " + entry.metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        let logMessage = "\(entry.message)\(metadataString)"
        
        switch entry.level {
        case .trace, .debug:
            logger.debug("\(logMessage)")
        case .info:
            logger.info("\(logMessage)")
        case .notice:
            logger.notice("\(logMessage)")
        case .warning:
            logger.warning("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .fault:
            logger.fault("\(logMessage)")
        }
    }
    
    // MARK: - Configuration
    
    /// Set the minimum log level
    public func setLogLevel(_ level: LogLevel) {
        logLevel = level
        info("Log level changed to \(level.description)", category: .app)
    }
    
    /// Get current log level
    public func getCurrentLogLevel() -> LogLevel {
        return logLevel
    }
    
    // MARK: - Log History and Analysis
    
    /// Get recent log history
    public func getLogHistory() -> [LogEntry] {
        return Array(logHistory.suffix(maxHistoryCount))
    }
    
    /// Get logs by category
    public func getLogs(for category: LogCategory) -> [LogEntry] {
        return logHistory.filter { $0.category == category }
    }
    
    /// Get logs by level
    public func getLogs(with level: LogLevel) -> [LogEntry] {
        return logHistory.filter { $0.level == level }
    }
    
    /// Get logs within time range
    public func getLogs(from startDate: Date, to endDate: Date) -> [LogEntry] {
        return logHistory.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    /// Clear log history
    public func clearHistory() {
        logHistory.removeAll()
        info("Log history cleared", category: .app)
    }
    
    // MARK: - Log Statistics
    
    /// Get logging statistics
    public func getLogStatistics() -> LogStatistics {
        let totalLogs = logHistory.count
        let categoryBuckets = Dictionary(grouping: logHistory, by: { $0.category })
            .mapValues { $0.count }
        let levelBuckets = Dictionary(grouping: logHistory, by: { $0.level })
            .mapValues { $0.count }
        
        return LogStatistics(
            totalLogs: totalLogs,
            categoryBreakdown: categoryBuckets,
            levelBreakdown: levelBuckets,
            oldestLog: logHistory.first?.timestamp,
            newestLog: logHistory.last?.timestamp
        )
    }
    
    public struct LogStatistics: Sendable {
        public let totalLogs: Int
        public let categoryBreakdown: [LogCategory: Int]
        public let levelBreakdown: [LogLevel: Int]
        public let oldestLog: Date?
        public let newestLog: Date?
    }
}

// MARK: - Specialized Logging Extensions

extension LoggingService {
    
    /// Log app lifecycle events
    public func logAppLifecycle(_ event: AppLifecycleEvent, metadata: [String: String] = [:]) {
        info("App lifecycle: \(event.rawValue)", category: .app, metadata: metadata)
    }
    
    public enum AppLifecycleEvent: String, Sendable {
        case launched = "launched"
        case backgrounded = "backgrounded"
        case foregrounded = "foregrounded"
        case terminated = "terminated"
        case memoryWarning = "memory_warning"
    }
    
    /// Log user interactions
    public func logUserAction(_ action: String, screen: String, metadata: [String: String] = [:]) {
        var combinedMetadata = metadata
        combinedMetadata["screen"] = screen
        info("User action: \(action)", category: .user, metadata: combinedMetadata)
    }
    
    /// Log performance metrics
    public func logPerformance(_ metric: String, value: Double, unit: String, metadata: [String: String] = [:]) {
        var combinedMetadata = metadata
        combinedMetadata["value"] = String(value)
        combinedMetadata["unit"] = unit
        info("Performance: \(metric)", category: .performance, metadata: combinedMetadata)
    }
    
    /// Log routine execution events
    public func logRoutineEvent(_ event: RoutineEvent, sessionId: UUID?, templateId: UUID?, metadata: [String: String] = [:]) {
        var combinedMetadata = metadata
        if let sessionId = sessionId {
            combinedMetadata["session_id"] = sessionId.uuidString
        }
        if let templateId = templateId {
            combinedMetadata["template_id"] = templateId.uuidString
        }
        info("Routine: \(event.rawValue)", category: .routine, metadata: combinedMetadata)
    }
    
    public enum RoutineEvent: String, Sendable {
        case started = "started"
        case completed = "completed"
        case paused = "paused"
        case resumed = "resumed"
        case habitCompleted = "habit_completed"
        case habitSkipped = "habit_skipped"
        case contextChanged = "context_changed"
    }
    
    /// Log location events
    public func logLocationEvent(_ event: LocationEvent, metadata: [String: String] = [:]) {
        info("Location: \(event.rawValue)", category: .location, metadata: metadata)
    }
    
    public enum LocationEvent: String, Sendable {
        case permissionRequested = "permission_requested"
        case permissionGranted = "permission_granted"
        case permissionDenied = "permission_denied"
        case locationUpdated = "location_updated"
        case locationSaved = "location_saved"
        case locationDetected = "location_detected"
        case geofenceEntered = "geofence_entered"
        case geofenceExited = "geofence_exited"
    }
    
    /// Log data operations
    public func logDataOperation(_ operation: DataOperation, key: String?, success: Bool, metadata: [String: String] = [:]) {
        var combinedMetadata = metadata
        if let key = key {
            combinedMetadata["key"] = key
        }
        combinedMetadata["success"] = String(success)
        
        let level: LogLevel = success ? .info : .warning
        log(level: level, category: .data, message: "Data: \(operation.rawValue)", metadata: combinedMetadata, file: #file, function: #function, line: #line)
    }
    
    public enum DataOperation: String, Sendable {
        case save = "save"
        case load = "load"
        case delete = "delete"
        case migrate = "migrate"
        case backup = "backup"
        case restore = "restore"
    }
}

// MARK: - Performance Measurement

extension LoggingService {
    
    /// Measure and log execution time
    public func measureTime<T>(
        _ operation: String,
        category: LogCategory = .performance,
        metadata: [String: String] = [:],
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        logPerformance(operation, value: timeElapsed * 1000, unit: "ms", metadata: metadata)
        return result
    }
    
    /// Measure async operation time
    public func measureTimeAsync<T: Sendable>(
        _ operation: String,
        category: LogCategory = .performance,
        metadata: [String: String] = [:],
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        logPerformance(operation, value: timeElapsed * 1000, unit: "ms", metadata: metadata)
        return result
    }
}

// MARK: - Memory and Resource Logging

extension LoggingService {
    
    /// Log current memory usage
    public func logMemoryUsage(context: String = "") {
        let memoryInfo = getMemoryInfo()
        var metadata: [String: String] = [
            "used_mb": String(format: "%.1f", memoryInfo.used / 1024 / 1024),
            "available_mb": String(format: "%.1f", memoryInfo.available / 1024 / 1024)
        ]
        
        if !context.isEmpty {
            metadata["context"] = context
        }
        
        info("Memory usage", category: .performance, metadata: metadata)
    }
    
    private func getMemoryInfo() -> (used: UInt64, available: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return (used: 0, available: 0)
        }
        
        return (used: info.resident_size, available: info.virtual_size)
    }
}

// MARK: - Global Convenience Functions

/// Global convenience function for quick logging
@MainActor
public func log(
    _ message: String,
    level: LoggingService.LogLevel = .info,
    category: LoggingService.LogCategory = .app,
    metadata: [String: String] = [:],
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    switch level {
    case .trace:
        LoggingService.shared.trace(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .debug:
        LoggingService.shared.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .info:
        LoggingService.shared.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .notice:
        LoggingService.shared.notice(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .warning:
        LoggingService.shared.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .error:
        LoggingService.shared.error(message, category: category, metadata: metadata, file: file, function: function, line: line)
    case .fault:
        LoggingService.shared.fault(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

// MARK: - Testing Support

#if DEBUG
extension LoggingService {
    /// Test helper to get log count
    public func getLogCount() -> Int {
        return logHistory.count
    }
    
    /// Test helper to find logs containing text
    public func findLogs(containing text: String) -> [LogEntry] {
        return logHistory.filter { $0.message.contains(text) }
    }
    
    /// Test helper to simulate different log levels
    public func testAllLogLevels() {
        trace("Test trace message")
        debug("Test debug message")
        info("Test info message")
        notice("Test notice message")
        warning("Test warning message")
        error("Test error message")
        fault("Test fault message")
    }
}
#endif