import SwiftUI

/// View for customizing time slot definitions
struct TimeSlotEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var timeSlots: [TimeSlotDefinition] = []
    @State private var hasChanges = false
    @State private var showingAddTimeSlot = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Customize when each time slot occurs to match your personal schedule.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Time Slots")
                }
                
                ForEach($timeSlots) { $timeSlot in
                    TimeSlotRow(
                        timeSlot: $timeSlot,
                        canDelete: !timeSlot.isBuiltIn,
                        onChange: {
                            hasChanges = true
                        },
                        onDelete: {
                            deleteTimeSlot(timeSlot)
                        }
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let timeSlot = timeSlots[index]
                        if !timeSlot.isBuiltIn {
                            deleteTimeSlot(timeSlot)
                        }
                    }
                }
                
                Section {
                    Button {
                        showingAddTimeSlot = true
                    } label: {
                        Label("Add Custom Time Slot", systemImage: "plus.circle")
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it works:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Adjust the time ranges to match your schedule")
                            Text("• Times automatically wrap around midnight")
                            Text("• Changes apply to all smart routine suggestions")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Tips")
                }
            }
            .navigationTitle("Time Slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTimeSlots()
                        dismiss()
                    }
                    .disabled(!hasChanges)
                }
            }
        }
        .onAppear {
            loadTimeSlots()
        }
        .sheet(isPresented: $showingAddTimeSlot) {
            AddTimeSlotView { newTimeSlot in
                timeSlots.append(newTimeSlot)
                hasChanges = true
            }
        }
    }
    
    private func loadTimeSlots() {
        timeSlots = TimeSlotManager.shared.getAllTimeSlots()
    }
    
    private func saveTimeSlots() {
        TimeSlotManager.shared.updateTimeSlots(timeSlots)
    }
    
    private func deleteTimeSlot(_ timeSlot: TimeSlotDefinition) {
        if !timeSlot.isBuiltIn {
            timeSlots.removeAll { $0.id == timeSlot.id }
            hasChanges = true
        }
    }
}

/// Row for editing a single time slot
private struct TimeSlotRow: View {
    @Binding var timeSlot: TimeSlotDefinition
    let canDelete: Bool
    let onChange: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeSlot.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if !timeSlot.isBuiltIn {
                            Text("Custom")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.blue.opacity(0.1))
                                )
                        }
                    }
                } icon: {
                    Image(systemName: timeSlot.icon)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: { timeSlot.startTime.date },
                            set: { date in
                                timeSlot.startTime = TimeOfDay.from(date: date)
                                onChange()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { timeSlot.endTime.date },
                            set: { date in
                                timeSlot.endTime = TimeOfDay.from(date: date)
                                onChange()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }
            
            Text(timeSlot.timeRange)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

/// View for adding a new custom time slot
private struct AddTimeSlotView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (TimeSlotDefinition) -> Void
    
    @State private var name = ""
    @State private var icon = "clock"
    @State private var startTime = TimeOfDay(hour: 9, minute: 0)
    @State private var endTime = TimeOfDay(hour: 17, minute: 0)
    
    private let availableIcons = [
        "clock", "sunrise", "sun.min", "sun.max", "sun.max.fill", 
        "sunset", "moon", "moon.stars", "timer", "alarm",
        "stopwatch", "hourglass", "calendar.clock"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Time Slot Details") {
                    TextField("Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.title2)
                                        .foregroundStyle(icon == iconName ? .white : .blue)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(icon == iconName ? .blue : .clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section("Time Range") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            DatePicker(
                                "Start",
                                selection: Binding(
                                    get: { startTime.date },
                                    set: { startTime = TimeOfDay.from(date: $0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Time")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            DatePicker(
                                "End",
                                selection: Binding(
                                    get: { endTime.date },
                                    set: { endTime = TimeOfDay.from(date: $0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                    }
                    
                    if !name.isEmpty {
                        Label {
                            Text("\(startTime.formatted) - \(endTime.formatted)")
                        } icon: {
                            Image(systemName: icon)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Time Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newTimeSlot = TimeSlotDefinition(
                            name: name,
                            icon: icon,
                            startTime: startTime,
                            endTime: endTime,
                            isBuiltIn: false
                        )
                        onAdd(newTimeSlot)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TimeSlotEditorView()
        .environment(RoutineService())
}