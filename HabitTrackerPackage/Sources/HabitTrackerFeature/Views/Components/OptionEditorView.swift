import SwiftUI

// MARK: - Supporting Types

struct EditingOptionData: Identifiable {
    let id = UUID()
    let habitId: UUID
    let option: ConditionalOption
}

// MARK: - Option Editor View

struct OptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var optionText: String
    let onSave: (ConditionalOption) -> Void
    
    private let option: ConditionalOption
    
    init(option: ConditionalOption, onSave: @escaping (ConditionalOption) -> Void) {
        self.option = option
        self.onSave = onSave
        self._optionText = State(initialValue: option.text)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Option Details") {
                    TextField("Option Text", text: $optionText)
                }
            }
            .navigationTitle("Edit Option")
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "RoutineBuilderView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedOption = ConditionalOption(
                            id: option.id,
                            text: optionText,
                            habits: option.habits
                        )
                        onSave(updatedOption)
                    }
                    .disabled(optionText.isEmpty)
                }
            }
        }
    }
}