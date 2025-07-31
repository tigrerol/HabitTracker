import SwiftUI

/// Sheet for creating a new habit snippet from selected habits
struct SaveSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    let selectedHabits: [Habit]
    let onSave: () -> Void
    let onCancel: (() -> Void)?
    
    @State private var snippetName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("Save snippet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Create a reusable collection of habits")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Snippet Name")
                        .font(.headline)
                    
                    TextField("Enter snippet name", text: $snippetName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Habits in this snippet")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(selectedHabits) { habit in
                            HStack {
                                Image(systemName: habit.type.iconName)
                                    .foregroundStyle(Color(hex: habit.color) ?? .blue)
                                Text(habit.name)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Snippet")
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSnippet()
                    }
                    .disabled(snippetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveSnippet() {
        let trimmedName = snippetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let snippet = HabitSnippet(name: trimmedName, habits: selectedHabits)
        routineService.snippetService.saveSnippet(snippet)
        
        onSave()
        dismiss()
    }
}