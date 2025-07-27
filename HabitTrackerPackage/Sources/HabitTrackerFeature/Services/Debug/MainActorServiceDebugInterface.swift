import Foundation
import SwiftUI

/// Debug testing interface for @MainActor @Observable services
@MainActor
public struct MainActorServiceDebugInterface {
    
    /// Test routine service operations
    public static func testRoutineServiceOperations(
        routineService: RoutineService
    ) async -> MainActorServiceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var operationResults: [String] = []
        
        // Test 1: Read current state
        let initialTemplatesCount = routineService.templates.count
        let hasCurrentSession = routineService.currentSession != nil
        operationResults.append("Initial state: \(initialTemplatesCount) templates, session: \(hasCurrentSession)")
        
        // Test 2: Access properties multiple times to test observation system
        for i in 0..<10 {
            let templatesCount = routineService.templates.count
            let sessionExists = routineService.currentSession != nil
            operationResults.append("Iteration \(i): \(templatesCount) templates, session: \(sessionExists)")
        }
        
        // Test 3: Measure property access performance
        let propertyAccessStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = routineService.templates.count
            _ = routineService.currentSession?.id
        }
        let propertyAccessDuration = (CFAbsoluteTimeGetCurrent() - propertyAccessStart) * 1000
        
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "RoutineService",
            operation: "testOperations",
            duration: totalDuration,
            metadata: [
                "templatesCount": initialTemplatesCount,
                "hasSession": hasCurrentSession,
                "propertyAccessDuration": propertyAccessDuration
            ]
        )
        
        return MainActorServiceTestResult(
            serviceName: "RoutineService",
            totalDuration: totalDuration,
            propertyAccessDuration: propertyAccessDuration,
            operationResults: operationResults,
            initialState: [
                "templatesCount": "\(initialTemplatesCount)",
                "hasCurrentSession": "\(hasCurrentSession)"
            ]
        )
    }
    
    /// Test error presentation service operations
    public static func testErrorPresentationServiceOperations(
        errorService: ErrorPresentationService
    ) async -> MainActorServiceTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var operationResults: [String] = []
        
        // Test 1: Read current state
        let hasCurrentError = errorService.currentError != nil
        operationResults.append("Initial state: currentError = \(hasCurrentError)")
        
        // Test 2: Property access performance
        let propertyAccessStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<50 {
            let errorExists = errorService.currentError != nil
            operationResults.append("Access \(i): error exists = \(errorExists)")
        }
        let propertyAccessDuration = (CFAbsoluteTimeGetCurrent() - propertyAccessStart) * 1000
        
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "ErrorPresentationService",
            operation: "testOperations",
            duration: totalDuration,
            metadata: [
                "hasCurrentError": hasCurrentError,
                "propertyAccessDuration": propertyAccessDuration
            ]
        )
        
        return MainActorServiceTestResult(
            serviceName: "ErrorPresentationService",
            totalDuration: totalDuration,
            propertyAccessDuration: propertyAccessDuration,
            operationResults: operationResults,
            initialState: [
                "hasCurrentError": "\(hasCurrentError)"
            ]
        )
    }
    
    /// Test concurrent UI updates on a @MainActor service
    public static func testConcurrentUIUpdates() async -> ConcurrentUITestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let updateTasks = (0..<10).map { index in
            Task { @MainActor in
                let taskStart = CFAbsoluteTimeGetCurrent()
                
                // Simulate UI updates by accessing main actor properties
                await Task.yield()
                
                let duration = (CFAbsoluteTimeGetCurrent() - taskStart) * 1000
                return MainActorOperation(
                    index: index,
                    duration: duration,
                    timestamp: Date()
                )
            }
        }
        
        // Collect all results
        let operations = await withTaskGroup(of: MainActorOperation.self) { group in
            for task in updateTasks {
                group.addTask { await task.value }
            }
            
            var results: [MainActorOperation] = []
            for await operation in group {
                results.append(operation)
            }
            return results.sorted { $0.timestamp < $1.timestamp }
        }
        
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let averageDuration = operations.map(\.duration).reduce(0, +) / Double(operations.count)
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "MainActor",
            operation: "testConcurrentUIUpdates",
            duration: totalDuration,
            metadata: [
                "operationCount": operations.count,
                "averageDuration": averageDuration
            ]
        )
        
        return ConcurrentUITestResult(
            totalDuration: totalDuration,
            averageOperationDuration: averageDuration,
            operations: operations,
            maxDuration: operations.map(\.duration).max() ?? 0,
            minDuration: operations.map(\.duration).min() ?? 0
        )
    }
    
    /// Test observation system performance
    public static func testObservationPerformance(
        routineService: RoutineService
    ) async -> ObservationTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate multiple observers accessing the same property
        let observerTasks = (0..<5).map { observerId in
            Task { @MainActor in
                var accessCount = 0
                let observerStart = CFAbsoluteTimeGetCurrent()
                
                // Simulate repeated property access like a UI would do
                for _ in 0..<20 {
                    _ = routineService.templates.count
                    _ = routineService.currentSession?.isCompleted
                    accessCount += 2
                    await Task.yield()
                }
                
                let duration = (CFAbsoluteTimeGetCurrent() - observerStart) * 1000
                return ObserverMetrics(
                    observerId: observerId,
                    accessCount: accessCount,
                    duration: duration
                )
            }
        }
        
        let observerMetrics = await withTaskGroup(of: ObserverMetrics.self) { group in
            for task in observerTasks {
                group.addTask { await task.value }
            }
            
            var results: [ObserverMetrics] = []
            for await metrics in group {
                results.append(metrics)
            }
            return results
        }
        
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let totalAccesses = observerMetrics.map(\.accessCount).reduce(0, +)
        let averageAccessDuration = observerMetrics.map(\.duration).reduce(0, +) / Double(observerMetrics.count)
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "RoutineService",
            operation: "testObservationPerformance",
            duration: totalDuration,
            metadata: [
                "observerCount": observerMetrics.count,
                "totalAccesses": totalAccesses,
                "averageAccessDuration": averageAccessDuration
            ]
        )
        
        return ObservationTestResult(
            totalDuration: totalDuration,
            observerCount: observerMetrics.count,
            totalAccesses: totalAccesses,
            averageAccessDuration: averageAccessDuration,
            observerMetrics: observerMetrics
        )
    }
}

/// Result of testing a @MainActor @Observable service
public struct MainActorServiceTestResult {
    public let serviceName: String
    public let totalDuration: Double // milliseconds
    public let propertyAccessDuration: Double // milliseconds
    public let operationResults: [String]
    public let initialState: [String: String]
}

/// Single operation on the main actor
public struct MainActorOperation: Sendable {
    public let index: Int
    public let duration: Double // milliseconds
    public let timestamp: Date
}

/// Result of testing concurrent UI updates
public struct ConcurrentUITestResult {
    public let totalDuration: Double // milliseconds
    public let averageOperationDuration: Double // milliseconds
    public let operations: [MainActorOperation]
    public let maxDuration: Double // milliseconds
    public let minDuration: Double // milliseconds
}

/// Metrics for a single observer
public struct ObserverMetrics: Sendable {
    public let observerId: Int
    public let accessCount: Int
    public let duration: Double // milliseconds
}

/// Result of testing observation system performance
public struct ObservationTestResult {
    public let totalDuration: Double // milliseconds
    public let observerCount: Int
    public let totalAccesses: Int
    public let averageAccessDuration: Double // milliseconds
    public let observerMetrics: [ObserverMetrics]
}