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
        HStack {
            Image(systemName: habit.type.iconName)
                .font(.body)
                .foregroundStyle(habit.swiftUIColor)
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
            
            Text(habit.estimatedDuration.formattedDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}