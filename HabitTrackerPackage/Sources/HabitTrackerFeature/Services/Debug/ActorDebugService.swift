import Foundation

/// Debug service for monitoring and testing actor-based services
@MainActor
@Observable
public final class ActorDebugService {
    public static let shared = ActorDebugService()
    
    public private(set) var debugLogs: [DebugLogEntry] = []
    public private(set) var actorMetrics: [String: ActorMetrics] = [:]
    public var isEnabled: Bool = false
    
    private init() {}
    
    /// Log an actor operation for debugging
    public func logActorOperation(
        actorType: String,
        operation: String,
        duration: TimeInterval? = nil,
        metadata: [String: Any] = [:]
    ) {
        guard isEnabled else { return }
        
        let entry = DebugLogEntry(
            timestamp: Date(),
            actorType: actorType,
            operation: operation,
            duration: duration,
            metadata: metadata
        )
        
        debugLogs.append(entry)
        updateMetrics(for: actorType, operation: operation, duration: duration)
        
        // Keep only last 1000 entries to prevent memory growth
        if debugLogs.count > 1000 {
            debugLogs.removeFirst(debugLogs.count - 1000)
        }
    }
    
    /// Get debug information for a specific actor type
    public func getDebugInfo(for actorType: String) -> ActorDebugInfo {
        let logs = debugLogs.filter { $0.actorType == actorType }
        let metrics = actorMetrics[actorType] ?? ActorMetrics()
        
        return ActorDebugInfo(
            actorType: actorType,
            totalOperations: metrics.totalOperations,
            averageDuration: metrics.averageDuration,
            recentLogs: Array(logs.suffix(20)),
            lastActivity: logs.last?.timestamp
        )
    }
    
    /// Clear all debug logs
    public func clearLogs() {
        debugLogs.removeAll()
        actorMetrics.removeAll()
    }
    
    /// Get formatted debug report
    public func getDebugReport() -> String {
        var report = "=== Actor Debug Report ===\n"
        report += "Generated: \(Date())\n"
        report += "Debug Enabled: \(isEnabled)\n"
        report += "Total Log Entries: \(debugLogs.count)\n\n"
        
        for (actorType, metrics) in actorMetrics.sorted(by: { $0.key < $1.key }) {
            report += "[\(actorType)]\n"
            report += "  Operations: \(metrics.totalOperations)\n"
            report += "  Avg Duration: \(String(format: "%.3f", metrics.averageDuration))ms\n"
            report += "  Recent Activity: \(metrics.lastActivity?.formatted() ?? "None")\n\n"
        }
        
        return report
    }
    
    private func updateMetrics(for actorType: String, operation: String, duration: TimeInterval?) {
        var metrics = actorMetrics[actorType] ?? ActorMetrics()
        
        metrics.totalOperations += 1
        metrics.lastActivity = Date()
        
        if let duration = duration {
            let totalDuration = metrics.averageDuration * Double(metrics.totalOperations - 1) + (duration * 1000)
            metrics.averageDuration = totalDuration / Double(metrics.totalOperations)
        }
        
        actorMetrics[actorType] = metrics
    }
}

/// Single debug log entry
public struct DebugLogEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let actorType: String
    public let operation: String
    public let duration: TimeInterval?
    public let metadata: [String: String] // Changed to Sendable type
    
    init(timestamp: Date, actorType: String, operation: String, duration: TimeInterval?, metadata: [String: Any]) {
        self.timestamp = timestamp
        self.actorType = actorType
        self.operation = operation
        self.duration = duration
        // Convert Any values to String for Sendable compliance
        self.metadata = metadata.mapValues { "\($0)" }
    }
}

/// Metrics for a specific actor type
public struct ActorMetrics {
    public var totalOperations: Int = 0
    public var averageDuration: Double = 0.0 // in milliseconds
    public var lastActivity: Date?
}

/// Consolidated debug information for an actor
public struct ActorDebugInfo {
    public let actorType: String
    public let totalOperations: Int
    public let averageDuration: Double
    public let recentLogs: [DebugLogEntry]
    public let lastActivity: Date?
}