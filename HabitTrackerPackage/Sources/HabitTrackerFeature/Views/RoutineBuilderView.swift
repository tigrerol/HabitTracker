import SwiftUI

/// Step-by-step routine builder that guides users through creating their morning routine
@MainActor
public struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RoutineService.self) private var routineService
    
    @State private var templateName = ""
    @State private var templateColor = "#34C759"
    @FocusState private var isNameFieldFocused: Bool
    @State private var habits: [Habit] = []
    @State private var currentStep: BuilderStep = .naming
    @State private var editingHabit: Habit?
    @State private var editingHabitIndex: Int?
    @State private var newHabitBeingCreated: Habit?
    @State private var newOptionHabitBeingCreated: (habit: Habit, optionId: UUID, habitId: UUID)?
    @State private var editingSubHabit: (habitIndex: Int, optionId: UUID, subHabitId: UUID)?
    @State private var editingSubHabitData: Habit? // Store a copy of the sub-habit being edited
    @State private var editingOptionData: EditingOptionData?
    @State private var expandedHabits: Set<UUID> = []
    @State private var selectedQuestionHabit: Habit?
    @State private var selectedOption: (habitId: UUID, optionId: UUID)?
    @State private var contextRule: RoutineContextRule?
    @State private var customLocations: [CustomLocation] = []
    @State private var smartSelectionExpanded = false
    @State private var selectedTimeSlots: Set<TimeSlot> = []
    @State private var selectedDayCategories: Set<String> = []
    @State private var selectedLocationIds: Set<String> = []
    @State private var smartSelectionPriority: Int = 1
    @State private var selectedHabitsForSnippet: Set<UUID> = []
    @State private var showingSaveSnippetSheet = false
    @State private var isSelectingForSnippet = false
    @State private var showingSnippetBrowser = false
    
    enum BuilderStep {
        case naming
        case building
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
                contextRule = template.contextRule
                
                // Initialize smart selection state from existing context rule
                if let rule = template.contextRule {
                    selectedTimeSlots = Set(rule.timeSlots)
                    selectedDayCategories = Set(rule.dayCategoryIds)
                    selectedLocationIds = Set(rule.locationIds)
                    smartSelectionPriority = rule.priority
                }
                
                currentStep = .building // Go to building for editing
            }
        }
        .task {
            customLocations = routineService.routineSelector.locationCoordinator.getAllCustomLocations()
        }
    }
    
    // MARK: - Naming Step
    
    private var namingStepView: some View {
        VStack(spacing: 0) {
            // Fixed header with modern card
            ModernCard(style: .frosted) {
                VStack(spacing: 16) {
                    // Step indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    .accessibilityLabel(String(localized: "Accessibility.Step1.Naming", bundle: .module))
                    .padding(.bottom, 8)
                    
                    Text(String(localized: "RoutineBuilderView.Naming.Title", bundle: .module))
                        .customTitle()
                    
                    Text(String(localized: "RoutineBuilderView.Naming.Subtitle", bundle: .module))
                        .customCaption()
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Name input card
                    ModernCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(String(localized: "RoutineBuilderView.Naming.RoutineName.Placeholder", bundle: .module))
                                .customHeadline()
                            
                            TextField(String(localized: "RoutineBuilderView.Naming.RoutineName.Placeholder", bundle: .module), text: $templateName)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                                .focused($isNameFieldFocused)
                            
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
                                                .customBody()
                                                .foregroundColor(templateName == suggestion ? .white : Theme.text)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(templateName == suggestion ? Theme.accent : Theme.cardBackground, in: Capsule())
                                        }
                                        .buttonStyle(ModernButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                    
                    // Color picker card
                    ModernCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "RoutineBuilderView.Naming.Color.Label", bundle: .module))
                                .customHeadline()
                            
                            HStack(spacing: 12) {
                                ForEach(Array(zip(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA"], [String(localized: "Color.Green", bundle: .module), String(localized: "Color.Blue", bundle: .module), String(localized: "Color.Orange", bundle: .module), String(localized: "Color.Red", bundle: .module), String(localized: "Color.Purple", bundle: .module), String(localized: "Color.LightBlue", bundle: .module)])), id: \.0) { color, colorName in
                                    Button {
                                        withAnimation(.easeInOut) {
                                            templateColor = color
                                        }
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: color) ?? .blue)
                                            .frame(width: 40, height: 40)
                                            .overlay {
                                                if templateColor == color {
                                                    Circle()
                                                        .stroke(Theme.accent, lineWidth: 3)
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .buttonStyle(ModernButtonStyle())
                                    .sensoryFeedback(.selection, trigger: templateColor == color)
                                    .accessibilityLabel(String(localized: "Accessibility.ColorButton", bundle: .module).replacingOccurrences(of: "%@", with: colorName))
                                    .accessibilityValue(templateColor == color ? String(localized: "Color.Selected", bundle: .module) : String(localized: "Color.NotSelected", bundle: .module))
                                    .accessibilityAddTraits(templateColor == color ? .isSelected : [])
                                }
                            }
                        }
                    }
                    
                    // Smart Selection Section
                    smartSelectionSection
                    
                    // Extra padding for safe area
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal)
            }
            
            // Fixed bottom button
            VStack {
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
            .background(.regularMaterial)
        }
        .task {
            // Small delay to ensure TextField is fully rendered before focusing
            try? await Task.sleep(for: .milliseconds(100))
            isNameFieldFocused = true
        }
    }
    
    // MARK: - Building Step
    
    @ViewBuilder
    private func habitListItem(for habit: Habit) -> some View {
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
                    let _ = print("🔍 RoutineBuilderView: Deleting habit \(habit.name), current editingHabitIndex: \(editingHabitIndex?.description ?? "nil")")
                    withAnimation(.easeInOut) {
                        habits.removeAll { $0.id == habit.id }
                        if selectedQuestionHabit?.id == habit.id {
                            selectedQuestionHabit = nil
                        }
                        if selectedOption?.habitId == habit.id {
                            selectedOption = nil
                        }
                        // Clear editing state if the deleted habit was being edited
                        if editingHabit?.id == habit.id {
                            editingHabitIndex = nil
                            editingHabit = nil
                        }
                    }
                },
                onEditOption: { optionId in
                    // Edit option functionality
                    print("🔍 DEBUG: onEditOption called for optionId: \(optionId)")
                    // Prevent duplicate triggers
                    guard editingOptionData == nil else { 
                        print("🔍 DEBUG: Already editing an option, ignoring")
                        return 
                    }
                    
                    if case .conditional(let info) = habit.type,
                       let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) {
                        let option = info.options[optionIndex]
                        print("🔍 DEBUG: Setting editingOptionData for option: \(option.text)")
                        editingOptionData = EditingOptionData(habitId: habit.id, option: option)
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
                    print("🔍 DEBUG: onEditSubHabit triggered")
                    print("🔍 DEBUG: - habit.id: \(habit.id)")
                    print("🔍 DEBUG: - optionId: \(optionId)")
                    print("🔍 DEBUG: - subHabitId: \(subHabitId)")
                    
                    if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                        print("🔍 DEBUG: Found habit at index: \(habitIndex)")
                        
                        // Validate that the sub-habit exists before setting editingSubHabit
                        if case .conditional(let info) = habits[habitIndex].type,
                           let optionIndex = info.options.firstIndex(where: { $0.id == optionId }),
                           let subHabitIndex = info.options[optionIndex].habits.firstIndex(where: { $0.id == subHabitId }) {
                            print("✅ DEBUG: Validated sub-habit exists")
                            print("🔍 DEBUG: Setting editingSubHabit to: (habitIndex: \(habitIndex), optionId: \(optionId), subHabitId: \(subHabitId))")
                            // Store a copy of the sub-habit to prevent race conditions
                            editingSubHabitData = info.options[optionIndex].habits[subHabitIndex]
                            editingSubHabit = (habitIndex: habitIndex, optionId: optionId, subHabitId: subHabitId)
                        } else {
                            print("❌ DEBUG: Sub-habit validation failed")
                            print("❌ DEBUG: Could not find optionId: \(optionId) or subHabitId: \(subHabitId)")
                            if case .conditional(let info) = habits[habitIndex].type {
                                print("❌ DEBUG: Available options: \(info.options.map { $0.id })")
                                if let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) {
                                    print("❌ DEBUG: Available sub-habits in option: \(info.options[optionIndex].habits.map { $0.id })")
                                }
                            }
                        }
                    } else {
                        print("❌ DEBUG: Could not find habit with id: \(habit.id)")
                        print("❌ DEBUG: Available habit ids: \(habits.map { $0.id })")
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
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                        print("🔍 RoutineBuilderView: Found habit at index \(index)")
                        editingHabitIndex = index
                        editingHabit = habit
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    let _ = print("🔍 RoutineBuilderView: Deleting habit \(habit.name), current editingHabitIndex: \(editingHabitIndex?.description ?? "nil")")
                    withAnimation(.easeInOut) {
                        habits.removeAll { $0.id == habit.id }
                        if selectedQuestionHabit?.id == habit.id {
                            selectedQuestionHabit = nil
                        }
                        if selectedOption?.habitId == habit.id {
                            selectedOption = nil
                        }
                        // Clear editing state if the deleted habit was being edited
                        if editingHabit?.id == habit.id {
                            editingHabitIndex = nil
                            editingHabit = nil
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .overlay(alignment: .topLeading) {
                if isSelectingForSnippet {
                    Button {
                        if selectedHabitsForSnippet.contains(habit.id) {
                            selectedHabitsForSnippet.remove(habit.id)
                        } else {
                            selectedHabitsForSnippet.insert(habit.id)
                        }
                    } label: {
                        Image(systemName: selectedHabitsForSnippet.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedHabitsForSnippet.contains(habit.id) ? .blue : .secondary)
                            .font(.title3)
                            .background(Color(.systemBackground), in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                }
            }
        } else {
            HabitRowView(habit: habit) {
                print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    print("🔍 RoutineBuilderView: Found habit at index \(index)")
                    editingHabitIndex = index
                    editingHabit = habit
                }
            } onDelete: {
                let _ = print("🔍 RoutineBuilderView: Deleting habit \(habit.name), current editingHabitIndex: \(editingHabitIndex?.description ?? "nil")")
                withAnimation(.easeInOut) {
                    habits.removeAll { $0.id == habit.id }
                    // Clear editing state if the deleted habit was being edited
                    if editingHabit?.id == habit.id {
                        editingHabitIndex = nil
                        editingHabit = nil
                    }
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    print("🔍 RoutineBuilderView: Edit closure called for habit: \(habit.name)")
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                        print("🔍 RoutineBuilderView: Found habit at index \(index)")
                        editingHabitIndex = index
                        editingHabit = habit
                    }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    let _ = print("🔍 RoutineBuilderView: Deleting habit \(habit.name), current editingHabitIndex: \(editingHabitIndex?.description ?? "nil")")
                    withAnimation(.easeInOut) {
                        habits.removeAll { $0.id == habit.id }
                        // Clear editing state if the deleted habit was being deleted
                        if editingHabit?.id == habit.id {
                            editingHabitIndex = nil
                            editingHabit = nil
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .overlay(alignment: .topLeading) {
                if isSelectingForSnippet {
                    Button {
                        if selectedHabitsForSnippet.contains(habit.id) {
                            selectedHabitsForSnippet.remove(habit.id)
                        } else {
                            selectedHabitsForSnippet.insert(habit.id)
                        }
                    } label: {
                        Image(systemName: selectedHabitsForSnippet.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedHabitsForSnippet.contains(habit.id) ? .blue : .secondary)
                            .font(.title3)
                            .background(Color(.systemBackground), in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                }
            }
        }
    }

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
                                
                                if !isSelectingForSnippet {
                                    Button {
                                        isSelectingForSnippet.toggle()
                                        selectedHabitsForSnippet.removeAll()
                                    } label: {
                                        Label("Save snippet", systemImage: "square.stack.3d.up")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Text(habits.count == 1 ? String(localized: "RoutineBuilderView.Building.HabitCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(habits.count)") : String(localized: "RoutineBuilderView.Building.HabitsCount.Plural", bundle: .module).replacingOccurrences(of: "%lld", with: "\(habits.count)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.horizontal)
                            
                            // List with drag-and-drop support
                            List {
                                ForEach(habits) { habit in
                                    habitListItem(for: habit)
                                }
                                .onMove { source, destination in
                                    withAnimation(.easeInOut) {
                                        habits.move(fromOffsets: source, toOffset: destination)
                                        updateHabitOrder()
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }
                            .listStyle(.plain)
                            .frame(minHeight: max(300, CGFloat(max(0, habits.count)) * 60)) // Dynamic height with bounds - minimum for 5 habits
                            .padding(.horizontal)
                        }
                    }
                    
                    // Create snippet button when habits are selected for snippet
                    if isSelectingForSnippet && !selectedHabitsForSnippet.isEmpty {
                        Button {
                            showingSaveSnippetSheet = true
                        } label: {
                            Text("Create Snippet (\(selectedHabitsForSnippet.count) habits)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Add Option section (when question is selected)
                    if let selectedQuestion = selectedQuestionHabit {
                        addOptionSection(for: selectedQuestion)
                    }
                    
                    // Habit types section (contextual based on selection)
                    if let selectedOption = selectedOption {
                        addHabitToOptionSection(for: selectedOption)
                    } else {
                        // Smart Selection Criteria section (for editing mode)
                        if editingTemplate != nil {
                            smartSelectionEditingSection
                        }
                        
                        // Snippet browser section
                        snippetBrowserSection
                        
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
                    
                    if editingTemplate != nil {
                        // Single update button for editing mode
                        Button {
                            saveTemplate()
                        } label: {
                            Text("Update Routine")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: templateColor) ?? .blue)
                                )
                        }
                    } else {
                        // Single save button for new routine creation
                        Button {
                            // Direct save - no review step needed
                            saveTemplate()
                        } label: {
                            Text(habits.isEmpty ? "Save Empty Routine" : "Save Routine")
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
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(isPresented: Binding(
            get: { editingHabitIndex != nil || newHabitBeingCreated != nil || newOptionHabitBeingCreated != nil },
            set: { if !$0 { 
                editingHabitIndex = nil; 
                editingHabit = nil
                newHabitBeingCreated = nil // Clear new habit on cancel
                newOptionHabitBeingCreated = nil // Clear new option habit on cancel
            } }
        )) {
            if let newHabit = newHabitBeingCreated {
                let _ = print("🔍 RoutineBuilderView: Sheet presenting new habit creation")
                newHabitEditorView(for: newHabit)
            } else if let newOptionHabit = newOptionHabitBeingCreated {
                let _ = print("🔍 RoutineBuilderView: Sheet presenting new option habit creation")
                newOptionHabitEditorView(for: newOptionHabit.habit, optionId: newOptionHabit.optionId, habitId: newOptionHabit.habitId)
            } else if let index = editingHabitIndex, index < habits.count {
                let _ = print("🔍 RoutineBuilderView: Sheet presenting using index \(index) for habits.count \(habits.count)")
                habitEditorView(for: $habits[index])
            } else {
                let _ = print("🔍 RoutineBuilderView: ERROR - Invalid index: \(editingHabitIndex?.description ?? "nil"), habits.count: \(habits.count)")
                VStack {
                    Text(String(localized: "RoutineBuilderView.Error.InvalidHabitIndex", bundle: .module))
                        .foregroundStyle(.red)
                    Text("Index: \(editingHabitIndex?.description ?? "nil"), Count: \(habits.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button(String(localized: "RoutineBuilderView.Error.Close.Button", bundle: .module)) {
                        editingHabitIndex = nil
                        editingHabit = nil
                        newHabitBeingCreated = nil
                        newOptionHabitBeingCreated = nil
                    }
                }
                .padding()
            }
        }
        .onChange(of: habits) { oldValue, newValue in
            print("🔍 DEBUG: habits array changed")
            print("🔍 DEBUG: Old count: \(oldValue.count), New count: \(newValue.count)")
            if let editData = editingSubHabit {
                print("🔍 DEBUG: editingSubHabit is active during habits change")
                print("🔍 DEBUG: - habitIndex: \(editData.habitIndex)")
                print("🔍 DEBUG: - current habits.count: \(newValue.count)")
                if editData.habitIndex >= newValue.count {
                    print("❌ DEBUG: habitIndex is now out of bounds after habits change!")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingSubHabit != nil },
            set: { if !$0 { 
                editingSubHabit = nil
                editingSubHabitData = nil
            } }
        )) {
            if let editData = editingSubHabit {
                let _ = print("🔍 DEBUG: Sheet presented with editData:")
                let _ = print("🔍 DEBUG: - habitIndex: \(editData.habitIndex)")
                let _ = print("🔍 DEBUG: - optionId: \(editData.optionId)")
                let _ = print("🔍 DEBUG: - subHabitId: \(editData.subHabitId)")
                let _ = print("🔍 DEBUG: - habits.count: \(habits.count)")
                
                if editData.habitIndex >= habits.count {
                    let _ = print("❌ DEBUG: habitIndex \(editData.habitIndex) is out of bounds (habits.count: \(habits.count))")
                } else {
                    let habit = habits[editData.habitIndex]
                    let _ = print("🔍 DEBUG: Found habit at index \(editData.habitIndex): \(habit.name)")
                    
                    if case .conditional(let info) = habit.type {
                        let _ = print("🔍 DEBUG: Habit is conditional with \(info.options.count) options")
                        let _ = print("🔍 DEBUG: Option IDs: \(info.options.map { $0.id })")
                        
                        if let optionIndex = info.options.firstIndex(where: { $0.id == editData.optionId }) {
                            let _ = print("🔍 DEBUG: Found option at index \(optionIndex)")
                            let option = info.options[optionIndex]
                            let _ = print("🔍 DEBUG: Option has \(option.habits.count) sub-habits")
                            let _ = print("🔍 DEBUG: Sub-habit IDs: \(option.habits.map { $0.id })")
                            
                            if let subHabitIndex = option.habits.firstIndex(where: { $0.id == editData.subHabitId }) {
                                let _ = print("✅ DEBUG: Found sub-habit at index \(subHabitIndex)")
                                let _ = print("🔍 RoutineBuilderView: Sheet presenting sub-habit editor")
                                subHabitEditorView(
                                    habitIndex: editData.habitIndex,
                                    optionIndex: optionIndex,
                                    subHabitIndex: subHabitIndex
                                )
                            } else if let storedSubHabit = editingSubHabitData {
                                let _ = print("🔄 DEBUG: Sub-habit not found in array, using stored copy")
                                let _ = print("🔄 DEBUG: Stored sub-habit name: \(storedSubHabit.name)")
                                fallbackSubHabitEditorView(
                                    storedSubHabit: storedSubHabit,
                                    editData: editData
                                )
                            } else {
                                let _ = print("❌ DEBUG: Could not find sub-habit with ID \(editData.subHabitId)")
                                VStack {
                                    Text(String(localized: "RoutineBuilderView.Error.InvalidSubHabitReference", bundle: .module))
                                        .foregroundStyle(.red)
                                    Button(String(localized: "RoutineBuilderView.Error.Close.Button", bundle: .module)) {
                                        editingSubHabit = nil
                                        editingSubHabitData = nil
                                    }
                                }
                                .padding()
                            }
                        } else {
                            let _ = print("❌ DEBUG: Could not find option with ID \(editData.optionId)")
                            VStack {
                                Text(String(localized: "RoutineBuilderView.Error.InvalidSubHabitReference", bundle: .module))
                                    .foregroundStyle(.red)
                                Button(String(localized: "RoutineBuilderView.Error.Close.Button", bundle: .module)) {
                                    editingSubHabit = nil
                                }
                            }
                            .padding()
                        }
                    } else {
                        let _ = print("❌ DEBUG: Habit is not conditional type")
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
            } else {
                let _ = print("❌ DEBUG: editingSubHabit is nil in sheet")
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
        .sheet(item: $editingOptionData) { data in
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
        .sheet(isPresented: $showingSaveSnippetSheet) {
            let selectedHabits = habits.filter { selectedHabitsForSnippet.contains($0.id) }
            SaveSnippetSheet(
                selectedHabits: selectedHabits,
                onSave: {
                    isSelectingForSnippet = false
                    selectedHabitsForSnippet.removeAll()
                },
                onCancel: {
                    isSelectingForSnippet = false
                    selectedHabitsForSnippet.removeAll()
                }
            )
        }
        .sheet(isPresented: $showingSnippetBrowser) {
            SnippetBrowserView { selectedHabits in
                withAnimation(.easeInOut) {
                    habits.append(contentsOf: selectedHabits)
                }
            }
        }
    }
    
    private var snippetBrowserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Habit Snippets")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Browse All") {
                    showingSnippetBrowser = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            
            // Show recent snippets or "Create your first snippet" prompt
            if routineService.snippetService.snippets.isEmpty {
                Text("No snippets yet. Select habits and tap 'Save snippet' to create reusable collections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(routineService.snippetService.getAllSnippets().prefix(3))) { snippet in
                            SnippetCard(snippet: snippet) {
                                // Add snippet habits to current routine
                                withAnimation(.easeInOut) {
                                    habits.append(contentsOf: snippet.habits)
                                }
                            }
                            .frame(width: 120)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .padding(.horizontal)
            }
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
            
            // First 4 habit types in 2x2 grid with fixed heights
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(basicHabitTypeOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = createHabitFromType(habitType.type)
                            
                            // Set new habit creation state instead of adding to array immediately
                            newHabitBeingCreated = newHabit
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
                                    .lineLimit(3)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(height: 80) // Fixed height for all cards
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Question type centered below at full width
            if let questionOption = questionHabitTypeOption {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        let newHabit = createHabitFromType(questionOption.type)
                        
                        // Set new habit creation state instead of adding to array immediately
                        newHabitBeingCreated = newHabit
                    }
                } label: {
                    HStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: questionOption.type.iconName)
                            .font(.title2)
                            .foregroundStyle(questionOption.color)
                            .frame(width: 32, height: 32)
                        
                        VStack(spacing: 2) {
                            Text(questionOption.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(questionOption.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(height: 80) // Same height as other cards
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }
    }
    
    private struct HabitTypeOption {
        let name: String
        let description: String
        let type: HabitType
        let color: Color
    }
    
    private var basicHabitTypeOptions: [HabitTypeOption] {
        [
            HabitTypeOption(
                name: String(localized: "HabitType.Task.Name", bundle: .module),
                description: String(localized: "HabitType.Task.Description", bundle: .module),
                type: .task(subtasks: []),
                color: .green
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Timer.Name", bundle: .module),
                description: String(localized: "HabitType.Timer.Description", bundle: .module),
                type: .timer(style: .down, duration: 300),
                color: .blue
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Action.Name", bundle: .module),
                description: String(localized: "HabitType.Action.Description", bundle: .module),
                type: .action(type: .app, identifier: "", displayName: ""),
                color: .red
            ),
            HabitTypeOption(
                name: String(localized: "HabitType.Tracking.Name", bundle: .module),
                description: String(localized: "HabitType.Tracking.Description", bundle: .module),
                type: .tracking(.counter(items: ["Item 1"])),
                color: .orange
            )
        ]
    }
    
    private var questionHabitTypeOption: HabitTypeOption? {
        HabitTypeOption(
            name: "Question",
            description: "Conditional path",
            type: .conditional(ConditionalHabitInfo(
                question: "", 
                options: [
                    ConditionalOption(text: "Yes", habits: []),
                    ConditionalOption(text: "No", habits: [])
                ]
            )),
            color: .indigo
        )
    }
    
    // Legacy property for backward compatibility
    private var habitTypeOptions: [HabitTypeOption] {
        basicHabitTypeOptions + [questionHabitTypeOption].compactMap { $0 }
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
        case .task:
            return "New Task"
        case .timer(let style, _, _, _):
            switch style {
            case .down: return "Timed Activity"
            case .up: return "Rest Period"
            case .multiple: return "Multiple Timers"
            }
        case .action(let type, _, _):
            switch type {
            case .app:
                return "Launch App"
            case .website:
                return "Open Website"
            case .shortcut:
                return "Run Shortcut"
            }
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "Track Items"
            case .measurement:
                return "Record Measurement"
            }
        case .guidedSequence:
            return "Guided Activity"
        case .conditional:
            return "Question"
        }
    }
    
    private func getColorForType(_ type: HabitType) -> String {
        switch type {
        case .task:
            return "#34C759" // Green
        case .timer:
            return "#007AFF" // Blue
        case .action:
            return "#FF3B30" // Red
        case .tracking(let trackingType):
            switch trackingType {
            case .counter:
                return "#FFD60A" // Yellow
            case .measurement:
                return "#BF5AF2" // Purple
            }
        case .guidedSequence:
            return "#64D2FF" // Light Blue
        case .conditional:
            return "#5856D6" // Indigo
        }
    }
    
    // MARK: - Review Step
    
    
    // MARK: - Smart Selection Section
    
    private var smartSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure arrow
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    smartSelectionExpanded.toggle()
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
                        .rotationEffect(.degrees(smartSelectionExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if smartSelectionExpanded {
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
                                get: { Double(smartSelectionPriority) },
                                set: { smartSelectionPriority = Int($0) }
                            ), in: 1...10, step: 1)
                            
                            Text("Higher")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("\(smartSelectionPriority)")
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
    
    // MARK: - Smart Selection Editing Section (for edit mode)
    
    private var smartSelectionEditingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure arrow
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    smartSelectionExpanded.toggle()
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
                        .rotationEffect(.degrees(smartSelectionExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if smartSelectionExpanded {
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
                                get: { Double(smartSelectionPriority) },
                                set: { smartSelectionPriority = Int($0) }
                            ), in: 1...10, step: 1)
                            
                            Text("Higher")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("\(smartSelectionPriority)")
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
    private func newHabitEditorView(for newHabit: Habit) -> some View {
        let _ = print("🔍 RoutineBuilderView: Creating new habit editor for \(newHabit.name)")
        switch newHabit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: newHabit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 0
            ) { updatedHabit in
                print("🔍 RoutineBuilderView: New ConditionalHabitEditorView onSave - adding to habits array")
                withAnimation(.easeInOut) {
                    habits.append(updatedHabit)
                    updateHabitOrder()
                }
                newHabitBeingCreated = nil // Clear creation state
            }
        default:
            HabitEditorView(habit: newHabit) { updatedHabit in
                print("🔍 RoutineBuilderView: New HabitEditorView onSave - adding to habits array")
                print("🔍 RoutineBuilderView: New habit type: \(updatedHabit.type)")
                withAnimation(.easeInOut) {
                    habits.append(updatedHabit)
                    updateHabitOrder()
                }
                newHabitBeingCreated = nil // Clear creation state
            }
        }
    }
    
    @ViewBuilder
    private func newOptionHabitEditorView(for newHabit: Habit, optionId: UUID, habitId: UUID) -> some View {
        let _ = print("🔍 RoutineBuilderView: Creating new option habit editor for \(newHabit.name)")
        switch newHabit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: newHabit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 1
            ) { updatedHabit in
                print("🔍 RoutineBuilderView: New option ConditionalHabitEditorView onSave - adding to option")
                addHabitToOption(updatedHabit, optionId: optionId, habitId: habitId)
                newOptionHabitBeingCreated = nil // Clear creation state
            }
        default:
            HabitEditorView(habit: newHabit) { updatedHabit in
                print("🔍 RoutineBuilderView: New option HabitEditorView onSave - adding to option")
                addHabitToOption(updatedHabit, optionId: optionId, habitId: habitId)
                newOptionHabitBeingCreated = nil // Clear creation state
            }
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
        let _ = print("🔍 DEBUG: subHabitEditorView called with:")
        let _ = print("🔍 DEBUG: - habitIndex: \(habitIndex)")
        let _ = print("🔍 DEBUG: - optionIndex: \(optionIndex)")
        let _ = print("🔍 DEBUG: - subHabitIndex: \(subHabitIndex)")
        let _ = print("🔍 DEBUG: - habits.count: \(habits.count)")
        
        // Create a binding to the specific sub-habit
        let subHabitBinding = Binding<Habit>(
            get: {
                let _ = print("🔍 DEBUG: subHabitBinding getter called")
                if habitIndex < habits.count {
                    let _ = print("🔍 DEBUG: Habit exists at index \(habitIndex)")
                    if case .conditional(let info) = habits[habitIndex].type {
                        let _ = print("🔍 DEBUG: Habit is conditional with \(info.options.count) options")
                        if optionIndex < info.options.count {
                            let _ = print("🔍 DEBUG: Option exists at index \(optionIndex)")
                            let _ = print("🔍 DEBUG: Option has \(info.options[optionIndex].habits.count) sub-habits")
                            if subHabitIndex < info.options[optionIndex].habits.count {
                                let _ = print("✅ DEBUG: Returning sub-habit at index \(subHabitIndex)")
                                return info.options[optionIndex].habits[subHabitIndex]
                            } else {
                                let _ = print("❌ DEBUG: subHabitIndex \(subHabitIndex) out of bounds")
                            }
                        } else {
                            let _ = print("❌ DEBUG: optionIndex \(optionIndex) out of bounds")
                        }
                    } else {
                        let _ = print("❌ DEBUG: Habit is not conditional type")
                    }
                } else {
                    let _ = print("❌ DEBUG: habitIndex \(habitIndex) out of bounds")
                }
                let _ = print("❌ DEBUG: Returning fallback habit")
                return Habit(name: "Error", type: .task(subtasks: [])) // Fallback
            },
            set: { newHabit in
                let _ = print("🔍 DEBUG: subHabitBinding setter called")
                let _ = print("🔍 DEBUG: New habit name: \(newHabit.name)")
                if habitIndex < habits.count {
                    if case .conditional(let info) = habits[habitIndex].type,
                       optionIndex < info.options.count,
                       subHabitIndex < info.options[optionIndex].habits.count {
                        
                        let _ = print("🔍 DEBUG: Updating sub-habit at indices [\(habitIndex)][\(optionIndex)][\(subHabitIndex)]")
                        var updatedOptions = info.options
                        updatedOptions[optionIndex].habits[subHabitIndex] = newHabit
                        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                        habits[habitIndex].type = .conditional(updatedInfo)
                    }
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
    
    @ViewBuilder
    private func fallbackSubHabitEditorView(storedSubHabit: Habit, editData: (habitIndex: Int, optionId: UUID, subHabitId: UUID)) -> some View {
        let _ = print("🔄 DEBUG: fallbackSubHabitEditorView called")
        let _ = print("🔄 DEBUG: - storedSubHabit.name: \(storedSubHabit.name)")
        
        // Create a binding that will save changes back to the array when possible
        let fallbackBinding = Binding<Habit>(
            get: {
                let _ = print("🔄 DEBUG: fallbackBinding getter called")
                return storedSubHabit
            },
            set: { updatedHabit in
                let _ = print("🔄 DEBUG: fallbackBinding setter called")
                let _ = print("🔄 DEBUG: Updated habit name: \(updatedHabit.name)")
                
                // Try to save the changes back to the array
                if editData.habitIndex < habits.count,
                   case .conditional(let info) = habits[editData.habitIndex].type,
                   let optionIndex = info.options.firstIndex(where: { $0.id == editData.optionId }),
                   let subHabitIndex = info.options[optionIndex].habits.firstIndex(where: { $0.id == editData.subHabitId }) {
                    let _ = print("🔄 DEBUG: Successfully saving fallback changes to array")
                    var updatedOptions = info.options
                    updatedOptions[optionIndex].habits[subHabitIndex] = updatedHabit
                    let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                    habits[editData.habitIndex].type = .conditional(updatedInfo)
                } else {
                    let _ = print("⚠️ DEBUG: Could not save fallback changes - sub-habit still missing from array")
                    // Update the stored copy for consistency
                    editingSubHabitData = updatedHabit
                }
            }
        )
        
        let fallbackSubHabit = fallbackBinding.wrappedValue
        
        switch fallbackSubHabit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: fallbackSubHabit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: 1
            ) { updatedHabit in
                fallbackBinding.wrappedValue = updatedHabit
            }
        default:
            HabitEditorView(habit: fallbackSubHabit, onSave: { updatedHabit in
                fallbackBinding.wrappedValue = updatedHabit
            })
        }
    }
    
    private func getAllAvailableHabits() -> [Habit] {
        // Get all habits from all templates to use as a library
        routineService.templates.flatMap { $0.habits }
    }
    
    private func saveTemplate() {
        updateHabitOrder()
        
        // Create context rule from smart selection state
        let finalContextRule: RoutineContextRule? = {
            if (!selectedTimeSlots.isEmpty || !selectedDayCategories.isEmpty || !selectedLocationIds.isEmpty) {
                return RoutineContextRule(
                    timeSlots: selectedTimeSlots,
                    dayCategoryIds: selectedDayCategories,
                    locationIds: selectedLocationIds,
                    priority: smartSelectionPriority
                )
            }
            return nil
        }()
        
        if let existingTemplate = editingTemplate {
            // Update existing template
            var updatedTemplate = existingTemplate
            updatedTemplate.name = templateName
            updatedTemplate.habits = habits
            updatedTemplate.color = templateColor
            updatedTemplate.isDefault = false
            updatedTemplate.contextRule = finalContextRule
            
            routineService.updateTemplate(updatedTemplate)
        } else {
            // Create new template
            let template = RoutineTemplate(
                name: templateName,
                habits: habits,
                color: templateColor,
                isDefault: false,
                contextRule: finalContextRule
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
            
            // First 4 habit types in 2x2 grid with fixed heights
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(basicHabitTypeOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = createHabitFromType(habitType.type)
                            if let selectedOption = selectedOption {
                                newOptionHabitBeingCreated = (habit: newHabit, optionId: selectedOption.optionId, habitId: selectedOption.habitId)
                            }
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
                                    .lineLimit(3)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(height: 80) // Fixed height for all cards
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Question type centered below at full width
            if let questionOption = questionHabitTypeOption {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        let newHabit = createHabitFromType(questionOption.type)
                        if let selectedOption = selectedOption {
                            newOptionHabitBeingCreated = (habit: newHabit, optionId: selectedOption.optionId, habitId: selectedOption.habitId)
                        }
                    }
                } label: {
                    HStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: questionOption.type.iconName)
                            .font(.title2)
                            .foregroundStyle(questionOption.color)
                            .frame(width: 32, height: 32)
                        
                        VStack(spacing: 2) {
                            Text(questionOption.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(questionOption.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(height: 80) // Same height as other cards
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            }
        } else {
            EmptyView()
        }
    }
    
    private func addHabitToOption(_ newHabit: Habit, optionId: UUID, habitId: UUID) {
        guard let habitIndex = habits.firstIndex(where: { $0.id == habitId }),
              case .conditional(let info) = habits[habitIndex].type,
              let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) else {
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
    
    // Legacy function for backwards compatibility - now unused
    private func addHabitToSelectedOption(_ newHabit: Habit) {
        guard let selection = selectedOption else { return }
        addHabitToOption(newHabit, optionId: selection.optionId, habitId: selection.habitId)
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
        case .task(let subtasks):
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
            case .task(let subtasks):
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
        guard case .task(var subtasks) = habit.type else { return }
        
        let newSubtask = Subtask(name: "New subtask")
        subtasks.append(newSubtask)
        habit.type = .task(subtasks: subtasks)
    }
    
    private func removeSubtask(at index: Int) {
        guard case .task(var subtasks) = habit.type else { return }
        guard index < subtasks.count else { return }
        
        subtasks.remove(at: index)
        habit.type = .task(subtasks: subtasks)
    }
    
    private func updateSubtaskName(at index: Int, newName: String) {
        guard case .task(var subtasks) = habit.type else { return }
        guard index < subtasks.count else { return }
        
        subtasks[index].name = newName
        habit.type = .task(subtasks: subtasks)
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
                    let optionColor = optionColors[index % optionColors.count]
                    
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
                                    print("🔍 DEBUG: Edit option button tapped for option: \(option.text)")
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
                                            print("🔍 DEBUG: Edit sub-habit button pressed")
                                            print("🔍 DEBUG: - option.id: \(option.id)")
                                            print("🔍 DEBUG: - sub-habit.id: \(habit.id)")
                                            print("🔍 DEBUG: - sub-habit.name: \(habit.name)")
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