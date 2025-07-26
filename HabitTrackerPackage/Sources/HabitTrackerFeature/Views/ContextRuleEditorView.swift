import SwiftUI

/// View for editing context rules that determine when a routine should be selected
struct ContextRuleEditorView: View {
    @Binding var contextRule: RoutineContextRule?
    @Environment(\.dismiss) private var dismiss
    @Environment(DayCategoryManager.self) private var dayCategoryManager
    @Environment(RoutineService.self) private var routineService
    
    // Local state for editing
    @State private var selectedTimeSlots: Set<TimeSlot> = []
    @State private var selectedDayCategories: Set<String> = [] // Changed to store category IDs
    @State private var selectedLocationIds: Set<String> = [] // Changed to store location IDs
    @State private var priority: Int = 0
    @State private var isEnabled: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(String(localized: "ContextRuleEditorView.EnableSmartSelection.Toggle", bundle: .module), isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, newValue in
                            if !newValue {
                                // Clear all selections when disabled
                                selectedTimeSlots.removeAll()
                                selectedDayCategories.removeAll()
                                selectedLocationIds.removeAll()
                                priority = 0
                            }
                        }
                } header: {
                    Text(String(localized: "ContextRuleEditorView.SmartSelection.Header", bundle: .module))
                } footer: {
                    Text(String(localized: "ContextRuleEditorView.SmartSelection.Footer", bundle: .module))
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
                        Text(String(localized: "ContextRuleEditorView.TimeOfDay.Header", bundle: .module))
                    } footer: {
                        Text(String(localized: "ContextRuleEditorView.TimeOfDay.Footer", bundle: .module))
                    }
                    
                    // Day Categories Section
                    Section {
                        ForEach(dayCategoryManager.getAllCategories(), id: \.id) { category in
                            MultipleSelectionRow(
                                title: category.displayName,
                                subtitle: nil,
                                icon: category.icon,
                                isSelected: selectedDayCategories.contains(category.id)
                            ) {
                                if selectedDayCategories.contains(category.id) {
                                    selectedDayCategories.remove(category.id)
                                } else {
                                    selectedDayCategories.insert(category.id)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "ContextRuleEditorView.DayType.Header", bundle: .module))
                    } footer: {
                        Text(String(localized: "ContextRuleEditorView.DayType.Footer", bundle: .module))
                    }
                    
                    // Locations Section
                    Section {
                        // Built-in locations
                        ForEach(LocationType.allCases.filter { $0 != .unknown }, id: \.self) { location in
                            MultipleSelectionRow(
                                title: location.displayName,
                                subtitle: nil,
                                icon: location.icon,
                                isSelected: selectedLocationIds.contains(location.rawValue)
                            ) {
                                if selectedLocationIds.contains(location.rawValue) {
                                    selectedLocationIds.remove(location.rawValue)
                                } else {
                                    selectedLocationIds.insert(location.rawValue)
                                }
                            }
                        }
                        
                        // Custom locations
                        let customLocations = routineService.smartSelector.locationManager.allCustomLocations
                        ForEach(customLocations) { customLocation in
                            MultipleSelectionRow(
                                title: customLocation.name,
                                subtitle: nil,
                                icon: customLocation.icon,
                                isSelected: selectedLocationIds.contains(customLocation.id.uuidString)
                            ) {
                                if selectedLocationIds.contains(customLocation.id.uuidString) {
                                    selectedLocationIds.remove(customLocation.id.uuidString)
                                } else {
                                    selectedLocationIds.insert(customLocation.id.uuidString)
                                }
                            }
                        }
                    } header: {
                        Text(String(localized: "ContextRuleEditorView.Location.Header", bundle: .module))
                    } footer: {
                        Text(String(localized: "ContextRuleEditorView.Location.Footer", bundle: .module))
                    }
                    
                    // Priority Section
                    Section {
                        Stepper(value: $priority, in: 0...10) {
                            HStack {
                                Text(String(localized: "ContextRuleEditorView.Priority.Label", bundle: .module))
                                Spacer()
                                Text("\(priority)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(String(localized: "ContextRuleEditorView.Priority.Header", bundle: .module))
                    } footer: {
                        Text(String(localized: "ContextRuleEditorView.Priority.Footer", bundle: .module))
                    }
                }
            }
            .navigationTitle(String(localized: "ContextRuleEditorView.NavigationTitle", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "ContextRuleEditorView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "ContextRuleEditorView.Done.Button", bundle: .module)) {
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
            selectedDayCategories = rule.dayCategoryIds
            selectedLocationIds = rule.locationIds
            priority = rule.priority
        } else {
            isEnabled = false
        }
    }
    
    private func saveContextRule() {
        if isEnabled {
            contextRule = RoutineContextRule(
                timeSlots: selectedTimeSlots,
                dayCategoryIds: selectedDayCategories,
                locationIds: selectedLocationIds,
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