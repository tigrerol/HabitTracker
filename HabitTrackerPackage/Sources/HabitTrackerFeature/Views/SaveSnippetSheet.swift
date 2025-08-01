import SwiftUI

/// Sheet for creating a new habit snippet from selected habits
struct SaveSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    let selectedHabits: [Habit]
    let onSave: () -> Void
    let onCancel: (() -> Void)?
    
    @State private var snippetName: String = ""
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with modern card
                    ModernCard(style: .frosted) {
                        VStack(spacing: 16) {
                            // Icon and title section
                            VStack(spacing: 12) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.accent)
                                
                                Text("Save Snippet")
                                    .customTitle()
                                
                                Text("Create a reusable collection of habits")
                                    .customBody()
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Input field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Snippet Name")
                                    .customHeadline()
                                
                                TextField("Enter snippet name", text: $snippetName)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isNameFieldFocused)
                            }
                        }
                    }
                    
                    // Habits preview section
                    if !selectedHabits.isEmpty {
                        ModernCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Habits in this snippet")
                                    .customHeadline()
                                
                                // Habit preview cards in grid
                                LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                                    ForEach(selectedHabits) { habit in
                                        HabitCard(habit: habit, isSelected: false) { }
                                            .disabled(true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("New Snippet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            
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
        .task {
            // Small delay to ensure TextField is fully rendered before focusing
            try? await Task.sleep(for: .milliseconds(100))
            isNameFieldFocused = true
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