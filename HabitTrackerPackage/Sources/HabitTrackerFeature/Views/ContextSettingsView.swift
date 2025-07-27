import SwiftUI

/// View for managing context settings (time slots, day types, and locations)
struct ContextSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var showingTimeSlotEditor = false
    @State private var showingDayTypeEditor = false
    @State private var showingLocationSetup = false
    @State private var savedLocationsCount = 0
    @State private var customLocationsCount = 0
    
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
                            Label(routineService.smartSelector.currentContext.timeSlot.displayName, 
                                  systemImage: routineService.smartSelector.currentContext.timeSlot.icon)
                            
                            Label(routineService.smartSelector.currentContext.dayCategory.displayName, 
                                  systemImage: routineService.smartSelector.currentContext.dayCategory.icon)
                            
                            if routineService.smartSelector.currentContext.location != .unknown {
                                Label(routineService.smartSelector.currentContext.location.displayName, 
                                      systemImage: routineService.smartSelector.currentContext.location.icon)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "ContextSettingsView.CurrentStatus", bundle: .module))
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
        .task {
            savedLocationsCount = await routineService.smartSelector.locationManager.savedLocations.count
            customLocationsCount = await routineService.smartSelector.locationManager.allCustomLocations.count
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

#Preview {
    ContextSettingsView()
        .environment(RoutineService())
}