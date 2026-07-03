import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Shows the AI prompt with a Copy button. The user pastes this into any AI
/// chat, adds their routine description, then brings the returned JSON back
/// through `AIRoutineImportView`.
struct AIPromptCopyView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Copy this prompt and paste it into ChatGPT, Claude, Gemini, or any chat AI. Replace the placeholder at the bottom with what kind of routine you want.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(AIRoutinePrompt.text)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("AI Prompt")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        copyPromptToClipboard()
                        withAnimation { didCopy = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { didCopy = false }
                        }
                    } label: {
                        Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }
}

extension AIPromptCopyView {
    private func copyPromptToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = AIRoutinePrompt.text
        #endif
    }
}

#Preview {
    AIPromptCopyView()
}
