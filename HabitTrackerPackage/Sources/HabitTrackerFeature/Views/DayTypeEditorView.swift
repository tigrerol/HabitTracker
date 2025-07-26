import SwiftUI

/// View for customizing day type definitions
struct DayTypeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var dayTypeSettings: DayTypeSettings = DayTypeSettings.default
    @State private var hasChanges = false
    @State private var showingPresets = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Customize which days count as weekdays vs weekends to match your personal schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Day Types")
                }
                
                Section("Weekdays") {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        HStack {
                            Label {
                                Text(weekday.displayName)
                            } icon: {
                                Image(systemName: weekday.icon)
                                    .foregroundStyle(.blue)
                            }
                            
                            Spacer()
                            
                            Picker("Day Type", selection: Binding(
                                get: { dayTypeSettings.dayType(for: weekday) },
                                set: { newValue in
                                    dayTypeSettings.setDayType(newValue, for: weekday)
                                    hasChanges = true
                                }
                            )) {
                                Text("Weekday").tag(DayType.weekday)
                                Text("Weekend").tag(DayType.weekend)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text("Current Setting")
                            .fontWeight(.medium)
                        Spacer()
                        Text(dayTypeSettings.summary)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Summary")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Standard: Mon-Fri weekdays, Sat-Sun weekend")
                            Text("• Shift worker: Custom days based on your schedule")
                            Text("• Freelancer: Set your own work/rest days")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Tips")
                }
                
                Section {
                    Button("Choose Preset Schedule") {
                        showingPresets = true
                    }
                    .foregroundStyle(.blue)
                    
                    Button("Reset to Standard") {
                        dayTypeSettings = DayTypeSettings.default
                        hasChanges = true
                    }
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Day Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDayTypeSettings()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .onAppear {
            loadDayTypeSettings()
        }
        .sheet(isPresented: $showingPresets) {
            DayTypePresetsView { preset in
                dayTypeSettings = preset
                hasChanges = true
            }
        }
    }
    
    private func loadDayTypeSettings() {
        dayTypeSettings = DayTypeManager.shared.getDayTypeSettings()
    }
    
    private func saveDayTypeSettings() {
        DayTypeManager.shared.updateDayTypeSettings(dayTypeSettings)
    }
}

/// View for selecting day type presets
private struct DayTypePresetsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (DayTypeSettings) -> Void
    
    private let presets: [(name: String, description: String, settings: DayTypeSettings)] = [
        ("Standard Work Week", "Monday to Friday work, weekends off", createStandardWeek()),
        ("Sunday Work Week", "Sunday to Thursday work, Friday-Saturday off", createSundayWorkWeek()),
        ("4-Day Work Week", "Monday to Thursday work, Friday-Sunday off", createFourDayWeek()),
        ("Shift Worker (3 on, 4 off)", "Work Mon/Tue/Wed, off Thu-Sun", createShiftWorkerA()),
        ("Shift Worker (4 on, 3 off)", "Work Thu/Fri/Sat/Sun, off Mon-Wed", createShiftWorkerB()),
        ("Every Other Day", "Alternating work and rest days", createAlternatingSchedule()),
        ("All Weekdays", "Every day is a work day", createAllWeekdays()),
        ("All Weekends", "Every day is a rest day", createAllWeekends())
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose a preset schedule that matches your work pattern.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Preset Schedules")
                }
                
                ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                    Button {
                        onSelect(preset.settings)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text(preset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(preset.settings.summary)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Preset Schedules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Preset Creation Functions
    
    private static func createStandardWeek() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekday, for: .monday)
        settings.setDayType(.weekday, for: .tuesday)
        settings.setDayType(.weekday, for: .wednesday)
        settings.setDayType(.weekday, for: .thursday)
        settings.setDayType(.weekday, for: .friday)
        settings.setDayType(.weekend, for: .saturday)
        settings.setDayType(.weekend, for: .sunday)
        return settings
    }
    
    private static func createSundayWorkWeek() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekday, for: .sunday)
        settings.setDayType(.weekday, for: .monday)
        settings.setDayType(.weekday, for: .tuesday)
        settings.setDayType(.weekday, for: .wednesday)
        settings.setDayType(.weekday, for: .thursday)
        settings.setDayType(.weekend, for: .friday)
        settings.setDayType(.weekend, for: .saturday)
        return settings
    }
    
    private static func createFourDayWeek() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekday, for: .monday)
        settings.setDayType(.weekday, for: .tuesday)
        settings.setDayType(.weekday, for: .wednesday)
        settings.setDayType(.weekday, for: .thursday)
        settings.setDayType(.weekend, for: .friday)
        settings.setDayType(.weekend, for: .saturday)
        settings.setDayType(.weekend, for: .sunday)
        return settings
    }
    
    private static func createShiftWorkerA() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekday, for: .monday)
        settings.setDayType(.weekday, for: .tuesday)
        settings.setDayType(.weekday, for: .wednesday)
        settings.setDayType(.weekend, for: .thursday)
        settings.setDayType(.weekend, for: .friday)
        settings.setDayType(.weekend, for: .saturday)
        settings.setDayType(.weekend, for: .sunday)
        return settings
    }
    
    private static func createShiftWorkerB() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekend, for: .monday)
        settings.setDayType(.weekend, for: .tuesday)
        settings.setDayType(.weekend, for: .wednesday)
        settings.setDayType(.weekday, for: .thursday)
        settings.setDayType(.weekday, for: .friday)
        settings.setDayType(.weekday, for: .saturday)
        settings.setDayType(.weekday, for: .sunday)
        return settings
    }
    
    private static func createAlternatingSchedule() -> DayTypeSettings {
        var settings = DayTypeSettings()
        settings.setDayType(.weekday, for: .monday)
        settings.setDayType(.weekend, for: .tuesday)
        settings.setDayType(.weekday, for: .wednesday)
        settings.setDayType(.weekend, for: .thursday)
        settings.setDayType(.weekday, for: .friday)
        settings.setDayType(.weekend, for: .saturday)
        settings.setDayType(.weekday, for: .sunday)
        return settings
    }
    
    private static func createAllWeekdays() -> DayTypeSettings {
        var settings = DayTypeSettings()
        for weekday in Weekday.allCases {
            settings.setDayType(.weekday, for: weekday)
        }
        return settings
    }
    
    private static func createAllWeekends() -> DayTypeSettings {
        var settings = DayTypeSettings()
        for weekday in Weekday.allCases {
            settings.setDayType(.weekend, for: weekday)
        }
        return settings
    }
}

#Preview {
    DayTypeEditorView()
        .environment(RoutineService())
}