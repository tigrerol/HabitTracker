import Foundation
import SwiftUI

/// Service for managing conditional habits, their responses, and associated business logic
@MainActor
@Observable
public final class ConditionalHabitService {
    public static let shared = ConditionalHabitService()
    
    // MARK: - State
    
    /// All conditional responses stored in the system
    public private(set) var responses: [ConditionalResponse] = []
    
    /// Cache of habit options for quick lookup
    private var optionCache: [UUID: [ConditionalOption]] = [:]
    
    /// Analytics data for conditional habit usage
    public private(set) var analytics: ConditionalHabitAnalytics = ConditionalHabitAnalytics()
    
    // MARK: - Migration
    
    /// Migration version for conditional habit data
    private let currentMigrationVersion = 2
    private let migrationVersionKey = "ConditionalHabitMigrationVersion"
    
    private init() {
        loadResponses()
        performMigrationIfNeeded()
        updateAnalytics()
    }
    
    // MARK: - Public Interface
    
    /// Record a user's response to a conditional habit
    public func recordResponse(_ response: ConditionalResponse) {
        // Remove any existing response for the same habit in the same routine
        responses.removeAll { 
            $0.habitId == response.habitId && 
            $0.routineId == response.routineId 
        }
        
        responses.append(response)
        persistResponses()
        updateAnalytics()
        
        LoggingService.shared.info(
            "Recorded conditional response",
            category: .routine,
            metadata: [
                "habitId": response.habitId.uuidString,
                "optionSelected": response.selectedOptionText,
                "wasSkipped": "\(response.wasSkipped)"
            ]
        )
    }
    
    /// Get the most recent response for a specific habit
    public func getLatestResponse(for habitId: UUID) -> ConditionalResponse? {
        return responses
            .filter { $0.habitId == habitId }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }
    
    /// Get responses for a specific routine
    public func getResponses(for routineId: UUID) -> [ConditionalResponse] {
        return responses
            .filter { $0.routineId == routineId }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Get response history for a habit over time
    public func getResponseHistory(for habitId: UUID, limit: Int = 20) -> [ConditionalResponse] {
        return responses
            .filter { $0.habitId == habitId }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Validate that a conditional habit configuration is valid
    public func validateConditionalHabit(_ info: ConditionalHabitInfo) -> ConditionalHabitValidation {
        var issues: [String] = []
        
        // Check question length
        if info.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Question cannot be empty")
        } else if info.question.count > 200 {
            issues.append("Question should be under 200 characters")
        }
        
        // Check options
        if info.options.isEmpty {
            issues.append("At least one option is required")
        } else if info.options.count > 4 {
            issues.append("Maximum 4 options allowed")
        }
        
        // Check option text
        for (index, option) in info.options.enumerated() {
            if option.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Option \(index + 1) text cannot be empty")
            } else if option.text.count > 50 {
                issues.append("Option \(index + 1) text should be under 50 characters")
            }
        }
        
        // Check for duplicate option texts
        let optionTexts = info.options.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let uniqueTexts = Set(optionTexts)
        if optionTexts.count != uniqueTexts.count {
            issues.append("Option texts must be unique")
        }
        
        return ConditionalHabitValidation(
            isValid: issues.isEmpty,
            issues: issues,
            optionCount: info.options.count,
            totalHabitsInPaths: info.options.reduce(0) { $0 + $1.habits.count }
        )
    }
    
    /// Get statistics about how often each option is selected for a habit
    public func getOptionStatistics(for habitId: UUID) -> [ConditionalOptionStatistics] {
        let habitResponses = responses.filter { $0.habitId == habitId && !$0.wasSkipped }
        let totalResponses = habitResponses.count
        
        guard totalResponses > 0 else { return [] }
        
        // Group responses by option ID
        let grouped = Dictionary(grouping: habitResponses) { $0.selectedOptionId }
        
        return grouped.map { optionId, responses in
            let percentage = Double(responses.count) / Double(totalResponses) * 100
            return ConditionalOptionStatistics(
                optionId: optionId,
                optionText: responses.first?.selectedOptionText ?? "Unknown",
                selectionCount: responses.count,
                selectionPercentage: percentage,
                lastSelected: responses.max { $0.timestamp < $1.timestamp }?.timestamp
            )
        }.sorted { $0.selectionCount > $1.selectionCount }
    }
    
