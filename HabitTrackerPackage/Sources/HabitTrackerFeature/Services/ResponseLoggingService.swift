import Foundation

/// Service for logging conditional habit responses
@MainActor
public final class ResponseLoggingService: Sendable {
    public static let shared = ResponseLoggingService()
    
    private let persistenceService: any PersistenceServiceProtocol
    private let responsesKey = "ConditionalHabitResponses"
    
    /// Initialize with dependency injection
    public init(persistenceService: any PersistenceServiceProtocol = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
    }
    
    private convenience init() {
        self.init(persistenceService: UserDefaultsPersistenceService())
    }
    
    /// Log a response for a conditional habit
    public func logResponse(_ response: ConditionalResponse) {
        Task { @MainActor in
            var responses = await getAllResponses()
            responses.append(response)
            await saveResponses(responses)
        }
    }
    
    /// Get all logged responses
    public func getAllResponses() async -> [ConditionalResponse] {
        do {
            return try await persistenceService.load([ConditionalResponse].self, forKey: responsesKey) ?? []
        } catch {
            return []
        }
    }
    
    /// Get responses for a specific habit
    public func getResponses(for habitId: UUID) async -> [ConditionalResponse] {
        let allResponses = await getAllResponses()
        return allResponses.filter { $0.habitId == habitId }
    }
    
    /// Get responses for a specific routine
    public func getResponsesForRoutine(_ routineId: UUID) async -> [ConditionalResponse] {
        let allResponses = await getAllResponses()
        return allResponses.filter { $0.routineId == routineId }
    }
    
    /// Get skip rate for a specific habit
    public func getSkipRate(for habitId: UUID) async -> Double {
        let responses = await getResponses(for: habitId)
        guard !responses.isEmpty else { return 0 }
        
        let skippedCount = responses.filter { $0.wasSkipped }.count
        return Double(skippedCount) / Double(responses.count)
    }
    
    /// Get response counts by option for a specific habit
    public func getResponseCounts(for habitId: UUID) async -> [String: Int] {
        let responses = await getResponses(for: habitId).filter { !$0.wasSkipped }
        var counts: [String: Int] = [:]
        
        for response in responses {
            counts[response.selectedOptionText, default: 0] += 1
        }
        
        return counts
    }
    
    /// Clear all responses (useful for testing or data reset)
    public func clearAllResponses() {
        Task { @MainActor in
            await persistenceService.delete(forKey: responsesKey)
        }
    }
    
    private func saveResponses(_ responses: [ConditionalResponse]) async {
        do {
            try await persistenceService.save(responses, forKey: responsesKey)
        } catch {
            // Log error but don't crash
            print("Failed to save conditional responses: \(error)")
        }
    }
}