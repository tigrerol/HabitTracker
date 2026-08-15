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
    @State private var weeklyTarget: Int? = nil
    @State private var includes: [RoutineInclude] = []
    @State private var showingIncludePicker = false
    @State private var previewingIncludedTemplate: RoutineTemplate?

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
            .appBackground()
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
                weeklyTarget = template.weeklyTarget
                includes = template.includes

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
                            .fill(Theme.Colors.accentTeal)
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
                                                .background(templateName == suggestion ? Theme.Colors.accentTeal : Theme.cardSurface, in: Capsule())
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
                                                        .stroke(Theme.Colors.accentTeal, lineWidth: 3)
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
                    SmartSelectionEditorView(
                        isExpanded: $smartSelectionExpanded,
                        selectedTimeSlots: $selectedTimeSlots,
                        selectedDayCategories: $selectedDayCategories,
                        selectedLocationIds: $selectedLocationIds,
                        priority: $smartSelectionPriority,
                        customLocations: customLocations
                    )

                    // Streak tracking
                    streakTrackingSection

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
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
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
                        // Clear editing state if the deleted habit was being edited
                        if editingHabit?.id == habit.id {
                            editingHabitIndex = nil
                            editingHabit = nil
                        }
                    }
                },
                onEditOption: { optionId in
                    // Prevent duplicate triggers
                    guard editingOptionData == nil else { return }

                    if case .conditional(let info) = habit.type,
                       let optionIndex = info.options.firstIndex(where: { $0.id == optionId }) {
                        let option = info.options[optionIndex]
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
                    if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                        // Validate that the sub-habit exists before setting editingSubHabit
                        if case .conditional(let info) = habits[habitIndex].type,
                           let optionIndex = info.options.firstIndex(where: { $0.id == optionId }),
                           let subHabitIndex = info.options[optionIndex].habits.firstIndex(where: { $0.id == subHabitId }) {
                            // Store a copy of the sub-habit to prevent race conditions
                            editingSubHabitData = info.options[optionIndex].habits[subHabitIndex]
                            editingSubHabit = (habitIndex: habitIndex, optionId: optionId, subHabitId: subHabitId)
                        }
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
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
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
                            .background(Theme.cardSurface, in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                }
            }
        } else {
            HabitRowView(habit: habit) {
                if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                    editingHabitIndex = index
                    editingHabit = habit
                }
            } onDelete: {
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
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
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
                            .background(Theme.cardSurface, in: Circle())
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .allowsHitTesting(true)
                }
            }
        }
    }

    /// A linked block in the builder list: one row standing in for another
    /// routine's habits. Editing happens in that routine, not here.
    private func includedRoutineRow(_ include: RoutineInclude) -> some View {
        let template = includedTemplate(for: include)

        return HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(template == nil ? Color.orange : Color.accentColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((template == nil ? Color.orange : Color.accentColor).opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(template?.name ?? "Missing routine")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(template == nil ? .secondary : .primary)

                if let template {
                    Text("\(template.activeHabitsCount) habits • \(template.formattedDuration) • linked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("This routine was deleted — remove this block")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if template != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let template {
                previewingIncludedTemplate = template
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(template.map { "Included routine \($0.name), \($0.activeHabitsCount) habits" } ?? "Missing included routine")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(.easeInOut) {
                    includes.removeAll { $0.id == include.id }
                    updateHabitOrder()
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    /// Entry point for wrapping another routine into this one.
    private var includeRoutineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Include a Routine")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Include") {
                    showingIncludePicker = true
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .disabled(includableTemplates.isEmpty)
            }
            .padding(.horizontal)

            Text(includableTemplates.isEmpty
                 ? "No other routines available to include. Routines that already include another one can't be nested again."
                 : "Reuse a whole routine as a block — edit it once and every routine that includes it follows.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var buildingStepView: some View {
        VStack(spacing: 0) {
            // Enhanced progress header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(
                            String(localized: "RoutineBuilderView.Naming.RoutineName.Placeholder", bundle: .module),
                            text: $templateName
                        )
                        .font(.title2)
                        .fontWeight(.semibold)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)

                        if builderItems.isEmpty {
                            Text(String(localized: "RoutineBuilderView.Building.Question", bundle: .module))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(String(localized: "RoutineBuilderView.Building.HabitsCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(resolvedHabitCount)").replacingOccurrences(of: "%@", with: totalDuration.formattedDuration))
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
                
                if !builderItems.isEmpty {
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
                    if !builderItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(String(localized: "RoutineBuilderView.Building.YourRoutine.Title", bundle: .module))
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if !isSelectingForSnippet && !habits.isEmpty {
                                    Button {
                                        isSelectingForSnippet.toggle()
                                        selectedHabitsForSnippet.removeAll()
                                    } label: {
                                        Label("Save snippet", systemImage: "square.stack.3d.up")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Text(resolvedHabitCount == 1 ? String(localized: "RoutineBuilderView.Building.HabitCount", bundle: .module).replacingOccurrences(of: "%lld", with: "\(resolvedHabitCount)") : String(localized: "RoutineBuilderView.Building.HabitsCount.Plural", bundle: .module).replacingOccurrences(of: "%lld", with: "\(resolvedHabitCount)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.horizontal)
                            
                            // List with drag-and-drop support
                            List {
                                ForEach(builderItems) { item in
                                    switch item {
                                    case .habit(let habit):
                                        habitListItem(for: habit)
                                    case .include(let include):
                                        includedRoutineRow(include)
                                    }
                                }
                                .onMove { source, destination in
                                    withAnimation(.easeInOut) {
                                        moveBuilderItems(from: source, to: destination)
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: min(CGFloat(builderItems.count) * 60, 360))
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
                            SmartSelectionEditorView(
                        isExpanded: $smartSelectionExpanded,
                        selectedTimeSlots: $selectedTimeSlots,
                        selectedDayCategories: $selectedDayCategories,
                        selectedLocationIds: $selectedLocationIds,
                        priority: $smartSelectionPriority,
                        customLocations: customLocations
                    )
                            streakTrackingSection
                                .padding(.horizontal)
                        }

                        // Snippet browser section
                        snippetBrowserSection
                        
                        includeRoutineSection

                        suggestedHabitsSection
                            .padding(.top, builderItems.isEmpty ? 20 : 0)
                    }
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom buttons
                }
            }
            
            // Bottom actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if builderItems.isEmpty {
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
                        let trimmedName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
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
                                        .fill(trimmedName.isEmpty ? Color.gray : (Color(hex: templateColor) ?? .blue))
                                )
                        }
                        .disabled(trimmedName.isEmpty)
                    } else {
                        // Single save button for new routine creation
                        Button {
                            // Direct save - no review step needed
                            saveTemplate()
                        } label: {
                            Text(builderItems.isEmpty ? "Save Empty Routine" : "Save Routine")
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
                newHabitEditorView(for: newHabit)
            } else if let newOptionHabit = newOptionHabitBeingCreated {
                newOptionHabitEditorView(for: newOptionHabit.habit, optionId: newOptionHabit.optionId, habitId: newOptionHabit.habitId)
            } else if let index = editingHabitIndex, index < habits.count {
                habitEditorView(for: $habits[index])
            } else {
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
        .sheet(isPresented: Binding(
            get: { editingSubHabit != nil },
            set: { if !$0 { 
                editingSubHabit = nil
                editingSubHabitData = nil
            } }
        )) {
            if let editData = editingSubHabit {
                if editData.habitIndex >= habits.count {
                    // habitIndex out of bounds
                } else {
                    let habit = habits[editData.habitIndex]

                    if case .conditional(let info) = habit.type {
                        if let optionIndex = info.options.firstIndex(where: { $0.id == editData.optionId }) {
                            let option = info.options[optionIndex]

                            if let subHabitIndex = option.habits.firstIndex(where: { $0.id == editData.subHabitId }) {
                                subHabitEditorView(
                                    habitIndex: editData.habitIndex,
                                    optionIndex: optionIndex,
                                    subHabitIndex: subHabitIndex
                                )
                            } else if let storedSubHabit = editingSubHabitData {
                                fallbackSubHabitEditorView(
                                    storedSubHabit: storedSubHabit,
                                    editData: editData
                                )
                            } else {
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
        .sheet(isPresented: $showingIncludePicker) {
            IncludeRoutinePickerView(templates: includableTemplates) { chosen in
                withAnimation(.easeInOut) {
                    includes.append(RoutineInclude(templateId: chosen.id, order: nextOrderSlot()))
                    updateHabitOrder()
                }
            }
        }
        .sheet(item: $previewingIncludedTemplate) { template in
            IncludedRoutinePreviewView(template: template)
        }
        .sheet(isPresented: $showingSnippetBrowser) {
            SnippetBrowserView(excludedRoutineId: editingTemplate?.id) { selectedHabits in
                withAnimation(.easeInOut) {
                    appendHabits(selectedHabits.map { $0.withNewIdentity() })
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
                Button("Snippets") {
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
                                    appendHabits(snippet.habits.map { $0.withNewIdentity() })
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
                ForEach(HabitTypeCatalog.basicOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = HabitTypeCatalog.makeHabit(ofType: habitType.type)
                            
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
            if let questionOption = HabitTypeCatalog.questionOption {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        let newHabit = HabitTypeCatalog.makeHabit(ofType: questionOption.type)
                        
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
    
    // MARK: - Review Step
    
    
    // MARK: - Streak Tracking Section

    private var streakTrackingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Streak tracking")
                .font(.headline)
            Toggle("Track streak", isOn: Binding(
                get: { weeklyTarget != nil },
                set: { weeklyTarget = $0 ? (weeklyTarget ?? 3) : nil }
            ))
            if let target = weeklyTarget {
                Stepper(
                    "Weekly target: \(target)× per week",
                    value: Binding(
                        get: { weeklyTarget ?? 3 },
                        set: { weeklyTarget = $0 }
                    ),
                    in: 1...7
                )
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers
    
    /// Habits this routine will actually run — its own plus every included block.
    private var resolvedHabits: [Habit] {
        let blockHabits = includes
            .compactMap { includedTemplate(for: $0) }
            .flatMap { $0.habits.filter(\.isActive) }
        return habits + blockHabits
    }

    private var resolvedHabitCount: Int { resolvedHabits.count }

    private var totalDuration: TimeInterval {
        let total = resolvedHabits.reduce(0) { accum, habit in
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
    
    /// Habits and included blocks share one ordering space so a block can sit
    /// between two loose habits. Renumber the merged list 0..n-1, keeping the
    /// current relative order.
    private func updateHabitOrder() {
        for (index, item) in builderItems.enumerated() {
            switch item {
            case .habit(let habit):
                if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[habitIndex].order = index
                }
            case .include(let include):
                if let includeIndex = includes.firstIndex(where: { $0.id == include.id }) {
                    includes[includeIndex].order = index
                }
            }
        }
        habits.sort { $0.order < $1.order }
        includes.sort { $0.order < $1.order }
    }

    /// The next free slot at the end of the merged list.
    private func nextOrderSlot() -> Int {
        max(habits.map(\.order).max() ?? -1, includes.map(\.order).max() ?? -1) + 1
    }

    /// Append habits at the end of the merged list (not just the habit array),
    /// so they land after any included block.
    private func appendHabits(_ newHabits: [Habit]) {
        var slot = nextOrderSlot()
        for habit in newHabits {
            var copy = habit
            copy.order = slot
            habits.append(copy)
            slot += 1
        }
        updateHabitOrder()
    }

    /// Habits and includes merged into the single list the builder shows.
    private var builderItems: [BuilderItem] {
        let habitItems = habits.map { BuilderItem.habit($0) }
        let includeItems = includes.map { BuilderItem.include($0) }
        return (habitItems + includeItems).sorted { $0.order < $1.order }
    }

    private func moveBuilderItems(from source: IndexSet, to destination: Int) {
        var items = builderItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            switch item {
            case .habit(let habit):
                if let habitIndex = habits.firstIndex(where: { $0.id == habit.id }) {
                    habits[habitIndex].order = index
                }
            case .include(let include):
                if let includeIndex = includes.firstIndex(where: { $0.id == include.id }) {
                    includes[includeIndex].order = index
                }
            }
        }
        habits.sort { $0.order < $1.order }
        includes.sort { $0.order < $1.order }
    }

    /// Routines eligible to be included: not this one, not already included,
    /// and not wrappers themselves (composition is one level deep).
    private var includableTemplates: [RoutineTemplate] {
        routineService.templates.filter { candidate in
            candidate.id != editingTemplate?.id
                && candidate.includes.isEmpty
                && !includes.contains { $0.templateId == candidate.id }
        }
    }

    private func includedTemplate(for include: RoutineInclude) -> RoutineTemplate? {
        routineService.templates.first { $0.id == include.templateId }
    }
    
    /// Single dispatch point for "conditional → ConditionalHabitEditorView,
    /// anything else → HabitEditorView". Every builder sheet routes through
    /// this instead of duplicating the branch.
    @ViewBuilder
    private func habitEditor(for habit: Habit, conditionalDepth: Int, onSave: @escaping (Habit) -> Void) -> some View {
        switch habit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: habit,
                habitLibrary: getAllAvailableHabits(),
                existingConditionalDepth: conditionalDepth,
                onSave: onSave
            )
        default:
            HabitEditorView(habit: habit, onSave: onSave)
        }
    }

    @ViewBuilder
    private func newHabitEditorView(for newHabit: Habit) -> some View {
        habitEditor(for: newHabit, conditionalDepth: 0) { updatedHabit in
            withAnimation(.easeInOut) {
                appendHabits([updatedHabit])
            }
            newHabitBeingCreated = nil // Clear creation state
        }
    }

    @ViewBuilder
    private func newOptionHabitEditorView(for newHabit: Habit, optionId: UUID, habitId: UUID) -> some View {
        habitEditor(for: newHabit, conditionalDepth: 1) { updatedHabit in
            addHabitToOption(updatedHabit, optionId: optionId, habitId: habitId)
            newOptionHabitBeingCreated = nil // Clear creation state
        }
    }

    @ViewBuilder
    private func habitEditorView(for habitBinding: Binding<Habit>) -> some View {
        habitEditor(for: habitBinding.wrappedValue, conditionalDepth: 0) { updatedHabit in
            habitBinding.wrappedValue = updatedHabit
        }
    }
    
    @ViewBuilder
    private func subHabitEditorView(habitIndex: Int, optionIndex: Int, subHabitIndex: Int) -> some View {
        // Create a binding to the specific sub-habit
        let subHabitBinding = Binding<Habit>(
            get: {
                if habitIndex < habits.count {
                    if case .conditional(let info) = habits[habitIndex].type {
                        if optionIndex < info.options.count {
                            if subHabitIndex < info.options[optionIndex].habits.count {
                                return info.options[optionIndex].habits[subHabitIndex]
                            }
                        }
                    }
                }
                return Habit(name: "Error", type: .task(subtasks: [])) // Fallback
            },
            set: { newHabit in
                if habitIndex < habits.count {
                    if case .conditional(let info) = habits[habitIndex].type,
                       optionIndex < info.options.count,
                       subHabitIndex < info.options[optionIndex].habits.count {
                        
                        var updatedOptions = info.options
                        updatedOptions[optionIndex].habits[subHabitIndex] = newHabit
                        let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                        habits[habitIndex].type = .conditional(updatedInfo)
                    }
                }
            }
        )
        
        habitEditor(for: subHabitBinding.wrappedValue, conditionalDepth: 1) { updatedHabit in
            subHabitBinding.wrappedValue = updatedHabit
        }
    }
    
    @ViewBuilder
    private func fallbackSubHabitEditorView(storedSubHabit: Habit, editData: (habitIndex: Int, optionId: UUID, subHabitId: UUID)) -> some View {
        // Create a binding that will save changes back to the array when possible
        let fallbackBinding = Binding<Habit>(
            get: {
                return storedSubHabit
            },
            set: { updatedHabit in
                // Try to save the changes back to the array
                if editData.habitIndex < habits.count,
                   case .conditional(let info) = habits[editData.habitIndex].type,
                   let optionIndex = info.options.firstIndex(where: { $0.id == editData.optionId }),
                   let subHabitIndex = info.options[optionIndex].habits.firstIndex(where: { $0.id == editData.subHabitId }) {
                    var updatedOptions = info.options
                    updatedOptions[optionIndex].habits[subHabitIndex] = updatedHabit
                    let updatedInfo = ConditionalHabitInfo(question: info.question, options: updatedOptions)
                    habits[editData.habitIndex].type = .conditional(updatedInfo)
                } else {
                    // Update the stored copy for consistency
                    editingSubHabitData = updatedHabit
                }
            }
        )
        
        habitEditor(for: fallbackBinding.wrappedValue, conditionalDepth: 1) { updatedHabit in
            fallbackBinding.wrappedValue = updatedHabit
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
            updatedTemplate.weeklyTarget = weeklyTarget
            updatedTemplate.includes = includes

            routineService.updateTemplate(updatedTemplate)
        } else {
            // Create new template
            let template = RoutineTemplate(
                name: templateName,
                habits: habits,
                color: templateColor,
                isDefault: false,
                contextRule: finalContextRule,
                weeklyTarget: weeklyTarget,
                includes: includes
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
                ForEach(HabitTypeCatalog.basicOptions, id: \.type) { habitType in
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            let newHabit = HabitTypeCatalog.makeHabit(ofType: habitType.type)
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
            if let questionOption = HabitTypeCatalog.questionOption {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        let newHabit = HabitTypeCatalog.makeHabit(ofType: questionOption.type)
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


#Preview {
    RoutineBuilderView()
        .environment(RoutineService())
}


// MARK: - Routine Includes

/// One row in the builder list: either a loose habit or a linked routine block.
enum BuilderItem: Identifiable {
    case habit(Habit)
    case include(RoutineInclude)

    var id: UUID {
        switch self {
        case .habit(let habit): habit.id
        case .include(let include): include.id
        }
    }

    var order: Int {
        switch self {
        case .habit(let habit): habit.order
        case .include(let include): include.order
        }
    }
}

/// Pick a routine to include as a block.
struct IncludeRoutinePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [RoutineTemplate]
    let onSelect: (RoutineTemplate) -> Void

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Text("No routines available to include.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(templates) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .foregroundStyle(.primary)
                                        Text("\(template.activeHabitsCount) habits • \(template.formattedDuration)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text("The block stays linked: edits to the routine you pick show up here automatically.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Include Routine")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// Read-only look at what an included block contributes.
struct IncludedRoutinePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let template: RoutineTemplate

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(template.habits.filter(\.isActive)) { habit in
                        HStack(spacing: 10) {
                            Image(systemName: habit.type.iconName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(habit.name)
                            Spacer()
                            Text(habit.type.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("\(template.activeHabitsCount) habits • \(template.formattedDuration)")
                } footer: {
                    Text("Edit these in the \(template.name) routine — changes apply everywhere it's included.")
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(template.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
