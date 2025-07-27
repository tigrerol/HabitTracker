import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("Logging Service Tests")
struct LoggingServiceTests {
    
    @Test("LoggingService initializes correctly")
    @MainActor func testLoggingServiceInitialization() {
        let service = LoggingService.shared
        
        #expect(service.getLogHistory().isEmpty)
        #expect(service.getCurrentLogLevel() == .info) // Release mode default
        
        let stats = service.getLogStatistics()
        #expect(stats.totalLogs == 0)
    }
    
    @Test("LoggingService logs at different levels")
    @MainActor func testLogLevels() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.trace("Test trace message")
        service.debug("Test debug message")
        service.info("Test info message")
        service.notice("Test notice message")
        service.warning("Test warning message")
        service.error("Test error message")
        service.fault("Test fault message")
        
        let history = service.getLogHistory()
        
        // Should only see logs at or above the current log level
        #expect(history.count >= 5) // info, notice, warning, error, fault
        
        // Check that we have different log levels
        let levels = Set(history.map { $0.level })
        #expect(levels.contains(.info))
        #expect(levels.contains(.notice))
        #expect(levels.contains(.warning))
        #expect(levels.contains(.error))
        #expect(levels.contains(.fault))
    }
    
    @Test("LoggingService respects log level filtering")
    @MainActor func testLogLevelFiltering() {
        let service = LoggingService.shared
        service.clearHistory()
        
        // Set to warning level
        service.setLogLevel(.warning)
        
        service.trace("Should not appear")
        service.debug("Should not appear")
        service.info("Should not appear")
        service.notice("Should not appear")
        service.warning("Should appear")
        service.error("Should appear")
        service.fault("Should appear")
        
        let history = service.getLogHistory()
        #expect(history.count == 3) // Only warning, error, fault
        
        let levels = Set(history.map { $0.level })
        #expect(levels == [.warning, .error, .fault])
    }
    
    @Test("LoggingService includes metadata in logs")
    @MainActor func testLogMetadata() {
        let service = LoggingService.shared
        service.clearHistory()
        
        let metadata = [
            "user_id": "12345",
            "session_id": "abc-def-ghi",
            "feature": "routine_execution"
        ]
        
        service.info("Test message with metadata", metadata: metadata)
        
        let history = service.getLogHistory()
        #expect(history.count == 1)
        
        let logEntry = history.first!
        #expect(logEntry.metadata["user_id"] == "12345")
        #expect(logEntry.metadata["session_id"] == "abc-def-ghi")
        #expect(logEntry.metadata["feature"] == "routine_execution")
    }
    
    @Test("LoggingService categorizes logs correctly")
    @MainActor func testLogCategories() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.info("App message", category: .app)
        service.info("UI message", category: .ui)
        service.info("Data message", category: .data)
        service.info("Location message", category: .location)
        service.info("Routine message", category: .routine)
        service.info("Error message", category: .error)
        service.info("Performance message", category: .performance)
        service.info("Network message", category: .network)
        service.info("User message", category: .user)
        service.info("Debug message", category: .debug)
        
        let appLogs = service.getLogs(for: .app)
        let uiLogs = service.getLogs(for: .ui)
        let dataLogs = service.getLogs(for: .data)
        
        #expect(appLogs.count == 1)
        #expect(uiLogs.count == 1)
        #expect(dataLogs.count == 1)
        
        let stats = service.getLogStatistics()
        #expect(stats.totalLogs == 10)
        #expect(stats.categoryBreakdown[.app] == 1)
        #expect(stats.categoryBreakdown[.ui] == 1)
    }
    
    @Test("LoggingService maintains log history limit")
    @MainActor func testLogHistoryLimit() {
        let service = LoggingService.shared
        service.clearHistory()
        
        // Add more logs than the history limit (500)
        for i in 0..<600 {
            service.info("Log message \(i)")
        }
        
        let history = service.getLogHistory()
        #expect(history.count == 500) // Should be capped at maxHistoryCount
        
        // Should have the most recent logs
        #expect(history.last?.message.contains("599") == true)
    }
    
    @Test("LoggingService filters logs by time range")
    @MainActor func testTimeRangeFiltering() {
        let service = LoggingService.shared
        service.clearHistory()
        
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        service.info("Old message")
        
        // Wait a tiny bit to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.001)
        
        service.info("Recent message")
        
        let recentLogs = service.getLogs(from: oneHourAgo, to: now)
        #expect(recentLogs.count == 2) // Both messages should be in this range
        
        let veryRecentLogs = service.getLogs(from: Date(), to: Date().addingTimeInterval(1))
        #expect(veryRecentLogs.count == 0) // No logs in the future
    }
    
    @Test("LoggingService filters logs by level")
    @MainActor func testLevelFiltering() {
        let service = LoggingService.shared
        service.clearHistory()
        service.setLogLevel(.trace) // Allow all levels
        
        service.info("Info message")
        service.warning("Warning message")
        service.error("Error message")
        
        let warningLogs = service.getLogs(with: .warning)
        let errorLogs = service.getLogs(with: .error)
        
        #expect(warningLogs.count == 1)
        #expect(errorLogs.count == 1)
        #expect(warningLogs.first?.message == "Warning message")
        #expect(errorLogs.first?.message == "Error message")
    }
    
    @Test("LoggingService provides accurate statistics")
    @MainActor func testLogStatistics() {
        let service = LoggingService.shared
        service.clearHistory()
        service.setLogLevel(.trace) // Allow all levels
        
        service.info("Message 1", category: .app)
        service.warning("Message 2", category: .app)
        service.error("Message 3", category: .routine)
        service.info("Message 4", category: .data)
        
        let stats = service.getLogStatistics()
        
        #expect(stats.totalLogs == 4)
        #expect(stats.categoryBreakdown[.app] == 2)
        #expect(stats.categoryBreakdown[.routine] == 1)
        #expect(stats.categoryBreakdown[.data] == 1)
        #expect(stats.levelBreakdown[.info] == 2)
        #expect(stats.levelBreakdown[.warning] == 1)
        #expect(stats.levelBreakdown[.error] == 1)
        #expect(stats.oldestLog != nil)
        #expect(stats.newestLog != nil)
    }
}

