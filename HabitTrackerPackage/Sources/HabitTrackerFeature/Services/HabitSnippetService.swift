import Foundation
import SwiftUI

/// Service for managing habit snippets - reusable collections of habits
@MainActor
@Observable
public final class HabitSnippetService: Sendable {
    public private(set) var snippets: [HabitSnippet] = []
    
    private let storageKey = "saved_habit_snippets"
    
    public init() {
        loadSnippets()
    }
    
    // MARK: - Public Interface
    
    /// Save a new snippet
    public func saveSnippet(_ snippet: HabitSnippet) {
        snippets.append(snippet)
        saveSnippets()
    }
    
    /// Delete a snippet
    public func deleteSnippet(withId id: UUID) {
        snippets.removeAll { $0.id == id }
        saveSnippets()
    }
    
    /// Update an existing snippet
    public func updateSnippet(_ updatedSnippet: HabitSnippet) {
        if let index = snippets.firstIndex(where: { $0.id == updatedSnippet.id }) {
            snippets[index] = updatedSnippet
            saveSnippets()
        }
    }
    
    /// Get all snippets, sorted by creation date (newest first)
    public func getAllSnippets() -> [HabitSnippet] {
        return snippets.sorted { $0.createdDate > $1.createdDate }
    }
    
    /// Search snippets by name
    public func searchSnippets(query: String) -> [HabitSnippet] {
        if query.isEmpty {
            return getAllSnippets()
        }
        return snippets.filter { 
            $0.name.localizedCaseInsensitiveContains(query) 
        }.sorted { $0.createdDate > $1.createdDate }
    }
    
    // MARK: - Private Storage
    
    private func loadSnippets() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HabitSnippet].self, from: data) else {
            snippets = []
            return
        }
        snippets = decoded
    }
    
    private func saveSnippets() {
        guard let encoded = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}