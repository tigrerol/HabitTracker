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
    @State private var editingHabitIndex: Int?
    @State private var editingSubHabit: (habitIndex: Int, optionId: UUID, subHabitId: UUID)?
    @State private var editingOptionData: (habitId: UUID, option: ConditionalOption)?
    @State private var isDefault = false
    @State private var expandedHabits: Set<UUID> = []
    @State private var selectedQuestionHabit: Habit?
    @State private var selectedOption: (habitId: UUID, optionId: UUID)?
    @State private var contextRule: RoutineContextRule?
    @State private var showingContextRuleEditor = false
    @State private var customLocations: [CustomLocation] = []
    
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
            .navigationTitle(editingTemplate != nil ? String(localized: "RoutineBuilderView.EditRoutine.NavigationTitle", bundle: .module) : String(localized: "RoutineBuilderView.CreateRoutine.NavigationTitle", bundle: .module))
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "RoutineBuilderView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let template = editingTemplate {
                // Initialize with existing template data
                templateName = template.name
                templateColor = template.color
                habits = template.habits
                isDefault = template.isDefault
                contextRule = template.contextRule
                currentStep = .review // Skip to review for editing
            }
        }
        .task {
            customLocations = routineService.routineSelector.locationCoordinator.getAllCustomLocations()
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
                .accessibilityLabel(String(localized: "Accessibility.Step1.Naming", bundle: .module))
                .padding(.bottom, 8)
                
                Text(String(localized: "RoutineBuilderView.Naming.Title", bundle: .module))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(String(localized: "RoutineBuilderView.Naming.Subtitle", bundle: .module))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 24) {
                TextField(String(localized: "RoutineBuilderView.Naming.RoutineName.Placeholder", bundle: .module), text: $templateName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                
                // Quick name suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([String(localized: "RoutineSuggestion.WeekdayMorning", bundle: .module), String(localized: "RoutineSuggestion.Weekend", bundle: .module), String(localized: "RoutineSuggestion.QuickStart", bundle: .module), String(localized: "RoutineSuggestion.FullRoutine", bundle: .module), String(localized: "RoutineSuggestion.Travel", bundle: .module)], id: \.self) { suggestion in
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
                    Text(String(localized: "RoutineBuilderView.Naming.Color.Label", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach(Array(zip(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA"], [String(localized: "Color.Green", bundle: .module), String(localized: "Color.Blue", bundle: .module), String(localized: "Color.Orange", bundle: .module), String(localized: "Color.Red", bundle: .module), String(localized: "Color.Purple", bundle: .module), String(localized: "Color.LightBlue", bundle: .module)])), id: \.0) { color, colorName in
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
                            .accessibilityLabel(String(localized: "Accessibility.ColorButton", bundle: .module).replacingOccurrences(of: "%@", with: colorName))
                            .accessibilityValue(templateColor == color ? String(localized: "Color.Selected", bundle: .module) : String(localized: "Color.NotSelected", bundle: .module))
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
                Text(String(localized: "RoutineBuilderView.Naming.Next.Button", bundle: .module))
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
                            Text(String(localized: "RoutineBuilderView.Building.Question", bundle: .module))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "RoutineBuilderView.Building.HabitsCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(habits.count)").replacingOccurrences(of: "%@", with: totalDuration.formattedDuration))
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
                    .accessibilityLabel(String(localized: "Accessibility.Step2.Building", bundle: .module))
                }
                
                if !habits.isEmpty {
                    Text(String(localized: "RoutineBuilderView.Building.Instructions", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(.regularMaterial)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Current habits section
                    if !habits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(String(localized: "RoutineBuilderView.Building.YourRoutine.Title", bundle: .module))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(habits.count == 1 ? String(localized: "RoutineBuilderView.Building.HabitCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(habits.count)") : String(localized: "RoutineBuilderView.Building.HabitsCount.Plural", bundle: .module).replacingOccurrences(of: "%lld", with: "\(habits.count)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(habits) { habit in
                                    if case .conditional = habit.type {
                                        SelectableQuestionHabitRow(
                                            habit: habit,
                                            isSelected: selectedQuestionHabit?.id == habit.id,
                                            selectedOption: selectedOption,
                                            onSelect: {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    selectedQuestionHabit = selectedQuestionHabit?.id == habit.id ? nil : habit
                                                    selectedOption = nil // Clear option selection when question selection changes
                                                }
                                            },
                                            onOptionSelect: { optionId in
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    if selectedOption?.optionId == optionId && selectedOption?.habitId == habit.id {
                                                        selectedOption = nil // Deselect if already selected
                                                    } else {
                                                        selectedOption = (habitId: habit.id, optionId: optionId)
                                                        selectedQuestionHabit = nil // Clear question selection when option is selected
                                                    }
                                                }
                                            },
                                            onEdit: {
                                                print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                                                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                                                    print("🔍 RoutineBuilderView: Found habit at index \(index)")
                                                    editingHabitIndex = index
                                                    editingHabit = habit
                                                }
                                            },
                                            onDelete: {
                                                withAnimation(.easeInOut) {
                                                    habits.removeAll { $0.id == habit.id }
                                                    if selectedQuestionHabit?.id == habit.id {
                                                        selectedQuestionHabit = nil
                                                    }
                                                    if selectedOption?.habitId == habit.id {
                                                        selectedOption = nil
                                                    }
                                                }
                                            },
                                            onEditOption: { optionId in
                                                // Edit option functionality
                                                if case .conditional(let info) = habit.type,
                                                   let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) {
                                                    let option = info.options[optionIndex]
                                                    editingOptionData = (habitId: habit.id, option: option)
                                                }
                                            },
                                            onDeleteOption: { optionId in
                                                // Delete option functionality
                                                withAnimation(.easeInOut) {
                                                    if case .conditional(let info) = habit.type {
                                                        var updatedOptions = info.options
                                                        updatedOptions.removeAll { $0.id == optionId }
                                                        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                                                        
                                                        if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                                                            var updatedHabit = habits[habitIndex]
                                                            updatedHabit.type = .conditional(updatedInfo)
                                                            habits[habitIndex] = updatedHabit
                                                        }
                                                        
                                                        // Clear selection if deleted option was selected
                                                        if selectedOption?.optionId == optionId {
                                                            selectedOption = nil
                                                        }
                                                    }
                                                }
                                            },
                                            onEditSubHabit: { optionId, subHabitId in
                                                // Edit sub-habit functionality
                                                if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                                                    editingSubHabit = (habitIndex: habitIndex, optionId: optionId, subHabitId: subHabitId)
                                                }
                                            },
                                            onDeleteSubHabit: { optionId, subHabitId in
                                                // Delete sub-habit functionality
                                                withAnimation(.easeInOut) {
                                                    if case .conditional(let info) = habit.type,
                                                       let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) {
                                                        var updatedOptions = info.options
                                                        updatedOptions[optionIndex].habits.removeAll { $0.id == subHabitId }
                                                        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                                                        
                                                        if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                                                            var updatedHabit = habits[habitIndex]
                                                            updatedHabit.type = .conditional(updatedInfo)
                                                            habits[habitIndex] = updatedHabit
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                    } else {
                                        HabitRowView(habit: habit) {
                                            print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                                            if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                                                print("🔍 RoutineBuilderView: Found habit at index \(index)")
                                                editingHabitIndex = index
                                                editingHabit = habit
                                            }
                                        } onDelete: {
                                            withAnimation(.easeInOut) {
                                                habits.removeAll { $0.id == habit.id }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Add Option section (when question is selected)
                    if let selectedQuestion = selectedQuestionHabit {
                        addOptionSection(for: selectedQuestion)
                    }
                    
                    // Habit types section (contextual based on selection)
                    if let selectedOption = selectedOption {
                        addHabitToOptionSection(for: selectedOption)
                    } else {
                        suggestedHabitsSection
                            .padding(.top, habits.isEmpty ? 20 : 0)
                    }
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom buttons
                }
            }
            
            // Bottom actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if habits.isEmpty {
                        Button {
                            currentStep = .naming
                        } label: {
                            Text(String(localized: "RoutineBuilderView.Building.Back.Button", bundle: .module))
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
                        Text(habits.isEmpty ? String(localized: "RoutineBuilderView.Building.Skip.Button", bundle: .module) : String(localized: "RoutineBuilderView.Building.Review.Button", bundle: .module))
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
        .sheet(isPresented: Binding(
            get: { editingHabitIndex != nil },
            set: { if !$0 { editingHabitIndex = nil; editingHabit = nil } }
        )) {
            if let index = editingHabitIndex, index < habits.count {
                let _ = print("🔍 RoutineBuilderView: Sheet presenting using index \(index)")
                habitEditorView(for: $habits[index])
            } else {
                VStack {
                    Text(String(localized: "RoutineBuilderView.Error.InvalidHabitIndex", bundle: .module))
                        .foregroundStyle(.red)
                    Button(String(localized: "RoutineBuilderView.Error.Close.Button", bundle: .module)) {
                        editingHabitIndex = nil
                        editingHabit = nil
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSubHabit != nil },
            set: { if !$0 { editingSubHabit = nil } }
        )) {
            if let editData = editingSubHabit,
               editData.habitIndex < habits.count,
               case .conditional(let info) = habits[editData.habitIndex].type,
               let optionIndex = info.options.firstIndex(where: { $0.id == editData.optionId }),
               let subHabitIndex = info.options[optionIndex].habits.firstIndex(where: { $0.id == editData.subHabitId }) {
                
                let _ = print("🔍 RoutineBuilderView: Sheet presenting sub-habit editor")
                subHabitEditorView(
                    habitIndex: editData.habitIndex,
                    optionIndex: optionIndex,
                    subHabitIndex: subHabitIndex
                )
            } else {
                VStack {
                    Text(String(localized: "RoutineBuilderView.Error.InvalidSubHabitReference", bundle: .module))
                        .foregroundStyle(.red)
                    Button(String(localized: "RoutineBuilderView.Error.Close.Button", bundle: .module)) {
                        editingSubHabit = nil
                    }
                }
                .padding()
            }
        }
        .sheet(item: Binding<EditingOptionData?>(
            get: { editingOptionData.map { EditingOptionData(habitId: $0.habitId, option: $0.option) } },
            set: { editingOptionData = $0.map { ($0.habitId, $0.option) } }
        )) { data in
            OptionEditorView(
                option: data.option,
                onSave: { updatedOption in
                    // Update the option in the habit
                    if case .conditional(let info) = habits.first(where: { $0.id == data.habitId })?.type,
                       let habitIndex = habits.firstIndex(where: { $0.id == data.habitId }),
                       let optionIndex = info.options.firstIndex(where: { $0.id == data.option.id }) {
                        var updatedOptions = info.options
                        updatedOptions[optionIndex] = updatedOption
                        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                        
                        var updatedHabit = habits[habitIndex]
                        updatedHabit.type = .conditional(updatedInfo)
                        habits[habitIndex] = updatedHabit
                    }
                    editingOptionData = nil
                }
            )
        }
    }
    
    private var suggestedHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "RoutineBuilderView.AddHabitType.Title", bundle: .module))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(localized: "RoutineBuilderView.AddHabitType.Subtitle", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(habitTypeOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = createHabitFromType(habitType.type)
                            habits.append(newHabit)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: habitType.type.iconName)
                                .font(.title2)
                                .foregroundStyle(habitType.color)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habitType.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                
                                Text(habitType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
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
                name: String(localized: "HabitType.Task.Name", bundle: .module),
                description: String(localized: "HabitType.Task.Description", bundle: .module),
                type: .checkbox,
                color: .green
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Checklist.Name", bundle: .module),
                description: String(localized: "HabitType.Checklist.Description", bundle: .module),
                type: .checkboxWithSubtasks(subtasks: []),
                color: .green
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Timer.Name", bundle: .module),
                description: String(localized: "HabitType.Timer.Description", bundle: .module),
                type: .timer(defaultDuration: 300),
                color: .blue
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.RestTimer.Name", bundle: .module),
                description: String(localized: "HabitType.RestTimer.Description", bundle: .module),
                type: .restTimer(targetDuration: 120),
                color: .blue
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.AppShortcut.Name", bundle: .module),
                description: String(localized: "HabitType.AppShortcut.Description", bundle: .module),
                type: .appLaunch(bundleId: "", appName: ""),
                color: .red
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Website.Name", bundle: .module),
                description: String(localized: "HabitType.Website.Description", bundle: .module),
                type: .website(url: URL(string: "https://example.com")!, title: ""),
                color: .orange
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Counter.Name", bundle: .module),
                description: String(localized: "HabitType.Counter.Description", bundle: .module),
                type: .counter(items: ["Item 1"]),
                color: .yellow
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Measurement.Name", bundle: .module),
                description: String(localized: "HabitType.Measurement.Description", bundle: .module),
                type: .measurement(unit: "value", targetValue: nil),
                color: .purple
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Sequence.Name", bundle: .module),
                description: String(localized: "HabitType.Sequence.Description", bundle: .module),
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
                        
                        if editingTemplate != nil {
                            TextField("Routine Name", text: $templateName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .textFieldStyle(.plain)
                        } else {
                            Text(templateName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text(String(localized: "RoutineBuilderView.Summary.HabitsCount", bundle: .module).replacingOccurrences(of: "%d", with: "\(habits.count)").replacingOccurrences(of: "%@", with: totalDuration.formattedDuration))
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
                
                // Smart Selection Configuration
                Button {
                    showingContextRuleEditor = true
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "RoutineBuilderView.Summary.SmartSelectionRules", bundle: .module))
                                    .foregroundStyle(.primary)
                                
                                if let rule = contextRule {
                                    Text(contextRuleSummary(rule))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(String(localized: "RoutineBuilderView.Summary.NotConfigured", bundle: .module))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.regularMaterial)
            
            if habits.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text(String(localized: "RoutineBuilderView.Summary.NoHabitsAdded", bundle: .module))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        currentStep = .building
                    } label: {
                        Text(String(localized: "RoutineBuilderView.Summary.AddHabits.Button", bundle: .module))
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        ExpandableHabitRow(
                            habit: Binding(
                                get: { habits[index] },
                                set: { habits[index] = $0 }
                            ),
                            isExpanded: Binding(
                                get: { expandedHabits.contains(habit.id) },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedHabits.insert(habit.id)
                                    } else {
                                        expandedHabits.remove(habit.id)
                                    }
                                }
                            )
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onMove { source, destination in
                        habits.move(fromOffsets: source, toOffset: destination)
                        updateHabitOrder()
                    }
                }
                .listStyle(.plain)
                
            }
            
            // Actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        currentStep = .building
                    } label: {
                        Text(String(localized: "RoutineBuilderView.Summary.Edit.Button", bundle: .module))
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
        .sheet(isPresented: $showingContextRuleEditor) {
            ContextRuleEditorView(contextRule: $contextRule)
        }
    }
    
    // MARK: - Helpers
    
    private var totalDuration: TimeInterval {
        let total = habits.reduce(0) { accum, habit in
            let duration = habit.estimatedDuration
            guard duration.isFinite, !duration.isNaN else { return accum }
            return accum + duration
        }
        return max(0, total)
    }
    
    /// Generate a human-readable summary of the context rule
    private func contextRuleSummary(_ rule: RoutineContextRule) -> String {
        var parts: [String] = []
        
        if !rule.timeSlots.isEmpty {
            let timeSlotNames = rule.timeSlots.map { $0.displayName }.sorted()
            parts.append("Time: \(timeSlotNames.joined(separator: ", "))")
        }
        
        if !rule.dayCategoryIds.isEmpty {
            let dayTypeNames = rule.dayCategoryIds.compactMap { categoryId in
                DayCategoryManager.shared.getAllCategories().first { $0.id == categoryId }?.displayName
            }.sorted()
            parts.append("Days: \(dayTypeNames.joined(separator: ", "))")
        }
        
        if !rule.locationIds.isEmpty {
            let locationNames = rule.locationIds.compactMap { locationId -> String? in
                // Check if it's a built-in location
                if let builtInLocation = LocationType(rawValue: locationId) {
                    return builtInLocation.displayName
                }
                // Check if it's a custom location
                if let uuid = UUID(uuidString: locationId),
                   let customLocation = customLocations.first(where: { $0.id == uuid }) {
                    return customLocation.name
                }
                return nil
            }.sorted()
            parts.append("Location: \(locationNames.joined(separator: ", "))")
        }
        
        if rule.priority > 0 {
            parts.append("Priority: \(rule.priority)")
        }
        
        return parts.isEmpty ? "Any time, any day, any location" : parts.joined(separator: " • ")
    }
    
    private func updateHabitOrder() {
        for (index, _) in habits.enumerated() {
            habits[index].order = index
        }
    }
    
    @ViewBuilder
    private func habitEditorView(for habitBinding: Binding<Habit>) -> some View {
        let habit = habitBinding.wrappedValue
        let _ = print("🔍 RoutineBuilderView: habitEditorView - Creating editor for habit '\(habit.name)' using direct binding")
        
        switch habit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: habit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 0
            ) { updatedHabit in
                print("🔍 RoutineBuilderView: ConditionalHabitEditorView onSave - updating via binding")
                habitBinding.wrappedValue = updatedHabit
            }
        default:
            HabitEditorView(habit: habit) { updatedHabit in
                print("🔍 RoutineBuilderView: HabitEditorView onSave - updating via binding")
                print("🔍 RoutineBuilderView: Updated habit type: \(updatedHabit.type)")
                habitBinding.wrappedValue = updatedHabit
            }
        }
    }
    
    @ViewBuilder
    private func subHabitEditorView(habitIndex: Int, optionIndex: Int, subHabitIndex: Int) -> some View {
        let _ = print("🔍 RoutineBuilderView: subHabitEditorView - Creating editor for sub-habit")
        
        // Create a binding to the specific sub-habit
        let subHabitBinding = Binding<Habit>(
            get: {
                if case .conditional(let info) = habits[habitIndex].type,
                   optionIndex < info.options.count,
                   subHabitIndex < info.options[optionIndex].habits.count {
                    return info.options[optionIndex].habits[subHabitIndex]
                }
                return Habit(name: "Error", type: .checkbox) // Fallback
            },
            set: { newHabit in
                print("🔍 RoutineBuilderView: subHabitEditorView - Updating sub-habit via binding")
                if case .conditional(let info) = habits[habitIndex].type,
                   optionIndex < info.options.count,
                   subHabitIndex < info.options[optionIndex].habits.count {
                    
                    var updatedOptions = info.options
                    updatedOptions[optionIndex].habits[subHabitIndex] = newHabit
                    let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                    habits[habitIndex].type = .conditional(updatedInfo)
                }
            }
        )
        
        let subHabit = subHabitBinding.wrappedValue
        
        switch subHabit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: subHabit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 1
            ) { updatedHabit in
                subHabitBinding.wrappedValue = updatedHabit
            }
        default:
            HabitEditorView(habit: subHabit) { updatedHabit in
                subHabitBinding.wrappedValue = updatedHabit
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
            updatedTemplate.contextRule = contextRule
            
            routineService.updateTemplate(updatedTemplate)
        } else {
            // Create new template
            let template = RoutineTemplate(
                name: templateName,
                habits: habits,
                color: templateColor,
                isDefault: isDefault,
                contextRule: contextRule
            )
            
            routineService.addTemplate(template)
        }
        
        dismiss()
    }
    
    // MARK: - Add Option Section
    
    @ViewBuilder
    private func addOptionSection(for selectedQuestion: Habit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "RoutineBuilderView.AddToQuestion", bundle: .module).replacingOccurrences(of: "%@", with: selectedQuestion.name))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(localized: "RoutineBuilderView.Selected.Label", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Button {
                addNewOptionToSelectedQuestion()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "RoutineBuilderView.AddOption.Button", bundle: .module))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text(String(localized: "RoutineBuilderView.CreateAnswerChoice", bundle: .module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
    
    private func addNewOptionToSelectedQuestion() {
        guard let selectedQuestion = selectedQuestionHabit,
              case .conditional(let info) = selectedQuestion.type,
              let habitIndex = habits.firstIndex(where: { $0.id == selectedQuestion.id }) else {
            return
        }
        
        // Add new option
        let newOption = ConditionalOption(
            text: "Option \(info.options.count + 1)",
            habits: []
        )
        
        // Create new info with updated options
        var updatedOptions = info.options
        updatedOptions.append(newOption)
        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
        
        // Update the habit
        var updatedHabit = selectedQuestion
        updatedHabit.type = .conditional(updatedInfo)
        habits[habitIndex] = updatedHabit
        
        // Update selectedQuestionHabit to reflect the changes
        selectedQuestionHabit = updatedHabit
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            // Trigger UI update
        }
    }
    
    @ViewBuilder
    private func addHabitToOptionSection(for selection: (habitId: UUID, optionId: UUID)) -> some View {
        if let selectedHabit = habits.first(where: { $0.id == selection.habitId }),
           case .conditional(let info) = selectedHabit.type,
           let selectedOptionData = info.options.first(where: { $0.id == selection.optionId }) {
            
            VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "RoutineBuilderView.AddHabitToOption", bundle: .module).replacingOccurrences(of: "%@", with: selectedOptionData.text))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(localized: "RoutineBuilderView.Selected.Label", bundle: .module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(habitTypeOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = createHabitFromType(habitType.type)
                            addHabitToSelectedOption(newHabit)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: habitType.type.iconName)
                                .font(.title2)
                                .foregroundStyle(habitType.color)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habitType.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                
                                Text(habitType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            }
        } else {
            EmptyView()
        }
    }
    
    private func addHabitToSelectedOption(_ newHabit: Habit) {
        guard let selection = selectedOption,
              let habitIndex = habits.firstIndex(where: { $0.id == selection.habitId }),
              case .conditional(let info) = habits[habitIndex].type,
              let optionIndex = info.options.firstIndex(where: { $0.id == selection.optionId }) else {
            return
        }
        
        // Add habit to the selected option
        var updatedOptions = info.options
        var updatedOption = updatedOptions[optionIndex]
        var habitWithOrder = newHabit
        habitWithOrder.order = updatedOption.habits.count
        updatedOption.habits.append(habitWithOrder)
        updatedOptions[optionIndex] = updatedOption
        
        // Update the conditional info
        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
        
        // Update the habit
        var updatedHabit = habits[habitIndex]
        updatedHabit.type = .conditional(updatedInfo)
        habits[habitIndex] = updatedHabit
    }
}

