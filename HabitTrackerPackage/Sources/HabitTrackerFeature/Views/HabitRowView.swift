import SwiftUI

/// Reusable row view for displaying habits in lists
public struct HabitRowView: View {
    let habit: Habit
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    public init(habit: Habit, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.habit = habit
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Main habit row
            HStack {
                Image(systemName: habit.type.iconName)
                    .font(.body)
                    .foregroundStyle(habit.swiftUIColor)
                    .frame(width: 32)
                    .accessibilityHidden(true) // Icon is decorative, text provides the info
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(habit.type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(habit.estimatedDuration.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 28, height: 28)
                            .background(.blue.opacity(0.1), in: Circle())
                    }
                    .accessibilityLabel("Edit habit")
                    
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                            .background(.red.opacity(0.1), in: Circle())
                    }
                    .accessibilityLabel("Delete habit")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            // Show options for conditional habits
            if case .conditional(let info) = habit.type {
                conditionalOptionsContent(info: info)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(habit.type.description), estimated duration \(habit.estimatedDuration.formattedDuration)")
        .accessibilityHint("Double tap to edit, or use actions")
        .accessibilityActions {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Habit", systemImage: "pencil")
            }
            
            Button {
                // Could add duplicate functionality here in the future
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Habit", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Conditional Options Display
    
    @ViewBuilder
    private func conditionalOptionsContent(info: ConditionalHabitInfo) -> some View {
        VStack(spacing: 8) {
            // Options displayed exactly like main habit rows
            if !info.options.isEmpty {
                ForEach(Array(info.options.enumerated()), id: \.element.id) { index, option in
                    let optionColor = optionColors[index % optionColors.count]
                    
                    VStack(spacing: 8) {
                        // Option in identical format to main habit row
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.body)
                                .foregroundStyle(optionColor)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.text)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text("\(option.habits.count) habit\(option.habits.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("0:30")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        
                        // Habits for this option
                        if !option.habits.isEmpty {
                            ForEach(option.habits) { habit in
                                HStack {
                                    Image(systemName: habit.type.iconName)
                                        .font(.body)
                                        .foregroundStyle(optionColor)
                                        .frame(width: 32)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habit.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Text(habit.type.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(habit.estimatedDuration.formattedDuration)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var optionColors: [Color] {
        [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
    }
}