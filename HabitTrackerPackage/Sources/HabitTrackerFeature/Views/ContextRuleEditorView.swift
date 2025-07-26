import SwiftUI

/// View for editing context rules that determine when a routine should be selected
struct ContextRuleEditorView: View {
    @Binding var contextRule: RoutineContextRule?
    @Environment(\.dismiss) private var dismiss
    
    // Local state for editing
    @State private var selectedTimeSlots: Set<TimeSlot> = []
    @State private var selectedDayTypes: Set<DayType> = []
    @State private var selectedLocations: Set<LocationType> = []
    @State private var priority: Int = 0
    @State private var isEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Smart Selection", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, newValue in
                            if !newValue {
                                // Clear all selections when disabled
                                selectedTimeSlots.removeAll()
                                selectedDayTypes.removeAll()
                                selectedLocations.removeAll()
                                priority = 0
                            }
                        }
                } header: {
                    Text("Smart Selection")
                } footer: {
                    Text("When enabled, this routine will be automatically selected based on time, day, and location.")
                }
                
                if isEnabled {
                    // Time Slots Section
                    Section {
                        ForEach(TimeSlot.allCases, id: \.self) { slot in
                            MultipleSelectionRow(
                                title: slot.displayName,
                                subtitle: slot.timeRange,
                                icon: slot.icon,
                                isSelected: selectedTimeSlots.contains(slot)
                            ) {
                                if selectedTimeSlots.contains(slot) {
                                    selectedTimeSlots.remove(slot)
                                } else {
                                    selectedTimeSlots.insert(slot)
                                }
                            }
                        }
                    } header: {
                        Text("Time of Day")
                    } footer: {
                        Text("Select when this routine should be suggested. Leave empty for any time.")
                    }
                    
                    // Day Types Section
                    Section {
                        ForEach(DayType.allCases, id: \.self) { dayType in
                            MultipleSelectionRow(
                                title: dayType.displayName,
                                subtitle: nil,
                                icon: dayType.icon,
                                isSelected: selectedDayTypes.contains(dayType)
                            ) {
                                if selectedDayTypes.contains(dayType) {
                                    selectedDayTypes.remove(dayType)
                                } else {
                                    selectedDayTypes.insert(dayType)
                                }
                            }
                        }
                    } header: {
                        Text("Day Type")
                    } footer: {
                        Text("Select which days this routine should be suggested. Leave empty for any day.")
                    }
                    
                    // Locations Section
                    Section {
                        ForEach(LocationType.allCases.filter { $0 != .unknown }, id: \.self) { location in
                            MultipleSelectionRow(
                                title: location.displayName,
                                subtitle: nil,
                                icon: location.icon,
                                isSelected: selectedLocations.contains(location)
                            ) {
                                if selectedLocations.contains(location) {
                                    selectedLocations.remove(location)
                                } else {
                                    selectedLocations.insert(location)
                                }
                            }
                        }
                    } header: {
                        Text("Location")
                    } footer: {
                        Text("Select where this routine should be suggested. Leave empty for any location.")
                    }
                    
                    // Priority Section
                    Section {
                        Stepper(value: $priority, in: 0...10) {
                            HStack {
                                Text("Priority")
                                Spacer()
                                Text("\(priority)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Priority")
                    } footer: {
                        Text("Higher priority routines are selected when multiple routines match the current context.")
                    }
                }
            }
            .navigationTitle("Smart Selection Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveContextRule()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadExistingRule()
        }
    }
    
    private func loadExistingRule() {
        if let rule = contextRule {
            isEnabled = true
            selectedTimeSlots = rule.timeSlots
            selectedDayTypes = rule.dayTypes
            selectedLocations = rule.locations
            priority = rule.priority
        } else {
            isEnabled = false
        }
    }
    
    private func saveContextRule() {
        if isEnabled {
            contextRule = RoutineContextRule(
                timeSlots: selectedTimeSlots,
                dayTypes: selectedDayTypes,
                locations: selectedLocations,
                priority: priority
            )
        } else {
            contextRule = nil
        }
    }
}

/// Row for multiple selection items
private struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(.primary)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContextRuleEditorView(contextRule: .constant(nil))
}