// MARK: - Supporting Views
// HabitRowView is now imported from its own file

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
        case .checkboxWithSubtasks:
            return true
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
            case .checkboxWithSubtasks(let subtasks):
                subtasksContent(subtasks: subtasks)
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
                    let optionColor = optionColors[index % optionColors.count]
                    
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
    
    private var optionColors: [Color] {
        [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
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
        guard case .checkboxWithSubtasks(var subtasks) = habit.type else { return }
        
        let newSubtask = Subtask(name: "New subtask")
        subtasks.append(newSubtask)
        habit.type = .checkboxWithSubtasks(subtasks: subtasks)
    }
    
    private func removeSubtask(at index: Int) {
        guard case .checkboxWithSubtasks(var subtasks) = habit.type else { return }
        guard index < subtasks.count else { return }
        
        subtasks.remove(at: index)
        habit.type = .checkboxWithSubtasks(subtasks: subtasks)
    }
    
    private func updateSubtaskName(at index: Int, newName: String) {
        guard case .checkboxWithSubtasks(var subtasks) = habit.type else { return }
        guard index < subtasks.count else { return }
        
        subtasks[index].name = newName
        habit.type = .checkboxWithSubtasks(subtasks: subtasks)
    }
}

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
            Button(action: onSelect) {
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
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(.plain)
            
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
                    let optionColor = optionColors[index % optionColors.count]
                    
                    VStack(spacing: 8) {
                        // Option in identical format to main habit row (selectable)
                        Button(action: { onOptionSelect(option.id) }) {
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
                                
                                HStack(spacing: 8) {
                                    Button {
                                        onEditOption(option.id)
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                            .frame(width: 28, height: 28)
                                            .background(.blue.opacity(0.1), in: Circle())
                                    }
                                    .accessibilityLabel("Edit option")
                                    
                                    Button {
                                        onDeleteOption(option.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .frame(width: 28, height: 28)
                                            .background(.red.opacity(0.1), in: Circle())
                                    }
                                    .accessibilityLabel("Delete option")
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
                        }
                        .buttonStyle(.plain)
                        
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
                                    
                                    HStack(spacing: 8) {
                                        Button {
                                            onEditSubHabit(option.id, habit.id)
                                        } label: {
                                            Image(systemName: "pencil")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                                .frame(width: 28, height: 28)
                                                .background(.blue.opacity(0.1), in: Circle())
                                        }
                                        .accessibilityLabel("Edit sub-habit")
                                        
                                        Button {
                                            onDeleteSubHabit(option.id, habit.id)
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                                .frame(width: 28, height: 28)
                                                .background(.red.opacity(0.1), in: Circle())
                                        }
                                        .accessibilityLabel("Delete sub-habit")
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
    
    private var optionColors: [Color] {
        [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
    }
}

#Preview {
    RoutineBuilderView()
        .environment(RoutineService())
}

// MARK: - Supporting Types

struct EditingOptionData: Identifiable {
    let id = UUID()
    let habitId: UUID
    let option: ConditionalOption
}

// MARK: - Option Editor View

struct OptionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var optionText: String
    let onSave: (ConditionalOption) -> Void
    
    private let option: ConditionalOption
    
    init(option: ConditionalOption, onSave: @escaping (ConditionalOption) -> Void) {
        self.option = option
        self.onSave = onSave
        self._optionText = State(initialValue: option.text)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Option Details") {
                    TextField("Option Text", text: $optionText)
                }
            }
            .navigationTitle("Edit Option")
            
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "RoutineBuilderView.Cancel.Button", bundle: .module)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedOption = ConditionalOption(
                            id: option.id,
                            text: optionText,
                            habits: option.habits
                        )
                        onSave(updatedOption)
                    }
                    .disabled(optionText.isEmpty)
                }
            }
        }
    }
}