@Suite("Specialized Logging Tests")
struct SpecializedLoggingTests {
    
    @Test("LoggingService logs app lifecycle events")
    @MainActor func testAppLifecycleLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logAppLifecycle(.launched, metadata: ["version": "1.0.0"])
        service.logAppLifecycle(.backgrounded)
        service.logAppLifecycle(.foregrounded)
        
        let history = service.getLogHistory()
        #expect(history.count == 3)
        
        let launchedLog = history.first { $0.message.contains("launched") }
        #expect(launchedLog?.metadata["version"] == "1.0.0")
        
        let appLogs = service.getLogs(for: .app)
        #expect(appLogs.count == 3)
    }
    
    @Test("LoggingService logs user actions")
    @MainActor func testUserActionLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logUserAction("tap_button", screen: "routine_view", metadata: ["button": "start"])
        service.logUserAction("swipe_left", screen: "habit_list")
        
        let userLogs = service.getLogs(for: .user)
        #expect(userLogs.count == 2)
        
        let tapLog = userLogs.first { $0.message.contains("tap_button") }
        #expect(tapLog?.metadata["screen"] == "routine_view")
        #expect(tapLog?.metadata["button"] == "start")
    }
    
    @Test("LoggingService logs performance metrics")
    @MainActor func testPerformanceLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logPerformance("routine_load_time", value: 125.5, unit: "ms")
        service.logPerformance("memory_usage", value: 64.2, unit: "MB", metadata: ["context": "startup"])
        
        let performanceLogs = service.getLogs(for: .performance)
        #expect(performanceLogs.count == 2)
        
        let loadTimeLog = performanceLogs.first { $0.message.contains("routine_load_time") }
        #expect(loadTimeLog?.metadata["value"] == "125.5")
        #expect(loadTimeLog?.metadata["unit"] == "ms")
        
        let memoryLog = performanceLogs.first { $0.message.contains("memory_usage") }
        #expect(memoryLog?.metadata["context"] == "startup")
    }
    
    @Test("LoggingService logs routine events")
    @MainActor func testRoutineEventLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        let sessionId = UUID()
        let templateId = UUID()
        
        service.logRoutineEvent(.started, sessionId: sessionId, templateId: templateId)
        service.logRoutineEvent(.habitCompleted, sessionId: sessionId, templateId: nil, metadata: ["habit": "meditation"])
        service.logRoutineEvent(.completed, sessionId: sessionId, templateId: templateId)
        
        let routineLogs = service.getLogs(for: .routine)
        #expect(routineLogs.count == 3)
        
        let startedLog = routineLogs.first { $0.message.contains("started") }
        #expect(startedLog?.metadata["session_id"] == sessionId.uuidString)
        #expect(startedLog?.metadata["template_id"] == templateId.uuidString)
        
        let habitLog = routineLogs.first { $0.message.contains("habit_completed") }
        #expect(habitLog?.metadata["habit"] == "meditation")
    }
    
    @Test("LoggingService logs location events")
    @MainActor func testLocationEventLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logLocationEvent(.permissionRequested)
        service.logLocationEvent(.locationSaved, metadata: ["type": "home", "radius": "100"])
        service.logLocationEvent(.geofenceEntered, metadata: ["location": "office"])
        
        let locationLogs = service.getLogs(for: .location)
        #expect(locationLogs.count == 3)
        
        let savedLog = locationLogs.first { $0.message.contains("location_saved") }
        #expect(savedLog?.metadata["type"] == "home")
        #expect(savedLog?.metadata["radius"] == "100")
    }
    
    @Test("LoggingService logs data operations")
    @MainActor func testDataOperationLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logDataOperation(.save, key: "routine_templates", success: true)
        service.logDataOperation(.load, key: "user_preferences", success: false, metadata: ["error": "not_found"])
        
        let dataLogs = service.getLogs(for: .data)
        #expect(dataLogs.count == 2)
        
        let saveLog = dataLogs.first { $0.message.contains("save") }
        #expect(saveLog?.metadata["key"] == "routine_templates")
        #expect(saveLog?.metadata["success"] == "true")
        #expect(saveLog?.level == .info) // Success should be info level
        
        let loadLog = dataLogs.first { $0.message.contains("load") }
        #expect(loadLog?.metadata["success"] == "false")
        #expect(loadLog?.level == .warning) // Failure should be warning level
    }
}