    /// Clear all responses (for testing or reset purposes)
    public func clearAllResponses() {
        responses.removeAll()
        persistResponses()
        updateAnalytics()
        
        LoggingService.shared.info("Cleared all conditional habit responses", category: .routine)
    }
    
    /// Export responses as JSON for backup or analysis
    public func exportResponses() throws -> Data {
        let export = ConditionalHabitExport(
            responses: responses,
            analytics: analytics,
            exportDate: Date(),
            version: currentMigrationVersion
        )
        
        return try JSONEncoder().encode(export)
    }
    
    /// Import responses from JSON (with validation and migration)
    public func importResponses(from data: Data) throws {
        let export = try JSONDecoder().decode(ConditionalHabitExport.self, from: data)
        
        // Validate import version
        if export.version > currentMigrationVersion {
            throw ConditionalHabitError.unsupportedVersion(export.version)
        }
        
        // Merge responses (avoiding duplicates)
        for importedResponse in export.responses {
            // Check if we already have this exact response
            let existingResponse = responses.first { existing in
                existing.id == importedResponse.id ||
                (existing.habitId == importedResponse.habitId &&
                 existing.routineId == importedResponse.routineId &&
                 existing.timestamp == importedResponse.timestamp)
            }
            
            if existingResponse == nil {
                responses.append(importedResponse)
            }
        }
        
        persistResponses()
        updateAnalytics()
        
        LoggingService.shared.info(
            "Imported conditional habit responses",
            category: .routine,
            metadata: ["importedCount": "\(export.responses.count)"]
        )
    }
    
    // MARK: - Private Implementation
    
    /// Load responses from persistent storage
    private func loadResponses() {
        if let data = UserDefaults.standard.data(forKey: "ConditionalHabitResponses") {
            do {
                responses = try JSONDecoder().decode([ConditionalResponse].self, from: data)
            } catch {
                LoggingService.shared.error(
                    "Failed to load conditional habit responses",
                    category: .data,
                    metadata: ["error": error.localizedDescription]
                )
                responses = []
            }
        }
    }
    
    /// Persist responses to storage
    private func persistResponses() {
        do {
            let data = try JSONEncoder().encode(responses)
            UserDefaults.standard.set(data, forKey: "ConditionalHabitResponses")
        } catch {
            LoggingService.shared.error(
                "Failed to persist conditional habit responses",
                category: .data,
                metadata: ["error": error.localizedDescription]
            )
        }
    }
    
    /// Update analytics based on current responses
    private func updateAnalytics() {
        let totalResponses = responses.count
        let skippedResponses = responses.filter { $0.wasSkipped }.count
        let completedResponses = totalResponses - skippedResponses
        
        let uniqueHabits = Set(responses.map { $0.habitId }).count
        let uniqueRoutines = Set(responses.map { $0.routineId }).count
        
        let averageResponsesPerHabit = uniqueHabits > 0 ? Double(totalResponses) / Double(uniqueHabits) : 0
        
        let skipRate = totalResponses > 0 ? Double(skippedResponses) / Double(totalResponses) : 0
        
        analytics = ConditionalHabitAnalytics(
            totalResponses: totalResponses,
            completedResponses: completedResponses,
            skippedResponses: skippedResponses,
            uniqueHabitsAnswered: uniqueHabits,
            uniqueRoutinesWithResponses: uniqueRoutines,
            averageResponsesPerHabit: averageResponsesPerHabit,
            skipRate: skipRate,
            lastResponseDate: responses.max { $0.timestamp < $1.timestamp }?.timestamp
        )
    }
    
