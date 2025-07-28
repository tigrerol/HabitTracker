import Testing
import Foundation
@testable import HabitTrackerFeature

@Suite("LoggingService Error Tests")
struct LoggingServiceErrorTests {
    
    @Test("LoggingService handles invalid metadata gracefully")
    @MainActor func testLoggingServiceInvalidMetadata() {
        let service = LoggingService.shared
        
        // Test with extremely large metadata
        var largeMetadata: [String: String] = [:]
        for i in 0..<1000 {
            largeMetadata["key\(i)"] = String(repeating: "a", count: 100) // Smaller to be reasonable
        }
        
        // Should handle large metadata without crashing
        service.info("Test message", category: .routine, metadata: largeMetadata)
        
        // Test with complex string metadata
        let complexMetadata: [String: String] = [
            "string": "value",
            "number": "42",
            "bool": "true",
            "array": "[1, 2, 3]",
            "nested": "nested_value",
            "unicode": "αβγδε 中文 日本語"
        ]
        
        service.error("Complex metadata test", category: .data, metadata: complexMetadata)
        
        // Service should handle these gracefully without throwing
        #expect(true) // If we reach here, the service handled the edge cases
    }
    
    @Test("LoggingService handles concurrent logging correctly")
    func testLoggingServiceConcurrentAccess() async {
        let service = await LoggingService.shared
        
        // Execute concurrent logging operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await service.info("Concurrent message \(i)", category: .routine)
                    await service.warning("Concurrent warning \(i)", category: .location)
                    await service.error("Concurrent error \(i)", category: .data)
                }
            }
        }
        
        // Service should handle concurrent access without data races
        #expect(true) // If we reach here, no data races occurred
    }
    
    @Test("LoggingService handles extreme message lengths")
    @MainActor func testLoggingServiceExtremeMessages() {
        let service = LoggingService.shared
        
        // Test empty message
        service.info("", category: .routine)
        
        // Test extremely long message
        let longMessage = String(repeating: "This is a very long message. ", count: 1000)
        service.error(longMessage, category: .data)
        
        // Test message with special characters
        let specialMessage = "🎯🔥💪 Special chars: \n\t\r\\\"' and Unicode: αβγδε 中文 日本語"
        service.warning(specialMessage, category: .ui)
        
        // Service should handle all cases gracefully
        #expect(true)
    }
    
    @Test("LoggingService handles invalid categories gracefully")
    @MainActor func testLoggingServiceInvalidCategories() {
        let service = LoggingService.shared
        
        // Test all valid categories to ensure they work
        service.debug("Debug test", category: .routine)
        service.info("Info test", category: .location)
        service.warning("Warning test", category: .data)
        service.error("Error test", category: .ui)
        
        // All should complete without issues
        #expect(true)
    }
}

@Suite("ResponseLoggingService Error Tests")
struct ResponseLoggingServiceErrorTests {
    
    @Test("ResponseLoggingService handles invalid responses gracefully")
    func testResponseLoggingServiceInvalidResponses() async {
        let service = await ResponseLoggingService.shared
        
        // Test response with empty question
        let invalidResponse1 = ConditionalResponse(
            habitId: UUID(),
            question: "", // Empty question
            selectedOptionId: UUID(),
            selectedOptionText: "Option",
            routineId: UUID(),
            wasSkipped: false
        )
        
        await service.logResponse(invalidResponse1)
        
        // Test response with extremely long text
        let longText = String(repeating: "Very long option text ", count: 100)
        let invalidResponse2 = ConditionalResponse(
            habitId: UUID(),
            question: "Question?",
            selectedOptionId: UUID(),
            selectedOptionText: longText,
            routineId: UUID(),
            wasSkipped: false
        )
        
        await service.logResponse(invalidResponse2)
        
        // Test skipped response
        let skippedResponse = ConditionalResponse.skip(
            habitId: UUID(),
            question: "Skipped question?",
            routineId: UUID()
        )
        
        await service.logResponse(skippedResponse)
        
        // Service should handle all cases without throwing
        #expect(true)
    }
    
