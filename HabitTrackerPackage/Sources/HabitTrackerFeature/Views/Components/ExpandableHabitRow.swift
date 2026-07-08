import SwiftUI

// MARK: - Expandable Habit Row
struct ExpandableHabitRow: View {
    @Binding var habit: Habit
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main habit row
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if hasExpandableContent {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: habit.type.iconName)
                        .font(.caption)
                        .foregroundStyle(habit.swiftUIColor)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        
                        Text(habit.type.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if hasExpandableContent {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.3), value: isExpanded)
                    }
                    
                    Text(String(localized: "RoutineBuilderView.Duration.Label", bundle: .module).replacingOccurrences(of: "%@", with: habit.estimatedDuration.formattedDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            
            // Always show conditional options (not expandable)
            if case .conditional(let info) = habit.type {
                conditionalOptionsContent(info: info)
            }
            
            // Expandable content for subtasks only
            if isExpanded && hasExpandableContent {
                expandableContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
            }
        }
    }
    
    private var hasExpandableContent: Bool {
        switch habit.type {
        case .task(let subtasks, _, _):
            return !subtasks.isEmpty
        default:
            return false
        }
    }

    @ViewBuilder
    private var expandableContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch habit.type {
            case .conditional(let info):
                conditionalOptionsContent(info: info)
            case .task(let subtasks, _, _):
                if !subtasks.isEmpty {
                    subtasksContent(subtasks: subtasks)
                }
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
        .background(Color.gray.opacity(0.1).opacity(0.5))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func conditionalOptionsContent(info: ConditionalHabitInfo) -> some View {
        VStack(spacing: 8) {
            // Options displayed exactly like main habit rows
            if !info.options.isEmpty {
                ForEach(Array(info.options.enumerated()), id: \.element.id) { index, option in
                    let optionColor = ConditionalOptionPalette.color(at: index)
                    
                    VStack(spacing: 8) {
                        // Option in identical format to main habit row
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(optionColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                Text(option.habits.count == 1 ? String(localized: "RoutineBuilderView.Building.HabitCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(option.habits.count)") : String(localized: "RoutineBuilderView.Building.HabitsCount.Plural", bundle: .module).replacingOccurrences(of: "%lld", with: "\(option.habits.count)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(String(localized: "RoutineBuilderView.Duration.Default", bundle: .module))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        
                        // Habits for this option
                        if !option.habits.isEmpty {
                            ForEach(option.habits) { habit in
                                HStack {
                                    Image(systemName: habit.type.iconName)
                                        .font(.caption)
                                        .foregroundStyle(optionColor)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habit.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        
                                        Text(habit.type.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(String(localized: "RoutineBuilderView.Duration.Label", bundle: .module).replacingOccurrences(of: "%@", with: habit.estimatedDuration.formattedDuration))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    
    @ViewBuilder
    private func subtasksContent(subtasks: [Subtask]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "RoutineBuilderView.Subtasks.Title", bundle: .module).replacingOccurrences(of: "%d", with: "\(subtasks.count)"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    addSubtask()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if !subtasks.isEmpty {
                ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                    HStack {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        TextField("Subtask name", text: Binding(
                            get: { subtask.name },
                            set: { newName in
                                updateSubtaskName(at: index, newName: newName)
                            }
                        ))
                        .font(.caption)
                        .textFieldStyle(.plain)
                        
                        Button {
                            removeSubtask(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text(String(localized: "RoutineBuilderView.Subtasks.NoSubtasks", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }
    
    private func addSubtask() {
        guard case .task(var subtasks, let minRequired, let duration) = habit.type else { return }

        let newSubtask = Subtask(name: "New subtask")
        subtasks.append(newSubtask)
        habit.type = .task(subtasks: subtasks, minRequired: minRequired, estimatedDuration: duration)
    }

    private func removeSubtask(at index: Int) {
        guard case .task(var subtasks, let minRequired, let duration) = habit.type else { return }
        guard index < subtasks.count else { return }

        subtasks.remove(at: index)
        habit.type = .task(subtasks: subtasks, minRequired: minRequired, estimatedDuration: duration)
    }

    private func updateSubtaskName(at index: Int, newName: String) {
        guard case .task(var subtasks, let minRequired, let duration) = habit.type else { return }
        guard index < subtasks.count else { return }

        subtasks[index].name = newName
        habit.type = .task(subtasks: subtasks, minRequired: minRequired, estimatedDuration: duration)
    }
}
