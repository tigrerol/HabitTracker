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
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .building:
                    buildingStepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .review:
                    reviewStepView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
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
                // Step indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                .accessibilityLabel("Step 1 of 3: Naming routine")
                .padding(.bottom, 8)
                
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
                        ForEach(Array(zip(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA"], ["Green", "Blue", "Orange", "Red", "Purple", "Light Blue"])), id: \.0) { color, colorName in
                            Button {
                                withAnimation(.easeInOut) {
                                    templateColor = color
                                }
                            } label: {
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
                            }
                            .accessibilityLabel("\(colorName) color")
                            .accessibilityValue(templateColor == color ? "Selected" : "Not selected")
                            .accessibilityAddTraits(templateColor == color ? .isSelected : [])
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
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
                    .scaleEffect(templateName.isEmpty ? 0.95 : 1.0)
            }
            .disabled(templateName.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: templateName.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Building Step
    
    private var buildingStepView: some View {
        VStack(spacing: 0) {
            // Enhanced progress header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(templateName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if habits.isEmpty {
                            Text("What's the first thing you do?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(habits.count) habits • \(totalDuration.formattedDuration) total")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Step indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    .accessibilityLabel("Step 2 of 3: Building routine")
                }
                
                if !habits.isEmpty {
                    Text("Keep adding habits or continue to review")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Prominent quick add section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add a habit")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        HabitQuickAddView { habit in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                habits.append(habit)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // Current habits section
                    if !habits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your routine")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("\(habits.count) habit\(habits.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.horizontal)
                            
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
                    }
                    
                    // Habit types section
                    suggestedHabitsSection
                        .padding(.bottom, 100) // Space for bottom buttons
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
            habitEditorView(for: habit)
        }
    }
    
    private var suggestedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Add habit type")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Tap to create")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(habitTypeOptions, id: \.type) { habitType in
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                let newHabit = createHabitFromType(habitType.type)
                                habits.append(newHabit)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: habitType.type.iconName)
                                    .font(.title3)
                                    .foregroundStyle(habitType.color)
                                    .frame(width: 32, height: 32)
                                
                                Text(habitType.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                
                                Text(habitType.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            .frame(width: 80)
                            .padding(.vertical, 12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private struct HabitTypeOption {
        let name: String
        let description: String
        let type: HabitType
        let color: Color
    }
    
    private var habitTypeOptions: [HabitTypeOption] {
        [
            HabitTypeOption(
                name: "Task",
                description: "Simple checkbox",
                type: .checkbox,
                color: .green
            ),
            HabitTypeOption(
                name: "Checklist",
                description: "Multiple steps",
                type: .checkboxWithSubtasks(subtasks: []),
                color: .green
            ),
            HabitTypeOption(
                name: "Timer",
                description: "Timed activity",
                type: .timer(defaultDuration: 300),
                color: .blue
            ),
            HabitTypeOption(
                name: "Rest Timer",
                description: "Track rest time",
                type: .restTimer(targetDuration: 120),
                color: .blue
            ),
            HabitTypeOption(
                name: "App/Shortcut",
                description: "Launch app",
                type: .appLaunch(bundleId: "", appName: ""),
                color: .red
            ),
            HabitTypeOption(
                name: "Website",
                description: "Open URL",
                type: .website(url: URL(string: "https://example.com")!, title: ""),
                color: .orange
            ),
            HabitTypeOption(
                name: "Counter",
                description: "Track items",
                type: .counter(items: ["Item 1"]),
                color: .yellow
            ),
            HabitTypeOption(
                name: "Measurement",
                description: "Record value",
                type: .measurement(unit: "value", targetValue: nil),
                color: .purple
            ),
            HabitTypeOption(
                name: "Sequence",
                description: "Guided steps",
                type: .guidedSequence(steps: []),
                color: .cyan
            ),
            HabitTypeOption(
                name: "Question",
                description: "Conditional path",
                type: .conditional(ConditionalHabitInfo(question: "", options: [])),
                color: .indigo
            )
        ]
    }
    
    private func createHabitFromType(_ type: HabitType) -> Habit {
        let name = getDefaultNameForType(type)
        let color = getColorForType(type)
        
        return Habit(
            name: name,
            type: type,
            color: color
        )
    }
    
    private func getDefaultNameForType(_ type: HabitType) -> String {
        switch type {
        case .checkbox:
            return "New Task"
        case .checkboxWithSubtasks:
            return "Task with Steps"
        case .timer:
            return "Timed Activity"
        case .restTimer:
            return "Rest Period"
        case .appLaunch:
            return "Run App"
        case .website:
            return "Visit Website"
        case .counter:
            return "Track Items"
        case .measurement:
            return "Record Measurement"
        case .guidedSequence:
            return "Guided Activity"
        case .conditional:
            return "Question"
        }
    }
    
    private func getColorForType(_ type: HabitType) -> String {
        switch type {
        case .checkbox, .checkboxWithSubtasks:
            return "#34C759" // Green
        case .timer, .restTimer:
            return "#007AFF" // Blue
        case .appLaunch:
            return "#FF3B30" // Red
        case .website:
            return "#FF9500" // Orange
        case .counter:
            return "#FFD60A" // Yellow
        case .measurement:
            return "#BF5AF2" // Purple
        case .guidedSequence:
            return "#64D2FF" // Light Blue
        case .conditional:
            return "#5856D6" // Indigo
        }
    }
    
    // MARK: - Review Step
    
    private var reviewStepView: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Step indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                        }
                        .accessibilityLabel("Step 3 of 3: Review routine")
                        .padding(.bottom, 4)
                        
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
    
    @ViewBuilder
    private func habitEditorView(for habit: Habit) -> some View {
        switch habit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: habit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 0
            ) { updatedHabit in
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index] = updatedHabit
                }
            }
        default:
            HabitEditorView(habit: habit) { updatedHabit in
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[index] = updatedHabit
                }
            }
        }
    }
    
    private func getAllAvailableHabits() -> [Habit] {
        // Get all habits from all templates to use as a library
        routineService.templates.flatMap { $0.habits }
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
// HabitRowView is now imported from its own file

#Preview {
    RoutineBuilderView()
        .environment(RoutineService())
}