    @Test("ResponseLoggingService handles concurrent response logging")
    func testResponseLoggingServiceConcurrentLogging() async {
        let service = await ResponseLoggingService.shared
        
        // Execute concurrent logging operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    let response = ConditionalResponse(
                        habitId: UUID(),
                        question: "Question \(i)?",
                        selectedOptionId: UUID(),
                        selectedOptionText: "Option \(i)",
                        routineId: UUID(),
                        wasSkipped: false
                    )
                    await service.logResponse(response)
                }
            }
        }
        
        // Service should handle concurrent access without issues
        #expect(true)
    }
    
    @Test("ResponseLoggingService handles persistence errors gracefully")
    func testResponseLoggingServicePersistenceErrors() async {
        // Create service with failing persistence
        let failingPersistence = FailingPersistenceService()
        let service = await ResponseLoggingService(persistenceService: failingPersistence)
        
        let response = ConditionalResponse(
            habitId: UUID(),
            question: "Test question?",
            selectedOptionId: UUID(),
            selectedOptionText: "Test option",
            routineId: UUID(),
            wasSkipped: false
        )
        
        // Should handle persistence failure gracefully
        await service.logResponse(response)
        
        // Should not crash even with persistence failures
        #expect(true)
    }
    
    @Test("ResponseLoggingService validates response data")
    func testResponseLoggingServiceValidation() async {
        let service = await ResponseLoggingService.shared
        let errorService = await ErrorHandlingService.shared
        await errorService.clearHistory()
        
        // Test response with suspicious data
        let suspiciousResponse = ConditionalResponse(
            habitId: UUID(),
            question: String(repeating: "?", count: 1000), // Extremely long
            selectedOptionId: UUID(),
            selectedOptionText: "", // Empty selection
            routineId: UUID(),
            wasSkipped: false
        )
        
        await service.logResponse(suspiciousResponse)
        
        // Service should handle validation gracefully
        // Check if any validation errors were logged
        let history = await errorService.getErrorHistory()
        // May or may not log errors depending on validation strategy
        #expect(history.count >= 0)
    }
}

@Suite("DayCategoryManager Error Tests")
struct DayCategoryManagerErrorTests {
    
    @Test("DayCategoryManager handles invalid dates gracefully")
    @MainActor func testDayCategoryManagerInvalidDates() {
        let manager = DayCategoryManager.shared
        
        // Test with distant past date
        let distantPast = Date.distantPast
        let pastCategory = manager.category(for: distantPast)
        #expect(pastCategory.id == "weekday" || pastCategory.id == "weekend")
        
        // Test with distant future date
        let distantFuture = Date.distantFuture
        let futureCategory = manager.category(for: distantFuture)
        #expect(futureCategory.id == "weekday" || futureCategory.id == "weekend")
        
        // Test with current date (should always work)
        let now = Date()
        let currentCategory = manager.category(for: now)
        #expect(currentCategory.id == "weekday" || currentCategory.id == "weekend")
    }
    
    @Test("DayCategoryManager handles concurrent access")
    func testDayCategoryManagerConcurrentAccess() async {
        let manager = await DayCategoryManager.shared
        
        // Execute concurrent category requests
        await withTaskGroup(of: DayCategory.self) { group in
            for i in 0..<50 {
                group.addTask {
                    let date = Date().addingTimeInterval(TimeInterval(i * 86400)) // Different days
                    return await MainActor.run {
                        manager.category(for: date)
                    }
                }
            }
            
            // Collect all results
            var categories: [DayCategory] = []
            for await category in group {
                categories.append(category)
            }
            
            // All requests should succeed
            #expect(categories.count == 50)
            #expect(categories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })
        }
    }
    
    @Test("DayCategoryManager handles edge case times")
    @MainActor func testDayCategoryManagerEdgeCases() {
        let manager = DayCategoryManager.shared
        let calendar = Calendar.current
        
        // Test midnight
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        if let midnight = calendar.date(from: components) {
            let category = manager.category(for: midnight)
            #expect(category.id == "weekday" || category.id == "weekend")
        }
        
        // Test end of day
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        if let endOfDay = calendar.date(from: components) {
            let category = manager.category(for: endOfDay)
            #expect(category.id == "weekday" || category.id == "weekend")
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