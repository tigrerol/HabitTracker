import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Lets the user paste (or pick a file containing) an AI-generated routine JSON
/// and import it as a new `RoutineTemplate`.
struct AIRoutineImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService

    @State private var pastedText: String = ""
    @State private var showingFilePicker = false
    @State private var importedRoutineName: String?
    @State private var importedHabitCount: Int = 0
    @State private var showingSuccessAlert = false
    @State private var errorMessage: String?

    private let importService = RoutineImportService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Paste the JSON your AI returned, or choose a .json file. You'll get a fresh routine added to your list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("How it works")
                }

                Section {
                    TextEditor(text: $pastedText)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if pastedText.isEmpty {
                                Text("Paste routine JSON here…")
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        #if canImport(UIKit)
                        Button {
                            if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                                pastedText = clipboard
                            }
                        } label: {
                            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        }
                        #endif

                        Spacer()

                        if !pastedText.isEmpty {
                            Button(role: .destructive) {
                                pastedText = ""
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                        }
                    }
                    .font(.footnote)
                } header: {
                    Text("Routine JSON")
                }

                Section {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Label("Choose .json File…", systemImage: "folder")
                    }
                } header: {
                    Text("Or import from a file")
                }
            }
            .navigationTitle("Import Routine from AI")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { performImport() }
                        .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFilePick(result)
            }
            .alert("Routine Imported", isPresented: $showingSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                if let name = importedRoutineName {
                    Text("Added \"\(name)\" with \(importedHabitCount) habit\(importedHabitCount == 1 ? "" : "s").")
                }
            }
            .alert(
                "Import Failed",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func performImport() {
        do {
            let template = try importService.importRoutine(
                fromJSON: pastedText,
                existingTemplateNames: routineService.templates.map(\.name)
            )
            routineService.addTemplate(template)
            importedRoutineName = template.name
            importedHabitCount = template.habits.count
            showingSuccessAlert = true
        } catch let error as RoutineImportError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

            let contents = try String(contentsOf: url, encoding: .utf8)
            pastedText = contents
        } catch {
            errorMessage = "Couldn't read the file: \(error.localizedDescription)"
        }
    }
}

#Preview {
    AIRoutineImportView()
        .environment(RoutineService())
}