@Suite("Performance Measurement Tests")
struct PerformanceMeasurementTests {
    
    @Test("LoggingService measures synchronous operation time")
    @MainActor func testSyncPerformanceMeasurement() {
        let service = LoggingService.shared
        service.clearHistory()
        
        let result = service.measureTime("test_operation") {
            // Simulate some work
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return "completed"
        }
        
        #expect(result == "completed")
        
        let performanceLogs = service.getLogs(for: .performance)
        #expect(performanceLogs.count == 1)
        
        let log = performanceLogs.first!
        #expect(log.message.contains("test_operation"))
        #expect(log.metadata["unit"] == "ms")
        
        // Should have measured some time (at least 5ms, allowing for variance)
        if let valueString = log.metadata["value"], let value = Double(valueString) {
            #expect(value >= 5.0)
        } else {
            Issue.record("Performance log should contain numeric value")
        }
    }
    
    @Test("LoggingService measures asynchronous operation time")
    @MainActor func testAsyncPerformanceMeasurement() async {
        let service = LoggingService.shared
        service.clearHistory()
        
        let result = await service.measureTimeAsync("async_test_operation") {
            // Simulate async work
            try? await Task.sleep(for: .milliseconds(10))
            return "async_completed"
        }
        
        #expect(result == "async_completed")
        
        let performanceLogs = service.getLogs(for: .performance)
        #expect(performanceLogs.count == 1)
        
        let log = performanceLogs.first!
        #expect(log.message.contains("async_test_operation"))
        #expect(log.metadata["unit"] == "ms")
    }
    
    @Test("LoggingService logs memory usage")
    @MainActor func testMemoryUsageLogging() {
        let service = LoggingService.shared
        service.clearHistory()
        
        service.logMemoryUsage(context: "test_context")
        
        let performanceLogs = service.getLogs(for: .performance)
        #expect(performanceLogs.count == 1)
        
        let log = performanceLogs.first!
        #expect(log.message.contains("Memory usage"))
        #expect(log.metadata["context"] == "test_context")
        #expect(log.metadata["used_mb"] != nil)
        #expect(log.metadata["available_mb"] != nil)
    }
}

@Suite("Global Convenience Function Tests")
struct GlobalConvenienceFunctionTests {
    
    @Test("Global log function works correctly")
    @MainActor func testGlobalLogFunction() {
        let service = LoggingService.shared
        service.clearHistory()
        
        log("Global test message", level: .info, category: .app, metadata: ["global": "true"])
        
        let history = service.getLogHistory()
        #expect(history.count == 1)
        
        let logEntry = history.first!
        #expect(logEntry.message == "Global test message")
        #expect(logEntry.level == .info)
        #expect(logEntry.category == .app)
        #expect(logEntry.metadata["global"] == "true")
    }
}

#if DEBUG
@Suite("Debug Testing Support Tests")
struct DebugTestingSupportTests {
    
    @Test("LoggingService debug helpers work correctly")
    @MainActor func testDebugHelpers() {
        let service = LoggingService.shared
        service.clearHistory()
        
        let initialCount = service.getLogCount()
        #expect(initialCount == 0)
        
        service.info("Test message for search")
        service.warning("Another message")
        
        #expect(service.getLogCount() == 2)
        
        let foundLogs = service.findLogs(containing: "search")
        #expect(foundLogs.count == 1)
        #expect(foundLogs.first?.message.contains("search") == true)
        
        let notFoundLogs = service.findLogs(containing: "missing")
        #expect(notFoundLogs.count == 0)
    }
    
    @Test("LoggingService test all log levels helper")
    @MainActor func testAllLogLevelsHelper() {
        let service = LoggingService.shared
        service.clearHistory()
        service.setLogLevel(.trace) // Allow all levels
        
        service.testAllLogLevels()
        
        let history = service.getLogHistory()
        #expect(history.count == 7) // All log levels
        
        let levels = Set(history.map { $0.level })
        #expect(levels.count == 7) // Should have all different levels
    }
}
#endif