import SwiftUI

/// View for creating and editing conditional habits
public struct ConditionalHabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var habitName: String
    @State private var question: String
    @State private var options: [ConditionalOption]
    @State private var color: String
    @State private var selectedOptionForBuilder: ConditionalOption?
    @State private var selectedOptionForHabitPicker: ConditionalOption?
    @State private var showingDeleteAlert = false
    @State private var optionToDelete: ConditionalOption?
    
    private let onSave: (Habit) -> Void
    private let existingHabit: Habit?
    private let habitLibrary: [Habit]
    private let existingConditionalDepth: Int
    
    public init(
        existingHabit: Habit? = nil,
        habitLibrary: [Habit] = [],
        existingConditionalDepth: Int = 0,
        onSave: @escaping (Habit) -> Void
    ) {
        self.existingHabit = existingHabit
        self.habitLibrary = habitLibrary
        self.existingConditionalDepth = existingConditionalDepth
        self.onSave = onSave
        
        // Initialize state from existing habit or defaults
        if let existingHabit = existingHabit,
           case .conditional(let info) = existingHabit.type {
            _habitName = State(initialValue: existingHabit.name)
            _question = State(initialValue: info.question)
            _options = State(initialValue: info.options)
            _color = State(initialValue: existingHabit.color)
        } else {
            _habitName = State(initialValue: "")
            _question = State(initialValue: "")
            _options = State(initialValue: [
                ConditionalOption(text: "Option 1", habits: []),
                ConditionalOption(text: "Option 2", habits: [])
            ])
            _color = State(initialValue: "#007AFF")
        }
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                habitDetailsSection
                optionsSection
                depthWarningSection
            }
            .navigationTitle(existingHabit == nil ? "New Question" : "Edit Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(item: $selectedOptionForBuilder) { option in
                let _ = print("🔍 Sheet: selectedOptionForBuilder triggered for option: \(option.text)")
                if let index = options.firstIndex(where: { $0.id == option.id }) {
                    let _ = print("🔍 Sheet: Found option at index \(index), showing PathBuilderView")
                    PathBuilderView(
                        option: optionBinding(for: index),
                        habitLibrary: habitLibrary,
                        existingConditionalDepth: existingConditionalDepth + 1
                    )
                } else {
                    let _ = print("🔍 Sheet: Could not find option in current list")
                    VStack {
                        Text("Error: Option not found")
                            .foregroundStyle(.red)
                        Text("Option: \(option.text)")
                            .font(.caption)
                        Button("Close") {
                            selectedOptionForBuilder = nil
                        }
                    }
                    .padding()
                }
            }
            .sheet(item: $selectedOptionForHabitPicker) { option in
                if let index = options.firstIndex(where: { $0.id == option.id }) {
                    HabitPickerView(
                        habitLibrary: habitLibrary,
                        existingConditionalDepth: existingConditionalDepth,
                        onSelect: { habit in
                            // Add habit to the specific option
                            let newHabit = Habit(
                                id: UUID(),
                                name: habit.name,
                                type: habit.type,
                                isOptional: habit.isOptional,
                                notes: habit.notes,
                                color: habit.color,
                                order: options[index].habits.count,
                                isActive: habit.isActive
                            )
                            var updatedOption = options[index]
                            updatedOption.habits.append(newHabit)
                            options[index] = updatedOption
                        }
                    )
                }
            }
            .alert("Delete Option", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let option = optionToDelete {
                        options.removeAll { $0.id == option.id }
                        // Reset selection if deleted option was selected
                        if selectedOptionForBuilder?.id == option.id {
                            selectedOptionForBuilder = nil
                        }
                        if selectedOptionForHabitPicker?.id == option.id {
                            selectedOptionForHabitPicker = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this option? This will also delete all habits in its path.")
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var habitDetailsSection: some View {
        Section("Habit Details") {
            TextField("Habit Name", text: $habitName)
            TextField("Question", text: $question)
            colorPickerView
        }
    }
    
    @ViewBuilder
    private var colorPickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ForEach(colorOptions, id: \.self) { colorHex in
                    Circle()
                        .fill(Color(hex: colorHex) ?? .blue)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if color == colorHex {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            color = colorHex
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private var optionsSection: some View {
        Section("Options") {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                OptionCard(
                    option: optionBinding(for: index),
                    onDelete: {
                        optionToDelete = option
                        showingDeleteAlert = true
                    },
                    onEditPath: {
                        selectedOptionForBuilder = option
                    }
                )
            }
            
            if options.count < 4 {
                Button {
                    addNewOption()
                } label: {
                    Label("Add Option", systemImage: "plus.circle.fill")
                }
            }
        }
    }
    
    @ViewBuilder
    private var depthWarningSection: some View {
        if existingConditionalDepth >= 2 {
            Section {
                Label("Maximum nesting depth reached", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var colorOptions: [String] {
        ["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA", "#FFD60A", "#FF2D55"]
    }
    
    private func optionBinding(for index: Int) -> Binding<ConditionalOption> {
        Binding(
            get: { options[index] },
            set: { options[index] = $0 }
        )
    }
    
    private var isValid: Bool {
        !habitName.isEmpty && !question.isEmpty && options.count >= 2
    }
    
    private func addNewOption() {
        let newOption = ConditionalOption(
            text: "Option \(options.count + 1)",
            habits: []
        )
        options.append(newOption)
    }
    
    
    private func saveHabit() {
        let conditionalInfo = ConditionalHabitInfo(
            question: question,
            options: options
        )
        
        let habit = Habit(
            id: existingHabit?.id ?? UUID(),
            name: habitName,
            type: .conditional(conditionalInfo),
            isOptional: existingHabit?.isOptional ?? false,
            notes: existingHabit?.notes,
            color: color,
            order: existingHabit?.order ?? 0,
            isActive: existingHabit?.isActive ?? true
        )
        
        onSave(habit)
        dismiss()
    }
}

private struct OptionCard: View {
    @Binding var option: ConditionalOption
    let onDelete: () -> Void
    let onEditPath: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with editable text and delete button
            HStack {
                TextField("Option text", text: Binding(
                    get: { option.text },
                    set: { option.text = $0 }
                ))
                .font(.headline)
                .textFieldStyle(.plain)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            
            // Habits preview and actions
            if option.habits.isEmpty {
                VStack(spacing: 8) {
                    Text("No habits yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    
                    HStack(spacing: 12) {
                        QuickHabitButton(title: "Timer", icon: "timer") {
                            addQuickHabit(.timer(defaultDuration: 300))
                        }
                        QuickHabitButton(title: "Task", icon: "checkmark.square") {
                            addQuickHabit(.checkbox)
                        }
                        QuickHabitButton(title: "Counter", icon: "list.bullet") {
                            addQuickHabit(.counter(items: ["Item 1"]))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    // Compact habit list
                    ForEach(Array(option.habits.enumerated()), id: \.element.id) { index, habit in
                        CompactHabitRow(
                            habit: Binding(
                                get: { option.habits[index] },
                                set: { newHabit in
                                    var updatedOption = option
                                    updatedOption.habits[index] = newHabit
                                    option = updatedOption
                                }
                            )
                        ) {
                            // Delete habit
                            var updatedOption = option
                            updatedOption.habits.remove(at: index)
                            option = updatedOption
                        }
                    }
                    
                    // Edit path button
                    HStack {
                        Spacer()
                        
                        Button("Edit Path") {
                            onEditPath()
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func addQuickHabit(_ type: HabitType) {
        let habit = Habit(
            name: type.quickName,
            type: type,
            order: option.habits.count
        )
        var updatedOption = option
        updatedOption.habits.append(habit)
        option = updatedOption
    }
}

// MARK: - Supporting Views

private struct QuickHabitButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct CompactHabitRow: View {
    @Binding var habit: Habit
    let onDelete: () -> Void
    @State private var habitName: String
    @State private var showingEditor = false
    
    init(habit: Binding<Habit>, onDelete: @escaping () -> Void) {
        self._habit = habit
        self.onDelete = onDelete
        self._habitName = State(initialValue: habit.wrappedValue.name)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: habit.color) ?? .blue)
                .frame(width: 6, height: 6)
            
            TextField("Habit name", text: $habitName)
                .font(.caption)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .onSubmit {
                    habit.name = habitName
                }
                .onChange(of: habitName) { _, newName in
                    habit.name = newName
                }
            
            Spacer()
            
            Text(habit.type.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            habitName = habit.name
        }
        .sheet(isPresented: $showingEditor) {
            habitEditorView(for: habit)
        }
    }
    
    @ViewBuilder
    private func habitEditorView(for habitToEdit: Habit) -> some View {
        switch habitToEdit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: habitToEdit,
                habitLibrary: [],
                existingConditionalDepth: 0
            ) { updatedHabit in
                habit = updatedHabit
            }
        default:
            HabitEditorView(habit: habitToEdit) { updatedHabit in
                habit = updatedHabit
            }
        }
    }
}

// MARK: - Path Builder View
struct PathBuilderView: View {
    @Binding var option: ConditionalOption
    let habitLibrary: [Habit]
    let existingConditionalDepth: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showingHabitPicker = false
    @State private var selectedHabitType: HabitTypeCategory?
    @State private var optionText: String
    @State private var habits: [Habit]
    
    init(option: Binding<ConditionalOption>, habitLibrary: [Habit], existingConditionalDepth: Int) {
        self._option = option
        self.habitLibrary = habitLibrary
        self.existingConditionalDepth = existingConditionalDepth
        self._optionText = State(initialValue: option.wrappedValue.text)
        self._habits = State(initialValue: option.wrappedValue.habits)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Option Details") {
                    TextField("Option Text", text: $optionText)
                        .onChange(of: optionText) {
                            saveChanges()
                        }
                }
                
                Section("Path Habits") {
                    if habits.isEmpty {
                        ContentUnavailableView(
                            "No Habits",
                            systemImage: "list.bullet",
                            description: Text("Tap the + button to add habits to this path")
                        )
                    } else {
                        ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                            HabitRow(
                                habit: Binding(
                                    get: { habits[index] },
                                    set: { habits[index] = $0; saveChanges() }
                                )
                            ) {
                                // Delete habit
                                habits.remove(at: index)
                                saveChanges()
                            }
                        }
                        .onMove { from, to in
                            habits.move(fromOffsets: from, toOffset: to)
                            saveChanges()
                        }
                    }
                }
            }
            .navigationTitle("Path for '\(optionText)'")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingHabitPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerView(
                    habitLibrary: habitLibrary,
                    existingConditionalDepth: existingConditionalDepth,
                    onSelect: { habit in
                        print("🔍 PathBuilderView: onSelect called with habit - name: '\(habit.name)', type: \(habit.type)")
                        // Create a copy of the habit with new ID
                        let newHabit = Habit(
                            id: UUID(), // New ID for the copy
                            name: habit.name,
                            type: habit.type,
                            isOptional: habit.isOptional,
                            notes: habit.notes,
                            color: habit.color,
                            order: habits.count,
                            isActive: habit.isActive
                        )
                        print("🔍 PathBuilderView: Created new habit copy - name: '\(newHabit.name)', type: \(newHabit.type)")
                        habits.append(newHabit)
                        print("🔍 PathBuilderView: habits.count is now \(habits.count)")
                        saveChanges()
                    }
                )
            }
        }
    }
    
    private func saveChanges() {
        // Create a new ConditionalOption with the updated values
        option = ConditionalOption(
            id: option.id,
            text: optionText,
            habits: habits
        )
    }
}

// MARK: - Habit Row
struct HabitRow: View {
    @Binding var habit: Habit
    let onDelete: () -> Void
    @State private var habitName: String
    @State private var showingEditor = false
    
    init(habit: Binding<Habit>, onDelete: @escaping () -> Void) {
        self._habit = habit
        self.onDelete = onDelete
        self._habitName = State(initialValue: habit.wrappedValue.name)
    }
    
    var body: some View {
        let _ = print("🔍 HabitRow: Displaying habit - name: '\(habit.name)', type: \(habit.type), description: '\(habit.type.description)'")
        HStack {
            Circle()
                .fill(Color(hex: habit.color) ?? .blue)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                TextField("Habit name", text: $habitName)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        habit.name = habitName
                        print("🔍 HabitRow: Updated habit name to '\(habitName)'")
                    }
                    .onChange(of: habitName) { _, newName in
                        habit.name = newName
                        print("🔍 HabitRow: Changed habit name to '\(newName)'")
                    }
                
                Text(habit.type.description.isEmpty ? "EMPTY DESCRIPTION" : habit.type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(.blue.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            habitName = habit.name
        }
        .sheet(isPresented: $showingEditor) {
            habitEditorView(for: habit)
        }
    }
    
    @ViewBuilder
    private func habitEditorView(for habitToEdit: Habit) -> some View {
        switch habitToEdit.type {
        case .conditional:
            ConditionalHabitEditorView(
                existingHabit: habitToEdit,
                habitLibrary: [],
                existingConditionalDepth: 0
            ) { updatedHabit in
                habit = updatedHabit
            }
        default:
            HabitEditorView(habit: habitToEdit) { updatedHabit in
                habit = updatedHabit
            }
        }
    }
}

// MARK: - Habit Picker
struct HabitPickerView: View {
    let habitLibrary: [Habit]
    let existingConditionalDepth: Int
    let onSelect: (Habit) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTypeForSheet: HabitTypeCategory?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Create New") {
                    ForEach(HabitTypeCategory.allCases, id: \.self) { category in
                        // Hide conditional if at max depth
                        if !(category == .conditional && existingConditionalDepth >= 2) {
                            Button {
                                print("🔍 HabitPickerView: Button tapped for category: \(category)")
                                selectedTypeForSheet = category
                                print("🔍 HabitPickerView: selectedTypeForSheet set to: \(selectedTypeForSheet?.displayName ?? "nil")")
                            } label: {
                                Label(category.displayName, systemImage: category.iconName)
                            }
                        }
                    }
                }
                
                if !habitLibrary.isEmpty {
                    Section("Duplicate from Library") {
                        ForEach(habitLibrary.filter { filterHabit($0) }) { habit in
                            Button {
                                onSelect(habit)
                                dismiss()
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: habit.color) ?? .blue)
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading) {
                                        Text(habit.name)
                                        Text(habit.type.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTypeForSheet) { type in
                let _ = print("🔍 HabitPickerView: Sheet presenting with type: \(type)")
                habitEditorView(for: type)
            }
        }
    }
    
    private func filterHabit(_ habit: Habit) -> Bool {
        // Filter out conditional habits if at max depth
        if case .conditional = habit.type, existingConditionalDepth >= 2 {
            return false
        }
        return true
    }
    
    @ViewBuilder
    private func habitEditorView(for type: HabitTypeCategory) -> some View {
        switch type {
        case .checkbox:
            HabitEditorView(
                habit: Habit(name: "New Task", type: .checkbox)
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .timer:
            let timerHabit = Habit(name: "New Timer", type: .timer(defaultDuration: 300))
            let _ = print("🔍 HabitPickerView: Creating timer habit - name: '\(timerHabit.name)', type: \(timerHabit.type)")
            HabitEditorView(habit: timerHabit) { habit in
                print("🔍 HabitPickerView: Timer habit saved - name: '\(habit.name)', type: \(habit.type)")
                onSelect(habit)
                dismiss()
            }
        case .counter:
            HabitEditorView(
                habit: Habit(name: "New Counter", type: .counter(items: ["Item 1"]))
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .measurement:
            HabitEditorView(
                habit: Habit(name: "New Measurement", type: .measurement(unit: "kg", targetValue: nil))
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .appLaunch:
            HabitEditorView(
                habit: Habit(name: "New App", type: .appLaunch(bundleId: "", appName: ""))
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .website:
            HabitEditorView(
                habit: Habit(name: "New Website", type: .website(url: URL(string: "https://example.com")!, title: ""))
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .guidedSequence:
            HabitEditorView(
                habit: Habit(name: "New Sequence", type: .guidedSequence(steps: []))
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        case .conditional:
            ConditionalHabitEditorView(
                habitLibrary: habitLibrary,
                existingConditionalDepth: existingConditionalDepth
            ) { habit in
                onSelect(habit)
                dismiss()
            }
        }
    }
}

// MARK: - Habit Type Category
enum HabitTypeCategory: CaseIterable, Identifiable {
    case checkbox
    case timer
    case counter
    case measurement
    case appLaunch
    case website
    case guidedSequence
    case conditional
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .checkbox: return "Checkbox"
        case .timer: return "Timer"
        case .counter: return "Counter"
        case .measurement: return "Measurement"
        case .appLaunch: return "App Launch"
        case .website: return "Website/Shortcut"
        case .guidedSequence: return "Guided Sequence"
        case .conditional: return "Question"
        }
    }
    
    var iconName: String {
        switch self {
        case .checkbox: return "checkmark.square"
        case .timer: return "timer"
        case .counter: return "list.bullet"
        case .measurement: return "chart.line.uptrend.xyaxis"
        case .appLaunch: return "app.badge"
        case .website: return "safari"
        case .guidedSequence: return "list.number"
        case .conditional: return "questionmark.circle"
        }
    }
}