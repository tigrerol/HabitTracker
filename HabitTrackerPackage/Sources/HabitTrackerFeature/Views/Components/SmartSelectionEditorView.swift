import SwiftUI

/// Collapsible editor for a routine's smart-selection context rule
/// (time slots, day types, locations, priority). Extracted from
/// RoutineBuilderView, where it existed twice as identical copies.
struct SmartSelectionEditorView: View {
    @Binding var isExpanded: Bool
    @Binding var selectedTimeSlots: Set<TimeSlot>
    @Binding var selectedDayCategories: Set<String>
    @Binding var selectedLocationIds: Set<String>
    @Binding var priority: Int
    let customLocations: [CustomLocation]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure arrow
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Label {
                        Text("Smart Selection Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("When should this routine be suggested?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    
                    // Time Slots
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time of Day")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(TimeSlot.allCases, id: \.self) { slot in
                                Button {
                                    withAnimation(.easeInOut) {
                                        if selectedTimeSlots.contains(slot) {
                                            selectedTimeSlots.remove(slot)
                                        } else {
                                            selectedTimeSlots.insert(slot)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: slot.icon)
                                            .font(.caption)
                                            .frame(width: 16)
                                        
                                        Text(slot.displayName)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        if selectedTimeSlots.contains(slot) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedTimeSlots.contains(slot) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                            .stroke(selectedTimeSlots.contains(slot) ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Day Categories
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Day Type")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(DayCategoryManager.shared.getAllCategories(), id: \.id) { category in
                                Button {
                                    withAnimation(.easeInOut) {
                                        if selectedDayCategories.contains(category.id) {
                                            selectedDayCategories.remove(category.id)
                                        } else {
                                            selectedDayCategories.insert(category.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: category.icon)
                                            .font(.caption)
                                            .frame(width: 16)
                                            .foregroundStyle(category.color)
                                        
                                        Text(category.displayName)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        if selectedDayCategories.contains(category.id) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedDayCategories.contains(category.id) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                            .stroke(selectedDayCategories.contains(category.id) ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Locations
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            // Built-in locations
                            ForEach([LocationType.home, LocationType.office, LocationType.unknown], id: \.self) { locationType in
                                Button {
                                    withAnimation(.easeInOut) {
                                        let locationId = locationType.rawValue
                                        if selectedLocationIds.contains(locationId) {
                                            selectedLocationIds.remove(locationId)
                                        } else {
                                            selectedLocationIds.insert(locationId)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: locationType.icon)
                                            .font(.caption)
                                            .frame(width: 16)
                                        
                                        Text(locationType.displayName)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        if selectedLocationIds.contains(locationType.rawValue) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedLocationIds.contains(locationType.rawValue) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                            .stroke(selectedLocationIds.contains(locationType.rawValue) ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Custom locations
                            ForEach(customLocations, id: \.id) { location in
                                Button {
                                    withAnimation(.easeInOut) {
                                        let locationId = location.id.uuidString
                                        if selectedLocationIds.contains(locationId) {
                                            selectedLocationIds.remove(locationId)
                                        } else {
                                            selectedLocationIds.insert(locationId)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: location.icon)
                                            .font(.caption)
                                            .frame(width: 16)
                                        
                                        Text(location.name)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        if selectedLocationIds.contains(location.id.uuidString) {
                                            Image(systemName: "checkmark")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedLocationIds.contains(location.id.uuidString) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                            .stroke(selectedLocationIds.contains(location.id.uuidString) ? Color.blue : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Priority section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Priority")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text("Lower")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(priority) },
                                set: { priority = Int($0) }
                            ), in: 1...10, step: 1)
                            
                            Text("Higher")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("\(priority)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
