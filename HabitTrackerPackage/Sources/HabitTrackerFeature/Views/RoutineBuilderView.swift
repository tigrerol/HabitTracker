import SwiftUI

/// Step-by-step routine builder that guides users through creating their morning routine
@MainActor
public struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var templateName = ""
    @State private var templateColor = "#34C759"
    @State private var habits: [Habit] = []
    @State private var currentStep: BuilderStep = .naming
    @State private var editingHabit: Habit?
    @State private var isDefault = false
    
    enum BuilderStep {
        case naming
        case building
        case review
    }
    
    private let editingTemplate: RoutineTemplate?
    
    public init(editingTemplate: RoutineTemplate? = nil) {
        self.editingTemplate = editingTemplate
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .naming:
                    namingStepView
                case .building:
                    buildingStepView
                case .review:
                    reviewStepView
                }
            }
            .navigationTitle(editingTemplate != nil ? "Edit Routine" : "Create Routine")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .top, alignment: .trailing) {
                Text("Build: 2024.12.24.1847")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 16)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            if let template = editingTemplate {
                // Initialize with existing template data
                templateName = template.name
                templateColor = template.color
                habits = template.habits
                isDefault = template.isDefault
                currentStep = .review // Skip to review for editing
            }
        }
    }
    
    // MARK: - Naming Step
    
    private var namingStepView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Text("Let's name your routine")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a name that describes when you'll use this routine")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 24) {
                TextField("Routine Name", text: $templateName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                
                // Quick name suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(["Weekday Morning", "Weekend", "Quick Start", "Full Routine", "Travel"], id: \.self) { suggestion in
                            Button {
                                withAnimation(.easeInOut) {
                                    templateName = suggestion
                                }
                            } label: {
                                Text(suggestion)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA"], id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color) ?? .blue)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if templateColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        templateColor = color
                                    }
                                }
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut) {
                    currentStep = .building
                }
            } label: {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(templateName.isEmpty ? Color.gray : Color(hex: templateColor) ?? .blue)
                    )
            }
            .disabled(templateName.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Building Step
    
    private var buildingStepView: some View {
        VStack(spacing: 0) {
            // Progress header
            VStack(spacing: 12) {
                HStack {
                    Text(templateName)
                        .font(.headline)
                    
                    Spacer()
                    
                    if !habits.isEmpty {
                        Text("\(totalDuration.formattedDuration) total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if habits.isEmpty {
                    Text("What's the first thing you do?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Add another habit or continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Quick add bar
                    HabitQuickAddView { habit in
                        withAnimation(.easeInOut) {
                            habits.append(habit)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Current habits
                    if !habits.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(habits) { habit in
                                HabitRowView(habit: habit) {
                                    print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                                    editingHabit = habit
                                    print("🔍 RoutineBuilderView: Set editingHabit to \(habit.name)")
                                } onDelete: {
                                    withAnimation(.easeInOut) {
                                        habits.removeAll { $0.id == habit.id }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Suggested habits
                    if habits.count < 3 {
                        suggestedHabitsSection
                    }
                }
            }
            
            // Bottom actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if habits.isEmpty {
                        Button {
                            currentStep = .naming
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    Button {
                        if habits.isEmpty {
                            // Skip to review with empty routine
                            currentStep = .review
                        } else {
                            // Continue to review
                            withAnimation(.easeInOut) {
                                currentStep = .review
                            }
                        }
                    } label: {
                        Text(habits.isEmpty ? "Skip" : "Review")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: templateColor) ?? .blue)
                            )
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(item: $editingHabit) { habit in
            let _ = print("🔍 RoutineBuilderView: Sheet presenting with habit: \(habit.name), type: \(habit.type)")
            HabitEditorView(habit: habit) { updatedHabit in
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index] = updatedHabit
                }
            }
        }
    }
    
    private var suggestedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Common habits")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestedHabits, id: \.name) { suggestion in
                        Button {
                            withAnimation(.easeInOut) {
                                habits.append(suggestion)
                            }
                        } label: {
                            HStack {
                                Image(systemName: suggestion.type.iconName)
                                    .font(.caption)
                                Text(suggestion.name)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(habits.contains(where: { $0.name == suggestion.name }))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var suggestedHabits: [Habit] {
        var suggestions: [Habit] = []
        
        // Context-aware suggestions
        if habits.isEmpty {
            suggestions.append(Habit(name: "Wake up routine", type: .checkboxWithSubtasks(subtasks: [
                Subtask(name: "Turn off alarm"),
                Subtask(name: "Open curtains"),
                Subtask(name: "Drink water")
            ])))
            suggestions.append(Habit(name: "Check HRV", type: .appLaunch(bundleId: "com.morpheus.app", appName: "Morpheus")))
        }
        
        if habits.contains(where: { $0.name.lowercased().contains("hrv") || $0.name.lowercased().contains("morpheus") }) {
            suggestions.append(Habit(name: "Morning Stretch", type: .timer(defaultDuration: 600)))
            suggestions.append(Habit(name: "Workout", type: .website(url: URL(string: "https://workout.app")!, title: "Workout App")))
        }
        
        if habits.contains(where: { $0.name.lowercased().contains("workout") || $0.name.lowercased().contains("stretch") }) {
            suggestions.append(Habit(name: "Rest", type: .restTimer(targetDuration: 120)))
            suggestions.append(Habit(name: "Shower", type: .checkbox))
        }
        
        // Always suggest these
        suggestions.append(Habit(name: "Coffee", type: .checkbox))
        suggestions.append(Habit(name: "Supplements", type: .counter(items: ["Vitamin D", "Omega-3", "Magnesium"])))
        suggestions.append(Habit(name: "Meditation", type: .timer(defaultDuration: 600)))
        suggestions.append(Habit(name: "Journal", type: .checkbox))
        suggestions.append(Habit(name: "Weight", type: .measurement(unit: "kg", targetValue: nil)))
        
        return suggestions
    }
    
    // MARK: - Review Step
    
    private var reviewStepView: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(templateName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("\(habits.count) habits • \(totalDuration.formattedDuration)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color(hex: templateColor) ?? .blue)
                        .frame(width: 44, height: 44)
                }
                
                Toggle("Set as default routine", isOn: $isDefault)
                    .font(.subheadline)
            }
            .padding()
            .background(.regularMaterial)
            
            if habits.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No habits added")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        currentStep = .building
                    } label: {
                        Text("Add Habits")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        HStack {
                            Image(systemName: habit.type.iconName)
                                .font(.caption)
                                .foregroundStyle(habit.swiftUIColor)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .font(.subheadline)
                                
                                Text(habit.type.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(habit.estimatedDuration.formattedDuration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onMove { source, destination in
                        habits.move(fromOffsets: source, toOffset: destination)
                        updateHabitOrder()
                    }
                }
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
            }
            
            // Actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        currentStep = .building
                    } label: {
                        Text("Edit")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button {
                        saveTemplate()
                    } label: {
                        Text(editingTemplate != nil ? "Update Routine" : "Save Routine")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: templateColor) ?? .blue)
                            )
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
        }
    }
    
    // MARK: - Helpers
    
    private var totalDuration: TimeInterval {
        habits.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    private func updateHabitOrder() {
        for (index, _) in habits.enumerated() {
            habits[index].order = index
        }
    }
    
    private func saveTemplate() {
        updateHabitOrder()
        
        if let existingTemplate = editingTemplate {
            // Update existing template
            var updatedTemplate = existingTemplate
            updatedTemplate.name = templateName
            updatedTemplate.habits = habits
            updatedTemplate.color = templateColor
            updatedTemplate.isDefault = isDefault
            
            routineService.updateTemplate(updatedTemplate)
        } else {
            // Create new template
            let template = RoutineTemplate(
                name: templateName,
                habits: habits,
                color: templateColor,
                isDefault: isDefault
            )
            
            routineService.addTemplate(template)
        }
        
        dismiss()
    }
}

// MARK: - Supporting Views

private struct HabitRowView: View {
    let habit: Habit
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
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

#Preview {
    RoutineBuilderView()
        .environment(RoutineService())
}