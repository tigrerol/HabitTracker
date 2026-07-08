import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings View

/// The single settings root: appearance, sound, smart-routine context,
/// snippets, data export/import, and AI import all live here (the separate
/// "Context Settings" screen was folded in). Sub-editors present as sheets
/// because they carry their own NavigationStacks.
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RoutineService.self) private var routineService

    @AppStorage(FeedbackManager.soundEnabledKey) private var timerSoundEnabled: Bool = true

    @State private var showingThemeCustomization = false

    // Smart routine
    @State private var showingTimeSlotEditor = false
    @State private var showingDayTypeEditor = false
    @State private var showingLocationSetup = false
    @State private var showingContextCoverage = false
    @State private var savedLocationsCount = 0
    @State private var customLocationsCount = 0

    // Snippets
    @State private var showingSnippetLibrary = false

    // Data & AI
    @State private var showingExportShare = false
    @State private var exportedFileURL: URL?
    @State private var showingFilePicker = false
    @State private var showingImportResult = false
    @State private var importResult: ImportResult?

    public init() {}

    private var accentName: String {
        AccentPreset.all.first { $0.hex.lowercased() == themeManager.accentHex.lowercased() }?.name ?? "Custom"
    }

    public var body: some View {
        NavigationStack {
            List {
                appearanceSection
                soundSection
                smartRoutineSection
                currentContextSection
                snippetsSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingThemeCustomization) {
            ThemeCustomizationView()
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
        .sheet(isPresented: $showingContextCoverage) {
            ContextCoverageView()
        }
        .sheet(isPresented: $showingSnippetLibrary) {
            SnippetLibraryView()
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

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("Appearance") {
            Button {
                showingThemeCustomization = true
                HapticManager.trigger(.light)
            } label: {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.currentAccentColor, themeManager.currentAccentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Appearance")
                            .customSubheadline()

                        Text(accentName + " · " + themeManager.appearanceMode.displayName)
                            .customCaption()
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Current theme accent swatch
                    Circle()
                        .fill(themeManager.currentAccentColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(themeManager.currentAccentColor.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var soundSection: some View {
        Section("Sound & Haptics") {
            Toggle(isOn: $timerSoundEnabled) {
                HStack {
                    Image(systemName: timerSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.currentAccentColor, themeManager.currentAccentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timer Sound")
                            .customSubheadline()

                        Text("Play a sound when a timer completes")
                            .customCaption()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var smartRoutineSection: some View {
        Section {
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

            Button {
                showingContextCoverage = true
            } label: {
                SettingsRow(
                    title: "Coverage Overview",
                    subtitle: "Visualize routine assignments across contexts",
                    icon: "chart.bar.xaxis",
                    detail: ""
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text("Smart Routine")
        } footer: {
            Text(String(localized: "ContextSettingsView.Description", bundle: .module))
        }
    }

    private var currentContextSection: some View {
        Section {
            DisclosureGroup {
                currentContextDetails
            } label: {
                Label {
                    Text(String(localized: "ContextSettingsView.CurrentContext", bundle: .module))
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "scope")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                }
            }
        }
    }

    @ViewBuilder
    private var currentContextDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Label(routineService.routineSelector.currentContext.timeSlot.displayName,
                      systemImage: routineService.routineSelector.currentContext.timeSlot.icon)

                Label(routineService.routineSelector.currentContext.dayCategories.map(\.displayName).joined(separator: " + "),
                      systemImage: routineService.routineSelector.currentContext.dayCategories.first?.icon ?? "calendar")

                if case .custom = routineService.routineSelector.currentContext.extendedLocation {
                    Label(routineService.routineSelector.currentContext.extendedLocation.displayName,
                          systemImage: routineService.routineSelector.currentContext.extendedLocation.icon)
                } else if routineService.routineSelector.currentContext.location != .unknown {
                    Label(routineService.routineSelector.currentContext.location.displayName,
                          systemImage: routineService.routineSelector.currentContext.location.icon)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let location = routineService.routineSelector.locationCoordinator.currentLocation {
                Label(
                    String(format: "GPS: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude),
                    systemImage: "location.fill"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospaced()

                // Debug: show distance to each saved location
                let saved = routineService.routineSelector.locationCoordinator.getSavedLocations()
                let custom = routineService.routineSelector.locationCoordinator.getAllCustomLocations()

                if saved.isEmpty && custom.isEmpty {
                    Text("No saved locations found by coordinator")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                ForEach(Array(saved.keys), id: \.self) { locationType in
                    if let savedLoc = saved[locationType] {
                        let distance = location.distance(from: savedLoc.clLocation)
                        Text(String(format: "%@: %.1fm (radius: %.0fm) %@",
                                    locationType.displayName,
                                    distance,
                                    savedLoc.radius,
                                    distance <= savedLoc.radius ? "MATCH" : "no match"))
                            .font(.caption2)
                            .foregroundStyle(distance <= savedLoc.radius ? .green : .orange)
                            .monospaced()
                    }
                }

                ForEach(custom) { customLoc in
                    if let customCL = customLoc.clLocation {
                        let distance = location.distance(from: customCL)
                        Text(String(format: "%@: %.1fm (radius: %.0fm) %@",
                                    customLoc.name,
                                    distance,
                                    customLoc.radius,
                                    distance <= customLoc.radius ? "MATCH" : "no match"))
                            .font(.caption2)
                            .foregroundStyle(distance <= customLoc.radius ? .green : .orange)
                            .monospaced()
                    }
                }
            } else {
                Label("GPS: no location", systemImage: "location.slash")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var snippetsSection: some View {
        Section("Snippets") {
            Button {
                showingSnippetLibrary = true
            } label: {
                SettingsRow(
                    title: "Snippet Library",
                    subtitle: "Manage your saved habit collections",
                    icon: "square.stack.3d.up",
                    detail: "\(routineService.snippetService.snippets.count) snippet\(routineService.snippetService.snippets.count == 1 ? "" : "s")"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dataSection: some View {
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
            Text("Data")
        } footer: {
            Text("To create a routine with AI, use the + menu on the Today tab.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.currentAccentColor.opacity(0.7), themeManager.currentAccentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HabitTracker")
                        .customSubheadline()

                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"))")
                        .customCaption()
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Summaries

    private var timeSlotSummary: String {
        let currentSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        return String(format: String(localized: "ContextSettingsView.TimeSlotSummary", bundle: .module), currentSlot.displayName)
    }

    private var dayTypeSummary: String {
        let currentCategories = DayCategoryManager.shared.getCurrentDayCategories()
        let names = currentCategories.map(\.displayName).joined(separator: " + ")
        return String(format: String(localized: "ContextSettingsView.DayTypeSummary", bundle: .module), names)
    }

    private var locationSummary: String {
        let total = savedLocationsCount + customLocationsCount

        if total == 0 {
            return String(localized: "ContextSettingsView.NoLocationsSet", bundle: .module)
        } else {
            return String(format: String(localized: "ContextSettingsView.LocationsConfigured", bundle: .module), total, total == 1 ? "" : "s")
        }
    }

    // MARK: - Data Export / Import

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
                LoggingService.shared.error("Export failed: \(error.localizedDescription)", category: .app)
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
            LoggingService.shared.error("Import failed: \(error.localizedDescription)", category: .app)
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

// MARK: - Settings Row

/// Reusable settings row component
struct SettingsRow: View {
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

// MARK: - Share Sheet

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

// MARK: - Settings Button Component

public struct SettingsButton: View {
    @State private var showingSettings = false

    public init() {}

    public var body: some View {
        Button {
            showingSettings = true
            HapticManager.trigger(.light)
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    SettingsView()
        .environment(RoutineService())
        .withDynamicTheme()
}
