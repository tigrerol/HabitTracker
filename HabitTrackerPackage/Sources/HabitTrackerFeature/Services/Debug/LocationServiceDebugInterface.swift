import Foundation
import CoreLocation

/// Debug testing interface for LocationService actor
public struct LocationServiceDebugInterface {
    private let locationService: LocationService
    
    public init(locationService: LocationService) {
        self.locationService = locationService
    }
    
    /// Get current state snapshot for testing
    public func getStateSnapshot() async -> LocationServiceStateSnapshot {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Access all state atomically through the actor
        let currentLocation = await locationService.getCurrentLocation()
        let (locationType, extendedLocationType) = await locationService.getCurrentLocationTypes()
        let savedLocations = await locationService.getSavedLocations()
        let customLocations = await locationService.getAllCustomLocations()
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "LocationService",
            operation: "getStateSnapshot",
            duration: duration,
            metadata: [
                "hasCurrentLocation": currentLocation != nil,
                "locationType": locationType.rawValue,
                "extendedLocationType": String(describing: extendedLocationType),
                "savedLocationsCount": savedLocations.count,
                "customLocationsCount": customLocations.count
            ]
        )
        
        return LocationServiceStateSnapshot(
            currentLocation: currentLocation.map { LocationCoordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) },
            locationType: locationType,
            extendedLocationType: extendedLocationType,
            savedLocationsCount: savedLocations.count,
            customLocationsCount: customLocations.count,
            captureTime: Date(),
            operationDuration: duration
        )
    }
    
    /// Test actor isolation by performing concurrent operations
    public func testConcurrentAccess(operationCount: Int = 10) async -> ConcurrencyTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple concurrent operations
        let service = locationService // Capture locally to avoid data races
        let tasks = (0..<operationCount).map { index in
            Task {
                let operationStart = CFAbsoluteTimeGetCurrent()
                
                // Mix different types of operations
                switch index % 4 {
                case 0:
                    _ = await service.getCurrentLocation()
                case 1:
                    _ = await service.getCurrentLocationTypes()
                case 2:
                    _ = await service.getSavedLocations()
                case 3:
                    _ = await service.getAllCustomLocations()
                default:
                    break
                }
                
                return CFAbsoluteTimeGetCurrent() - operationStart
            }
        }
        
        // Wait for all operations to complete
        let durations = await withTaskGroup(of: Double.self) { group in
            for task in tasks {
                group.addTask { await task.value }
            }
            
            var results: [Double] = []
            for await duration in group {
                results.append(duration)
            }
            return results
        }
        
        let totalDuration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let averageDuration = (durations.reduce(0, +) / Double(durations.count)) * 1000
        let maxDuration = (durations.max() ?? 0) * 1000
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "LocationService",
            operation: "testConcurrentAccess",
            duration: totalDuration,
            metadata: [
                "operationCount": operationCount,
                "averageOperationDuration": averageDuration,
                "maxOperationDuration": maxDuration
            ]
        )
        
        return ConcurrencyTestResult(
            operationCount: operationCount,
            totalDuration: totalDuration,
            averageOperationDuration: averageDuration,
            maxOperationDuration: maxDuration,
            operationDurations: durations.map { $0 * 1000 }
        )
    }
    
    /// Test memory management by forcing operations and checking state consistency
    public func testMemoryManagement() async -> MemoryTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Take initial snapshot
        let initialSnapshot = await getStateSnapshot()
        
        // Perform operations that could trigger memory issues
        let service = locationService // Capture locally to avoid data races
        let operationTasks = (0..<20).map { _ in
            Task {
                // Mix state-reading operations
                _ = await service.getCurrentLocation()
                _ = await service.getSavedLocations()
                await Task.yield() // Allow other tasks to run
            }
        }
        
        // Wait for all operations
        for task in operationTasks {
            await task.value
        }
        
        // Take final snapshot
        let finalSnapshot = await getStateSnapshot()
        
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Check for consistency
        let isConsistent = initialSnapshot.locationType == finalSnapshot.locationType &&
                          initialSnapshot.extendedLocationType == finalSnapshot.extendedLocationType &&
                          initialSnapshot.savedLocationsCount == finalSnapshot.savedLocationsCount
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "LocationService",
            operation: "testMemoryManagement",
            duration: duration,
            metadata: [
                "isStateConsistent": isConsistent,
                "initialLocationType": initialSnapshot.locationType.rawValue,
                "finalLocationType": finalSnapshot.locationType.rawValue
            ]
        )
        
        return MemoryTestResult(
            duration: duration,
            isStateConsistent: isConsistent,
            initialSnapshot: initialSnapshot,
            finalSnapshot: finalSnapshot
        )
    }
    
    /// Test isolation by verifying actor queue behavior
    public func testActorIsolation() async -> ActorIsolationTestResult {
        let service = locationService // Capture locally to avoid data races
        let operationTimestamps: [Date] = await withTaskGroup(of: Date.self) { group in
            // Start multiple tasks simultaneously
            for _ in 0..<5 {
                group.addTask {
                    // Each task records when it actually starts executing inside the actor
                    await service.recordOperationTimestamp()
                }
            }
            
            var timestamps: [Date] = []
            for await timestamp in group {
                timestamps.append(timestamp)
            }
            return timestamps.sorted()
        }
        
        // Analyze timestamp gaps to verify serialization
        var gaps: [TimeInterval] = []
        for i in 1..<operationTimestamps.count {
            let gap = operationTimestamps[i].timeIntervalSince(operationTimestamps[i-1])
            gaps.append(gap)
        }
        
        await ActorDebugService.shared.logActorOperation(
            actorType: "LocationService",
            operation: "testActorIsolation",
            metadata: [
                "operationCount": operationTimestamps.count,
                "averageGap": gaps.isEmpty ? 0 : gaps.reduce(0, +) / Double(gaps.count),
                "maxGap": gaps.max() ?? 0
            ]
        )
        
        return ActorIsolationTestResult(
            operationTimestamps: operationTimestamps,
            gaps: gaps,
            averageGap: gaps.isEmpty ? 0 : gaps.reduce(0, +) / Double(gaps.count),
            maxGap: gaps.max() ?? 0
        )
    }
}

/// Snapshot of LocationService state at a point in time
public struct LocationServiceStateSnapshot: Sendable {
    public let currentLocation: LocationCoordinate?
    public let locationType: LocationType
    public let extendedLocationType: ExtendedLocationType
    public let savedLocationsCount: Int
    public let customLocationsCount: Int
    public let captureTime: Date
    public let operationDuration: Double // milliseconds
}

/// Result of concurrency testing
public struct ConcurrencyTestResult: Sendable {
    public let operationCount: Int
    public let totalDuration: Double // milliseconds
    public let averageOperationDuration: Double // milliseconds
    public let maxOperationDuration: Double // milliseconds
    public let operationDurations: [Double] // milliseconds
}

/// Result of memory management testing
public struct MemoryTestResult: Sendable {
    public let duration: Double // milliseconds
    public let isStateConsistent: Bool
    public let initialSnapshot: LocationServiceStateSnapshot
    public let finalSnapshot: LocationServiceStateSnapshot
}

/// Result of actor isolation testing
public struct ActorIsolationTestResult: Sendable {
    public let operationTimestamps: [Date]
    public let gaps: [TimeInterval]
    public let averageGap: TimeInterval
    public let maxGap: TimeInterval
}