import SwiftUI

/// Full library view for managing saved snippets
public struct SnippetLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var searchText = ""
    @State private var snippetToDelete: HabitSnippet?
    @State private var showingDeleteAlert = false
    @State private var editingSnippetId: UUID?
    @State private var editingName: String = ""
    
    private var filteredSnippets: [HabitSnippet] {
        routineService.snippetService.searchSnippets(query: searchText)
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack {
                if filteredSnippets.isEmpty {
                    emptyStateView
                } else {
                    snippetList
                }
            }
            .navigationTitle("Snippet Library")
            .searchable(text: $searchText, prompt: "Search snippets")
            
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Delete Snippet", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let snippet = snippetToDelete {
                    routineService.snippetService.deleteSnippet(withId: snippet.id)
                }
            }
        } message: {
            if let snippet = snippetToDelete {
                Text("Are you sure you want to delete '\(snippet.name)'? This action cannot be undone.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Snippets Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Create your first snippet by selecting habits in a routine and tapping 'Save snippet'")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var snippetList: some View {
        List {
            ForEach(filteredSnippets) { snippet in
                SnippetListRow(
                    snippet: snippet,
                    isEditing: editingSnippetId == snippet.id,
                    editingName: $editingName,
                    onStartEdit: {
                        editingSnippetId = snippet.id
                        editingName = snippet.name
                    },
                    onSaveEdit: {
                        if !editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            var updatedSnippet = snippet
                            updatedSnippet.name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                            routineService.snippetService.updateSnippet(updatedSnippet)
                        }
                        editingSnippetId = nil
                    },
                    onCancelEdit: {
                        editingSnippetId = nil
                        editingName = ""
                    }
                )
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        editingSnippetId = snippet.id
                        editingName = snippet.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        snippetToDelete = snippet
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

/// Row for snippet in the library list
struct SnippetListRow: View {
    let snippet: HabitSnippet
    let isEditing: Bool
    @Binding var editingName: String
    let onStartEdit: () -> Void
    let onSaveEdit: () -> Void
    let onCancelEdit: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: snippet.icon)
                .font(.title2)
                .foregroundStyle(snippet.swiftUIColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Snippet name", text: $editingName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .focused($isTextFieldFocused)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            onSaveEdit()
                        }
                        .onAppear {
                            isTextFieldFocused = true
                        }
                } else {
                    Text(snippet.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("\(snippet.habitCount) habit\(snippet.habitCount == 1 ? "" : "s")")
                    Text("•")
                    Text(snippet.estimatedDuration.formattedDuration)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isEditing {
                HStack(spacing: 8) {
                    Button("Cancel") {
                        onCancelEdit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Button("Save") {
                        onSaveEdit()
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(snippet.createdDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}