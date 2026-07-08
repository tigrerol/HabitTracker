import SwiftUI

// MARK: - Selectable Question Habit Row

struct SelectableQuestionHabitRow: View {
    let habit: Habit
    let isSelected: Bool
    let selectedOption: (habitId: UUID, optionId: UUID)?
    let onSelect: () -> Void
    let onOptionSelect: (UUID) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onEditOption: (UUID) -> Void
    let onDeleteOption: (UUID) -> Void
    let onEditSubHabit: (UUID, UUID) -> Void
    let onDeleteSubHabit: (UUID, UUID) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Main habit row (selectable)
            HStack {
                Image(systemName: habit.type.iconName)
                    .font(.body)
                    .foregroundStyle(habit.swiftUIColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(habit.type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.blue)
                }
                
                Text(habit.estimatedDuration.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onSelect()
            }
            
            // Show options for conditional habits
            if case .conditional(let info) = habit.type {
                conditionalOptionsContent(info: info)
            }
        }
    }
    
    @ViewBuilder
    private func conditionalOptionsContent(info: ConditionalHabitInfo) -> some View {
        VStack(spacing: 8) {
            // Options displayed exactly like main habit rows
            if !info.options.isEmpty {
                ForEach(Array(info.options.enumerated()), id: \.element.id) { index, option in
                    let optionColor = ConditionalOptionPalette.color(at: index)
                    
                    VStack(spacing: 8) {
                        // Option in identical format to main habit row (selectable)
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.body)
                                .foregroundStyle(optionColor)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.text)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                
                                Text(option.habits.count == 1 ? String(localized: "RoutineBuilderView.Building.HabitCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(option.habits.count)") : String(localized: "RoutineBuilderView.Building.HabitsCount.Plural", bundle: .module).replacingOccurrences(of: "%lld", with: "\(option.habits.count)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Show selection indicator for this option
                            if let selection = selectedOption, 
                               selection.habitId == habit.id && selection.optionId == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }
                            
                            Text(String(localized: "RoutineBuilderView.Duration.Default", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            
                            // Edit and Delete buttons for options
                            HStack(spacing: 8) {
                                Button {
                                    onEditOption(option.id)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedOption?.optionId == option.id) // Disable if this option is selected
                                
                                Button {
                                    onDeleteOption(option.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.regularMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            (selectedOption?.habitId == habit.id && selectedOption?.optionId == option.id) ? .blue : .clear, 
                                            lineWidth: 2
                                        )
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onOptionSelect(option.id)
                        }
                        
                        // Habits for this option (indented to show hierarchy)
                        if !option.habits.isEmpty {
                            ForEach(option.habits) { habit in
                                HStack {
                                    // Visual indentation - 10% of the container width
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
                                    
                                    Text(String(localized: "RoutineBuilderView.Duration.Label", bundle: .module).replacingOccurrences(of: "%@", with: habit.estimatedDuration.formattedDuration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    
                                    // Edit and Delete buttons for sub-habits
                                    HStack(spacing: 8) {
                                        Button {
                                            onEditSubHabit(option.id, habit.id)
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
                                            onDeleteSubHabit(option.id, habit.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .padding(.leading, 32) // Additional left padding for indentation
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }
    
}
