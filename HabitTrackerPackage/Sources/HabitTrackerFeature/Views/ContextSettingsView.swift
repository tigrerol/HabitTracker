import SwiftUI
import UniformTypeIdentifiers

/// View for managing context settings (time slots, day types, and locations)
struct ContextSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var showingTimeSlotEditor = false
    @State private var showingDayTypeEditor = false
    @State private var showingLocationSetup = false
    @State private var savedLocationsCount = 0
    @State private var customLocationsCount = 0
    @State private var showingExportShare = false
    @State private var exportedFileURL: URL?
    @State private var showingFilePicker = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(localized: "ContextSettingsView.Description", bundle: .module))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(localized: "ContextSettingsView.SmartRoutineSettings", bundle: .module))
                }
                
                Section(String(localized: "ContextSettingsView.TimeOfDay", bundle: .module)) {
                    Button {
                        showingTimeSlotEditor = true
                    } label: {
                        SettingsRow(
                            title: String(localized: "ContextSettingsView.TimeSlots.Title", bundle: .module),
                            subtitle: String(localized: "ContextSettingsView.TimeSlots.Subtitle", bundle: .module),
                            icon: "clock",
                            detail: timeSlotSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section(String(localized: "ContextSettingsView.DayType", bundle: .module)) {
                    Button {
                        showingDayTypeEditor = true
                    } label: {
                        SettingsRow(
                            title: String(localized: "ContextSettingsView.WeekdaysWeekends.Title", bundle: .module),
                            subtitle: String(localized: "ContextSettingsView.WeekdaysWeekends.Subtitle", bundle: .module),
                            icon: "calendar",
                            detail: dayTypeSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section(String(localized: "ContextSettingsView.Location", bundle: .module)) {
                    Button {
                        showingLocationSetup = true
                    } label: {
                        SettingsRow(
                            title: String(localized: "ContextSettingsView.Locations.Title", bundle: .module),
                            subtitle: String(localized: "ContextSettingsView.Locations.Subtitle", bundle: .module),
                            icon: "location",
                            detail: locationSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "ContextSettingsView.CurrentContext", bundle: .module))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 16) {
                            Label(routineService.routineSelector.currentContext.timeSlot.displayName, 
                                  systemImage: routineService.routineSelector.currentContext.timeSlot.icon)
                            
                            Label(routineService.routineSelector.currentContext.dayCategory.displayName, 
                                  systemImage: routineService.routineSelector.currentContext.dayCategory.icon)
                            
                            if routineService.routineSelector.currentContext.location != .unknown {
                                Label(routineService.routineSelector.currentContext.location.displayName, 
                                      systemImage: routineService.routineSelector.currentContext.location.icon)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "ContextSettingsView.CurrentStatus", bundle: .module))
                }
                
                Section {
                    Button {
                        exportData()
                    } label: {
                        SettingsRow(
                            title: "Export Data",
                            subtitle: "Export all routines and settings as JSON",
                            icon: "square.and.arrow.up",
                            detail: ""
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        SettingsRow(
                            title: "Import Data",
                            subtitle: "Import routines and settings from JSON file",
                            icon: "square.and.arrow.down",
                            detail: ""
                        )
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Data Management")
                }
            }
            .navigationTitle(String(localized: "ContextSettingsView.NavigationTitle", bundle: .module))
            
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "ContextSettingsView.Done", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingTimeSlotEditor) {
            TimeSlotEditorView()
        }
        .sheet(isPresented: $showingDayTypeEditor) {
            DayTypeEditorView()
        }
        .sheet(isPresented: $showingLocationSetup) {
            LocationSetupView()
        }
        .sheet(isPresented: $showingExportShare) {
            if let exportedFileURL = exportedFileURL {
                ShareSheet(items: [exportedFileURL])
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result)
            }
        }
        .alert("Import Results", isPresented: $showingImportResult) {
            Button("OK") { }
        } message: {
            if let result = importResult {
                Text(formatImportResult(result))
            }
        }
        .task {
            savedLocationsCount = routineService.routineSelector.locationCoordinator.getSavedLocations().count
            customLocationsCount = routineService.routineSelector.locationCoordinator.getAllCustomLocations().count
        }
    }
    
    private var timeSlotSummary: String {
        let currentSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        return String(format: String(localized: "ContextSettingsView.TimeSlotSummary", bundle: .module), currentSlot.displayName)
    }
    
    private var dayTypeSummary: String {
        let currentCategory = DayCategoryManager.shared.getCurrentDayCategory()
        return String(format: String(localized: "ContextSettingsView.DayTypeSummary", bundle: .module), currentCategory.displayName)
    }
    
    private var locationSummary: String {
        let total = savedLocationsCount + customLocationsCount
        
        if total == 0 {
            return String(localized: "ContextSettingsView.NoLocationsSet", bundle: .module)
        } else {
            return String(format: String(localized: "ContextSettingsView.LocationsConfigured", bundle: .module), total, total == 1 ? "" : "s")
        }
    }
    
    private func exportData() {
        Task {
            do {
                let exportService = DataExportService(routineService: routineService)
                let jsonString = try exportService.exportToJSON()
                
                // Create a temporary file
                let tempDirectory = FileManager.default.temporaryDirectory
                let filename = exportService.generateExportFilename()
                let fileURL = tempDirectory.appendingPathComponent(filename)
                
                try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                
                await MainActor.run {
                    exportedFileURL = fileURL
                    showingExportShare = true
                }
            } catch {
                // Handle error - could show an alert
                print("Export failed: \(error)")
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        do {
            let fileURLs = try result.get()
            guard let fileURL = fileURLs.first else { return }
            
            let exportService = DataExportService(routineService: routineService)
            let result = try exportService.importFromFile(fileURL)
            
            await MainActor.run {
                importResult = result
                showingImportResult = true
            }
        } catch {
            await MainActor.run {
                // Create an error result
                let errorResult = ImportResult()
                importResult = errorResult
                showingImportResult = true
            }
            print("Import failed: \(error)")
        }
    }
    
    private func formatImportResult(_ result: ImportResult) -> String {
        var message = ""
        
        if result.hasImportedItems {
            message += "Successfully imported:\n"
            if result.routinesImported > 0 {
                message += "• \(result.routinesImported) routine\(result.routinesImported == 1 ? "" : "s")\n"
            }
            if result.customLocationsImported > 0 {
                message += "• \(result.customLocationsImported) custom location\(result.customLocationsImported == 1 ? "" : "s")\n"
            }
            if result.savedLocationsImported > 0 {
                message += "• \(result.savedLocationsImported) saved location\(result.savedLocationsImported == 1 ? "" : "s")\n"
            }
            if result.dayCategoriesImported > 0 {
                message += "• \(result.dayCategoriesImported) day categor\(result.dayCategoriesImported == 1 ? "y" : "ies")\n"
            }
        }
        
        if result.totalItemsSkipped > 0 {
            message += "\nSkipped \(result.totalItemsSkipped) duplicate item\(result.totalItemsSkipped == 1 ? "" : "s")"
        }
        
        if result.exportDate != nil, let version = result.sourceAppVersion {
            message += "\n\nImported from app version \(version)"
        }
        
        return message.isEmpty ? "No new items to import" : message
    }
}

/// Reusable settings row component
private struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let detail: String
    
    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContextSettingsView()
        .environment(RoutineService())
}