import Foundation

/// Service for logging conditional habit responses
@MainActor
public final class ResponseLoggingService: Sendable {
    public static let shared = ResponseLoggingService()
    
    private let userDefaults = UserDefaults.standard
    private let responsesKey = "ConditionalHabitResponses"
    
    private init() {}
    
    /// Log a response for a conditional habit
    public func logResponse(_ response: ConditionalResponse) {
        var responses = getAllResponses()
        responses.append(response)
        saveResponses(responses)
    }
    
    /// Get all logged responses
    public func getAllResponses() -> [ConditionalResponse] {
        guard let data = userDefaults.data(forKey: responsesKey),
              let responses = try? JSONDecoder().decode([ConditionalResponse].self, from: data) else {
            return []
        }
        return responses
    }
    
    /// Get responses for a specific habit
    public func getResponses(for habitId: UUID) -> [ConditionalResponse] {
        getAllResponses().filter { $0.habitId == habitId }
    }
    
    /// Get responses for a specific routine
    public func getResponses(for routineId: UUID) -> [ConditionalResponse] {
        getAllResponses().filter { $0.routineId == routineId }
    }
    
    /// Get skip rate for a specific habit
    public func getSkipRate(for habitId: UUID) -> Double {
        let responses = getResponses(for: habitId)
        guard !responses.isEmpty else { return 0 }
        
        let skippedCount = responses.filter { $0.wasSkipped }.count
        return Double(skippedCount) / Double(responses.count)
    }
    
    /// Get response counts by option for a specific habit
    public func getResponseCounts(for habitId: UUID) -> [String: Int] {
        let responses = getResponses(for: habitId).filter { !$0.wasSkipped }
        var counts: [String: Int] = [:]
        
        for response in responses {
            counts[response.selectedOptionText, default: 0] += 1
        }
        
        return counts
    }
    
    /// Clear all responses (useful for testing or data reset)
    public func clearAllResponses() {
        userDefaults.removeObject(forKey: responsesKey)
    }
    
    private func saveResponses(_ responses: [ConditionalResponse]) {
        if let data = try? JSONEncoder().encode(responses) {
            userDefaults.set(data, forKey: responsesKey)
        }
    }
}