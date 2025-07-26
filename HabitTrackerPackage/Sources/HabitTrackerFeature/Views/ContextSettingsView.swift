import SwiftUI

/// View for managing context settings (time slots, day types, and locations)
struct ContextSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var showingTimeSlotEditor = false
    @State private var showingDayTypeEditor = false
    @State private var showingLocationSetup = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Customize how the app determines the best routine for your current situation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Smart Routine Settings")
                }
                
                Section("Time of Day") {
                    Button {
                        showingTimeSlotEditor = true
                    } label: {
                        SettingsRow(
                            title: "Time Slots",
                            subtitle: "Customize when each time period occurs",
                            icon: "clock",
                            detail: timeSlotSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Day Type") {
                    Button {
                        showingDayTypeEditor = true
                    } label: {
                        SettingsRow(
                            title: "Weekdays & Weekends",
                            subtitle: "Define which days are work vs rest days",
                            icon: "calendar",
                            detail: dayTypeSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section("Location") {
                    Button {
                        showingLocationSetup = true
                    } label: {
                        SettingsRow(
                            title: "Locations",
                            subtitle: "Set up your important places",
                            icon: "location",
                            detail: locationSummary
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Context:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack(spacing: 16) {
                            Label(routineService.smartSelector.currentContext.timeSlot.displayName, 
                                  systemImage: routineService.smartSelector.currentContext.timeSlot.icon)
                            
                            Label(routineService.smartSelector.currentContext.dayType.displayName, 
                                  systemImage: routineService.smartSelector.currentContext.dayType.icon)
                            
                            if routineService.smartSelector.currentContext.location != .unknown {
                                Label(routineService.smartSelector.currentContext.location.displayName, 
                                      systemImage: routineService.smartSelector.currentContext.location.icon)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Current Status")
                }
            }
            .navigationTitle("Context Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
    }
    
    private var timeSlotSummary: String {
        let currentSlot = TimeSlotManager.shared.getCurrentTimeSlot()
        return "Currently: \(currentSlot.displayName)"
    }
    
    private var dayTypeSummary: String {
        let currentCategory = DayCategoryManager.shared.getCurrentDayCategory()
        return "Today: \(currentCategory.displayName)"
    }
    
    private var locationSummary: String {
        let builtInCount = routineService.smartSelector.locationManager.savedLocations.count
        let customCount = routineService.smartSelector.locationManager.allCustomLocations.count
        let total = builtInCount + customCount
        
        if total == 0 {
            return "No locations set"
        } else {
            return "\(total) location\(total == 1 ? "" : "s") configured"
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