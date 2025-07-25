import SwiftUI

/// View for creating and editing conditional habits
public struct ConditionalHabitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var habitName: String
    @State private var question: String
    @State private var options: [ConditionalOption]
    @State private var color: String
    @State private var showingPathBuilder: Bool = false
    @State private var selectedOptionIndex: Int?
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
            _options = State(initialValue: [])
            _color = State(initialValue: "#007AFF")
        }
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Habit Details") {
                    TextField("Habit Name", text: $habitName)
                    TextField("Question", text: $question)
                    // Color picker using predefined colors (similar to HabitEditorView)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 12) {
                            ForEach(["#34C759", "#007AFF", "#FF9500", "#FF3B30", "#AF52DE", "#5AC8FA", "#FFD60A", "#FF2D55"], id: \.self) { colorHex in
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
                
                Section("Options") {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        OptionCard(
                            option: option,
                            onTap: {
                                selectedOptionIndex = index
                                showingPathBuilder = true
                            },
                            onDelete: {
                                optionToDelete = option
                                showingDeleteAlert = true
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
                
                if existingConditionalDepth >= 2 {
                    Section {
                        Label("Maximum nesting depth reached", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
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
            .sheet(isPresented: $showingPathBuilder) {
                if let index = selectedOptionIndex {
                    PathBuilderView(
                        option: binding(for: index),
                        habitLibrary: habitLibrary,
                        existingConditionalDepth: existingConditionalDepth + 1
                    )
                }
            }
            .alert("Delete Option", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let option = optionToDelete {
                        options.removeAll { $0.id == option.id }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this option? This will also delete all habits in its path.")
            }
        }
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
    
    private func binding(for index: Int) -> Binding<ConditionalOption> {
        Binding(
            get: { options[index] },
            set: { options[index] = $0 }
        )
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
    let option: ConditionalOption
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.text)
                    .font(.headline)
                
                if option.habits.isEmpty {
                    Text("No habits - continues to next")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(option.habits.count) habit\(option.habits.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
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
                            HabitRow(habit: habit) {
                                // Delete habit
                                habits.remove(at: index)
                            }
                        }
                        .onMove { from, to in
                            habits.move(fromOffsets: from, toOffset: to)
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
                        habits.append(newHabit)
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
    let habit: Habit
    let onDelete: () -> Void
    
    var body: some View {
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
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Habit Picker
struct HabitPickerView: View {
    let habitLibrary: [Habit]
    let existingConditionalDepth: Int
    let onSelect: (Habit) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: HabitTypeCategory?
    @State private var showingNewHabitEditor = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Create New") {
                    ForEach(HabitTypeCategory.allCases, id: \.self) { category in
                        // Hide conditional if at max depth
                        if !(category == .conditional && existingConditionalDepth >= 2) {
                            Button {
                                selectedType = category
                                showingNewHabitEditor = true
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
            .sheet(isPresented: $showingNewHabitEditor) {
                if let type = selectedType {
                    habitEditorView(for: type)
                }
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
            HabitEditorView(
                habit: Habit(name: "New Timer", type: .timer(defaultDuration: 300))
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
        // Add other cases as needed
        default:
            EmptyView()
        }
    }
}

// MARK: - Habit Type Category
enum HabitTypeCategory: CaseIterable {
    case checkbox
    case timer
    case counter
    case measurement
    case appLaunch
    case website
    case guidedSequence
    case conditional
    
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