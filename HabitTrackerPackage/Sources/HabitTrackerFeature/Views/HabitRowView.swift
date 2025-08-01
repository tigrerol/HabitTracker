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
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            // Show options for conditional habits
            if case .conditional(let info) = habit.type {
                conditionalOptionsContent(info: info)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.name), \(habit.type.description), estimated duration \(habit.estimatedDuration.formattedDuration)")
        .accessibilityHint("Double tap to edit, or use actions")
        .accessibilityActions {
            Button("Edit") { onEdit() }
            Button("Delete") { onDelete() }
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
                List(Array(info.options.enumerated()), id: \.element.id) { index, option in
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
                                
                                Text(option.habits.count == 1 ? 
                                     String(format: String(localized: "HabitRowView.HabitSingular", bundle: .module), option.habits.count) :
                                     String(format: String(localized: "HabitRowView.HabitPlural", bundle: .module), option.habits.count))
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
                        
                        // Habits for this option (indented to show hierarchy)
                        if !option.habits.isEmpty {
                            List(option.habits) { habit in
                                HStack {
                                    // Visual indentation - color-coded line to show hierarchy
                                    Rectangle()
                                        .fill(optionColor.opacity(0.3))
                                        .frame(width: 3, height: 24)
                                        .cornerRadius(1.5)
                                    
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
                                .padding(.leading, 32) // Additional left padding for indentation
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(height: CGFloat(option.habits.count) * 56)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(info.options.count) * 120)
            }
        }
    }
    
    private var optionColors: [Color] {
        [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
    }
}