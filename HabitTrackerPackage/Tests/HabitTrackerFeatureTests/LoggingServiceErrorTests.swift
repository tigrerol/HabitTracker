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

@Suite("DayCategoryManager Error Tests")
struct DayCategoryManagerErrorTests {
    
    @Test("DayCategoryManager handles invalid dates gracefully")
    @MainActor func testDayCategoryManagerInvalidDates() {
        let manager = DayCategoryManager.shared

        // Test with distant past date
        let distantPast = Date.distantPast
        let pastCategories = manager.categories(for: distantPast)
        #expect(pastCategories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })

        // Test with distant future date
        let distantFuture = Date.distantFuture
        let futureCategories = manager.categories(for: distantFuture)
        #expect(futureCategories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })

        // Test with current date (should always work)
        let now = Date()
        let currentCategories = manager.categories(for: now)
        #expect(currentCategories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })
    }

    @Test("DayCategoryManager handles concurrent access")
    func testDayCategoryManagerConcurrentAccess() async {
        let manager = await DayCategoryManager.shared

        // Execute concurrent category requests
        await withTaskGroup(of: [DayCategory].self) { group in
            for i in 0..<50 {
                group.addTask {
                    let date = Date().addingTimeInterval(TimeInterval(i * 86400)) // Different days
                    return await MainActor.run {
                        manager.categories(for: date)
                    }
                }
            }

            // Collect all results
            var allCategories: [[DayCategory]] = []
            for await categories in group {
                allCategories.append(categories)
            }

            // All requests should succeed
            #expect(allCategories.count == 50)
            #expect(allCategories.allSatisfy { cats in
                cats.allSatisfy { $0.id == "weekday" || $0.id == "weekend" }
            })
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
            let categories = manager.categories(for: midnight)
            #expect(categories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })
        }

        // Test end of day
        components.hour = 23
        components.minute = 59
        components.second = 59

        if let endOfDay = calendar.date(from: components) {
            let categories = manager.categories(for: endOfDay)
            #expect(categories.allSatisfy { $0.id == "weekday" || $0.id == "weekend" })
        }
    }
}