    /// Perform data migration if needed
    private func performMigrationIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        
        if savedVersion < currentMigrationVersion {
            LoggingService.shared.info(
                "Starting conditional habit data migration",
                category: .data,
                metadata: [
                    "fromVersion": "\(savedVersion)",
                    "toVersion": "\(currentMigrationVersion)"
                ]
            )
            
            // Migration from version 0 to 1: Add routine ID to responses that lack it
            if savedVersion < 1 {
                var migratedResponses: [ConditionalResponse] = []
                for response in responses {
                    if response.routineId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                        // Generate a synthetic routine ID based on timestamp
                        let migratedResponse = ConditionalResponse(
                            id: response.id,
                            habitId: response.habitId,
                            question: response.question,
                            selectedOptionId: response.selectedOptionId,
                            selectedOptionText: response.selectedOptionText,
                            timestamp: response.timestamp,
                            routineId: UUID(),
                            wasSkipped: response.wasSkipped
                        )
                        migratedResponses.append(migratedResponse)
                    } else {
                        migratedResponses.append(response)
                    }
                }
                responses = migratedResponses
            }
            
            // Migration from version 1 to 2: Clean up invalid responses
            if savedVersion < 2 {
                responses.removeAll { response in
                    response.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    response.selectedOptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
            
            persistResponses()
            UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
            
            LoggingService.shared.info(
                "Completed conditional habit data migration",
                category: .data,
                metadata: ["finalResponseCount": "\(responses.count)"]
            )
        }
    }
}

// MARK: - Supporting Types

/// Validation result for a conditional habit configuration
public struct ConditionalHabitValidation {
    public let isValid: Bool
    public let issues: [String]
    public let optionCount: Int
    public let totalHabitsInPaths: Int
    
    public var warningCount: Int {
        var warnings = 0
        if optionCount > 3 { warnings += 1 }
        if totalHabitsInPaths > 10 { warnings += 1 }
        return warnings
    }
}

/// Statistics for how often a conditional option is selected
public struct ConditionalOptionStatistics {
    public let optionId: UUID
    public let optionText: String
    public let selectionCount: Int
    public let selectionPercentage: Double
    public let lastSelected: Date?
}

/// Analytics data for conditional habit usage
public struct ConditionalHabitAnalytics: Codable {
    public let totalResponses: Int
    public let completedResponses: Int
    public let skippedResponses: Int
    public let uniqueHabitsAnswered: Int
    public let uniqueRoutinesWithResponses: Int
    public let averageResponsesPerHabit: Double
    public let skipRate: Double
    public let lastResponseDate: Date?
    
    public init(
        totalResponses: Int = 0,
        completedResponses: Int = 0,
        skippedResponses: Int = 0,
        uniqueHabitsAnswered: Int = 0,
        uniqueRoutinesWithResponses: Int = 0,
        averageResponsesPerHabit: Double = 0,
        skipRate: Double = 0,
        lastResponseDate: Date? = nil
    ) {
        self.totalResponses = totalResponses
        self.completedResponses = completedResponses
        self.skippedResponses = skippedResponses
        self.uniqueHabitsAnswered = uniqueHabitsAnswered
        self.uniqueRoutinesWithResponses = uniqueRoutinesWithResponses
        self.averageResponsesPerHabit = averageResponsesPerHabit
        self.skipRate = skipRate
        self.lastResponseDate = lastResponseDate
    }
}

/// Export structure for conditional habit data
public struct ConditionalHabitExport: Codable {
    public let responses: [ConditionalResponse]
    public let analytics: ConditionalHabitAnalytics
    public let exportDate: Date
    public let version: Int
}

/// Errors that can occur in conditional habit operations
public enum ConditionalHabitError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case invalidData
    case migrationFailed
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported data version: \(version)"
        case .invalidData:
            return "Invalid conditional habit data"
        case .migrationFailed:
            return "Failed to migrate conditional habit data"
        }
    }
}