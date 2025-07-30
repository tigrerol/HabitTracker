import SwiftUI

/// Browser for selecting snippets to add to a routine
struct SnippetBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    let onSnippetSelected: ([Habit]) -> Void
    
    @State private var searchText = ""
    
    private var filteredSnippets: [HabitSnippet] {
        routineService.snippetService.searchSnippets(query: searchText)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if filteredSnippets.isEmpty {
                    emptyStateView
                } else {
                    snippetGrid
                }
            }
            .navigationTitle("Add Snippet")
            .searchable(text: $searchText, prompt: "Search snippets")
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? "No Snippets Yet" : "No Results")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty ? 
                 "Create your first snippet by selecting habits in a routine and tapping 'Save snippet'" : 
                 "Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var snippetGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(filteredSnippets) { snippet in
                    SnippetCard(snippet: snippet) {
                        onSnippetSelected(snippet.habits)
                        dismiss()
                    }
                }
            }
            .padding()
        }
    }
}

/// Individual snippet card
struct SnippetCard: View {
    let snippet: HabitSnippet
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: snippet.icon)
                    .font(.title2)
                    .foregroundStyle(snippet.swiftUIColor)
                
                Spacer()
                
                Text("\(snippet.habitCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.regularMaterial, in: Capsule())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(snippet.estimatedDuration.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(height: 100)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}